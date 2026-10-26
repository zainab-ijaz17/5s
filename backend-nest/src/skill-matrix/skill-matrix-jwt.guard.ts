import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { SM_JWT_PREFIX } from './skill-matrix.constants';

export type SmJwtUser = {
  sub: string;
  employeeNumber: string;
  fullName: string;
  email: string;
  roleName: string;
};

@Injectable()
export class SkillMatrixJwtGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest();
    const header = String(req.headers.authorization ?? '');
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (!token) {
      throw new UnauthorizedException('Missing token');
    }

    let payload: { sub?: string; employeeNumber?: string; fullName?: string; email?: string; roleName?: string };
    try {
      payload = this.jwt.verify(token);
    } catch {
      throw new UnauthorizedException('Invalid token');
    }

    if (!payload.sub?.startsWith(SM_JWT_PREFIX)) {
      throw new UnauthorizedException('Not a Skill Matrix token');
    }

    req.smUser = {
      sub: payload.sub.slice(SM_JWT_PREFIX.length),
      employeeNumber: payload.employeeNumber ?? '',
      fullName: payload.fullName ?? '',
      email: payload.email ?? '',
      roleName: payload.roleName ?? '',
    } satisfies SmJwtUser;

    return true;
  }
}
