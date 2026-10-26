import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { PrismaModule } from '../prisma/prisma.module';
import { SkillMatrixController } from './skill-matrix.controller';
import { SkillMatrixAuthService } from './skill-matrix-auth.service';
import { SkillMatrixAssessmentsService } from './skill-matrix-assessments.service';
import { SkillMatrixTrainingService } from './skill-matrix-training.service';
import { SkillMatrixJwtGuard } from './skill-matrix-jwt.guard';

@Module({
  imports: [
    PrismaModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET', 'change_me'),
        signOptions: { expiresIn: '7d' },
      }),
    }),
  ],
  controllers: [SkillMatrixController],
  providers: [
    SkillMatrixAuthService,
    SkillMatrixAssessmentsService,
    SkillMatrixTrainingService,
    SkillMatrixJwtGuard,
  ],
})
export class SkillMatrixModule {}
