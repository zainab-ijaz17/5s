import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

export type GembaJwtUser = {
  sub: string;
  email: string | null;
  name: string;
  costCenter: string | null;
  companyName: string | null;
  employeeNumber: string;
  role: 'user' | 'admin';
  authKind: 'sf';
};

@Injectable()
export class GembaJwtAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<{
      headers: { authorization?: string };
      user?: GembaJwtUser;
    }>();
    const header = request.headers.authorization?.trim() ?? '';
    if (!header.toLowerCase().startsWith('bearer ')) {
      throw new UnauthorizedException('Missing Gemba auth token');
    }

    const token = header.slice(7).trim();
    if (!token) {
      throw new UnauthorizedException('Missing Gemba auth token');
    }

    try {
      const payload = await this.jwt.verifyAsync<GembaJwtUser>(token);
      if (!String(payload.sub ?? '').startsWith('gemba:sf:')) {
        throw new UnauthorizedException('Invalid Gemba session');
      }
      request.user = {
        ...payload,
        role: payload.role === 'admin' ? 'admin' : 'user',
      };
      return true;
    } catch {
      throw new UnauthorizedException('Invalid or expired Gemba session');
    }
  }
}
