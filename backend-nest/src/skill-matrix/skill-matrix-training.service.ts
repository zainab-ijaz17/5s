import { ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SM_ROLE } from './skill-matrix.constants';
import { SmJwtUser } from './skill-matrix-jwt.guard';

@Injectable()
export class SkillMatrixTrainingService {
  constructor(private readonly prisma: PrismaService) {}

  async listCatalog() {
    return this.prisma.skillMatrixTraining.findMany({
      orderBy: { name: 'asc' },
    });
  }

  async assignTraining(
    assigner: SmJwtUser,
    workerId: string,
    trainingId: string,
    skillId?: string,
    dueDate?: string,
  ) {
    if (assigner.roleName !== SM_ROLE.etAdmin && assigner.roleName !== SM_ROLE.lineManager) {
      throw new ForbiddenException('Only E & T Admin or Line Manager can assign trainings');
    }

    if (assigner.roleName === SM_ROLE.lineManager) {
      const worker = await this.prisma.skillMatrixUser.findFirst({
        where: { id: workerId, lineManagerId: assigner.sub },
      });
      if (!worker) {
        throw new ForbiddenException('Not your direct report');
      }
    }

    return this.prisma.skillMatrixTrainingAssignment.create({
      data: {
        workerId,
        trainingId,
        skillId: skillId ?? null,
        assignedById: assigner.sub,
        dueDate: dueDate ? new Date(dueDate) : null,
        status: 'Scheduled',
      },
      include: {
        training: true,
        skill: { include: { category: true } },
        assignedBy: { select: { fullName: true, role: { select: { name: true } } } },
      },
    });
  }

  async workerAssignments(workerId: string) {
    const worker = await this.prisma.skillMatrixUser.findUnique({
      where: { id: workerId },
      select: { levelId: true },
    });

    const rows = await this.prisma.skillMatrixTrainingAssignment.findMany({
      where: { workerId },
      include: {
        training: true,
        skill: {
          include: {
            category: true,
            requirements: true,
          },
        },
        assignedBy: { select: { fullName: true, role: { select: { name: true } } } },
      },
      orderBy: { dueDate: 'asc' },
    });

    const assessment = await this.prisma.skillMatrixAssessment.findFirst({
      where: {
        userId: workerId,
        cycle: { isActive: true },
      },
      include: { lines: true },
    });
    const selfRatingBySkill = new Map(
      (assessment?.lines ?? []).map((l) => [l.skillId, l.selfRating]),
    );

    return rows.map((r) => {
      const canRateForTraining =
        r.skillId != null &&
        (r.status === 'Scheduled' || r.status === 'InProgress');
      const hasSelfRating =
        r.skillId != null && selfRatingBySkill.get(r.skillId) != null;
      return {
        id: r.id,
        skillId: r.skillId,
        title: r.training.name,
        category: r.skill?.category.name ?? '',
        linkedGap: r.skill?.name ?? '',
        requiredLevel:
          r.skill?.requirements.find((req) => req.levelId === worker?.levelId)
            ?.requiredLevel ?? null,
        assignedBy: r.assignedBy.fullName,
        assignedByRole: r.assignedBy.role?.name ?? '',
        dueDate: r.dueDate?.toISOString().slice(0, 10) ?? '',
        status: r.status,
        hours: r.training.durationHours != null ? `${r.training.durationHours}h` : '',
        requiresSelfAssessment: canRateForTraining,
        canRateForTraining,
        selfAssessmentPending: canRateForTraining && !hasSelfRating,
      };
    });
  }

  async completeOpenTrainingsForSkill(workerId: string, skillId: string) {
    await this.prisma.skillMatrixTrainingAssignment.updateMany({
      where: {
        workerId,
        skillId,
        status: { in: ['Scheduled', 'InProgress'] },
      },
      data: { status: 'Completed' },
    });
  }

  async markTrainingRatedForSkill(workerId: string, skillId: string) {
    await this.prisma.skillMatrixTrainingAssignment.updateMany({
      where: {
        workerId,
        skillId,
        status: { in: ['Scheduled', 'InProgress'] },
      },
      data: { status: 'InProgress' },
    });
  }

  async workerGaps(workerId: string) {
    const assessment = await this.prisma.skillMatrixAssessment.findFirst({
      where: {
        userId: workerId,
        cycle: { isActive: true },
      },
      include: {
        lines: {
          include: {
            skill: { include: { category: true } },
          },
        },
      },
    });

    if (!assessment) return [];

    const assignments = await this.workerAssignments(workerId);
    const trainingBySkill = new Map(
      assignments.filter((a) => a.linkedGap).map((a) => [a.linkedGap, a.title]),
    );

    return assessment.lines
      .map((l) => {
        const current = l.managerRating ?? l.selfRating ?? 0;
        const gap = l.requiredLevel - current;
        return {
          category: l.skill.category.name,
          skill: l.skill.name,
          current,
          required: l.requiredLevel,
          gap,
          assignedTraining: gap > 0 ? trainingBySkill.get(l.skill.name) ?? null : null,
        };
      })
      .filter((g) => g.gap > 0);
  }
}
