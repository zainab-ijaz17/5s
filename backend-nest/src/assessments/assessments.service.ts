import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { existsSync } from 'fs';
import { mkdtemp, unlink, writeFile } from 'fs/promises';
import { basename, join } from 'path';
import { tmpdir } from 'os';
import { randomUUID } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';
import { CreateAssessmentDto } from './dto/create-assessment.dto';
import {
  EMAIL_TESTING_MODE,
  EMAIL_TESTING_RECIPIENTS,
  getCompanyExtraRecipients,
  getDirectoryRecipients,
} from './assessment-recipients';
import {
  buildAssessmentEmailHtml,
  buildAssessmentEmailText,
  buildFollowUpEmailHtml,
  buildFollowUpEmailSubject,
  buildFollowUpEmailText,
} from '../mail/assessment-email.template';

type AssessmentEmailRecord = {
  id: string;
  company: string;
  bu: string | null;
  section: string | null;
  auditorName: string;
  auditeeName: string;
  auditorEmail: string | null;
  auditeeEmail: string | null;
  score: number;
  isFlagged: boolean;
  createdAt: Date;
  items: Array<{
    question: string;
    answer: string;
    remarks: string | null;
    isFlagged: boolean;
    attachments: Array<{ url: string | null; localPath?: string | null }>;
  }>;
  createdBy?: { email: string } | null;
};

@Injectable()
export class AssessmentsService {
  private readonly logger = new Logger(AssessmentsService.name);
  /** Prevents accidental duplicate notification mails for the same assessment id. */
  private readonly emailedAssessmentIds = new Set<string>();
  /** Prevents duplicate follow-up mails per assessment id (in-memory guard). */
  private readonly followUpEmailedIds = new Set<string>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly mailService: MailService,
    private readonly configService: ConfigService,
  ) {}

  async create(dto: CreateAssessmentDto, createdById?: string) {
    // Save the FULL assessment + all items + all attachment URLs in one write.
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

    const attachmentCount = created.items.reduce(
      (sum, item) => sum + item.attachments.length,
      0,
    );
    this.logger.log(
      `Assessment ${created.id} fully saved: ${created.items.length} item(s), ` +
        `${attachmentCount} attachment URL(s). Queueing ONE combined email.`,
    );

    // Only after full payload is in DB — one combined mail, no file-attachment mail.
    void this.sendAssessmentEmailFromSaved(created).catch((error: unknown) => {
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

  /**
   * Send follow-up emails for overdue flagged assessments (DB is source of truth).
   * Called by cron and POST /assessments/follow-ups/sweep.
   */
  async sweepFollowUpEmails(): Promise<{
    processed: number;
    sent: number;
    errors: string[];
  }> {
    const now = new Date();
    const due = await this.prisma.assessment.findMany({
      where: {
        isFlagged: true,
        resolved: false,
        followUpSent: false,
        followUpDueAt: { not: null, lte: now },
      },
      include: {
        items: { include: { attachments: true } },
        createdBy: { select: { email: true } },
      },
      orderBy: { followUpDueAt: 'asc' },
    });

    let sent = 0;
    const errors: string[] = [];

    for (const assessment of due) {
      try {
        await this.sendFollowUpEmailFromSaved(assessment);
        await this.prisma.assessment.update({
          where: { id: assessment.id },
          data: { followUpSent: true },
        });
        sent += 1;
      } catch (error: unknown) {
        const message =
          error instanceof Error ? error.message : String(error);
        errors.push(`${assessment.id}: ${message}`);
        this.logger.error(
          `Follow-up email failed for ${assessment.id}: ${message}`,
          error instanceof Error ? error.stack : undefined,
        );
      }
    }

    return { processed: due.length, sent, errors };
  }

  private extractAttachments(item: {
    attachments?: { localPath?: string; url?: string }[];
    imagePaths?: string[];
    imageUrls?: string[];
  }) {
    const rows: { localPath?: string; url?: string }[] = [];

    for (const attachment of item.attachments ?? []) {
      rows.push({
        localPath: attachment.localPath,
        url: attachment.url,
      });
    }
    for (const path of item.imagePaths ?? []) {
      rows.push({ localPath: path });
    }
    for (const url of item.imageUrls ?? []) {
      rows.push({ url });
    }

    const cleaned = rows
      .map((entry) => {
        const localPath =
          typeof entry.localPath === 'string' && entry.localPath.trim()
            ? entry.localPath.trim()
            : undefined;
        const url =
          typeof entry.url === 'string' && entry.url.trim()
            ? entry.url.trim()
            : undefined;
        return { localPath, url };
      })
      .filter((entry) => !!entry.localPath || !!entry.url);

    this.logger.log(
      `Extracted ${cleaned.length} attachment(s) for item ` +
        `(urls=${cleaned.filter((e) => e.url).length})`,
    );
    return cleaned;
  }

  private async sendAssessmentEmailFromSaved(
    assessment: AssessmentEmailRecord,
  ): Promise<void> {
    // Mark first to block parallel/duplicate sends for this assessment id.
    if (this.emailedAssessmentIds.has(assessment.id)) {
      this.logger.warn(
        `Skipping duplicate assessment email for ${assessment.id}`,
      );
      return;
    }
    this.emailedAssessmentIds.add(assessment.id);

    // Prefer createdBy from DB if missing on the saved graph.
    let createdBy = assessment.createdBy ?? null;
    if (!createdBy) {
      const withUser = await this.prisma.assessment.findUnique({
        where: { id: assessment.id },
        select: { createdBy: { select: { email: true } } },
      });
      createdBy = withUser?.createdBy ?? null;
    }

    const recipientPlan = await this.buildRecipientPlan({
      company: assessment.company,
      bu: assessment.bu,
      section: assessment.section,
      auditorEmail: assessment.auditorEmail,
      auditeeEmail: assessment.auditeeEmail,
      createdBy,
    });
    if (recipientPlan.toRecipients.length === 0) {
      throw new Error(
        `No recipients found for assessment email (${assessment.id}).`,
      );
    }

    this.logger.log(
      `Sending ONE combined assessment email for ${assessment.id} ` +
        `(${assessment.items.length} questions) To: ${recipientPlan.toRecipients.join(', ')}` +
        (recipientPlan.cc.length
          ? `; CC: ${recipientPlan.cc.join(', ')}`
          : ''),
    );

    const subject = `5S Assessment - ${assessment.company} - ${assessment.bu ?? 'N/A'} - ${assessment.section ?? 'N/A'}`;
    const resolveUrl = (url: string | null | undefined) =>
      this.absoluteUrl(url);
    const html = buildAssessmentEmailHtml(assessment, resolveUrl);
    const text = buildAssessmentEmailText(assessment, resolveUrl);
    const { attachments: fileAttachments, tempFiles } =
      await this.collectFileAttachmentsAsync(assessment.items);

    this.logger.log(
      `Assessment ${assessment.id}: attaching ${fileAttachments.length} photo file(s) to email`,
    );

    try {
      await this.mailService.sendAssessmentEmail({
        recipients: recipientPlan.toRecipients,
        ...(recipientPlan.cc.length > 0 ? { cc: recipientPlan.cc } : {}),
        subject,
        html,
        text,
        fileAttachments,
      });
    } finally {
      await this.cleanupTempFiles(tempFiles);
    }
  }

  private async sendFollowUpEmailFromSaved(
    assessment: AssessmentEmailRecord,
  ): Promise<void> {
    if (this.followUpEmailedIds.has(assessment.id)) {
      this.logger.warn(
        `Skipping duplicate follow-up email for ${assessment.id}`,
      );
      return;
    }
    this.followUpEmailedIds.add(assessment.id);

    let createdBy = assessment.createdBy ?? null;
    if (!createdBy) {
      const withUser = await this.prisma.assessment.findUnique({
        where: { id: assessment.id },
        select: { createdBy: { select: { email: true } } },
      });
      createdBy = withUser?.createdBy ?? null;
    }

    const recipientPlan = await this.buildRecipientPlan({
      company: assessment.company,
      bu: assessment.bu,
      section: assessment.section,
      auditorEmail: assessment.auditorEmail,
      auditeeEmail: assessment.auditeeEmail,
      createdBy,
    });
    if (recipientPlan.toRecipients.length === 0) {
      throw new Error(
        `No recipients found for follow-up email (${assessment.id}).`,
      );
    }

    const subject = buildFollowUpEmailSubject(assessment);
    const html = buildFollowUpEmailHtml(assessment);
    const text = buildFollowUpEmailText(assessment);
    const { attachments: fileAttachments, tempFiles } =
      await this.collectFileAttachmentsAsync(assessment.items);

    this.logger.log(
      `Follow-up ${assessment.id}: attaching ${fileAttachments.length} photo file(s)`,
    );

    try {
      await this.mailService.sendAssessmentEmail({
        recipients: recipientPlan.toRecipients,
        ...(recipientPlan.cc.length > 0 ? { cc: recipientPlan.cc } : {}),
        subject,
        html,
        text,
        fileAttachments,
      });
    } finally {
      await this.cleanupTempFiles(tempFiles);
    }
  }

  /** Build SMTP file attachments from uploads dir or by downloading saved URLs. */
  private async collectFileAttachmentsAsync(
    items: Array<{
      attachments: Array<{ url: string | null; localPath?: string | null }>;
    }>,
  ): Promise<{
    attachments: { filename: string; path: string }[];
    tempFiles: string[];
  }> {
    const attachments: { filename: string; path: string }[] = [];
    const tempFiles: string[] = [];
    const seen = new Set<string>();

    for (let questionIndex = 0; questionIndex < items.length; questionIndex++) {
      const item = items[questionIndex];
      let photoIndex = 0;
      for (const att of item.attachments) {
        for (const candidate of this.listAttachmentSources(att)) {
          const dedupeKey = this.attachmentDedupeKey(candidate);
          if (seen.has(dedupeKey)) continue;

          const resolved = await this.resolveAttachmentFile(candidate);
          if (!resolved) {
            this.logger.warn(
              `Assessment attachment unavailable for Q${questionIndex + 1}: ${candidate}`,
            );
            continue;
          }

          seen.add(dedupeKey);
          if (resolved.isTemp) tempFiles.push(resolved.path);
          photoIndex += 1;
          const original = basename(resolved.path);
          attachments.push({
            filename: `Q${questionIndex + 1}_${photoIndex}_${original}`,
            path: resolved.path,
          });
        }
      }
    }

    if (attachments.length === 0) {
      this.logger.warn(
        'No assessment photo attachments resolved (check /uploads files or image URLs)',
      );
    }

    return { attachments, tempFiles };
  }

  private listAttachmentSources(att: {
    url: string | null;
    localPath?: string | null;
  }): string[] {
    const sources: string[] = [];
    const url = att.url?.trim();
    if (url) sources.push(url);

    const localPath = att.localPath?.trim();
    if (
      localPath &&
      (/uploads[/\\]/i.test(localPath) || /^https?:\/\//i.test(localPath))
    ) {
      sources.push(localPath);
    }
    return sources;
  }

  private attachmentDedupeKey(source: string): string {
    const match =
      source.match(/\/uploads\/([^/?#]+)/i) ??
      source.match(/uploads[/\\]([^/?#]+)/i);
    if (match?.[1]) return decodeURIComponent(match[1]).toLowerCase();
    return source.trim().toLowerCase();
  }

  private async resolveAttachmentFile(
    urlOrPath: string,
  ): Promise<{ path: string; isTemp: boolean } | null> {
    const localPath = this.resolveLocalUploadPath(urlOrPath);
    if (localPath) {
      return { path: localPath, isTemp: false };
    }

    const absoluteUrl = this.absoluteUrl(urlOrPath);
    if (!absoluteUrl || !/^https?:\/\//i.test(absoluteUrl)) {
      return null;
    }

    try {
      const response = await fetch(absoluteUrl);
      if (!response.ok) {
        this.logger.warn(
          `Could not download attachment ${absoluteUrl}: HTTP ${response.status}`,
        );
        return null;
      }

      const buffer = Buffer.from(await response.arrayBuffer());
      if (buffer.length === 0) return null;

      let fileName = 'photo.jpg';
      try {
        fileName = basename(new URL(absoluteUrl).pathname) || fileName;
      } catch {
        fileName = basename(urlOrPath.split('?')[0] ?? '') || fileName;
      }

      const tempDir = await mkdtemp(join(tmpdir(), '5s-email-'));
      const tempPath = join(tempDir, `${randomUUID()}-${fileName}`);
      await writeFile(tempPath, buffer);
      return { path: tempPath, isTemp: true };
    } catch (error: unknown) {
      this.logger.warn(
        `Attachment download failed for ${absoluteUrl}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      return null;
    }
  }

  private async cleanupTempFiles(paths: string[]) {
    for (const filePath of paths) {
      try {
        await unlink(filePath);
      } catch {
        // ignore missing temp files
      }
    }
  }

  private resolveLocalUploadPath(urlOrPath: string): string | null {
    const trimmed = urlOrPath.trim();
    if (!trimmed) return null;

    const uploadsDir =
      this.configService.get<string>('UPLOADS_DIR')?.trim() ||
      join(process.cwd(), 'uploads');

    if (existsSync(trimmed) && /uploads[/\\]/i.test(trimmed)) {
      return trimmed;
    }

    const match =
      trimmed.match(/\/uploads\/([^/?#]+)/i) ??
      trimmed.match(/uploads[/\\]([^/?#]+)/i);
    const fileName = match?.[1];
    if (!fileName) return null;

    const decoded = decodeURIComponent(fileName);
    const candidates = [
      join(uploadsDir, decoded),
      join(process.cwd(), 'uploads', decoded),
    ];
    for (const fullPath of candidates) {
      if (existsSync(fullPath)) return fullPath;
    }
    return null;
  }

  /** @deprecated use sendAssessmentEmailFromSaved after full create */
  private async sendAssessmentEmail(assessmentId: string): Promise<void> {
    if (this.emailedAssessmentIds.has(assessmentId)) {
      this.logger.warn(
        `Skipping duplicate assessment email for ${assessmentId}`,
      );
      return;
    }

    const assessment = await this.prisma.assessment.findUnique({
      where: { id: assessmentId },
      include: {
        items: { include: { attachments: true } },
        createdBy: { select: { email: true } },
      },
    });
    if (!assessment) return;
    await this.sendAssessmentEmailFromSaved(assessment);
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

    /*
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
    */

    return {
      toRecipients: [...EMAIL_TESTING_RECIPIENTS],
      cc: [],
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
}
