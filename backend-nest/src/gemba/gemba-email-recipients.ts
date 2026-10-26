/**
 * Digital Gemba email routing (separate from 5S assessment recipients).
 * SF emails are used in production; testing mode overrides delivery only.
 */

export const GEMBA_EMAIL_TESTING_MODE = true;

export const GEMBA_EMAIL_TESTING_RECIPIENTS: string[] = [
  'anasbabar404@gmail.com',
];

export const GEMBA_EMAIL_CC = 'anas.babar@packages.com.pk';

export function resolveGembaRecipients(sfEmail: string | null): string[] {
  if (GEMBA_EMAIL_TESTING_MODE) {
    return [...GEMBA_EMAIL_TESTING_RECIPIENTS];
  }
  const trimmed = sfEmail?.trim().toLowerCase();
  if (!trimmed) return [];
  return [trimmed];
}
