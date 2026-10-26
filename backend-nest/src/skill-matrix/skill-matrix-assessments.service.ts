import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SM_ROLE, SmRoleName } from './skill-matrix.constants';
import { SmJwtUser } from './skill-matrix-jwt.guard';
import { SkillMatrixTrainingService } from './skill-matrix-training.service';

@Injectable()
export class SkillMatrixAssessmentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly training: SkillMatrixTrainingService,
  ) {}

  async getActiveCycle() {
    const cycle = await this.prisma.skillMatrixAssessmentCycle.findFirst({
      where: { isActive: true },
      orderBy: { createdAt: 'desc' },
    });
    if (!cycle) {
      throw new NotFoundException('No active assessment cycle');
    }
    return cycle;
  }

  async getOrCreateCurrentAssessment(userId: string) {
    const cycle = await this.getActiveCycle();
    let assessment = await this.prisma.skillMatrixAssessment.findUnique({
      where: { userId_cycleId: { userId, cycleId: cycle.id } },
      include: {
        cycle: true,
        lines: {
          include: {
            skill: { include: { category: true } },
          },
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    if (!assessment) {
      assessment = await this.prisma.skillMatrixAssessment.create({
        data: { userId, cycleId: cycle.id, status: 'draft' },
        include: {
          cycle: true,
          lines: {
            include: {
              skill: { include: { category: true } },
            },
          },
        },
      });
    }

    return assessment;
  }

  mapAssessmentLine(line: {
    id: string;
    requiredLevel: number;
    selfRating: number | null;
    selfComment: string | null;
    managerRating: number | null;
    managerComment: string | null;
    skill: {
      id: string;
      name: string;
      category: { name: string };
    };
  }) {
    const validated = line.managerRating ?? line.selfRating;
    const gap =
      line.requiredLevel - (validated == null ? 0 : Math.min(5, Math.max(0, validated)));

    return {
      id: line.id,
      skillId: line.skill.id,
      category: line.skill.category.name,
      skill: line.skill.name,
      requiredLevel: line.requiredLevel,
      selfRating: line.selfRating,
      selfComment: line.selfComment,
      managerRating: line.managerRating,
      managerComment: line.managerComment,
      validatedRating: validated,
      gap,
      hasGap: gap > 0,
    };
  }

  async upsertSelfLine(userId: string, skillId: string, selfRating: number, selfComment?: string) {
    const user = await this.prisma.skillMatrixUser.findUnique({
      where: { id: userId },
      include: { level: true },
    });
    if (!user?.levelId) {
      throw new BadRequestException('Worker level is not set');
    }

    const skill = await this.prisma.skillMatrixSkill.findUnique({
      where: { id: skillId },
      include: {
        requirements: { where: { levelId: user.levelId } },
        applicableLevels: { where: { levelId: user.levelId } },
      },
    });
    if (!skill || skill.applicableLevels.length === 0) {
      throw new BadRequestException('Skill not applicable for your level');
    }

    const req = skill.requirements[0]?.requiredLevel ?? 3;
    const assessment = await this.getOrCreateCurrentAssessment(userId);
    const openTrainingForSkill =
      await this.prisma.skillMatrixTrainingAssignment.findFirst({
        where: {
          workerId: userId,
          skillId,
          status: { in: ['Scheduled', 'InProgress'] },
        },
      });
    const workerCanEdit =
      assessment.status === 'draft' || assessment.status === 'submitted';
    if (!workerCanEdit && !openTrainingForSkill) {
      throw new BadRequestException(
        'Your assessment is locked after line manager validation. Open an assigned training to update a linked skill.',
      );
    }

    const line = await this.prisma.skillMatrixAssessmentLine.upsert({
      where: {
        assessmentId_skillId: { assessmentId: assessment.id, skillId },
      },
      create: {
        assessmentId: assessment.id,
        skillId,
        requiredLevel: req,
        selfRating,
        selfComment: selfComment?.trim() || null,
      },
      update: {
        selfRating,
        selfComment: selfComment?.trim() || null,
      },
      include: { skill: { include: { category: true } } },
    });

    await this.training.markTrainingRatedForSkill(userId, skillId);

    return this.mapAssessmentLine(line);
  }

  async submitAssessment(userId: string) {
    const assessment = await this.getOrCreateCurrentAssessment(userId);
    if (assessment.lines.length === 0) {
      throw new BadRequestException('Add at least one skill rating before submitting');
    }
    if (assessment.status === 'approved' || assessment.status === 'reviewed') {
      throw new BadRequestException(
        'Your line manager has already validated this assessment',
      );
    }

    return this.prisma.skillMatrixAssessment.update({
      where: { id: assessment.id },
      data: { status: 'submitted', submittedAt: new Date() },
    });
  }

  async listSkillsForWorker(userId: string) {
    const user = await this.prisma.skillMatrixUser.findUnique({
      where: { id: userId },
    });
    if (!user?.levelId) return [];

    return this.prisma.skillMatrixSkill.findMany({
      where: {
        applicableLevels: { some: { levelId: user.levelId } },
      },
      include: {
        category: true,
        requirements: { where: { levelId: user.levelId } },
      },
      orderBy: [{ category: { name: 'asc' } }, { name: 'asc' }],
    });
  }

  async managerTeam(managerId: string) {
    const reports = await this.prisma.skillMatrixUser.findMany({
      where: { lineManagerId: managerId, status: 'Active' },
      include: { level: true },
    });

    const cycle = await this.getActiveCycle();
    const assessments = await this.prisma.skillMatrixAssessment.findMany({
      where: {
        cycleId: cycle.id,
        userId: { in: reports.map((r) => r.id) },
      },
      include: { lines: true },
    });
    const byUser = new Map(assessments.map((a) => [a.userId, a]));

    return reports.map((r) => {
      const a = byUser.get(r.id);
      const lines = a?.lines ?? [];
      const validated = lines
        .map((l) => l.managerRating ?? l.selfRating)
        .filter((v): v is number => v != null);
      const overall =
        validated.length === 0
          ? null
          : validated.reduce((s, v) => s + v, 0) / validated.length;
      const openGaps = lines.filter((l) => {
        const v = l.managerRating ?? l.selfRating ?? 0;
        return l.requiredLevel - v > 0;
      }).length;

      let assessmentStatus = 'Not started';
      let awaitingReview = false;
      if (a) {
        switch (a.status) {
          case 'draft': {
            const workerSaved = lines.some((l) => l.selfRating != null);
            if (workerSaved) {
              assessmentStatus = 'Worker saved · Ready to validate';
              awaitingReview = true;
            } else {
              assessmentStatus = lines.length > 0 ? 'Draft' : 'Not started';
            }
            break;
          }
          case 'submitted':
            assessmentStatus = 'Awaiting my review';
            awaitingReview = true;
            break;
          case 'reviewed':
            assessmentStatus = 'Reviewed';
            awaitingReview = false;
            break;
          case 'approved':
            assessmentStatus = 'Approved';
            break;
        }
      }

      return {
        id: r.employeeNumber,
        userId: r.id,
        name: r.fullName,
        department: r.department ?? '',
        level: r.level?.code ?? '',
        assessmentStatus,
        overallScore: overall == null ? null : Math.round(overall * 10) / 10,
        openGaps,
        awaitingReview,
      };
    });
  }

  private async getDirectReport(managerId: string, workerRef: string) {
    const ref = workerRef.trim();
    const worker = await this.prisma.skillMatrixUser.findFirst({
      where: {
        lineManagerId: managerId,
        OR: [{ id: ref }, { employeeNumber: ref }],
      },
    });
    if (!worker) {
      throw new ForbiddenException('Not your direct report');
    }
    return worker;
  }

  async getReportAssessment(managerId: string, workerUserId: string) {
    const worker = await this.getDirectReport(managerId, workerUserId);

    const assessment = await this.getOrCreateCurrentAssessment(worker.id);
    return {
      assessmentId: assessment.id,
      status: assessment.status,
      cycleLabel: assessment.cycle.label,
      lines: assessment.lines.map((l) => this.mapAssessmentLine(l)),
    };
  }

  async saveManagerLines(
    managerId: string,
    assessmentId: string,
    lines: { lineId: string; managerRating: number; managerComment?: string }[],
  ) {
    const assessment = await this.prisma.skillMatrixAssessment.findUnique({
      where: { id: assessmentId },
      include: {
        user: true,
        lines: true,
      },
    });
    if (!assessment) throw new NotFoundException('Assessment not found');
    if (assessment.user.lineManagerId !== managerId) {
      throw new ForbiddenException('Not your direct report');
    }
    const workerHasSavedRatings = assessment.lines.some(
      (l) => l.selfRating != null,
    );
    if (
      assessment.status === 'draft' &&
      !workerHasSavedRatings
    ) {
      throw new BadRequestException(
        'Worker has not saved any skill ratings yet.',
      );
    }
    if (
      assessment.status !== 'submitted' &&
      assessment.status !== 'reviewed' &&
      assessment.status !== 'draft' &&
      assessment.status !== 'approved'
    ) {
      throw new BadRequestException(
        'This assessment is already closed for validation.',
      );
    }
    if (lines.length === 0) {
      throw new BadRequestException('No rating lines to save');
    }

    for (const input of lines) {
      const updated = await this.prisma.skillMatrixAssessmentLine.updateMany({
        where: { id: input.lineId, assessmentId },
        data: {
          managerRating: input.managerRating,
          managerComment: input.managerComment?.trim() || null,
        },
      });
      if (updated.count === 0) {
        throw new BadRequestException(
          `Could not update skill line ${input.lineId}. Reload the review screen and try again.`,
        );
      }
    }

    const savedLines = await this.prisma.skillMatrixAssessmentLine.findMany({
      where: { assessmentId },
    });
    for (const line of savedLines) {
      const rating = line.managerRating ?? line.selfRating ?? 0;
      const effective = Math.min(5, Math.max(0, rating));
      const gap = line.requiredLevel - effective;
      if (gap <= 0) {
        await this.training.completeOpenTrainingsForSkill(
          assessment.userId,
          line.skillId,
        );
      }
    }

    const now = new Date();
    await this.prisma.skillMatrixAssessment.update({
      where: { id: assessmentId },
      data: {
        status: 'approved',
        reviewedAt: now,
        approvedAt: now,
        submittedAt: assessment.submittedAt ?? now,
      },
    });

    return this.getReportAssessment(managerId, assessment.userId);
  }

  async approveAssessment(managerId: string, assessmentId: string) {
    const assessment = await this.prisma.skillMatrixAssessment.findUnique({
      where: { id: assessmentId },
      include: { user: true },
    });
    if (!assessment) throw new NotFoundException('Assessment not found');
    if (assessment.user.lineManagerId !== managerId) {
      throw new ForbiddenException('Not your direct report');
    }
    if (assessment.status !== 'reviewed' && assessment.status !== 'submitted') {
      throw new BadRequestException('Complete manager review first');
    }

    await this.prisma.skillMatrixAssessment.update({
      where: { id: assessmentId },
      data: { status: 'approved', approvedAt: new Date() },
    });

    return { ok: true };
  }

  assertRole(user: SmJwtUser, allowed: SmRoleName[]) {
    if (!allowed.includes(user.roleName as SmRoleName)) {
      throw new ForbiddenException('Role not allowed');
    }
  }

  isEtAdmin(user: SmJwtUser) {
    return user.roleName === SM_ROLE.etAdmin;
  }
}
