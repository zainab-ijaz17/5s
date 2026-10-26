export const APP_ROLES = [
  'admin',
  'power_user',
  'poweruser',
  'bu_manager',
  'bumanager',
  'manager',
  'auditor',
  'user',
] as const;

export type AppRole = (typeof APP_ROLES)[number];

export function normalizeRole(role?: string | null): AppRole {
  const normalized = (role ?? '').trim().toLowerCase();
  if (normalized === 'poweruser') return 'power_user';
  if (normalized === 'bumanager' || normalized === 'manager') {
    return 'bu_manager';
  }
  if ((APP_ROLES as readonly string[]).includes(normalized)) {
    return normalized as AppRole;
  }
  return 'user';
}
