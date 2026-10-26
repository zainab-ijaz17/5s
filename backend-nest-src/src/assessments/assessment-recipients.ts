/**
 * Assessment email recipients (ported from Flutter AssessmentRecipients).
 * EMAIL_TESTING_MODE overrides the production directory until testing is done.
 */

export const EMAIL_TESTING_MODE = true;

export const EMAIL_TESTING_RECIPIENTS: string[] = ['anasbabar404@gmail.com'];
// export const EMAIL_TESTING_RECIPIENTS: string[] = [
//   'anasbabar404@gmail.com',
//   'usman.muhammad@packages.com.pk',
// ];

export const ASSESSMENT_CC_EMAIL = 'anas.babar@packages.com.pk';

const BUFP_RECIPIENTS = [
  'tooba.shahid@packages.com.pk',
  'iftikhar.alam@packages.com.pk',
  'usman.muhammad@packages.com.pk',
  'hafiz.yousaf@packages.com.pk',
];

/** Production BU / section directory. */
const RECIPIENT_MAP: Record<string, Record<string, string[]>> = {
  BUCP: {
    'Facial Tissue': [
      'manahill.iftikhar@packages.com.pk',
      'Muaz.Hashmi@packages.com.pk',
      'usman.muhammad@packages.com.pk',
    ],
    'Non-Tissue': [
      'manahill.iftikhar@packages.com.pk',
      'Muaz.Hashmi@packages.com.pk',
      'usman.muhammad@packages.com.pk',
    ],
    'Tissue Roll': [
      'manahill.iftikhar@packages.com.pk',
      'Muaz.Hashmi@packages.com.pk',
      'usman.muhammad@packages.com.pk',
    ],
    'PM-09': [
      'aansa.batool@packages.com.pk',
      'shoaib.riasat@packages.com.pk',
      'hammad.razaq@packages.com.pk',
      'usman.muhammad@packages.com.pk',
    ],
    FemCare: [
      'nimra.areeb@packages.com.pk',
      'muhammad.zeeshan@packages.com.pk',
      'usman.muhammad@packages.com.pk',
    ],
  },
  BUFC: {
    'Folding & Gluing': [
      'aliza.imam@packages.com.pk',
      'daud.jabran@packages.com.pk',
    ],
    'Offset Printing': [
      'aliza.imam@packages.com.pk',
      'daud.jabran@packages.com.pk',
    ],
    'Roto Line': [
      'aliza.imam@packages.com.pk',
      'daud.jabran@packages.com.pk',
    ],
    'Sorting & Breaking': [
      'aliza.imam@packages.com.pk',
      'daud.jabran@packages.com.pk',
    ],
    'FG& paper Cup': [
      'aliza.imam@packages.com.pk',
      'daud.jabran@packages.com.pk',
    ],
  },
  BUFP: {
    Printing: BUFP_RECIPIENTS,
    Lamination: BUFP_RECIPIENTS,
    Extrusion: BUFP_RECIPIENTS,
    Slitting: BUFP_RECIPIENTS,
    'Mechanical Workshop': BUFP_RECIPIENTS,
    'Electrical Workshop': BUFP_RECIPIENTS,
  },
};

function normalizeSection(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]/g, '');
}

export function getDirectoryRecipients(
  bu?: string | null,
  section?: string | null,
): string[] {
  if (!bu) return [];
  const buMap = RECIPIENT_MAP[bu];
  if (!buMap) return [];

  if (!section) {
    return Array.from(new Set(Object.values(buMap).flat()));
  }

  const exact = buMap[section];
  if (exact) return [...exact];

  const normalized = normalizeSection(section);
  for (const [key, emails] of Object.entries(buMap)) {
    if (normalizeSection(key) === normalized) {
      return [...emails];
    }
  }
  return [];
}

/** Company-level extras previously applied in Flutter EmailService. */
export function getCompanyExtraRecipients(company?: string | null): string[] {
  if (company === 'Packages Convertors Limited' || company === 'Tri-Pack') {
    return [
      'usman.muhammad@packages.com.pk',
      'muhammad.ammad@packages.com.pk',
    ];
  }
  return [];
}
