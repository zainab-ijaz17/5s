import { Module } from '@nestjs/common';
import { MailModule } from '../mail/mail.module';
import { AssessmentsFollowUpScheduler } from './assessments-follow-up.scheduler';
import { AssessmentsController } from './assessments.controller';
import { AssessmentsService } from './assessments.service';

@Module({
  imports: [MailModule],
  controllers: [AssessmentsController],
  providers: [AssessmentsService, AssessmentsFollowUpScheduler],
})
export class AssessmentsModule {}
