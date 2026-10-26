import {
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CompleteGembaObservationDto } from './dto/complete-gemba-observation.dto';
import { CreateGembaObservationDto } from './dto/create-gemba-observation.dto';
import {
  GembaObservationWithPhotos,
  mapGembaObservation,
} from './gemba-observation.mapper';
import { GembaObservationMailService } from './gemba-observation-mail.service';

type GembaSessionUser = {
  employeeNumber: string;
  name?: string | null;
};

type GembaListUser = GembaSessionUser & {
  role: 'user' | 'admin';
};

type GembaListQuery = {
  bu?: string;
  section?: string;
};

@Injectable()
export class GembaObservationsService {
  private readonly logger = new Logger(GembaObservationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly gembaMailService: GembaObservationMailService,
  ) {}

  async list(user: GembaListUser, query: GembaListQuery = {}) {
    const where = this.buildListWhere(user, query);
    const rows = await this.prisma.gembaObservation.findMany({
      where,
      include: { photos: true },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map(mapGembaObservation);
  }

  async findOne(id: string, user: GembaListUser) {
    const row = await this.requireObservation(id);
    this.assertCanAccess(row, user);
    return mapGembaObservation(row);
  }

  async create(dto: CreateGembaObservationDto, user: GembaSessionUser) {
    const beforePhotoUrls = dto.beforePhotoUrls ?? [];

    const row = await this.prisma.gembaObservation.create({
      data: {
        title: dto.title.trim(),
        location: dto.location.trim(),
        category: dto.category.trim(),
        status: 'In-progress',
        assignedEmployeeNumber: dto.assignedEmployeeNumber.trim(),
        assignedEmployeeName: dto.assignedEmployeeName?.trim() || null,
        createdByEmployeeNumber: user.employeeNumber.trim(),
        createdByName: user.name?.trim() || null,
        remarks: dto.remarks?.trim() || '',
        company: dto.company.trim(),
        bu: dto.bu?.trim() || null,
        section: dto.section?.trim() || null,
        machineValue: dto.machineValue?.trim() || null,
        photos: {
          create: beforePhotoUrls.map((url, index) => ({
            kind: 'before',
            url: url.trim(),
            sortOrder: index,
          })),
        },
      },
      include: { photos: true },
    });

    void this.gembaMailService
      .sendAssignedNotification(row)
      .catch((error: unknown) => {
        this.logger.error(
          `Observation ${row.id} saved but assignee email failed`,
          error instanceof Error ? error.stack : String(error),
        );
      });

    return mapGembaObservation(row);
  }

  async complete(
    id: string,
    dto: CompleteGembaObservationDto,
    user: GembaSessionUser,
  ) {
    const existing = await this.requireObservation(id);
    if (existing.status === 'Done') {
      throw new ForbiddenException('Observation is already completed');
    }

    const assignee = existing.assignedEmployeeNumber.trim();
    if (assignee !== user.employeeNumber.trim()) {
      throw new ForbiddenException(
        'Only the assigned employee can mark this observation as done',
      );
    }

    const afterPhotoUrls = dto.afterPhotoUrls ?? [];
    const row = await this.prisma.gembaObservation.update({
      where: { id },
      data: {
        status: 'Done',
        afterRemarks: dto.afterRemarks.trim(),
        completedByEmployeeNumber: user.employeeNumber.trim(),
        completedByName: user.name?.trim() || null,
        completedAt: new Date(),
        photos: {
          create: afterPhotoUrls.map((url, index) => ({
            kind: 'after',
            url: url.trim(),
            sortOrder: index,
          })),
        },
      },
      include: { photos: true },
    });

    void this.gembaMailService
      .sendCompletedNotification(row)
      .catch((error: unknown) => {
        this.logger.error(
          `Observation ${row.id} completed but creator email failed`,
          error instanceof Error ? error.stack : String(error),
        );
      });

    return mapGembaObservation(row);
  }

  async adminSummary() {
    const rows = await this.prisma.gembaObservation.findMany({
      include: { photos: true },
      orderBy: { createdAt: 'desc' },
    });

    let inProgress = 0;
    let done = 0;
    for (const row of rows) {
      if (row.status === 'Done') {
        done++;
      } else {
        inProgress++;
      }
    }

    return {
      total: rows.length,
      inProgress,
      done,
      observations: rows.map(mapGembaObservation),
    };
  }

  private buildListWhere(
    user: GembaListUser,
    query: GembaListQuery,
  ): Prisma.GembaObservationWhereInput {
    const employeeNumber = user.employeeNumber.trim();
    const bu = query.bu?.trim();
    const section = query.section?.trim();

    const locationFilter: Prisma.GembaObservationWhereInput = {};
    if (bu) locationFilter.bu = bu;
    if (section) locationFilter.section = section;

    if (user.role === 'admin') {
      return locationFilter;
    }

    return {
      ...locationFilter,
      OR: [
        { createdByEmployeeNumber: employeeNumber },
        { assignedEmployeeNumber: employeeNumber },
      ],
    };
  }

  private assertCanAccess(
    row: GembaObservationWithPhotos,
    user: GembaListUser,
  ) {
    if (user.role === 'admin') return;

    const employeeNumber = user.employeeNumber.trim();
    const createdBy = row.createdByEmployeeNumber.trim();
    const assignedTo = row.assignedEmployeeNumber.trim();
    if (employeeNumber !== createdBy && employeeNumber !== assignedTo) {
      throw new ForbiddenException('You do not have access to this observation');
    }
  }

  private async requireObservation(id: string): Promise<GembaObservationWithPhotos> {
    const row = await this.prisma.gembaObservation.findUnique({
      where: { id },
      include: { photos: true },
    });
    if (!row) {
      throw new NotFoundException('Observation not found');
    }
    return row;
  }
}
