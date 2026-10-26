#!/usr/bin/env node
/**
 * Bulk-create app users via POST /auth/register.
 *
 * Login format used by the Flutter app:
 *   Employee ID: <employeeId>
 *   Password:    12345678 (or USER_PASSWORD env)
 *   (email stored as <employeeId>@packages.local)
 *
 * Usage:
 *   node scripts/add-users.js
 *   API_BASE_URL=https://5s-api.packagesgroup.com node scripts/add-users.js
 *   node scripts/add-users.js --dry-run
 */

const fs = require('fs');
const path = require('path');

const API_BASE_URL = (
  process.env.API_BASE_URL || 'https://5s-api.packagesgroup.com'
).replace(/\/+$/, '');

const DEFAULT_PASSWORD = process.env.USER_PASSWORD || '12345678';
const DEFAULT_ROLE = process.env.USER_ROLE || 'user';

const usersPath = path.join(__dirname, 'users-bulk.json');
const dryRun = process.argv.includes('--dry-run');

function emailFor(employeeId) {
  return `${employeeId}@packages.local`;
}

async function registerUser(user) {
  const body = {
    email: emailFor(user.employeeId),
    password: DEFAULT_PASSWORD,
    name: user.name.trim(),
    employeeId: user.employeeId,
    role: user.role || DEFAULT_ROLE,
  };

  if (user.businessUnit) body.businessUnit = user.businessUnit;
  if (user.section) body.section = user.section;

  if (dryRun) {
    console.log(`[dry-run] would create ${user.employeeId} — ${user.name}`);
    return { status: 'dry-run', user };
  }

  const response = await fetch(`${API_BASE_URL}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  const text = await response.text();
  let data;
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = { message: text };
  }

  if (response.ok) {
    return { status: 'created', user };
  }

  const message =
    data.message ||
    (Array.isArray(data.message) ? data.message.join(', ') : text) ||
    `HTTP ${response.status}`;

  if (response.status === 409) {
    return { status: 'exists', user, message };
  }

  return { status: 'error', user, message };
}

async function main() {
  if (!fs.existsSync(usersPath)) {
    console.error(`Missing ${usersPath}`);
    process.exit(1);
  }

  const users = JSON.parse(fs.readFileSync(usersPath, 'utf8'));
  if (!Array.isArray(users) || users.length === 0) {
    console.error('No users in users-bulk.json');
    process.exit(1);
  }

  console.log(`API: ${API_BASE_URL}`);
  console.log(`Users: ${users.length} | Password: ${DEFAULT_PASSWORD} | Role: ${DEFAULT_ROLE}`);
  if (dryRun) console.log('Mode: dry-run (no API calls)\n');
  else console.log('');

  const summary = { created: 0, exists: 0, error: 0 };

  for (const user of users) {
    if (!user.employeeId || !user.name) {
      console.log(`✗ skip invalid row: ${JSON.stringify(user)}`);
      summary.error++;
      continue;
    }

    try {
      const result = await registerUser(user);
      const id = user.employeeId;
      const label = `${id} — ${user.name}`;

      if (result.status === 'created' || result.status === 'dry-run') {
        console.log(`✓ ${result.status === 'dry-run' ? 'dry-run' : 'created'}: ${label}`);
        summary.created++;
      } else if (result.status === 'exists') {
        console.log(`• already exists: ${label} (${result.message})`);
        summary.exists++;
      } else {
        console.log(`✗ failed: ${label} — ${result.message}`);
        summary.error++;
      }
    } catch (err) {
      console.log(`✗ failed: ${user.employeeId} — ${err.message}`);
      summary.error++;
    }
  }

  console.log('\n--- Summary ---');
  console.log(`Created: ${summary.created}`);
  console.log(`Already existed: ${summary.exists}`);
  console.log(`Failed: ${summary.error}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
