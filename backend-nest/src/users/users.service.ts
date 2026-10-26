import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { normalizeRole } from '../common/roles';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  findAll() {
    return this.prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        employeeId: true,
        name: true,
        email: true,
        role: true,
        businessUnit: true,
        section: true,
        createdAt: true,
      },
    });
  }

  findByEmployeeId(employeeId: number) {
    return this.prisma.user.findUnique({
      where: { employeeId },
      select: {
        id: true,
        employeeId: true,
        name: true,
        email: true,
        role: true,
        businessUnit: true,
        section: true,
      },
    });
  }

  updateUser(
    id: string,
    data: {
      businessUnit?: string;
      section?: string;
      role?: string;
      name?: string;
      email?: string;
    },
  ) {
    const role = data.role ? normalizeRole(data.role) : undefined;
    return this.prisma.user.update({
      where: { id },
      data: {
        businessUnit: data.businessUnit,
        section: data.section,
        name: data.name,
        email: data.email,
        role:
          role === undefined
            ? undefined
            : role === 'admin'
              ? 'admin'
              : role === 'power_user'
                ? 'power_user'
                : role === 'bu_manager'
                  ? 'bu_manager'
                  : role === 'auditor'
                    ? 'auditor'
                    : 'user',
      },
      select: {
        id: true,
        employeeId: true,
        name: true,
        email: true,
        role: true,
        businessUnit: true,
        section: true,
      },
    });
  }
}
