import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';
import { CreateAssessmentDto } from './dto/create-assessment.dto';
import {
  ASSESSMENT_CC_EMAIL,
  EMAIL_TESTING_MODE,
  EMAIL_TESTING_RECIPIENTS,
  getCompanyExtraRecipients,
  getDirectoryRecipients,
} from './assessment-recipients';

@Injectable()
export class AssessmentsService {
  private readonly logger = new Logger(AssessmentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly mailService: MailService,
    private readonly configService: ConfigService,
  ) {}

  async create(dto: CreateAssessmentDto, createdById?: string) {
    const created = await this.prisma.assessment.create({
      data: {
        id: dto.id,
        company: dto.company,
        bu: dto.bu,
        section: dto.section,
        auditorName: dto.auditorName,
        auditeeName: dto.auditeeName,
        auditorEmail: dto.auditorEmail,
        auditeeEmail: dto.auditeeEmail,
        userName: dto.userName,
        employeeId: dto.employeeId,
        score: dto.score,
        isFlagged: dto.isFlagged,
        followUpDueAt: dto.followUpDueAt ? new Date(dto.followUpDueAt) : null,
        followUpSent: dto.followUpSent ?? false,
        resolved: dto.resolved ?? false,
        resolvedAt: dto.resolvedAt ? new Date(dto.resolvedAt) : null,
        resolvedBy: dto.resolvedBy,
        createdAt: dto.date ? new Date(dto.date) : undefined,
        createdById,
        items: {
          create: dto.items.map((item) => ({
            question: item.question,
            answer: item.answer,
            remarks: item.remarks ?? '',
            isFlagged: item.isFlagged,
            attachments: {
              create: this.extractAttachments(item),
            },
          })),
        },
      },
      include: { items: { include: { attachments: true } } },
    });

    // Fire-and-forget: submit returns without waiting on SMTP.
    void this.sendAssessmentEmail(created.id).catch((error: unknown) => {
      this.logger.error(
        `Assessment ${created.id} saved but email notification failed`,
        error instanceof Error ? error.stack : String(error),
      );
    });

    return created;
  }

  findAll() {
    return this.prisma.assessment.findMany({
      include: { items: { include: { attachments: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  findOne(id: string) {
    return this.prisma.assessment.findUnique({
      where: { id },
      include: { items: { include: { attachments: true } } },
    });
  }

  private extractAttachments(item: {
    attachments?: { localPath?: string; url?: string }[];
    imagePaths?: string[];
    imageUrls?: string[];
  }) {
    const attachments = item.attachments ?? [];
    const oldPathEntries = (item.imagePaths ?? []).map((p) => ({ localPath: p }));
    const oldUrlEntries = (item.imageUrls ?? []).map((u) => ({ url: u }));
    const merged = [...attachments, ...oldPathEntries, ...oldUrlEntries];
    return merged.filter((entry) => 'localPath' in entry || 'url' in entry);
  }

  private async sendAssessmentEmail(assessmentId: string): Promise<void> {
    const assessment = await this.prisma.assessment.findUnique({
      where: { id: assessmentId },
      include: {
        items: { include: { attachments: true } },
        createdBy: { select: { email: true } },
      },
    });
    if (!assessment) return;

    const recipientPlan = await this.buildRecipientPlan(assessment);
    if (recipientPlan.toRecipients.length === 0) {
      throw new Error(
        `No recipients found for assessment email (${assessmentId}).`,
      );
    }

    this.logger.log(
      `Assessment ${assessmentId} email To (${recipientPlan.toRecipients.length}): ${recipientPlan.toRecipients.join(', ')}` +
        (recipientPlan.cc.length
          ? `; CC: ${recipientPlan.cc.join(', ')}`
          : ''),
    );

    const subject = `5S Assessment - ${assessment.company} - ${assessment.bu ?? 'N/A'} - ${assessment.section ?? 'N/A'}`;
    const html = this.buildHtml(assessment);
    const text = this.buildText(assessment);

    await this.mailService.sendAssessmentEmail({
      recipients: recipientPlan.toRecipients,
      ...(recipientPlan.cc.length > 0 ? { cc: recipientPlan.cc } : {}),
      subject,
      html,
      text,
    });
  }

  private async buildRecipientPlan(assessment: {
    company: string;
    bu: string | null;
    section: string | null;
    auditorEmail: string | null;
    auditeeEmail: string | null;
    createdBy: { email: string } | null;
  }): Promise<{ toRecipients: string[]; cc: string[] }> {
    if (EMAIL_TESTING_MODE) {
      this.logger.warn(
        `EMAIL_TESTING_MODE active -> To: ${EMAIL_TESTING_RECIPIENTS.join(', ')}`,
      );
      return {
        toRecipients: [...EMAIL_TESTING_RECIPIENTS],
        cc: [],
      };
    }

    const fromDirectory = getDirectoryRecipients(
      assessment.bu,
      assessment.section,
    );
    const fromDb = await this.resolveRecipientsFromUsers(
      assessment.bu ?? '',
      assessment.section ?? '',
    );
    const fromCompany = getCompanyExtraRecipients(assessment.company);
    const merged = Array.from(
      new Set([
        ...fromDirectory,
        ...fromDb,
        ...fromCompany,
        ...this.collectParticipantEmails(assessment),
      ].map((e) => e.toLowerCase())),
    );

    const toRecipients = merged.filter(
      (e) => e !== ASSESSMENT_CC_EMAIL.toLowerCase(),
    );

    return {
      toRecipients,
      cc: [ASSESSMENT_CC_EMAIL],
    };
  }

  private collectParticipantEmails(assessment: {
    auditorEmail: string | null;
    auditeeEmail: string | null;
    createdBy: { email: string } | null;
  }): string[] {
    const out: string[] = [];
    const add = (raw?: string | null) => {
      const t = raw?.trim();
      if (t && this.isLikelyEmail(t)) {
        out.push(t.toLowerCase());
      }
    };
    add(assessment.auditorEmail);
    add(assessment.auditeeEmail);
    add(assessment.createdBy?.email);
    return out;
  }

  private isLikelyEmail(s: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
  }

  /** Fallback / overlap with directory: users in DB for the same BU/section. */
  private async resolveRecipientsFromUsers(bu: string, section: string) {
    const users = await this.prisma.user.findMany({
      where: {
        OR: [
          { businessUnit: bu, section },
          { businessUnit: bu, section: null },
          { role: 'admin' },
          { role: 'power_user' },
        ],
      },
      select: { email: true },
    });
    return Array.from(
      new Set(
        users
          .map((u) => u.email)
          .filter((e): e is string => typeof e === 'string' && e.length > 0),
      ),
    );
  }

  private absoluteUrl(url: string | null | undefined): string | null {
    if (!url) return null;
    if (/^https?:\/\//i.test(url)) return url;
    const base =
      this.configService.get<string>('PUBLIC_API_URL') ??
      this.configService.get<string>('API_BASE_URL') ??
      'https://5s-api.packagesgroup.com';
    const normalizedBase = base.replace(/\/$/, '');
    const path = url.startsWith('/') ? url : `/${url}`;
    return `${normalizedBase}${path}`;
  }

  private buildHtml(assessment: {
    id: string;
    company: string;
    bu: string | null;
    section: string | null;
    auditorName: string;
    auditeeName: string;
    score: number;
    items: Array<{
      question: string;
      answer: string;
      remarks: string | null;
      attachments: Array<{ url: string | null }>;
    }>;
  }) {
    const rows = assessment.items
      .map((item, idx) => {
        const links = item.attachments
          .map((a) => this.absoluteUrl(a.url))
          .filter((u): u is string => typeof u === 'string' && u.length > 0)
          .map((u) => `<a href="${u}">${u}</a>`)
          .join('<br/>');
        return `<tr><td>${idx + 1}</td><td>${item.question}</td><td>${item.answer}</td><td>${item.remarks ?? ''}</td><td>${links}</td></tr>`;
      })
      .join('');

    return `<h2>5S Assessment Completed</h2>
<p><strong>Company:</strong> ${assessment.company}</p>
<p><strong>BU:</strong> ${assessment.bu ?? 'N/A'} | <strong>Section:</strong> ${assessment.section ?? 'N/A'}</p>
<p><strong>Auditor:</strong> ${assessment.auditorName} | <strong>Auditee:</strong> ${assessment.auditeeName}</p>
<p><strong>Score:</strong> ${assessment.score}%</p>
<table border="1" cellpadding="6" cellspacing="0">
<thead><tr><th>#</th><th>Question</th><th>Answer</th><th>Remarks</th><th>Image Links</th></tr></thead>
<tbody>${rows}</tbody></table>`;
  }

  private buildText(assessment: {
    company: string;
    bu: string | null;
    section: string | null;
    auditorName: string;
    auditeeName: string;
    score: number;
    items: Array<{
      question: string;
      answer: string;
      remarks: string | null;
      attachments: Array<{ url: string | null }>;
    }>;
  }) {
    const lines: string[] = [];
    lines.push('5S Assessment Completed');
    lines.push(`Company: ${assessment.company}`);
    lines.push(`BU: ${assessment.bu ?? 'N/A'} | Section: ${assessment.section ?? 'N/A'}`);
    lines.push(`Auditor: ${assessment.auditorName} | Auditee: ${assessment.auditeeName}`);
    lines.push(`Score: ${assessment.score}%`);
    lines.push('');
    assessment.items.forEach((item, idx) => {
      lines.push(`Q${idx + 1}: ${item.question}`);
      lines.push(`Answer: ${item.answer}`);
      if (item.remarks) lines.push(`Remarks: ${item.remarks}`);
      item.attachments
        .map((a) => this.absoluteUrl(a.url))
        .filter((url): url is string => typeof url === 'string' && url.length > 0)
        .forEach((url) => lines.push(`Image: ${url}`));
      lines.push('');
    });
    return lines.join('\n');
  }
}
