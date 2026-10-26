import { Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export type GembaRoleName = 'user' | 'admin';

@Injectable()
export class GembaRolesService implements OnModuleInit {
  private adminRoleId: string | null = null;
  private userRoleId: string | null = null;

  constructor(private readonly prisma: PrismaService) {}

  async onModuleInit() {
    await this.ensureDefaultRoles();
  }

  async ensureDefaultRoles() {
    const userRole = await this.prisma.gembaRole.upsert({
      where: { name: 'user' },
      create: { name: 'user' },
      update: {},
    });
    const adminRole = await this.prisma.gembaRole.upsert({
      where: { name: 'admin' },
      create: { name: 'admin' },
      update: {},
    });
    this.userRoleId = userRole.id;
    this.adminRoleId = adminRole.id;
  }

  async resolveRoleForEmployee(
    employeeNumber: string,
  ): Promise<GembaRoleName> {
    await this.ensureDefaultRoles();
    const normalized = employeeNumber.trim();
    if (!normalized) return 'user';

    const adminUser = await this.prisma.gembaAdminUser.findUnique({
      where: { employeeNumber: normalized },
      include: { role: true },
    });

    if (adminUser?.role.name === 'admin') {
      return 'admin';
    }
    return 'user';
  }

  async getAdminRoleId(): Promise<string> {
    await this.ensureDefaultRoles();
    if (!this.adminRoleId) {
      throw new Error('Admin role is not initialized');
    }
    return this.adminRoleId;
  }

  async getUserRoleId(): Promise<string> {
    await this.ensureDefaultRoles();
    if (!this.userRoleId) {
      throw new Error('User role is not initialized');
    }
    return this.userRoleId;
  }
}
