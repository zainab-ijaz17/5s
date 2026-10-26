import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { MailModule } from '../mail/mail.module';
import { PrismaModule } from '../prisma/prisma.module';
import { GembaAuthController } from './gemba-auth.controller';
import { GembaAuthService } from './gemba-auth.service';
import { GembaEmployeesService } from './gemba-employees.service';
import { GembaJwtAuthGuard } from './gemba-jwt-auth.guard';
import { GembaObservationsController } from './gemba-observations.controller';
import { GembaObservationsService } from './gemba-observations.service';
import { GembaObservationMailService } from './gemba-observation-mail.service';
import { GembaUploadsController } from './gemba-uploads.controller';
import { GembaRolesService } from './gemba-roles.service';
import { GembaAdminController } from './gemba-admin.controller';
import { GembaAdminGuard } from './gemba-admin.guard';

@Module({
  imports: [
    ConfigModule,
    PrismaModule,
    MailModule,
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET', 'change_me'),
        signOptions: { expiresIn: '7d' },
      }),
    }),
  ],
  controllers: [
    GembaAuthController,
    GembaObservationsController,
    GembaUploadsController,
    GembaAdminController,
  ],
  providers: [
    GembaAuthService,
    GembaEmployeesService,
    GembaJwtAuthGuard,
    GembaObservationsService,
    GembaObservationMailService,
    GembaRolesService,
    GembaAdminGuard,
  ],
})
export class GembaModule {}
