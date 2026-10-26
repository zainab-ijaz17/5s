/**
 * One-off: compare division EmpJob rows vs PKGS cost-center filter.
 * Run: node scripts/debug-gemba-cost-centers.mjs
 */

const SAP_BASE = 'https://api44.sapsf.com';
const SAP_TOKEN_URL = 'https://api44.sapsf.com/oauth/token';
const SAP_CLIENT_ID = 'NmEwYWE4MDJmYmVlMjg2NGVhNzhjYzcwOWY2OA';
const DIVISION = '20000044';

const ALLOWED = new Set([
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

const DEFAULT_KEY =
  'TUlJRXZRSUJBREFOQmdrcWhraUc5dzBCQVFFRkFBU0NCS2N3Z2dTakFnRUFBb0lCQVFEaU1RbUpZOFJwa1MwVnlrbzg4ckpMQm9ZaHhCUU5HNWs4Q0RId2J6SkZFT1BNLzJndEJSd1liL3czbGJkM2RHRXRUajg0WEZQZ05PZTJaeVhETHlDWW1rTEVmcWhHS0VKb1hqSVV6enhiUHpoNHN2ZDFPVjMvTEl2M25ZR1BUeEZYamdJT213T0piS1gyUFY0eENad1NzWGtwVEJwcFRTN0o4Vk11RnIwL2FLZFlMY2lYSjEzV0tlRjlJZXVhWHlGRW1HNjh5bmdzK25FWDNWZWVnRW1vQi95cmhMbmlhM2t6cEc4U2hlS2JnSU9NUU81MGR6YjEyRFY0NDNYN2hPNm1YbTYvMU54NlVhVUVzZ3VSQ24vTDM4RGtOcnd5OVR1M0xtcFBwQzNmS2VEbExDamVFN0FkQWMvU2l0TWRuWThqbko0Q1lqeW1selZxNVJneHFBY0JBZ01CQUFFQ2dnRUFUTTBpdEZROFVpMzVsWDhBMHc0RERPZHpyczVoa292TzdXdkk3UjhNZmhmOGlWUWxucmV2OFBwQk5PeHdoYTV0K3BDcGRhMGZ5NjZiQ0x1Z1BsUm5xSGtrZDR5Yi9XcFpGZy81eUVnUGNkb1hCaUNhVm1LNnNGU0RWL25Tam9MbDNBazdXSk00MGJZaTZlZXZiazRaZ04xaXl1dHN3bGx6TEIxMVJWNXlOcTlpUXE0SVhDSkxuRVQ4ZGdWVWladUo4OUxUeFlMUFBBcWROL0ZueDNkb2k4cmhjc05kUVlTT1FMSUoybHpPVFNhWjJWQmM3eHNRTjNVZFJnTHlCWkZLSGNnUTUzRjhaVy9aOUwwVHRRZjJXWjVUSnhwM1F3V25zREE2c1NncTRTSEYrQ0c3M3paQzc4eXRtUm5NMXk5SnVoRmViOUhUb3hFNE1nQjVPTWFjMndLQmdRRDJEb1UxenBVY29DY0ZVdU1RRUNobDJxV0hGS1hDaDNNazM5NnRMUzNFN29uWGRvL25Vb3huNVJQaHpwNk52VVRLcGNUL0JwRStjNVBVZ3M5NEphcFRJeWJha09yQnlmZ1NHRit1TUROWWdnbXRMYkNOZkZZTG90TWlwZGlxQWpQT2ZWdWZxMjk2REk2OFdOemRVbml4ak5SZ3F0SkJTMUpmUDZSNGRtR2hzd0tCZ1FEclZRS0g3dGdyWVhxcDFXRnFlR2owR2w3R0xPS1haRlhTQk9XYldEOGEwYmRJMkhtb0wrcDdoM2tqMUVsdXliQU1Xb3NHcmcxZWpVNjAvTVZtUEtvZFdBUXA4OFFvdVp1bjcwdVQ3TCtUcEJkbXRMMVhiV1JhTG5BVXhQbStxM2ZGUDBKdk9MK3JtUFZoaU9JNEhidHBoZ1R2dHVWUFdGWkJ3cmRveHp4U2V3S0JnUURPN205QlRUZENGNzQ1VC9mOTdsakxNQks5ZzdQVDRhNEllTzRBbmxvN29KRDBUNVcrYVVJRHJqZ0dVNG9za2R4a3dQem5yVkpCUDFvNEFyc1F4RHgySnIzcVdxM1R4Rk9JaEU4VFl4NExkWEZGMzRMM3VuVnkyOEROQnNVc1ZTWFVwc0NEaTkzNHVzN2Z2NndmeGRnVEdla1NVeGI0S3F4Znhsby9wTzkrMlFLQmdBOFUyNXlxaWQvOTEwYWJEaXNzbkUxSWcxcGY5Z1dOd0pJOURobnVoZHpLSTl6ZlFxeXNwWEpWTkVZL2pKVTFCN3RDOGpYellaZjFwbDJpOVdPZjc2Y0J4UUtMUkw3M1ppcFZBNXJ2U1RmRkJGcm9xbG00QVA1bWkzaEpSMWdZMVF3bkNiTG5DQ0dQSStxa1F4c2xqS1V1bVpKalBqN2ZnbWVrZXV5VUdDR1JBb0dBZWlsOEpSanRsZ1ljVG1Xd0w5RitrUFJDMmtXRVNmUFpKclZuOWkxZXdxa1QyYTYraG9OUnVGUHBpWTd1K1dPckJOcjJnUitYVytncmtUQVVCSUZXTEZReEk1Q0VrVkd0WUEySzQ4Zk9VSmxxRVZUQzM2SGNCcEFhc3hURjZTR21JTUkvVThENTBHNGdVNmJqN1NrZ05DS0hpam96eVcxK3IxMVdOeWFYV3kwPSMjI3BhY2thZ2VzbGk';

function readSfCode(value) {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed || null;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return String(value);
  }
  if (value && typeof value === 'object') {
    for (const key of ['externalCode', 'code', 'id', 'name', 'label', 'description']) {
      const candidate = value[key];
      if (typeof candidate === 'string' && candidate.trim()) {
        return candidate.trim();
      }
    }
  }
  return null;
}

function normalizeCostCenter(code) {
  const trimmed = code.trim().toUpperCase();
  return trimmed.startsWith('PKGS') ? trimmed : `PKGS${trimmed}`;
}

function isAllowed(costCenter) {
  return ALLOWED.has(normalizeCostCenter(costCenter));
}

async function getSapToken() {
  const idpBody = new URLSearchParams({
    user_id: process.env.SAP_IDP_USER_ID || 'ECAdmin',
    token_url: SAP_TOKEN_URL,
    private_key: process.env.SAP_PRIVATE_KEY || DEFAULT_KEY,
    client_id: process.env.SAP_CLIENT_ID || SAP_CLIENT_ID,
  });
  const idpRes = await fetch(`${SAP_BASE}/oauth/idp`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: idpBody,
  });
  if (!idpRes.ok) throw new Error(`IDP failed ${idpRes.status}`);
  const idpRaw = (await idpRes.text()).trim();
  let assertion = idpRaw;
  try {
    const parsed = JSON.parse(idpRaw);
    assertion = parsed.assertion || parsed.Assertion || idpRaw;
  } catch {
    /* raw assertion */
  }

  const tokenBody = new URLSearchParams({
    client_id: process.env.SAP_CLIENT_ID || SAP_CLIENT_ID,
    grant_type: 'urn:ietf:params:oauth:grant-type:saml2-bearer',
    company_id: process.env.SAP_COMPANY_ID || 'packagesli',
    assertion,
  });
  const tokenRes = await fetch(SAP_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: tokenBody,
  });
  if (!tokenRes.ok) throw new Error(`Token failed ${tokenRes.status}`);
  const tokenJson = await tokenRes.json();
  return tokenJson.access_token;
}

async function fetchDivisionRows(token, expandUser) {
  const escaped = DIVISION.replace(/'/g, "''");
  const url =
    `${SAP_BASE}/odata/v2/EmpJob` +
    `?$format=json&$top=500` +
    `&$filter=${encodeURIComponent(`division eq '${escaped}'`)}` +
    (expandUser
      ? `&$select=userId,costCenter,userNav/displayName&$expand=userNav`
      : `&$select=userId,costCenter`);

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`EmpJob failed ${res.status}: ${text.slice(0, 300)}`);
  }
  const data = JSON.parse(text);
  return data.d?.results ?? data.results ?? [];
}

async function main() {
  console.log('Fetching SAP token...');
  const token = await getSapToken();

  let rows = [];
  for (const expand of [true, false]) {
    try {
      rows = await fetchDivisionRows(token, expand);
      if (rows.length > 0) {
        console.log(`EmpJob rows fetched (expand=${expand}): ${rows.length}`);
        break;
      }
    } catch (e) {
      console.warn(`expand=${expand} failed:`, e.message);
    }
  }

  const userIds = new Set();
  const matched = new Set();
  const missingCostCenter = [];
  const rejectedCostCenters = new Map();

  for (const row of rows) {
    const userId = row.userId?.trim();
    if (!userId) continue;
    userIds.add(userId);

    const cc = readSfCode(row.costCenter);
    if (!cc) {
      missingCostCenter.push({ userId, raw: row.costCenter });
      continue;
    }
    if (isAllowed(cc)) {
      matched.add(userId);
    } else {
      rejectedCostCenters.set(cc, (rejectedCostCenters.get(cc) || 0) + 1);
    }
  }

  console.log('\n--- Cost center filter check (BUFP division 20000044) ---');
  console.log(`Total EmpJob rows:        ${rows.length}`);
  console.log(`Unique userIds (division): ${userIds.size}`);
  console.log(`After PKGS cost-center filter: ${matched.size}`);
  console.log(`Rows with no readable costCenter: ${missingCostCenter.length}`);

  if (matched.size > 0) {
    console.log('\nFilter IS active — matched employees sample:', [...matched].slice(0, 5).join(', '));
  } else {
    console.log('\nFilter may block everyone — no matches.');
  }

  if (rejectedCostCenters.size > 0) {
    console.log('\nTop rejected cost centers (not in allowlist):');
    [...rejectedCostCenters.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .forEach(([cc, count]) => console.log(`  ${cc}: ${count}`));
  }

  const matchedCostCenters = new Map();
  for (const row of rows) {
    const cc = readSfCode(row.costCenter);
    if (!cc || !isAllowed(cc)) continue;
    matchedCostCenters.set(cc, (matchedCostCenters.get(cc) || 0) + 1);
  }
  if (matchedCostCenters.size > 0) {
    console.log('\nAllowed cost centers seen in SF data:');
    [...matchedCostCenters.entries()]
      .sort((a, b) => b[1] - a[1])
      .forEach(([cc, count]) =>
        console.log(`  ${cc} → ${count} rows (normalized: ${normalizeCostCenter(cc)})`),
      );
  }

  if (missingCostCenter.length > 0) {
    console.log('\nSample missing costCenter raw values:');
    missingCostCenter.slice(0, 3).forEach((r) =>
      console.log(`  userId=${r.userId} raw=${JSON.stringify(r.raw)?.slice(0, 120)}`),
    );
  }

  // Hit live API if server is up
  try {
    const jwt = await import('jsonwebtoken');
    const token = jwt.default.sign(
      {
        sub: 'gemba:sf:debug',
        name: 'Debug',
        employeeNumber: 'debug',
        authKind: 'sf',
      },
      process.env.JWT_SECRET || 'change_me',
    );
    const apiRes = await fetch('http://127.0.0.1:3000/gemba/auth/employees?bu=BUFP', {
      headers: { Authorization: `Bearer ${token}` },
    });
    const apiBody = await apiRes.json();
    const apiCount = Array.isArray(apiBody) ? apiBody.length : 0;
    console.log(`\nLive API GET /gemba/auth/employees?bu=BUFP → ${apiRes.status}, count=${apiCount}`);
    if (apiCount !== matched.size) {
      console.log(`  Note: API count (${apiCount}) vs SF filter calc (${matched.size}) — cache may differ`);
    }
  } catch (e) {
    console.log('\nLive API check skipped:', e.message);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
