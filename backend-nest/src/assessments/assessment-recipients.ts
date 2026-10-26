/**
 * Assessment email recipients.
 * Production directory is commented out — testing inbox only for now.
 */

/** When true, all 5S assessment + follow-up emails go only to testing recipients. */
export const EMAIL_TESTING_MODE = true;

/** Testing inbox for 5S emails (assessment submit + follow-up sweep). */
export const EMAIL_TESTING_RECIPIENTS: string[] = ['anasbabar404@gmail.com'];

// export const ASSESSMENT_CC_EMAIL = 'anas.babar@packages.com.pk';

/*
 * Production recipients (disabled during testing):
 *
 * const BUFP_RECIPIENTS = [
 *   'tooba.shahid@packages.com.pk',
 *   'iftikhar.alam@packages.com.pk',
 *   'usman.muhammad@packages.com.pk',
 *   'hafiz.yousaf@packages.com.pk',
 * ];
 *
 * const RECIPIENT_MAP: Record<string, Record<string, string[]>> = { ... };
 */

export function getDirectoryRecipients(
  _bu?: string | null,
  _section?: string | null,
): string[] {
  return [];
}

/** Company-level extras — disabled during testing. */
export function getCompanyExtraRecipients(_company?: string | null): string[] {
  return [];
}
