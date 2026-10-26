/**
 * HTML + plain-text templates for Digital Gemba observation emails.
 * Photos are embedded inline via MIME Content-ID (no remote URL fetch in clients).
 */

export type GembaObservationEmailData = {
  id: string;
  title: string;
  location: string;
  category: string;
  status: string;
  company: string;
  bu: string | null;
  section: string | null;
  machineValue: string | null;
  remarks: string;
  afterRemarks?: string | null;
  assignedEmployeeNumber: string;
  assignedEmployeeName: string | null;
  createdByEmployeeNumber: string;
  createdByName: string | null;
  completedByEmployeeNumber?: string | null;
  completedByName?: string | null;
  createdAt: Date;
  completedAt?: Date | null;
  beforePhotoCids: string[];
  afterPhotoCids: string[];
};

export type GembaEmailKind = 'assigned' | 'completed';

/** Fixed display size for photos in email clients (many ignore class-based CSS). */
const EMAIL_PHOTO_WIDTH_PX = 280;
const EMAIL_PHOTO_MAX_HEIGHT_PX = 210;

function emailPhotoStyle(): string {
  return (
    `display:block;width:${EMAIL_PHOTO_WIDTH_PX}px;max-width:100%;` +
    `height:auto;max-height:${EMAIL_PHOTO_MAX_HEIGHT_PX}px;` +
    'border-radius:8px;border:1px solid #d6eaf8;margin:0 0 10px;'
  );
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function formatDate(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  const hh = String(date.getHours()).padStart(2, '0');
  const mm = String(date.getMinutes()).padStart(2, '0');
  return `${y}-${m}-${d} ${hh}:${mm}`;
}

function displayName(name: string | null | undefined, fallback: string): string {
  const trimmed = name?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : fallback;
}

function statusBadge(status: string): string {
  const done = status.trim().toLowerCase() === 'done';
  const bg = done ? '#10B981' : '#008FD5';
  const label = done ? 'DONE' : 'IN PROGRESS';
  return (
    `<span style="display:inline-block;padding:5px 14px;border-radius:16px;` +
    `font-weight:bold;color:#ffffff;background-color:${bg};` +
    `font-size:12px;letter-spacing:0.4px;">${label}</span>`
  );
}

function infoRow(label: string, value: string): string {
  return `
    <div class="info-row">
      <span class="info-label">${escapeHtml(label)}</span>
      <span>${escapeHtml(value)}</span>
    </div>`;
}

function remarksBlock(title: string, text: string): string {
  return `
    <div class="remarks">
      <div class="remarks-title">${escapeHtml(title)}</div>
      <div>${escapeHtml(text.trim() || '—')}</div>
    </div>`;
}

function buildObservationBody(kind: GembaEmailKind, data: GembaObservationEmailData): string {
  if (kind === 'assigned') {
    return (
      remarksBlock('Before remarks', data.remarks) +
      inlinePhotoSection('Before', data.beforePhotoCids)
    );
  }

  return (
    remarksBlock('Before remarks', data.remarks) +
    inlinePhotoSection('Before', data.beforePhotoCids) +
    remarksBlock('After remarks', data.afterRemarks ?? '') +
    inlinePhotoSection('After', data.afterPhotoCids)
  );
}

function inlinePhotoSection(title: string, cids: string[]): string {
  if (cids.length === 0) {
    return `
    <div class="photo-section">
      <div class="photo-title">${escapeHtml(title)}</div>
      <div class="photo-empty">No photos</div>
    </div>`;
  }

  const images = cids
    .map(
      (cid, index) =>
        `<img src="cid:${escapeHtml(cid)}" alt="${escapeHtml(title)} photo ${index + 1}" ` +
        `width="${EMAIL_PHOTO_WIDTH_PX}" style="${emailPhotoStyle()}" />`,
    )
    .join('');

  return `
    <div class="photo-section">
      <div class="photo-title">${escapeHtml(title)}</div>
      <div class="photo-images">${images}</div>
    </div>`;
}

function baseStyles(): string {
  return `
    body {
      font-family: Arial, Helvetica, sans-serif;
      line-height: 1.6;
      color: #1e293b;
      max-width: 760px;
      margin: 0 auto;
      padding: 20px;
      background: #f8fafc;
    }
    .card {
      background: #ffffff;
      border: 1px solid #d6eaf8;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 8px 24px rgba(15, 23, 42, 0.06);
    }
    .header {
      background: linear-gradient(135deg, #006BA6 0%, #008FD5 55%, #4DB8E8 100%);
      color: #ffffff;
      padding: 24px 22px;
    }
    .header h1 {
      margin: 0 0 6px;
      font-size: 22px;
      font-weight: 700;
    }
    .header p {
      margin: 0;
      opacity: 0.92;
      font-size: 14px;
    }
    .content {
      padding: 22px;
    }
    .info-section {
      background: #e8f4fc;
      padding: 16px;
      border-radius: 10px;
      margin-bottom: 18px;
    }
    .info-row {
      margin: 7px 0;
      font-size: 14px;
    }
    .info-label {
      font-weight: 700;
      display: inline-block;
      width: 150px;
      color: #006BA6;
    }
    .remarks {
      background: #f8fafc;
      border-left: 4px solid #008FD5;
      padding: 14px 16px;
      border-radius: 8px;
      margin-bottom: 16px;
    }
    .remarks-title {
      font-weight: 700;
      color: #006BA6;
      margin-bottom: 6px;
    }
    .photo-section {
      border: 1px solid #d6eaf8;
      border-radius: 10px;
      padding: 14px;
      background: #ffffff;
      margin-bottom: 14px;
    }
    .photo-title {
      font-weight: 700;
      color: #008FD5;
      margin-bottom: 10px;
      font-size: 14px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .photo-images img {
      width: ${EMAIL_PHOTO_WIDTH_PX}px;
      max-width: 100%;
      height: auto;
      max-height: ${EMAIL_PHOTO_MAX_HEIGHT_PX}px;
      border-radius: 8px;
      border: 1px solid #d6eaf8;
      margin: 0 0 10px;
      display: block;
    }
    .photo-empty {
      font-size: 13px;
      color: #94a3b8;
      font-style: italic;
    }
    .footer {
      padding: 16px 22px 22px;
      font-size: 12px;
      color: #64748b;
      border-top: 1px solid #e2e8f0;
    }`;
}

export function buildGembaObservationEmailSubject(
  kind: GembaEmailKind,
  data: GembaObservationEmailData,
): string {
  const section = data.section?.trim() || data.location.trim() || 'General';
  if (kind === 'assigned') {
    return `Digital Gemba - New observation assigned - ${data.category} - ${section}`;
  }
  return `Digital Gemba - Observation completed - ${data.category} - ${section}`;
}

export function buildGembaObservationEmailHtml(
  kind: GembaEmailKind,
  data: GembaObservationEmailData,
): string {
  const isAssigned = kind === 'assigned';
  const headline = isAssigned
    ? 'New Gemba observation assigned to you'
    : 'Gemba observation marked as Done';
  const intro = isAssigned
    ? 'A new shop-floor observation has been assigned to you in Digital Gemba. Please review the details below and complete the required action.'
    : 'An observation you created has been marked as Done. Review the before and after details below.';

  const assignee = displayName(
    data.assignedEmployeeName,
    data.assignedEmployeeNumber,
  );
  const creator = displayName(
    data.createdByName,
    data.createdByEmployeeNumber,
  );
  const completer = displayName(
    data.completedByName,
    data.completedByEmployeeNumber ?? '—',
  );

  const locationParts = [
    data.company,
    data.bu,
    data.section,
    data.machineValue,
  ].filter((part) => !!part?.trim());

  const observationBody = buildObservationBody(kind, data);

  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>${baseStyles()}</style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1>${escapeHtml(headline)}</h1>
      <p>${escapeHtml(intro)}</p>
    </div>
    <div class="content">
      <div style="margin-bottom:16px;">${statusBadge(data.status)}</div>
      <div class="info-section">
        ${infoRow('Observation', data.title)}
        ${infoRow('Category', data.category)}
        ${infoRow('Location', locationParts.join(' / ') || data.location)}
        ${infoRow('Assigned to', assignee)}
        ${infoRow('Created by', creator)}
        ${isAssigned ? '' : infoRow('Completed by', completer)}
        ${infoRow('Created at', formatDate(data.createdAt))}
        ${data.completedAt ? infoRow('Completed at', formatDate(data.completedAt)) : ''}
      </div>
      ${observationBody}
    </div>
    <div class="footer">
      Packages Group · Digital Gemba · Observation ID ${escapeHtml(data.id)}
    </div>
  </div>
</body>
</html>`;
}

function photoCountLines(title: string, count: number): string[] {
  if (count <= 0) return [`${title}:`, '- None'];
  return [`${title}:`, `- ${count} photo(s) embedded in HTML`];
}

export function buildGembaObservationEmailText(
  kind: GembaEmailKind,
  data: GembaObservationEmailData,
): string {
  const isAssigned = kind === 'assigned';
  const headline = isAssigned
    ? 'NEW GEMBA OBSERVATION ASSIGNED'
    : 'GEMBA OBSERVATION COMPLETED';

  const assignee = displayName(
    data.assignedEmployeeName,
    data.assignedEmployeeNumber,
  );
  const creator = displayName(
    data.createdByName,
    data.createdByEmployeeNumber,
  );
  const completer = displayName(
    data.completedByName,
    data.completedByEmployeeNumber ?? '—',
  );

  const lines = [
    headline,
    '='.repeat(headline.length),
    '',
    `Observation: ${data.title}`,
    `Category: ${data.category}`,
    `Status: ${data.status}`,
    `Company: ${data.company}`,
    ...(data.bu ? [`BU: ${data.bu}`] : []),
    ...(data.section ? [`Section: ${data.section}`] : []),
    ...(data.machineValue ? [`Machine: ${data.machineValue}`] : []),
    `Assigned to: ${assignee}`,
    `Created by: ${creator}`,
    ...(isAssigned ? [] : [`Completed by: ${completer}`]),
    `Created at: ${formatDate(data.createdAt)}`,
    ...(data.completedAt
      ? [`Completed at: ${formatDate(data.completedAt)}`]
      : []),
    '',
    'Before remarks:',
    data.remarks.trim() || '—',
    '',
    ...photoCountLines('Before', data.beforePhotoCids.length),
  ];

  if (!isAssigned) {
    lines.push(
      '',
      'After remarks:',
      data.afterRemarks?.trim() || '—',
      '',
      ...photoCountLines('After', data.afterPhotoCids.length),
    );
  }

  lines.push(
    '',
    'Photos are embedded in the HTML version of this email.',
    '',
    `Observation ID: ${data.id}`,
    'Packages Group · Digital Gemba',
  );

  return lines.join('\n');
}
