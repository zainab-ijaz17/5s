import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { CompleteGembaObservationDto } from './dto/complete-gemba-observation.dto';
import { CreateGembaObservationDto } from './dto/create-gemba-observation.dto';
import { GembaObservationsService } from './gemba-observations.service';
import { GembaJwtAuthGuard, GembaJwtUser } from './gemba-jwt-auth.guard';

@Controller('gemba/observations')
@UseGuards(GembaJwtAuthGuard)
export class GembaObservationsController {
  constructor(private readonly observations: GembaObservationsService) {}

  @Get()
  list(
    @Req() req: { user?: GembaJwtUser },
    @Query('bu') bu?: string,
    @Query('section') section?: string,
  ) {
    return this.observations.list(this.requireListUser(req), { bu, section });
  }

  @Get(':id')
  findOne(@Param('id') id: string, @Req() req: { user?: GembaJwtUser }) {
    return this.observations.findOne(id, this.requireListUser(req));
  }

  @Post()
  create(
    @Body() dto: CreateGembaObservationDto,
    @Req() req: { user?: GembaJwtUser },
  ) {
    return this.observations.create(dto, this.requireUser(req));
  }

  @Patch(':id/complete')
  complete(
    @Param('id') id: string,
    @Body() dto: CompleteGembaObservationDto,
    @Req() req: { user?: GembaJwtUser },
  ) {
    return this.observations.complete(id, dto, this.requireUser(req));
  }

  private requireListUser(req: { user?: GembaJwtUser }) {
    const user = req.user;
    if (!user?.employeeNumber?.trim()) {
      throw new UnauthorizedException('Missing Gemba session user');
    }
    return {
      employeeNumber: user.employeeNumber,
      name: user.name,
      role: user.role === 'admin' ? ('admin' as const) : ('user' as const),
    };
  }

  private requireUser(req: { user?: GembaJwtUser }) {
    const user = req.user;
    if (!user?.employeeNumber?.trim()) {
      throw new UnauthorizedException('Missing Gemba session user');
    }
    return {
      employeeNumber: user.employeeNumber,
      name: user.name,
    };
  }
}
