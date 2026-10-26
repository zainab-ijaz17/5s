import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  GembaSfLoginDto,
  gembaLoginIdentifierFromDto,
} from './dto/sf-login.dto';
import { GembaAuthService } from './gemba-auth.service';
import { GembaEmployeesService } from './gemba-employees.service';
import { GembaJwtAuthGuard } from './gemba-jwt-auth.guard';

@Controller('gemba/auth')
export class GembaAuthController {
  constructor(
    private readonly auth: GembaAuthService,
    private readonly employees: GembaEmployeesService,
  ) {}

  @Post('sf-login')
  sfLogin(@Body() dto: GembaSfLoginDto) {
    const identifier = gembaLoginIdentifierFromDto(dto);
    if (!identifier) {
      throw new BadRequestException('username or email is required');
    }
    return this.auth.sfLogin(identifier, dto.password);
  }

  /** SF employees for selected form BU (division lookup in SF). */
  @UseGuards(GembaJwtAuthGuard)
  @Get('employees')
  listEmployees(@Query('bu') bu?: string) {
    const code = bu?.trim();
    if (!code) {
      throw new BadRequestException('bu query param is required');
    }
    return this.employees.listByBu(code);
  }
}
