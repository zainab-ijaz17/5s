/**
 * Seed Gemba admin user(s).
 * Usage: node scripts/seed-gemba-admin.mjs [employeeNumber...]
 * Example: node scripts/seed-gemba-admin.mjs 10009729
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const DEFAULT_ADMINS = ['10009729', '1000000'];

async function main() {
  const fromArgs = process.argv.slice(2).map((v) => v.trim()).filter(Boolean);
  const employeeNumbers = fromArgs.length > 0 ? fromArgs : DEFAULT_ADMINS;

  const adminRole = await prisma.gembaRole.upsert({
    where: { name: 'admin' },
    create: { name: 'admin' },
    update: {},
  });

  await prisma.gembaRole.upsert({
    where: { name: 'user' },
    create: { name: 'user' },
    update: {},
  });

  for (const employeeNumber of employeeNumbers) {
    const record = await prisma.gembaAdminUser.upsert({
      where: { employeeNumber },
      create: {
        employeeNumber,
        roleId: adminRole.id,
      },
      update: {
        roleId: adminRole.id,
      },
    });
    console.log(`Admin granted: employee ${record.employeeNumber} (id: ${record.id})`);
  }
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
