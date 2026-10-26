import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { SM_JWT_PREFIX } from './skill-matrix.constants';

@Injectable()
export class SkillMatrixAuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async login(employeeNumber: string, password: string) {
    const normalized = employeeNumber.trim();
    const user = await this.prisma.skillMatrixUser.findFirst({
      where: { employeeNumber: normalized, status: 'Active' },
      include: { role: true, level: true, category: true, lineManager: true },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const accessToken = await this.jwt.signAsync({
      sub: `${SM_JWT_PREFIX}${user.id}`,
      employeeNumber: user.employeeNumber,
      fullName: user.fullName,
      email: user.email,
      roleName: user.role.name,
    });

    return { accessToken, user: this.mapUser(user) };
  }

  mapUser(user: {
    id: string;
    fullName: string;
    email: string;
    employeeNumber: string;
    department: string | null;
    areaLine: string | null;
    designation: string | null;
    photoUrl: string | null;
    dateOfJoining: Date | null;
    status: string;
    role: { id: string; name: string };
    level: { id: string; code: string } | null;
    category: { id: string; name: string } | null;
    lineManager: { id: string; fullName: string; employeeNumber: string } | null;
  }) {
    return {
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      employeeNumber: user.employeeNumber,
      department: user.department,
      areaLine: user.areaLine,
      designation: user.designation,
      photoUrl: user.photoUrl,
      dateOfJoining: user.dateOfJoining?.toISOString() ?? null,
      status: user.status,
      role: user.role,
      level: user.level,
      category: user.category,
      lineManager: user.lineManager
        ? {
            id: user.lineManager.id,
            fullName: user.lineManager.fullName,
            employeeNumber: user.lineManager.employeeNumber,
          }
        : null,
    };
  }
}
