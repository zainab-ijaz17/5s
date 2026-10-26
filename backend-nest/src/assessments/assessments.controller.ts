import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateAssessmentDto } from './dto/create-assessment.dto';
import { AssessmentsService } from './assessments.service';

@Controller('assessments')
@UseGuards(JwtAuthGuard)
export class AssessmentsController {
  constructor(private readonly assessmentsService: AssessmentsService) {}

  @Post('submit')
  create(@Body() dto: CreateAssessmentDto, @Req() req: { user?: { id: string } }) {
    return this.assessmentsService.create(dto, req.user?.id);
  }

  @Post('follow-ups/sweep')
  sweepFollowUps() {
    return this.assessmentsService.sweepFollowUpEmails();
  }

  @Get()
  findAll() {
    return this.assessmentsService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.assessmentsService.findOne(id);
  }
}
