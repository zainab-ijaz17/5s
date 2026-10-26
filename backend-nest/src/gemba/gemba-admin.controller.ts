import { Controller, Get, UseGuards } from '@nestjs/common';
import { GembaAdminGuard } from './gemba-admin.guard';
import { GembaObservationsService } from './gemba-observations.service';

@Controller('gemba/admin')
@UseGuards(GembaAdminGuard)
export class GembaAdminController {
  constructor(private readonly observations: GembaObservationsService) {}

  @Get('summary')
  summary() {
    return this.observations.adminSummary();
  }
}
