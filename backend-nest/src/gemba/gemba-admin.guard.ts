import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { GembaJwtAuthGuard, GembaJwtUser } from './gemba-jwt-auth.guard';

@Injectable()
export class GembaAdminGuard extends GembaJwtAuthGuard implements CanActivate {
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const ok = await super.canActivate(context);
    if (!ok) return false;

    const request = context.switchToHttp().getRequest<{ user?: GembaJwtUser }>();
    const user = request.user;
    if (user?.role !== 'admin') {
      throw new ForbiddenException('Admin access required');
    }
    return true;
  }
}
