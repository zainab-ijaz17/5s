import {
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  GEMBA_DEMO_ADMIN_EMPLOYEE_NUMBER,
  GEMBA_DEMO_ADMIN_NAME,
  GEMBA_DEMO_ADMIN_PASSWORD,
  isGembaDemoAdminEnabled,
  matchesGembaDemoAdminCredentials,
} from './gemba-demo-auth';
import { GembaRolesService, GembaRoleName } from './gemba-roles.service';

const SF_SUB_PREFIX = 'gemba:sf:';

export type GembaSfUser = {
  email: string | null;
  name: string;
  costCenter: string | null;
  companyName: string | null;
  employeeNumber: string;
  role: GembaRoleName;
  isAdmin: boolean;
};

type GembaJwtPayload = {
  sub: string;
  email: string | null;
  name: string;
  costCenter: string | null;
  companyName: string | null;
  employeeNumber: string;
  role: GembaRoleName;
  authKind: 'sf' | 'demo';
};

/**
 * SuccessFactors login for Gemba Walk (same SAP flow as CRF).
 * Returns: email, name, costCenter, companyName, employeeNumber.
 */
@Injectable()
export class GembaAuthService {
  private static readonly SAP_BASE = 'https://api44.sapsf.com';
  private static readonly SAP_TOKEN_URL = 'https://api44.sapsf.com/oauth/token';
  private static readonly SAP_CLIENT_ID =
    'NmEwYWE4MDJmYmVlMjg2NGVhNzhjYzcwOWY2OA';
  private static readonly SF_FETCH_TIMEOUT_MS = 20_000;

  private readonly logger = new Logger(GembaAuthService.name);

  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly roles: GembaRolesService,
  ) {}

  async sfLogin(username: string, password: string) {
    const trimmed = username.trim();
    if (!trimmed) {
      throw new UnauthorizedException('Username is required');
    }

    const demoSession = await this.tryDemoAdminLogin(trimmed, password);
    if (demoSession) {
      return demoSession;
    }

    const normalizedUsername = this.normalizeUsernameForSap(trimmed);
    const employeeId = this.extractEmployeeId(normalizedUsername);

    try {
      await this.step1BackgroundCommunity(normalizedUsername, password);
      const assertion = await this.step2Idp();
      const sapToken = await this.step3Token(assertion);
      const accessToken = String(sapToken.access_token ?? '');

      const profile = await this.fetchProfileFields(accessToken, employeeId);
      const email = this.resolveEmail(trimmed, employeeId, profile.email);

      const user: GembaSfUser = {
        email,
        name: profile.displayName?.trim() || employeeId,
        costCenter: profile.costCenter,
        companyName: profile.companyName,
        employeeNumber: employeeId,
        role: await this.roles.resolveRoleForEmployee(employeeId),
        isAdmin: false,
      };
      user.isAdmin = user.role === 'admin';

      const session: GembaJwtPayload = {
        sub: `${SF_SUB_PREFIX}${employeeId}`,
        email: user.email,
        name: user.name,
        costCenter: user.costCenter,
        companyName: user.companyName,
        employeeNumber: user.employeeNumber,
        role: user.role,
        authKind: 'sf',
      };
      const jwtAccessToken = await this.jwt.signAsync(session);

      return {
        accessToken: jwtAccessToken,
        user,
      };
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        throw error;
      }
      throw new UnauthorizedException('Invalid credentials');
    }
  }

  /** Backend-only demo admin (no SF call). Uses the normal login form in the app. */
  private async tryDemoAdminLogin(
    username: string,
    password: string,
  ): Promise<{ accessToken: string; user: GembaSfUser } | null> {
    if (
      !isGembaDemoAdminEnabled(
        this.config.get<string>('GEMBA_DEMO_ADMIN_ENABLED'),
      )
    ) {
      return null;
    }

    const demoEmployee =
      this.config.get<string>('GEMBA_DEMO_ADMIN_EMPLOYEE_NUMBER')?.trim() ||
      GEMBA_DEMO_ADMIN_EMPLOYEE_NUMBER;
    const demoPassword =
      this.config.get<string>('GEMBA_DEMO_ADMIN_PASSWORD') ??
      GEMBA_DEMO_ADMIN_PASSWORD;

    if (
      !matchesGembaDemoAdminCredentials(
        username,
        password,
        demoEmployee,
        demoPassword,
      )
    ) {
      return null;
    }

    const role = await this.roles.resolveRoleForEmployee(demoEmployee);
    const user: GembaSfUser = {
      email: `${demoEmployee}@packagesli`,
      name: GEMBA_DEMO_ADMIN_NAME,
      costCenter: null,
      companyName: 'Packages Convertors Limited',
      employeeNumber: demoEmployee,
      role,
      isAdmin: role === 'admin',
    };

    if (!user.isAdmin) {
      this.logger.warn(
        `Demo admin ${demoEmployee} authenticated but is not seeded as admin`,
      );
    }

    const session: GembaJwtPayload = {
      sub: `${SF_SUB_PREFIX}${demoEmployee}`,
      email: user.email,
      name: user.name,
      costCenter: user.costCenter,
      companyName: user.companyName,
      employeeNumber: user.employeeNumber,
      role: user.role,
      authKind: 'demo',
    };

    this.logger.log(`Gemba demo admin signed in (${demoEmployee})`);

    return {
      accessToken: await this.jwt.signAsync(session),
      user,
    };
  }

  private resolveEmail(
    inputUsername: string,
    employeeId: string,
    sfEmail: string | null,
  ): string | null {
    if (sfEmail?.trim()) return sfEmail.trim().toLowerCase();
    const normalized = inputUsername.trim().toLowerCase();
    if (normalized.includes('@')) return normalized;
    return employeeId ? `${employeeId}@packagesli` : null;
  }

  private normalizeUsernameForSap(username: string): string {
    const trimmed = username.trim();
    if (!trimmed) throw new UnauthorizedException('Username is required');
    if (trimmed.includes('@')) {
      const [local] = trimmed.split('@');
      return `${local}@packagesli`;
    }
    return `${trimmed}@packagesli`;
  }

  private extractEmployeeId(normalizedUsername: string): string {
    return normalizedUsername.split('@')[0]?.trim() ?? '';
  }

  private async step1BackgroundCommunity(
    userWithDomain: string,
    password: string,
  ): Promise<void> {
    const credentials = Buffer.from(`${userWithDomain}:${password}`).toString(
      'base64',
    );
    const response = await fetch(
      `${GembaAuthService.SAP_BASE}/odata/v2/Background_Community?$top=20`,
      {
        headers: { Authorization: `Basic ${credentials}` },
      },
    );
    if (!response.ok) {
      throw new UnauthorizedException('Invalid SAP credentials');
    }
  }

  private async step2Idp(): Promise<string> {
    const privateKey =
      this.config.get<string>('SAP_PRIVATE_KEY')?.trim() ||
      this.defaultPrivateKey();
    const body = new URLSearchParams({
      user_id: this.config.get<string>('SAP_IDP_USER_ID', 'ECAdmin'),
      token_url: GembaAuthService.SAP_TOKEN_URL,
      private_key: privateKey,
      client_id: this.config.get<string>(
        'SAP_CLIENT_ID',
        GembaAuthService.SAP_CLIENT_ID,
      ),
    });
    const response = await fetch(`${GembaAuthService.SAP_BASE}/oauth/idp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });
    if (!response.ok) {
      throw new UnauthorizedException('SAP IDP authentication failed');
    }
    const raw = (await response.text()).trim();
    try {
      const parsed = JSON.parse(raw) as {
        assertion?: string;
        Assertion?: string;
      };
      return parsed.assertion || parsed.Assertion || raw;
    } catch {
      return raw;
    }
  }

  private async step3Token(
    assertion: string,
  ): Promise<Record<string, unknown>> {
    const body = new URLSearchParams({
      client_id: this.config.get<string>(
        'SAP_CLIENT_ID',
        GembaAuthService.SAP_CLIENT_ID,
      ),
      grant_type: 'urn:ietf:params:oauth:grant-type:saml2-bearer',
      company_id: this.config.get<string>('SAP_COMPANY_ID', 'packagesli'),
      assertion,
    });
    const response = await fetch(GembaAuthService.SAP_TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });
    if (!response.ok) {
      throw new UnauthorizedException('SAP token exchange failed');
    }
    return (await response.json()) as Record<string, unknown>;
  }

  private async fetchProfileFields(
    sapAccessToken: string,
    employeeId: string,
  ): Promise<{
    displayName: string | null;
    email: string | null;
    costCenter: string | null;
    companyName: string | null;
  }> {
    const [user, empJob] = await Promise.all([
      this.fetchUserNameAndEmail(sapAccessToken, employeeId),
      this.fetchEmpJobFields(sapAccessToken, employeeId),
    ]);
    return {
      displayName: user.displayName,
      email: user.email,
      costCenter: empJob.costCenter,
      companyName: empJob.companyName,
    };
  }

  private async sapFetch(url: string, sapAccessToken: string) {
    const controller = new AbortController();
    const timer = setTimeout(
      () => controller.abort(),
      GembaAuthService.SF_FETCH_TIMEOUT_MS,
    );
    try {
      return await fetch(url, {
        headers: { Authorization: `Bearer ${sapAccessToken}` },
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timer);
    }
  }

  private async fetchUserNameAndEmail(
    sapAccessToken: string,
    userId: string,
  ): Promise<{ displayName: string | null; email: string | null }> {
    const empty = { displayName: null, email: null };
    if (!sapAccessToken || !userId.trim()) return empty;

    const escaped = userId.replace(/'/g, "''");
    const userUrl =
      `${GembaAuthService.SAP_BASE}/odata/v2/User('${escaped}')` +
      `?$format=json&$select=displayName,email,defaultFullName`;

    const userResponse = await this.sapFetch(userUrl, sapAccessToken);
    if (!userResponse.ok) return empty;

    const data = (await userResponse.json()) as {
      d?: Record<string, unknown>;
    } & Record<string, unknown>;
    const user = (data.d ?? data) as Record<string, unknown>;

    const displayName =
      (typeof user.displayName === 'string' && user.displayName.trim()) ||
      (typeof user.defaultFullName === 'string' &&
        user.defaultFullName.trim()) ||
      null;
    const email =
      typeof user.email === 'string' ? user.email.trim() || null : null;

    return { displayName, email };
  }

  private async fetchEmpJobFields(
    sapAccessToken: string,
    employeeId: string,
  ): Promise<{ costCenter: string | null; companyName: string | null }> {
    const empty = { costCenter: null, companyName: null };
    const escaped = employeeId.replace(/'/g, "''");
    const url =
      `${GembaAuthService.SAP_BASE}/odata/v2/EmpJob` +
      `?$format=json&$top=1&$orderby=startDate desc` +
      `&$filter=userId eq '${escaped}'` +
      `&$select=costCenter,company,companyNav`;

    const response = await this.sapFetch(url, sapAccessToken);
    if (!response.ok) return empty;

    const data = (await response.json()) as {
      d?: {
        results?: Array<Record<string, unknown>>;
        costCenter?: unknown;
        company?: unknown;
        companyNav?: unknown;
      };
      results?: Array<Record<string, unknown>>;
    };

    const results = data.d?.results ?? data.results ?? [];
    const first = (Array.isArray(results) ? results[0] : undefined) ?? data.d;
    if (!first) return empty;

    const companyName =
      (await this.resolveNavName(sapAccessToken, first.companyNav)) ||
      this.readSfCode(first.company);

    return {
      costCenter: this.readSfCode(first.costCenter),
      companyName,
    };
  }

  /** Resolve FO foundation nav: inline name or deferred URI → $select=name. */
  private async resolveNavName(
    sapAccessToken: string,
    nav: unknown,
  ): Promise<string | null> {
    if (!nav || typeof nav !== 'object') return null;
    const record = nav as Record<string, unknown>;

    if (typeof record.name === 'string' && record.name.trim()) {
      return record.name.trim();
    }

    const deferred = record.__deferred;
    if (!deferred || typeof deferred !== 'object') return null;
    const uri =
      typeof (deferred as { uri?: unknown }).uri === 'string'
        ? (deferred as { uri: string }).uri.trim()
        : '';
    if (!uri) return null;

    try {
      const url = new URL(uri);
      url.searchParams.set('$format', 'json');
      url.searchParams.set('$select', 'name');
      const response = await this.sapFetch(url.toString(), sapAccessToken);
      if (!response.ok) return null;

      const data = (await response.json()) as {
        d?: { name?: unknown };
        name?: unknown;
        error?: unknown;
      };
      if (data.error) return null;
      const name = data.d?.name ?? data.name;
      return typeof name === 'string' && name.trim() ? name.trim() : null;
    } catch {
      return null;
    }
  }

  private readSfCode(value: unknown): string | null {
    if (typeof value === 'string') {
      const trimmed = value.trim();
      return trimmed || null;
    }
    if (typeof value === 'number' && Number.isFinite(value)) {
      return String(value);
    }
    if (value && typeof value === 'object') {
      const record = value as Record<string, unknown>;
      for (const key of [
        'externalCode',
        'code',
        'id',
        'name',
        'label',
        'description',
      ] as const) {
        const candidate = record[key];
        if (typeof candidate === 'string' && candidate.trim()) {
          return candidate.trim();
        }
      }
    }
    return null;
  }

  /** Same SAP IDP fallback key used by CRF / FireX when env is empty. */
  private defaultPrivateKey(): string {
    return 'TUlJRXZRSUJBREFOQmdrcWhraUc5dzBCQVFFRkFBU0NCS2N3Z2dTakFnRUFBb0lCQVFEaU1RbUpZOFJwa1MwVnlrbzg4ckpMQm9ZaHhCUU5HNWs4Q0RId2J6SkZFT1BNLzJndEJSd1liL3czbGJkM2RHRXRUajg0WEZQZ05PZTJaeVhETHlDWW1rTEVmcWhHS0VKb1hqSVV6enhiUHpoNHN2ZDFPVjMvTEl2M25ZR1BUeEZYamdJT213T0piS1gyUFY0eENad1NzWGtwVEJwcFRTN0o4Vk11RnIwL2FLZFlMY2lYSjEzV0tlRjlJZXVhWHlGRW1HNjh5bmdzK25FWDNWZWVnRW1vQi95cmhMbmlhM2t6cEc4U2hlS2JnSU9NUU81MGR6YjEyRFY0NDNYN2hPNm1YbTYvMU54NlVhVUVzZ3VSQ24vTDM4RGtOcnd5OVR1M0xtcFBwQzNmS2VEbExDamVFN0FkQWMvU2l0TWRuWThqbko0Q1lqeW1selZxNVJneHFBY0JBZ01CQUFFQ2dnRUFUTTBpdEZROFVpMzVsWDhBMHc0RERPZHpyczVoa292TzdXdkk3UjhNZmhmOGlWUWxucmV2OFBwQk5PeHdoYTV0K3BDcGRhMGZ5NjZiQ0x1Z1BsUm5xSGtrZDR5Yi9XcFpGZy81eUVnUGNkb1hCaUNhVm1LNnNGU0RWL25Tam9MbDNBazdXSk00MGJZaTZlZXZiazRaZ04xaXl1dHN3bGx6TEIxMVJWNXlOcTlpUXE0SVhDSkxuRVQ4ZGdWVWladUo4OUxUeFlMUFBBcWROL0ZueDNkb2k4cmhjc05kUVlTT1FMSUoybHpPVFNhWjJWQmM3eHNRTjNVZFJnTHlCWkZLSGNnUTUzRjhaVy9aOUwwVHRRZjJXWjVUSnhwM1F3V25zREE2c1NncTRTSEYrQ0c3M3paQzc4eXRtUm5NMXk5SnVoRmViOUhUb3hFNE1nQjVPTWFjMndLQmdRRDJEb1UxenBVY29DY0ZVdU1RRUNobDJxV0hGS1hDaDNNazM5NnRMUzNFN29uWGRvL25Vb3huNVJQaHpwNk52VVRLcGNUL0JwRStjNVBVZ3M5NEphcFRJeWJha09yQnlmZ1NHRit1TUROWWdnbXRMYkNOZkZZTG90TWlwZGlxQWpQT2ZWdWZxMjk2REk2OFdOemRVbml4ak5SZ3F0SkJTMUpmUDZSNGRtR2hzd0tCZ1FEclZRS0g3dGdyWVhxcDFXRnFlR2owR2w3R0xPS1haRlhTQk9XYldEOGEwYmRJMkhtb0wrcDdoM2tqMUVsdXliQU1Xb3NHcmcxZWpVNjAvTVZtUEtvZFdBUXA4OFFvdVp1bjcwdVQ3TCtUcEJkbXRMMVhiV1JhTG5BVXhQbStxM2ZGUDBKdk9MK3JtUFZoaU9JNEhidHBoZ1R2dHVWUFdGWkJ3cmRveHp4U2V3S0JnUURPN205QlRUZENGNzQ1VC9mOTdsakxNQks5ZzdQVDRhNEllTzRBbmxvN29KRDBUNVcrYVVJRHJqZ0dVNG9za2R4a3dQem5yVkpCUDFvNEFyc1F4RHgySnIzcVdxM1R4Rk9JaEU4VFl4NExkWEZGMzRMM3VuVnkyOEROQnNVc1ZTWFVwc0NEaTkzNHVzN2Z2NndmeGRnVEdla1NVeGI0S3F4Znhsby9wTzkrMlFLQmdBOFUyNXlxaWQvOTEwYWJEaXNzbkUxSWcxcGY5Z1dOd0pJOURobnVoZHpLSTl6ZlFxeXNwWEpWTkVZL2pKVTFCN3RDOGpYellaZjFwbDJpOVdPZjc2Y0J4UUtMUkw3M1ppcFZBNXJ2U1RmRkJGcm9xbG00QVA1bWkzaEpSMWdZMVF3bkNiTG5DQ0dQSStxa1F4c2xqS1V1bVpKalBqN2ZnbWVrZXV5VUdDR1JBb0dBZWlsOEpSanRsZ1ljVG1Xd0w5RitrUFJDMmtXRVNmUFpKclZuOWkxZXdxa1QyYTYraG9OUnVGUHBpWTd1K1dPckJOcjJnUitYVytncmtUQVVCSUZXTEZReEk1Q0VrVkd0WUEySzQ4Zk9VSmxxRVZUQzM2SGNCcEFhc3hURjZTR21JTUkvVThENTBHNGdVNmJqN1NrZ05DS0hpam96eVcxK3IxMVdOeWFYV3kwPSMjI3BhY2thZ2VzbGk';
  }
}
