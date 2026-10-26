/**
 * Hidden Gemba demo admin login (no UI shortcut — use normal sign-in form).
 * Credentials are checked server-side only before SuccessFactors auth.
 */

export const GEMBA_DEMO_ADMIN_EMPLOYEE_NUMBER = '1000000';
export const GEMBA_DEMO_ADMIN_PASSWORD = 'admin123';
export const GEMBA_DEMO_ADMIN_NAME = 'Gemba Demo Admin';

export function isGembaDemoAdminEnabled(raw: string | undefined): boolean {
  const value = (raw ?? 'true').trim().toLowerCase();
  return value !== '0' && value !== 'false' && value !== 'no';
}

export function matchesGembaDemoAdminCredentials(
  username: string,
  password: string,
  configuredEmployeeNumber: string = GEMBA_DEMO_ADMIN_EMPLOYEE_NUMBER,
  configuredPassword: string = GEMBA_DEMO_ADMIN_PASSWORD,
): boolean {
  const employee = username.trim();
  const expectedEmployee = configuredEmployeeNumber.trim();
  if (!employee || employee !== expectedEmployee) return false;
  return password === configuredPassword;
}
