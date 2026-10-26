import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { SkillMatrixAssessmentsService } from './skill-matrix-assessments.service';
import { SkillMatrixAuthService } from './skill-matrix-auth.service';
import { SkillMatrixTrainingService } from './skill-matrix-training.service';
import { SmLoginDto } from './dto/sm-login.dto';
import { UpsertAssessmentLineDto } from './dto/upsert-assessment-line.dto';
import { ManagerAssessmentLineDto } from './dto/manager-line.dto';
import { AssignTrainingDto } from './dto/assign-training.dto';
import { CreateTrainingDto } from './dto/create-training.dto';
import { CreateSkillDto } from './dto/create-skill.dto';
import { SM_ROLE } from './skill-matrix.constants';
import { SkillMatrixJwtGuard, SmJwtUser } from './skill-matrix-jwt.guard';
import { PrismaService } from '../prisma/prisma.service';

type AuthedRequest = { smUser: SmJwtUser };

@Controller('skill-matrix')
export class SkillMatrixController {
  constructor(
    private readonly auth: SkillMatrixAuthService,
    private readonly assessments: SkillMatrixAssessmentsService,
    private readonly training: SkillMatrixTrainingService,
    private readonly prisma: PrismaService,
  ) {}

  @Post('auth/login')
  login(@Body() dto: SmLoginDto) {
    return this.auth.login(dto.employeeNumber, dto.password);
  }

  @Get('me')
  @UseGuards(SkillMatrixJwtGuard)
  async me(@Req() req: AuthedRequest) {
    const user = await this.prisma.skillMatrixUser.findUnique({
      where: { id: req.smUser.sub },
      include: {
        role: true,
        level: true,
        category: true,
        lineManager: true,
      },
    });
    if (!user) return null;
    return this.auth.mapUser(user);
  }

  @Get('master/categories')
  @UseGuards(SkillMatrixJwtGuard)
  listCategories() {
    return this.prisma.skillMatrixCategory.findMany({ orderBy: { name: 'asc' } });
  }

  @Get('master/levels')
  @UseGuards(SkillMatrixJwtGuard)
  listLevels() {
    return this.prisma.skillMatrixLevel.findMany({ orderBy: { sortOrder: 'asc' } });
  }

  @Get('skills/for-me')
  @UseGuards(SkillMatrixJwtGuard)
  skillsForMe(@Req() req: AuthedRequest) {
    return this.assessments.listSkillsForWorker(req.smUser.sub);
  }

  @Get('assessments/current')
  @UseGuards(SkillMatrixJwtGuard)
  async currentAssessment(@Req() req: AuthedRequest) {
    const a = await this.assessments.getOrCreateCurrentAssessment(req.smUser.sub);
    return {
      id: a.id,
      status: a.status,
      cycleLabel: a.cycle.label,
      submittedAt: a.submittedAt,
      lines: a.lines.map((l) => this.assessments.mapAssessmentLine(l)),
    };
  }

  @Post('assessments/lines')
  @UseGuards(SkillMatrixJwtGuard)
  upsertLine(@Req() req: AuthedRequest, @Body() dto: UpsertAssessmentLineDto) {
    this.assessments.assertRole(req.smUser, [SM_ROLE.worker]);
    return this.assessments.upsertSelfLine(
      req.smUser.sub,
      dto.skillId,
      dto.selfRating,
      dto.selfComment,
    );
  }

  @Post('assessments/submit')
  @UseGuards(SkillMatrixJwtGuard)
  submit(@Req() req: AuthedRequest) {
    this.assessments.assertRole(req.smUser, [SM_ROLE.worker]);
    return this.assessments.submitAssessment(req.smUser.sub);
  }

  @Get('trainings/mine')
  @UseGuards(SkillMatrixJwtGuard)
  myTrainings(@Req() req: AuthedRequest) {
    return this.training.workerAssignments(req.smUser.sub);
  }

  @Get('gaps/mine')
  @UseGuards(SkillMatrixJwtGuard)
  myGaps(@Req() req: AuthedRequest) {
    return this.training.workerGaps(req.smUser.sub);
  }

  @Get('manager/team')
  @UseGuards(SkillMatrixJwtGuard)
  managerTeam(@Req() req: AuthedRequest) {
    this.assessments.assertRole(req.smUser, [SM_ROLE.lineManager]);
    return this.assessments.managerTeam(req.smUser.sub);
  }

  @Get('manager/assessments/:workerUserId')
  @UseGuards(SkillMatrixJwtGuard)
  managerView(@Req() req: AuthedRequest, @Param('workerUserId') workerUserId: string) {
    this.assessments.assertRole(req.smUser, [SM_ROLE.lineManager]);
    return this.assessments.getReportAssessment(req.smUser.sub, workerUserId);
  }

  @Patch('manager/assessments/:assessmentId/lines')
  @UseGuards(SkillMatrixJwtGuard)
  managerLines(
    @Req() req: AuthedRequest,
    @Param('assessmentId') assessmentId: string,
    @Body() body: { lines: ManagerAssessmentLineDto[] },
  ) {
    this.assessments.assertRole(req.smUser, [SM_ROLE.lineManager]);
    return this.assessments.saveManagerLines(
      req.smUser.sub,
      assessmentId,
      body.lines ?? [],
    );
  }

  @Post('manager/assessments/:assessmentId/approve')
  @UseGuards(SkillMatrixJwtGuard)
  approve(
    @Req() req: AuthedRequest,
    @Param('assessmentId') assessmentId: string,
  ) {
    this.assessments.assertRole(req.smUser, [SM_ROLE.lineManager]);
    return this.assessments.approveAssessment(req.smUser.sub, assessmentId);
  }

  @Get('admin/trainings')
  @UseGuards(SkillMatrixJwtGuard)
  listTrainings(@Req() req: AuthedRequest) {
    if (!this.assessments.isEtAdmin(req.smUser)) {
      this.assessments.assertRole(req.smUser, [SM_ROLE.lineManager, SM_ROLE.worker]);
    }
    return this.training.listCatalog();
  }

  @Get('admin/users')
  @UseGuards(SkillMatrixJwtGuard)
  async adminUsers(@Req() req: AuthedRequest) {
    this.assessments.assertRole(req.smUser, [SM_ROLE.etAdmin]);
    const users = await this.prisma.skillMatrixUser.findMany({
      orderBy: { fullName: 'asc' },
      include: {
        role: true,
        level: true,
        category: true,
        lineManager: { select: { id: true, fullName: true, employeeNumber: true } },
      },
    });
    return users.map((u) => this.auth.mapUser(u));
  }

  @Get('admin/skills')
  @UseGuards(SkillMatrixJwtGuard)
  async adminSkills(@Req() req: AuthedRequest) {
    this.assessments.assertRole(req.smUser, [SM_ROLE.etAdmin]);
    return this.prisma.skillMatrixSkill.findMany({
      include: {
        category: true,
        applicableLevels: { include: { level: true } },
        requirements: { include: { level: true } },
      },
      orderBy: [{ category: { name: 'asc' } }, { name: 'asc' }],
    });
  }

  @Post('admin/skills')
  @UseGuards(SkillMatrixJwtGuard)
  async createSkill(@Req() req: AuthedRequest, @Body() dto: CreateSkillDto) {
    this.assessments.assertRole(req.smUser, [SM_ROLE.etAdmin]);

    const defaultLevel = dto.defaultRequiredLevel ?? 3;
    const levelIds = [...new Set(dto.applicableLevelIds)];
    const reqByLevel = new Map(
      (dto.requirements ?? []).map((r) => [r.levelId, r.requiredLevel]),
    );

    return this.prisma.$transaction(async (tx) => {
      const skill = await tx.skillMatrixSkill.create({
        data: {
          name: dto.name.trim(),
          categoryId: dto.categoryId,
          department: dto.department?.trim() || null,
          area: dto.area?.trim() || null,
          description: dto.description?.trim() || null,
        },
      });

      for (const levelId of levelIds) {
        await tx.skillMatrixSkillApplicableLevel.create({
          data: { skillId: skill.id, levelId },
        });
        await tx.skillMatrixSkillRequirement.create({
          data: {
            skillId: skill.id,
            levelId,
            requiredLevel: reqByLevel.get(levelId) ?? defaultLevel,
          },
        });
      }

      return tx.skillMatrixSkill.findUnique({
        where: { id: skill.id },
        include: {
          category: true,
          applicableLevels: { include: { level: true } },
          requirements: { include: { level: true } },
        },
      });
    });
  }

  @Post('admin/trainings')
  @UseGuards(SkillMatrixJwtGuard)
  createTraining(@Req() req: AuthedRequest, @Body() dto: CreateTrainingDto) {
    this.assessments.assertRole(req.smUser, [SM_ROLE.etAdmin]);
    return this.prisma.skillMatrixTraining.create({
      data: {
        name: dto.name.trim(),
        description: dto.description?.trim() || null,
        durationHours: dto.durationHours ?? null,
      },
    });
  }

  @Post('admin/training-assignments')
  @UseGuards(SkillMatrixJwtGuard)
  assignTraining(@Req() req: AuthedRequest, @Body() dto: AssignTrainingDto) {
    if (!this.assessments.isEtAdmin(req.smUser)) {
      this.assessments.assertRole(req.smUser, [SM_ROLE.lineManager]);
    }
    return this.training.assignTraining(
      req.smUser,
      dto.workerId,
      dto.trainingId,
      dto.skillId,
      dto.dueDate,
    );
  }

  @Get('worker/validated-assessment')
  @UseGuards(SkillMatrixJwtGuard)
  async validatedForWorker(@Req() req: AuthedRequest) {
    this.assessments.assertRole(req.smUser, [SM_ROLE.worker]);
    const a = await this.assessments.getOrCreateCurrentAssessment(req.smUser.sub);
    const lines = a.lines.map((l) => this.assessments.mapAssessmentLine(l));
    const hasManagerRatings = a.lines.some((l) => l.managerRating != null);
    return {
      status: a.status,
      cycleLabel: a.cycle.label,
      lines,
      showManagerView:
        a.status === 'reviewed' ||
        a.status === 'approved' ||
        hasManagerRatings,
    };
  }
}
