import * as admin from 'firebase-admin';
import * as bcrypt from 'bcrypt';
import * as fs from 'fs';
import { PrismaClient, Role } from '@prisma/client';

const prisma = new PrismaClient();

function parseRole(role?: string | null): Role {
  const normalized = (role ?? '').toLowerCase().trim();
  if (normalized === 'admin') return Role.admin;
  if (normalized === 'power_user' || normalized === 'poweruser') {
    return Role.power_user;
  }
  if (
    normalized === 'bu_manager' ||
    normalized === 'bumanager' ||
    normalized === 'manager'
  ) {
    return Role.bu_manager;
  }
  if (normalized === 'auditor') return Role.auditor;
  return Role.user;
}

function normalizeScalarString(
  value: unknown,
  fallback: string | null = null,
): string | null {
  if (value === undefined || value === null) return fallback;
  if (typeof value === 'string') return value;
  if (typeof value === 'number' || typeof value === 'boolean') {
    return String(value);
  }
  if (typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>);
    if (entries.length === 0) return fallback;
    const [, firstValue] = entries[0];
    if (
      typeof firstValue === 'string' ||
      typeof firstValue === 'number' ||
      typeof firstValue === 'boolean'
    ) {
      return String(firstValue);
    }
    return entries[0][0];
  }
  return fallback;
}

async function bootstrap() {
  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (!serviceAccountPath) {
    throw new Error('Set FIREBASE_SERVICE_ACCOUNT_PATH in environment.');
  }

  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  const db = admin.firestore();
  const defaultPasswordHash = await bcrypt.hash('12345678', 10);

  console.log('Migrating users...');
  const usersSnapshot = await db
    .collection('company')
    .doc('main')
    .collection('users')
    .get();

  for (const doc of usersSnapshot.docs) {
    const data = doc.data();
    const email = String(data.email ?? `${doc.id}@migrated.local`).toLowerCase();
    const name = String(data.name ?? data.username ?? doc.id);
    const businessUnit = normalizeScalarString(
      data.business_unit ?? data.businessUnit,
      null,
    );
    const section = normalizeScalarString(data.section, null);

    let employeeId: number | null = null;
    const rawEmployee = data.employeeId ?? data.employee_id;
    if (rawEmployee !== undefined && rawEmployee !== null) {
      const parsed = Number(rawEmployee);
      if (!Number.isNaN(parsed)) employeeId = parsed;
    }

    // If another record already uses this employeeId, avoid unique constraint failure.
    if (employeeId !== null) {
      const byEmployee = await prisma.user.findUnique({
        where: { employeeId },
        select: { email: true },
      });
      if (byEmployee && byEmployee.email !== email) {
        employeeId = null;
      }
    }

    await prisma.user.upsert({
      where: { email },
      create: {
        email,
        name,
        employeeId: employeeId ?? undefined,
        role: parseRole(data.role),
        businessUnit,
        section,
        passwordHash: defaultPasswordHash,
      },
      update: {
        name,
        employeeId: employeeId ?? undefined,
        role: parseRole(data.role),
        businessUnit,
        section,
      },
    });
  }

  console.log('Migrating questions...');
  const questionsSnapshot = await db.collection('questions').get();
  for (const doc of questionsSnapshot.docs) {
    const q = doc.data();
    await prisma.question.upsert({
      where: { id: doc.id },
      create: {
        id: doc.id,
        question: String(q.question ?? ''),
        details: String(q.details ?? ''),
        category: String(q.category ?? 'SORT'),
        order: Number(q.order ?? 0),
      },
      update: {
        question: String(q.question ?? ''),
        details: String(q.details ?? ''),
        category: String(q.category ?? 'SORT'),
        order: Number(q.order ?? 0),
      },
    });
  }

  console.log('Migrating assessments from user arrays...');
  for (const doc of usersSnapshot.docs) {
    const user = doc.data();
    const rawAssessments = Array.isArray(user.assessments) ? user.assessments : [];
    const email = String(user.email ?? '').toLowerCase();
    const creator = email
      ? await prisma.user.findUnique({ where: { email } })
      : null;

    for (const row of rawAssessments) {
      const id = String(row.id ?? `${Date.now()}-${Math.random()}`);
      const existing = await prisma.assessment.findUnique({ where: { id } });
      if (existing) continue;

      await prisma.assessment.create({
        data: {
          id,
          company: String(row.company ?? 'Unknown'),
          bu: row.bu ? String(row.bu) : null,
          section: row.section ? String(row.section) : null,
          auditorName: String(row.auditorName ?? 'Unknown Auditor'),
          auditeeName: String(row.auditeeName ?? 'Unknown Auditee'),
          auditorEmail: row.auditorEmail ? String(row.auditorEmail) : null,
          auditeeEmail: row.auditeeEmail ? String(row.auditeeEmail) : null,
          userName: row.userName ? String(row.userName) : null,
          employeeId:
            row.employeeId !== undefined && row.employeeId !== null
              ? Number(row.employeeId)
              : null,
          score: Number(row.score ?? 0),
          isFlagged: Boolean(row.isFlagged),
          followUpDueAt: row.followUpDueAt ? new Date(String(row.followUpDueAt)) : null,
          followUpSent: Boolean(row.followUpSent),
          resolved: Boolean(row.resolved),
          resolvedAt: row.resolvedAt ? new Date(String(row.resolvedAt)) : null,
          resolvedBy: row.resolvedBy ? String(row.resolvedBy) : null,
          createdById: creator?.id,
          createdAt: row.date ? new Date(String(row.date)) : new Date(),
          items: {
            create: (Array.isArray(row.items) ? row.items : []).map((item: Record<string, unknown>) => {
              const imagePaths = Array.isArray(item.imagePaths)
                ? (item.imagePaths as unknown[]).map(String)
                : [];
              const imageUrls = Array.isArray(item.imageUrls)
                ? (item.imageUrls as unknown[]).map(String)
                : [];
              return {
                question: String(item.question ?? ''),
                answer: String(item.answer ?? 'N/A'),
                remarks: String(item.remarks ?? ''),
                isFlagged: Boolean(item.isFlagged),
                attachments: {
                  create: [
                    ...imagePaths.map((p) => ({ localPath: p })),
                    ...imageUrls.map((u) => ({ url: u })),
                  ],
                },
              };
            }),
          },
        },
      });
    }
  }

  console.log('Migration complete. All imported users use password: 12345678');
}

bootstrap()
  .catch((err) => {
    console.error('Migration failed:', err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
