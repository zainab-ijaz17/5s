import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { normalizeRole } from '../common/roles';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async register(dto: RegisterDto) {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
    });
    if (existing) {
      throw new ConflictException('Email already exists.');
    }

    if (dto.employeeId !== undefined && dto.employeeId !== null) {
      const employeeExists = await this.prisma.user.findUnique({
        where: { employeeId: dto.employeeId },
      });
      if (employeeExists) {
        throw new ConflictException('Employee ID already exists.');
      }
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const role = normalizeRole(dto.role);

    const created = await this.prisma.user.create({
      data: {
        email: dto.email.toLowerCase(),
        name: dto.name,
        passwordHash,
        employeeId: dto.employeeId,
        role:
          role === 'admin'
            ? 'admin'
            : role === 'power_user'
              ? 'power_user'
              : role === 'bu_manager'
                ? 'bu_manager'
                : role === 'auditor'
                  ? 'auditor'
                  : 'user',
        businessUnit: dto.businessUnit,
        section: dto.section,
      },
    });

    return this.buildAuthResponse(created.id, created.email, created.role);
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid credentials.');
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('Invalid credentials.');
    }

    return this.buildAuthResponse(user.id, user.email, user.role);
  }

  private async buildAuthResponse(userId: string, email: string, role: string) {
    const accessToken = await this.jwtService.signAsync({
      sub: userId,
      email,
      role,
    });

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        employeeId: true,
        businessUnit: true,
        section: true,
      },
    });

    return {
      success: true,
      data: {
        accessToken,
        user,
      },
    };
  }
}
