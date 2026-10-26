/**
 * Exact port of Flutter EmailService._generateAssessmentEmailHtml /
 * _generateAssessmentEmailText so backend mail looks the same.
 */

export type AssessmentEmailItem = {
  question: string;
  answer: string;
  remarks: string | null;
  isFlagged: boolean;
  attachments: Array<{ url: string | null; localPath?: string | null }>;
};

export type AssessmentEmailData = {
  company: string;
  bu: string | null;
  section: string | null;
  auditorName: string;
  auditeeName: string;
  score: number;
  isFlagged: boolean;
  createdAt: Date;
  items: AssessmentEmailItem[];
};

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

function getFileName(pathOrUrl: string): string {
  const cleaned = pathOrUrl.split('?')[0] ?? pathOrUrl;
  const parts = cleaned.split(/[/\\]/);
  return parts[parts.length - 1] || cleaned;
}

function isAssessmentFlagged(data: AssessmentEmailData): boolean {
  return data.isFlagged || data.score < 90;
}

function assessmentStatusLabel(data: AssessmentEmailData): string {
  return isAssessmentFlagged(data) ? 'FLAGGED' : 'COMPLETED';
}

/** Same inline badge as Flutter EmailService._assessmentStatusBadgeHtml */
function assessmentStatusBadgeHtml(data: AssessmentEmailData): string {
  const flagged = isAssessmentFlagged(data);
  const label = flagged ? 'FLAGGED' : 'COMPLETED';
  const background = flagged ? '#EF4444' : '#10B981';
  return (
    `<span style="display:inline-block;padding:5px 14px;border-radius:16px;` +
    `font-weight:bold;color:#ffffff;background-color:${background};` +
    `margin-left:10px;font-size:13px;letter-spacing:0.3px;">${label}</span>`
  );
}

function collectImageUrls(
  item: AssessmentEmailItem,
  resolveUrl: (url: string | null | undefined) => string | null,
): string[] {
  const urls: string[] = [];
  for (const a of item.attachments) {
    const resolved = resolveUrl(a.url);
    if (resolved && !urls.includes(resolved)) urls.push(resolved);
  }
  return urls;
}

function collectAttachmentNames(
  item: AssessmentEmailItem,
  imageUrls: string[],
): string[] {
  const names: string[] = [];
  for (const a of item.attachments) {
    if (a.localPath && a.localPath.length > 0) {
      names.push(getFileName(a.localPath));
    }
  }
  // Backend usually only has URLs (Flutter already uploaded). Show filenames
  // like Flutter's "Attached: …" when local paths are absent.
  if (names.length === 0) {
    for (const url of imageUrls) {
      names.push(getFileName(url));
    }
  }
  return names;
}

export function buildAssessmentEmailHtml(
  data: AssessmentEmailData,
  resolveUrl: (url: string | null | undefined) => string | null,
): string {
  let questions = '';

  for (let i = 0; i < data.items.length; i++) {
    const item = data.items[i];
    const question = item.question ?? '';
    const answer = item.answer ?? 'N/A';
    const remarks = item.remarks ?? '';
    const isFlagged = item.isFlagged ?? false;
    const imageUrls = collectImageUrls(item, resolveUrl);
    const attachmentNames = collectAttachmentNames(item, imageUrls);

    questions += `
  <div class="question-item ${isFlagged ? 'flagged' : ''}">
    <div class="question-number">Question ${i + 1}</div>
    <div class="question-text">${escapeHtml(question)}</div>
    <div class="answer">
      <span class="answer-label">Answer: </span>
      <span class="answer-value">${escapeHtml(answer)}</span>
    </div>
`;

    if (remarks.trim().length > 0) {
      questions += `
    <div class="remarks">
      <strong>Remarks:</strong> ${escapeHtml(remarks)}
    </div>
`;
    } else {
      questions += `
    <div class="remarks no-remarks">No remarks provided</div>
`;
    }

    if (attachmentNames.length > 0 || imageUrls.length > 0) {
      questions += `
    <div class="image-attachment">
      <strong>Images:</strong>
      <div>
`;
      if (attachmentNames.length > 0) {
        questions += `<div>Attached: ${attachmentNames.map(escapeHtml).join(', ')}</div>`;
      }
      if (imageUrls.length > 0) {
        questions += '<div>Links:</div><ul>';
        for (const url of imageUrls) {
          questions += `<li><a href="${escapeHtml(url)}">${escapeHtml(url)}</a></li>`;
        }
        questions += '</ul>';
        // Inline previews so photos still show without SMTP file attachments
        // (frontend used to attach the files; layout stays the same above).
        questions +=
          '<div style="margin-top:12px;">' +
          imageUrls
            .map(
              (url) =>
                `<div style="margin:8px 0;"><img src="${escapeHtml(url)}" alt="${escapeHtml(getFileName(url))}" style="max-width:100%;height:auto;border-radius:4px;border:1px solid #ddd;display:block;" /></div>`,
            )
            .join('') +
          '</div>';
      }
      questions += `
      </div>
    </div>
`;
    }

    questions += `  </div>\n`;
  }

  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body {
      font-family: Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 800px;
      margin: 0 auto;
      padding: 20px;
    }
    .header {
      background-color: #0891B2;
      color: white;
      padding: 20px;
      border-radius: 5px;
      margin-bottom: 20px;
    }
    .info-section {
      background-color: #f5f5f5;
      padding: 15px;
      border-radius: 5px;
      margin-bottom: 20px;
    }
    .info-row {
      margin: 8px 0;
    }
    .info-label {
      font-weight: bold;
      display: inline-block;
      width: 150px;
    }
    .score-badge {
      display: inline-block;
      padding: 5px 15px;
      border-radius: 20px;
      font-weight: bold;
      color: white;
      margin-left: 10px;
    }
    .score-high {
      background-color: #10B981;
    }
    .score-low {
      background-color: #EF4444;
    }
    .question-item {
      border: 1px solid #ddd;
      border-radius: 5px;
      padding: 15px;
      margin-bottom: 15px;
      background-color: #fff;
    }
    .question-item.flagged {
      border-left: 4px solid #EF4444;
      background-color: #FEF2F2;
    }
    .question-number {
      font-weight: bold;
      color: #0891B2;
      margin-bottom: 8px;
    }
    .question-text {
      font-size: 14px;
      margin-bottom: 10px;
    }
    .answer {
      margin: 8px 0;
      padding: 8px;
      background-color: #f9f9f9;
      border-radius: 3px;
    }
    .answer-label {
      font-weight: bold;
      color: #666;
    }
    .answer-value {
      color: #0891B2;
      font-weight: bold;
    }
    .remarks {
      margin-top: 10px;
      padding: 10px;
      background-color: #F0F9FF;
      border-left: 3px solid #0891B2;
      font-style: italic;
    }
    .image-attachment {
      margin-top: 10px;
      padding: 10px;
      background-color: #F0F9FF;
      border-left: 3px solid #0891B2;
    }
    .no-remarks {
      color: #999;
      font-style: italic;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>5S Digital Assessment - Completed</h1>
  </div>
  
  <div class="info-section">
    <h2>Assessment Details</h2>
    <div class="info-row">
      <span class="info-label">Company:</span>
      <span>${escapeHtml(data.company)}</span>
    </div>
    <div class="info-row">
      <span class="info-label">Business Unit:</span>
      <span>${escapeHtml(data.bu ?? 'N/A')}</span>
    </div>
    <div class="info-row">
      <span class="info-label">Section:</span>
      <span>${escapeHtml(data.section ?? 'N/A')}</span>
    </div>
    <div class="info-row">
      <span class="info-label">Auditor:</span>
      <span>${escapeHtml(data.auditorName)}</span>
    </div>
    <div class="info-row">
      <span class="info-label">Auditee:</span>
      <span>${escapeHtml(data.auditeeName)}</span>
    </div>
    <div class="info-row">
      <span class="info-label">Date:</span>
      <span>${escapeHtml(formatDate(data.createdAt))}</span>
    </div>
    <div class="info-row">
      <span class="info-label">Score:</span>
      <span>${data.score}% ${assessmentStatusBadgeHtml(data)}</span>
    </div>
  </div>
  
  <h2>Assessment Questions & Answers</h2>
${questions}
  <div style="margin-top: 30px; padding: 15px; background-color: #f5f5f5; border-radius: 5px; text-align: center; color: #666; font-size: 12px;">
    This is an automated email from the 5S Digital Assessment System.
  </div>
</body>
</html>`;
}

export function buildAssessmentEmailText(
  data: AssessmentEmailData,
  resolveUrl: (url: string | null | undefined) => string | null,
): string {
  const lines: string[] = [];

  lines.push('5S Digital Assessment - Completed');
  lines.push('='.repeat(50));
  lines.push('');
  lines.push('Assessment Details:');
  lines.push(`  Company: ${data.company}`);
  lines.push(`  Business Unit: ${data.bu ?? 'N/A'}`);
  lines.push(`  Section: ${data.section ?? 'N/A'}`);
  lines.push(`  Auditor: ${data.auditorName}`);
  lines.push(`  Auditee: ${data.auditeeName}`);
  lines.push(`  Date: ${formatDate(data.createdAt)}`);
  lines.push(`  Score: ${data.score}% (${assessmentStatusLabel(data)})`);
  lines.push('');
  lines.push('Assessment Questions & Answers:');
  lines.push('='.repeat(50));
  lines.push('');

  for (let i = 0; i < data.items.length; i++) {
    const item = data.items[i];
    const question = item.question ?? '';
    const answer = item.answer ?? 'N/A';
    const remarks = item.remarks ?? '';
    const isFlagged = item.isFlagged ?? false;
    const imageUrls = collectImageUrls(item, resolveUrl);
    const attachmentNames = collectAttachmentNames(item, imageUrls);

    lines.push(`Question ${i + 1}${isFlagged ? ' [FLAGGED]' : ''}`);
    lines.push(question);
    lines.push(`Answer: ${answer}`);
    if (remarks.trim().length > 0) {
      lines.push(`Remarks: ${remarks}`);
    }
    if (attachmentNames.length > 0) {
      lines.push(`Images attached: ${attachmentNames.join(', ')}`);
    }
    for (const url of imageUrls) {
      lines.push(`Image link: ${url}`);
    }
    lines.push('');
  }

  return lines.join('\n');
}
