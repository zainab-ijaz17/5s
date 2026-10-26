import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { existsSync } from 'fs';
import { readFile } from 'fs/promises';
import { MailerService } from '@nestjs-modules/mailer';

export type AssessmentMailFileAttachment = {
  filename: string;
  path: string;
  contentType?: string;
};

/** Inline image embedded in HTML via `cid:` (loads with the email, no remote fetch). */
export type GembaMailInlineAttachment = {
  filename: string;
  path: string;
  cid: string;
};

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);

  constructor(
    private readonly mailer: MailerService,
    private readonly configService: ConfigService,
  ) {}

  /**
   * ONE combined assessment email:
   * - Full HTML body (no inline images / image links)
   * - Photos as real SMTP file attachments only
   */
  async sendAssessmentEmail(params: {
    recipients: string[];
    cc?: string[];
    subject: string;
    html: string;
    text: string;
    fileAttachments?: AssessmentMailFileAttachment[];
  }) {
    if (!params.recipients.length) {
      throw new Error('No recipients found for assessment email.');
    }

    const fromEmail =
      this.configService.get<string>('SMTP_FROM') ??
      this.configService.get<string>('SMTP_USER');
    if (!fromEmail) {
      throw new Error('SMTP_FROM or SMTP_USER must be set to send mail.');
    }
    const from = `5S <${fromEmail}>`;

    const cc = params.cc?.filter(Boolean) ?? [];
    const fileAttachments = params.fileAttachments ?? [];

    const smtpAttachments: Array<{
      filename: string;
      content: Buffer;
      contentType?: string;
      contentDisposition: 'attachment';
    }> = [];

    for (const file of fileAttachments) {
      if (!existsSync(file.path)) {
        this.logger.warn(`Assessment attachment missing on disk: ${file.path}`);
        continue;
      }
      try {
        const content = await readFile(file.path);
        if (content.length === 0) {
          this.logger.warn(`Assessment attachment empty: ${file.path}`);
          continue;
        }
        smtpAttachments.push({
          filename: file.filename,
          content,
          contentType: file.contentType ?? guessImageContentType(file.filename),
          contentDisposition: 'attachment',
        });
      } catch (error: unknown) {
        this.logger.warn(
          `Could not read assessment attachment ${file.path}: ${
            error instanceof Error ? error.message : String(error)
          }`,
        );
      }
    }

    await this.mailer.sendMail({
      to: params.recipients,
      ...(cc.length > 0 ? { cc } : {}),
      from,
      subject: params.subject,
      html: params.html,
      text: params.text,
      ...(smtpAttachments.length > 0 ? { attachments: smtpAttachments } : {}),
    });

    this.logger.log(
      `ONE assessment email sent with ${smtpAttachments.length} file attachment(s); ` +
        `To: ${params.recipients.join(', ')}` +
        (cc.length > 0 ? `; CC: ${cc.join(', ')}` : ''),
    );
  }

  /** Digital Gemba observation notifications (separate from 5S assessment mail). */
  async sendGembaEmail(params: {
    recipients: string[];
    cc?: string[];
    subject: string;
    html: string;
    text: string;
    inlineAttachments?: GembaMailInlineAttachment[];
  }) {
    if (!params.recipients.length) {
      throw new Error('No recipients found for Gemba email.');
    }

    const fromEmail =
      this.configService.get<string>('SMTP_FROM') ??
      this.configService.get<string>('SMTP_USER');
    if (!fromEmail) {
      throw new Error('SMTP_FROM or SMTP_USER must be set to send mail.');
    }
    const from = `Digital Gemba <${fromEmail}>`;

    const cc = params.cc?.filter(Boolean) ?? [];
    const inlineAttachments = params.inlineAttachments ?? [];

    await this.mailer.sendMail({
      to: params.recipients,
      ...(cc.length > 0 ? { cc } : {}),
      from,
      subject: params.subject,
      html: params.html,
      text: params.text,
      ...(inlineAttachments.length > 0
        ? {
            attachments: inlineAttachments.map((file) => ({
              filename: file.filename,
              path: file.path,
              cid: file.cid,
              contentDisposition: 'inline' as const,
            })),
          }
        : {}),
    });

    this.logger.log(
      `Gemba email sent with ${inlineAttachments.length} embedded inline photo(s); ` +
        `To: ${params.recipients.join(', ')}` +
        (cc.length > 0 ? `; CC: ${cc.join(', ')}` : ''),
    );
  }
}

function guessImageContentType(filename: string): string {
  const lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.heif')) return 'image/heif';
  return 'image/jpeg';
}
