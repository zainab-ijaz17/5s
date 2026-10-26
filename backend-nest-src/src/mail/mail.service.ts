import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MailerService } from '@nestjs-modules/mailer';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);

  constructor(
    private readonly mailer: MailerService,
    private readonly configService: ConfigService,
  ) {}

  async sendAssessmentEmail(params: {
    recipients: string[];
    cc?: string[];
    subject: string;
    html: string;
    text: string;
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
    // Match Flutter EmailService from display name.
    const from = `5S <${fromEmail}>`;

    const cc = params.cc?.filter(Boolean) ?? [];

    await this.mailer.sendMail({
      to: params.recipients,
      ...(cc.length > 0 ? { cc } : {}),
      from,
      subject: params.subject,
      html: params.html,
      text: params.text,
    });

    this.logger.log(
      `Assessment email sent; To: ${params.recipients.join(', ')}` +
        (cc.length > 0 ? `; CC: ${cc.join(', ')}` : ''),
    );
  }
}
