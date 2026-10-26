import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { AssessmentsService } from './assessments.service';

@Injectable()
export class AssessmentsFollowUpScheduler {
  private readonly logger = new Logger(AssessmentsFollowUpScheduler.name);

  constructor(private readonly assessments: AssessmentsService) {}

  /** Hourly sweep — replaces device-side FollowUpService. */
  @Cron(CronExpression.EVERY_HOUR)
  async handleHourlyFollowUps() {
    try {
      const result = await this.assessments.sweepFollowUpEmails();
      if (result.processed > 0) {
        this.logger.log(
          `Follow-up sweep: processed ${result.processed}, sent ${result.sent}`,
        );
      }
      if (result.errors.length > 0) {
        this.logger.warn(`Follow-up sweep errors: ${result.errors.join('; ')}`);
      }
    } catch (error: unknown) {
      this.logger.error(
        'Follow-up sweep failed',
        error instanceof Error ? error.stack : String(error),
      );
    }
  }
}
