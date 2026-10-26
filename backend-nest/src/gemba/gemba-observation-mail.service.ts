import { Injectable, Logger } from '@nestjs/common';
import { existsSync } from 'fs';
import { basename, join } from 'path';
import { GembaMailInlineAttachment, MailService } from '../mail/mail.service';
import {
  buildGembaObservationEmailHtml,
  buildGembaObservationEmailSubject,
  buildGembaObservationEmailText,
  GembaEmailKind,
  GembaObservationEmailData,
} from '../mail/gemba-observation-email.template';
import {
  GEMBA_EMAIL_CC,
  GEMBA_EMAIL_TESTING_MODE,
  resolveGembaRecipients,
} from './gemba-email-recipients';
import { GembaEmployeesService } from './gemba-employees.service';
import { GembaObservationWithPhotos } from './gemba-observation.mapper';

type PreparedGembaEmail = {
  data: GembaObservationEmailData;
  inlineAttachments: GembaMailInlineAttachment[];
};

@Injectable()
export class GembaObservationMailService {
  private readonly logger = new Logger(GembaObservationMailService.name);

  constructor(
    private readonly mailService: MailService,
    private readonly employeesService: GembaEmployeesService,
  ) {}

  /** Notify assignee when a new observation is created (one email per observation). */
  async sendAssignedNotification(
    observation: GembaObservationWithPhotos,
  ): Promise<void> {
    const assigneeNumber = observation.assignedEmployeeNumber.trim();
    const sfEmail = await this.employeesService.fetchUserEmail(assigneeNumber);
    const recipients = resolveGembaRecipients(sfEmail);

    if (recipients.length === 0) {
      this.logger.warn(
        `Skipping assigned email for observation ${observation.id}: ` +
          `no email for assignee ${assigneeNumber}`,
      );
      return;
    }

    await this.sendObservationEmail('assigned', observation, recipients, sfEmail);
  }

  /** Notify observation creator when assignee marks it done (never the assignee). */
  async sendCompletedNotification(
    observation: GembaObservationWithPhotos,
  ): Promise<void> {
    const creatorNumber = observation.createdByEmployeeNumber.trim();
    const assigneeNumber = observation.assignedEmployeeNumber.trim();

    if (!creatorNumber) {
      this.logger.warn(
        `Skipping completed email for observation ${observation.id}: no creator`,
      );
      return;
    }

    const sfEmail = await this.employeesService.fetchUserEmail(creatorNumber);
    const recipients = resolveGembaRecipients(sfEmail);

    if (recipients.length === 0) {
      this.logger.warn(
        `Skipping completed email for observation ${observation.id}: ` +
          `no email for creator ${creatorNumber}`,
      );
      return;
    }

    this.logger.log(
      `Completion email for observation ${observation.id}: ` +
        `creator=${creatorNumber}, assignee=${assigneeNumber} (not notified)`,
    );

    await this.sendObservationEmail('completed', observation, recipients, sfEmail);
  }

  private async sendObservationEmail(
    kind: GembaEmailKind,
    observation: GembaObservationWithPhotos,
    recipients: string[],
    sfEmail: string | null,
  ): Promise<void> {
    const prepared = this.prepareEmailContent(kind, observation);
    const subject = buildGembaObservationEmailSubject(kind, prepared.data);
    const html = buildGembaObservationEmailHtml(kind, prepared.data);
    const text = buildGembaObservationEmailText(kind, prepared.data);

    if (GEMBA_EMAIL_TESTING_MODE) {
      this.logger.warn(
        `GEMBA_EMAIL_TESTING_MODE active -> To: ${recipients.join(', ')} ` +
          `(SF target: ${sfEmail ?? 'none'})`,
      );
    }

    this.logger.log(
      `Sending Gemba ${kind} email for observation ${observation.id} ` +
        `with ${prepared.inlineAttachments.length} embedded photo(s) To: ${recipients.join(', ')}`,
    );

    await this.mailService.sendGembaEmail({
      recipients,
      cc: GEMBA_EMAIL_CC ? [GEMBA_EMAIL_CC] : [],
      subject,
      html,
      text,
      inlineAttachments: prepared.inlineAttachments,
    });
  }

  private prepareEmailContent(
    kind: GembaEmailKind,
    observation: GembaObservationWithPhotos,
  ): PreparedGembaEmail {
    const beforePhotos = observation.photos
      .filter((p) => p.kind === 'before')
      .sort((a, b) => a.sortOrder - b.sortOrder);
    const afterPhotos = observation.photos
      .filter((p) => p.kind === 'after')
      .sort((a, b) => a.sortOrder - b.sortOrder);

    const inlineAttachments: GembaMailInlineAttachment[] = [];
    const beforePhotoCids = this.embedPhotos(
      observation.id,
      'before',
      beforePhotos,
      inlineAttachments,
    );
    const afterPhotoCids =
      kind === 'completed'
        ? this.embedPhotos(
            observation.id,
            'after',
            afterPhotos,
            inlineAttachments,
          )
        : [];

    return {
      data: {
        id: observation.id,
        title: observation.title,
        location: observation.location,
        category: observation.category,
        status: observation.status,
        company: observation.company,
        bu: observation.bu,
        section: observation.section,
        machineValue: observation.machineValue,
        remarks: observation.remarks,
        afterRemarks: observation.afterRemarks,
        assignedEmployeeNumber: observation.assignedEmployeeNumber,
        assignedEmployeeName: observation.assignedEmployeeName,
        createdByEmployeeNumber: observation.createdByEmployeeNumber,
        createdByName: observation.createdByName,
        completedByEmployeeNumber: observation.completedByEmployeeNumber,
        completedByName: observation.completedByName,
        createdAt: observation.createdAt,
        completedAt: observation.completedAt,
        beforePhotoCids,
        afterPhotoCids,
      },
      inlineAttachments,
    };
  }

  /** Attach photos with Content-ID so HTML renders them without remote downloads. */
  private embedPhotos(
    observationId: string,
    prefix: 'before' | 'after',
    photos: Array<{ url: string }>,
    out: GembaMailInlineAttachment[],
  ): string[] {
    const cids: string[] = [];
    const seen = new Set<string>();

    photos.forEach((photo, index) => {
      const localPath = this.resolveLocalUploadPath(photo.url);
      if (!localPath || seen.has(localPath)) return;
      seen.add(localPath);

      const cid = `gemba-${observationId}-${prefix}-${index}@digital-gemba`;
      cids.push(cid);
      out.push({
        cid,
        path: localPath,
        filename: `${prefix}_${index + 1}_${basename(localPath)}`,
      });
    });

    return cids;
  }

  /** Resolve `/uploads/gemba/{file}` or gemba upload paths to disk. */
  private resolveLocalUploadPath(urlOrPath: string): string | null {
    const trimmed = urlOrPath.trim();
    if (!trimmed) return null;

    if (existsSync(trimmed) && /uploads[/\\]/i.test(trimmed)) {
      return trimmed;
    }

    const gembaMatch =
      trimmed.match(/\/uploads\/gemba\/([^/?#]+)/i) ??
      trimmed.match(/uploads[/\\]gemba[/\\]([^/?#]+)/i);
    if (gembaMatch?.[1]) {
      const fullPath = join(
        process.cwd(),
        'uploads',
        'gemba',
        decodeURIComponent(gembaMatch[1]),
      );
      return existsSync(fullPath) ? fullPath : null;
    }

    const genericMatch =
      trimmed.match(/\/uploads\/([^/?#]+)/i) ??
      trimmed.match(/uploads[/\\]([^/?#]+)/i);
    const fileName = genericMatch?.[1];
    if (!fileName) return null;

    const fullPath = join(process.cwd(), 'uploads', decodeURIComponent(fileName));
    return existsSync(fullPath) ? fullPath : null;
  }
}
