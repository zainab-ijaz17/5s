import {
  BadRequestException,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export type GembaEmployeeOption = {
  employeeNumber: string;
  name: string | null;
};

/**
 * SuccessFactors EmpJob employees: division query, then cost-center filter.
 */
@Injectable()
export class GembaEmployeesService {
  private readonly logger = new Logger(GembaEmployeesService.name);

  private static readonly SAP_BASE = 'https://api44.sapsf.com';
  private static readonly SAP_TOKEN_URL = 'https://api44.sapsf.com/oauth/token';
  private static readonly SAP_CLIENT_ID =
    'NmEwYWE4MDJmYmVlMjg2NGVhNzhjYzcwOWY2OA';
  private static readonly SF_FETCH_TIMEOUT_MS = 25_000;
  private static readonly EMPLOYEE_LIST_TTL_MS = 5 * 60 * 1000;
  private static readonly USER_NAME_BATCH_SIZE = 25;
  private static readonly USER_NAME_BATCH_CONCURRENCY = 4;
  private static readonly USER_NAME_FALLBACK_CONCURRENCY = 12;

  /** Form BU → SF division external code for EmpJob lookup. */
  private static readonly GEMBA_BU_DIVISIONS: Record<string, string> = {
    BUFP: '20000044',
    // BUFC: '...',
    // BUCP: '...',
  };

  /** Only employees in these cost centers are returned (within the division). */
  private static readonly GEMBA_COST_CENTERS = new Set([
    'PKGS1110150002',
    'PKGS1110100000',
    'PKGS1111100000',
    'PKGS1102154001',
    'PKGS1110150000',
    'PKGS1110500001',
    'PKGS1110152001',
    'PKGS1110151001',
    'PKGS1110151002',
  ]);

  private employeeListCache = new Map<
    string,
    { expiresAt: number; data: GembaEmployeeOption[] }
  >();
  private employeeListInflight = new Map<
    string,
    Promise<GembaEmployeeOption[]>
  >();
  private emailCache = new Map<
    string,
    { expiresAt: number; email: string | null }
  >();
  private static readonly EMAIL_LOOKUP_TTL_MS = 10 * 60 * 1000;
  private sapServiceToken: { token: string; expiresAt: number } | null = null;
  private sapServiceTokenInflight: Promise<string> | null = null;

  constructor(private readonly config: ConfigService) {}

  async listByBu(bu: string): Promise<GembaEmployeeOption[]> {
    const normalized = bu.trim().toUpperCase();
    const division = GembaEmployeesService.GEMBA_BU_DIVISIONS[normalized];
    if (!division) {
      throw new BadRequestException(
        'bu is not configured for Gemba employee lookup',
      );
    }

    const cached = this.employeeListCache.get(normalized);
    if (cached && cached.expiresAt > Date.now() && cached.data.length > 0) {
      return cached.data;
    }

    const inflight = this.employeeListInflight.get(normalized);
    if (inflight) return inflight;

    const loadPromise = this.loadEmployees(normalized, division)
      .then((data) => {
        if (data.length > 0) {
          this.employeeListCache.set(normalized, {
            data,
            expiresAt: Date.now() + GembaEmployeesService.EMPLOYEE_LIST_TTL_MS,
          });
        } else {
          this.employeeListCache.delete(normalized);
        }
        this.logger.log(
          `Loaded ${data.length} Gemba employees from SF for ${normalized} division ${division}`,
        );
        return data;
      })
      .finally(() => {
        this.employeeListInflight.delete(normalized);
      });

    this.employeeListInflight.set(normalized, loadPromise);
    return loadPromise;
  }

  /** Resolve work email from SuccessFactors (not exposed in the app UI). */
  async fetchUserEmail(employeeNumber: string): Promise<string | null> {
    const userId = employeeNumber.trim();
    if (!userId) return null;

    const cached = this.emailCache.get(userId);
    if (cached && cached.expiresAt > Date.now()) {
      return cached.email;
    }

    try {
      const sapAccessToken = await this.getServiceSapAccessToken();
      const email = await this.fetchUserEmailFromSf(sapAccessToken, userId);
      this.emailCache.set(userId, {
        email,
        expiresAt: Date.now() + GembaEmployeesService.EMAIL_LOOKUP_TTL_MS,
      });
      return email;
    } catch (error) {
      this.logger.warn(
        `SF email lookup failed for ${userId}: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      return null;
    }
  }

  private async fetchUserEmailFromSf(
    sapAccessToken: string,
    userId: string,
  ): Promise<string | null> {
    const escaped = userId.replace(/'/g, "''");
    const url =
      `${GembaEmployeesService.SAP_BASE}/odata/v2/User('${escaped}')` +
      `?$format=json&$select=email`;

    const response = await this.sapFetch(url, sapAccessToken);
    if (!response.ok) return null;

    const data = (await response.json()) as {
      d?: Record<string, unknown>;
    } & Record<string, unknown>;
    const user = (data.d ?? data) as Record<string, unknown>;
    const email =
      typeof user.email === 'string' ? user.email.trim().toLowerCase() : null;
    return email && this.isLikelyEmail(email) ? email : null;
  }

  private isLikelyEmail(value: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
  }

  private async loadEmployees(
    buLabel: string,
    division: string,
  ): Promise<GembaEmployeeOption[]> {
    const sapAccessToken = await this.getServiceSapAccessToken();

    const expanded = await this.fetchEmpJobByDivision(
      sapAccessToken,
      division,
      true,
    );

    let rows = expanded.rows;
    if (rows.length === 0) {
      rows = (await this.fetchEmpJobByDivision(
        sapAccessToken,
        division,
        false,
      )).rows;
    }

    const namesById = expanded.namesById;
    const userIdSet = new Set<string>();

    for (const row of rows) {
      const userId = row.userId?.trim();
      if (!userId) continue;

      const costCenter = this.readSfCode(row.costCenter);
      if (!costCenter || !this.isAllowedCostCenter(costCenter)) continue;

      userIdSet.add(userId);
      const raw =
        row.userNav?.displayName ?? row.userNav?.d?.displayName ?? null;
      const displayName =
        typeof raw === 'string' ? raw.trim() || null : null;
      if (displayName) namesById.set(userId, displayName);
    }

    const userIds = [...userIdSet];
    await this.ensureDisplayNames(sapAccessToken, userIds, namesById);

    const employees = userIds.map((employeeNumber) => ({
      employeeNumber,
      name: namesById.get(employeeNumber) ?? null,
    }));

    employees.sort((a, b) => {
      const nameA = (a.name || a.employeeNumber).toLowerCase();
      const nameB = (b.name || b.employeeNumber).toLowerCase();
      const byName = nameA.localeCompare(nameB);
      if (byName !== 0) return byName;
      return a.employeeNumber.localeCompare(b.employeeNumber, undefined, {
        numeric: true,
      });
    });

    if (employees.length === 0) {
      this.logger.warn(
        `No Gemba employees matched cost-center filter for ${buLabel} division ${division}`,
      );
    }

    return employees;
  }

  private async fetchEmpJobByDivision(
    sapAccessToken: string,
    division: string,
    expandUser: boolean,
  ): Promise<{
    rows: Array<{
      userId?: string;
      costCenter?: unknown;
      userNav?: {
        displayName?: string;
        d?: { displayName?: string };
      } | null;
    }>;
    namesById: Map<string, string | null>;
  }> {
    const namesById = new Map<string, string | null>();
    const escaped = division.replace(/'/g, "''");
    const url =
      `${GembaEmployeesService.SAP_BASE}/odata/v2/EmpJob` +
      `?$format=json&$top=500` +
      `&$filter=${encodeURIComponent(`division eq '${escaped}'`)}` +
      (expandUser
        ? `&$select=userId,costCenter,userNav/displayName&$expand=userNav`
        : `&$select=userId,costCenter`);

    try {
      const response = await this.sapFetch(url, sapAccessToken);
      if (!response.ok) {
        const body = await response.text().catch(() => '');
        this.logger.warn(
          `EmpJob division=${division} expand=${expandUser} failed (${response.status}) ${body.slice(0, 180)}`,
        );
        return { rows: [], namesById };
      }

      const data = (await response.json()) as {
        d?: {
          results?: Array<{
            userId?: string;
            costCenter?: unknown;
            userNav?: {
              displayName?: string;
              d?: { displayName?: string };
            } | null;
          }>;
        };
        results?: Array<{
          userId?: string;
          costCenter?: unknown;
          userNav?: {
            displayName?: string;
            d?: { displayName?: string };
          } | null;
        }>;
      };

      const rows = data.d?.results ?? data.results ?? [];

      if (expandUser) {
        for (const row of rows) {
          const userId = row.userId?.trim();
          if (!userId) continue;
          const raw =
            row.userNav?.displayName ?? row.userNav?.d?.displayName ?? null;
          const displayName =
            typeof raw === 'string' ? raw.trim() || null : null;
          if (displayName) namesById.set(userId, displayName);
        }
      }

      return { rows, namesById };
    } catch (error) {
      this.logger.warn(
        `EmpJob division=${division} expand=${expandUser} error: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
      return { rows: [], namesById };
    }
  }

  private normalizeCostCenter(code: string): string {
    const trimmed = code.trim().toUpperCase();
    return trimmed.startsWith('PKGS') ? trimmed : `PKGS${trimmed}`;
  }

  private isAllowedCostCenter(costCenter: string): boolean {
    return GembaEmployeesService.GEMBA_COST_CENTERS.has(
      this.normalizeCostCenter(costCenter),
    );
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

  private async ensureDisplayNames(
    sapAccessToken: string,
    userIds: string[],
    namesById: Map<string, string | null>,
  ) {
    let missing = userIds.filter((id) => !namesById.get(id)?.trim());
    if (missing.length === 0) return;

    const batched = await this.fetchDisplayNamesBatched(
      sapAccessToken,
      missing,
    );
    for (const [userId, displayName] of batched) {
      if (displayName?.trim()) namesById.set(userId, displayName.trim());
    }

    missing = userIds.filter((id) => !namesById.get(id)?.trim());
    if (missing.length === 0) return;

    await this.mapWithConcurrency(
      missing,
      GembaEmployeesService.USER_NAME_FALLBACK_CONCURRENCY,
      async (userId) => {
        namesById.set(
          userId,
          await this.fetchUserDisplayName(sapAccessToken, userId),
        );
      },
    );
  }

  private async fetchDisplayNamesBatched(
    sapAccessToken: string,
    userIds: string[],
  ): Promise<Map<string, string | null>> {
    const names = new Map<string, string | null>();
    if (userIds.length === 0) return names;

    const chunks: string[][] = [];
    for (
      let i = 0;
      i < userIds.length;
      i += GembaEmployeesService.USER_NAME_BATCH_SIZE
    ) {
      chunks.push(
        userIds.slice(i, i + GembaEmployeesService.USER_NAME_BATCH_SIZE),
      );
    }

    await this.mapWithConcurrency(
      chunks,
      GembaEmployeesService.USER_NAME_BATCH_CONCURRENCY,
      async (chunk) => {
        const filter = chunk
          .map((id) => `userId eq '${id.replace(/'/g, "''")}'`)
          .join(' or ');
        const url =
          `${GembaEmployeesService.SAP_BASE}/odata/v2/User` +
          `?$format=json&$top=${chunk.length}` +
          `&$select=userId,displayName` +
          `&$filter=${encodeURIComponent(filter)}`;

        try {
          const response = await this.sapFetch(url, sapAccessToken);
          if (!response.ok) return;
          const data = (await response.json()) as {
            d?: {
              results?: Array<{ userId?: string; displayName?: string }>;
            };
            results?: Array<{ userId?: string; displayName?: string }>;
          };
          for (const row of data.d?.results ?? data.results ?? []) {
            const userId = row.userId?.trim();
            if (!userId) continue;
            names.set(
              userId,
              typeof row.displayName === 'string'
                ? row.displayName.trim() || null
                : null,
            );
          }
        } catch {
          // covered by per-user fallback
        }
      },
    );

    return names;
  }

  private async fetchUserDisplayName(
    sapAccessToken: string,
    userId: string,
  ): Promise<string | null> {
    if (!sapAccessToken || !userId.trim()) return null;
    const escaped = userId.replace(/'/g, "''");
    const url =
      `${GembaEmployeesService.SAP_BASE}/odata/v2/User('${escaped}')` +
      `?$format=json&$select=displayName`;
    const response = await this.sapFetch(url, sapAccessToken);
    if (!response.ok) return null;
    const data = (await response.json()) as {
      d?: Record<string, unknown>;
    } & Record<string, unknown>;
    const user = (data.d ?? data) as Record<string, unknown>;
    return typeof user.displayName === 'string'
      ? user.displayName.trim() || null
      : null;
  }

  private async mapWithConcurrency<T, R>(
    items: T[],
    concurrency: number,
    mapper: (item: T) => Promise<R>,
  ): Promise<R[]> {
    if (items.length === 0) return [];
    const limit = Math.max(1, concurrency);
    const results = new Array<R>(items.length);
    let nextIndex = 0;

    async function worker() {
      while (nextIndex < items.length) {
        const current = nextIndex;
        nextIndex += 1;
        results[current] = await mapper(items[current]);
      }
    }

    await Promise.all(
      Array.from({ length: Math.min(limit, items.length) }, () => worker()),
    );
    return results;
  }

  private async getServiceSapAccessToken() {
    const now = Date.now();
    if (
      this.sapServiceToken &&
      this.sapServiceToken.expiresAt > now + 30_000
    ) {
      return this.sapServiceToken.token;
    }
    if (this.sapServiceTokenInflight) {
      return this.sapServiceTokenInflight;
    }

    this.sapServiceTokenInflight = (async () => {
      const assertion = await this.step2Idp();
      const sapToken = await this.step3Token(assertion);
      const token = String(sapToken.access_token ?? '');
      if (!token) {
        throw new UnauthorizedException('SAP service token unavailable');
      }
      const expiresInSec = Number(sapToken.expires_in);
      const ttlMs =
        Number.isFinite(expiresInSec) && expiresInSec > 60
          ? expiresInSec * 1000
          : 55 * 60 * 1000;
      this.sapServiceToken = {
        token,
        expiresAt: Date.now() + ttlMs,
      };
      return token;
    })().finally(() => {
      this.sapServiceTokenInflight = null;
    });

    return this.sapServiceTokenInflight;
  }

  private async step2Idp(): Promise<string> {
    const privateKey =
      this.config.get<string>('SAP_PRIVATE_KEY')?.trim() ||
      this.defaultPrivateKey();
    const body = new URLSearchParams({
      user_id: this.config.get<string>('SAP_IDP_USER_ID', 'ECAdmin'),
      token_url: GembaEmployeesService.SAP_TOKEN_URL,
      private_key: privateKey,
      client_id: this.config.get<string>(
        'SAP_CLIENT_ID',
        GembaEmployeesService.SAP_CLIENT_ID,
      ),
    });
    const response = await fetch(
      `${GembaEmployeesService.SAP_BASE}/oauth/idp`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body,
      },
    );
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
        GembaEmployeesService.SAP_CLIENT_ID,
      ),
      grant_type: 'urn:ietf:params:oauth:grant-type:saml2-bearer',
      company_id: this.config.get<string>('SAP_COMPANY_ID', 'packagesli'),
      assertion,
    });
    const response = await fetch(GembaEmployeesService.SAP_TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });
    if (!response.ok) {
      throw new UnauthorizedException('SAP token exchange failed');
    }
    return (await response.json()) as Record<string, unknown>;
  }

  private async sapFetch(url: string, sapAccessToken: string) {
    const controller = new AbortController();
    const timer = setTimeout(
      () => controller.abort(),
      GembaEmployeesService.SF_FETCH_TIMEOUT_MS,
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

  private defaultPrivateKey(): string {
    return 'TUlJRXZRSUJBREFOQmdrcWhraUc5dzBCQVFFRkFBU0NCS2N3Z2dTakFnRUFBb0lCQVFEaU1RbUpZOFJwa1MwVnlrbzg4ckpMQm9ZaHhCUU5HNWs4Q0RId2J6SkZFT1BNLzJndEJSd1liL3czbGJkM2RHRXRUajg0WEZQZ05PZTJaeVhETHlDWW1rTEVmcWhHS0VKb1hqSVV6enhiUHpoNHN2ZDFPVjMvTEl2M25ZR1BUeEZYamdJT213T0piS1gyUFY0eENad1NzWGtwVEJwcFRTN0o4Vk11RnIwL2FLZFlMY2lYSjEzV0tlRjlJZXVhWHlGRW1HNjh5bmdzK25FWDNWZWVnRW1vQi95cmhMbmlhM2t6cEc4U2hlS2JnSU9NUU81MGR6YjEyRFY0NDNYN2hPNm1YbTYvMU54NlVhVUVzZ3VSQ24vTDM4RGtOcnd5OVR1M0xtcFBwQzNmS2VEbExDamVFN0FkQWMvU2l0TWRuWThqbko0Q1lqeW1selZxNVJneHFBY0JBZ01CQUFFQ2dnRUFUTTBpdEZROFVpMzVsWDhBMHc0RERPZHpyczVoa292TzdXdkk3UjhNZmhmOGlWUWxucmV2OFBwQk5PeHdoYTV0K3BDcGRhMGZ5NjZiQ0x1Z1BsUm5xSGtrZDR5Yi9XcFpGZy81eUVnUGNkb1hCaUNhVm1LNnNGU0RWL25Tam9MbDNBazdXSk00MGJZaTZlZXZiazRaZ04xaXl1dHN3bGx6TEIxMVJWNXlOcTlpUXE0SVhDSkxuRVQ4ZGdWVWladUo4OUxUeFlMUFBBcWROL0ZueDNkb2k4cmhjc05kUVlTT1FMSUoybHpPVFNhWjJWQmM3eHNRTjNVZFJnTHlCWkZLSGNnUTUzRjhaVy9aOUwwVHRRZjJXWjVUSnhwM1F3V25zREE2c1NncTRTSEYrQ0c3M3paQzc4eXRtUm5NMXk5SnVoRmViOUhUb3hFNE1nQjVPTWFjMndLQmdRRDJEb1UxenBVY29DY0ZVdU1RRUNobDJxV0hGS1hDaDNNazM5NnRMUzNFN29uWGRvL25Vb3huNVJQaHpwNk52VVRLcGNUL0JwRStjNVBVZ3M5NEphcFRJeWJha09yQnlmZ1NHRit1TUROWWdnbXRMYkNOZkZZTG90TWlwZGlxQWpQT2ZWdWZxMjk2REk2OFdOemRVbml4ak5SZ3F0SkJTMUpmUDZSNGRtR2hzd0tCZ1FEclZRS0g3dGdyWVhxcDFXRnFlR2owR2w3R0xPS1haRlhTQk9XYldEOGEwYmRJMkhtb0wrcDdoM2tqMUVsdXliQU1Xb3NHcmcxZWpVNjAvTVZtUEtvZFdBUXA4OFFvdVp1bjcwdVQ3TCtUcEJkbXRMMVhiV1JhTG5BVXhQbStxM2ZGUDBKdk9MK3JtUFZoaU9JNEhidHBoZ1R2dHVWUFdGWkJ3cmRveHp4U2V3S0JnUURPN205QlRUZENGNzQ1VC9mOTdsakxNQks5ZzdQVDRhNEllTzRBbmxvN29KRDBUNVcrYVVJRHJqZ0dVNG9za2R4a3dQem5yVkpCUDFvNEFyc1F4RHgySnIzcVdxM1R4Rk9JaEU4VFl4NExkWEZGMzRMM3VuVnkyOEROQnNVc1ZTWFVwc0NEaTkzNHVzN2Z2NndmeGRnVEdla1NVeGI0S3F4Znhsby9wTzkrMlFLQmdBOFUyNXlxaWQvOTEwYWJEaXNzbkUxSWcxcGY5Z1dOd0pJOURobnVoZHpLSTl6ZlFxeXNwWEpWTkVZL2pKVTFCN3RDOGpYellaZjFwbDJpOVdPZjc2Y0J4UUtMUkw3M1ppcFZBNXJ2U1RmRkJGcm9xbG00QVA1bWkzaEpSMWdZMVF3bkNiTG5DQ0dQSStxa1F4c2xqS1V1bVpKalBqN2ZnbWVrZXV5VUdDR1JBb0dBZWlsOEpSanRsZ1ljVG1Xd0w5RitrUFJDMmtXRVNmUFpKclZuOWkxZXdxa1QyYTYraG9OUnVGUHBpWTd1K1dPckJOcjJnUitYVytncmtUQVVCSUZXTEZReEk1Q0VrVkd0WUEySzQ4Zk9VSmxxRVZUQzM2SGNCcEFhc3hURjZTR21JTUkvVThENTBHNGdVNmJqN1NrZ05DS0hpam96eVcxK3IxMVdOeWFYV3kwPSMjI3BhY2thZ2VzbGk';
  }
}
