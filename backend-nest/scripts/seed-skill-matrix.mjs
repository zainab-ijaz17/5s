/**
 * Seed Skill Matrix roles, levels, categories, users, skills, trainings, cycle.
 * Run: node scripts/seed-skill-matrix.mjs
 */
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

const LEVELS = [
  ['Opr', 1],
  ['Jr.Opr', 2],
  ['Sr.Opr', 3],
  ['S.I', 4],
  ['Technician', 5],
  ['QC', 6],
  ['Supervisor', 7],
];

const ROLES = ['Worker', 'Line Manager', 'E & T Admin'];

const CATEGORIES = [
  'Troubleshooting',
  'Line operations',
  'Safety',
  'Autonomous Maintenance',
  'Metallizer operations',
  'Slitter Operations',
  '5S/Food Safety',
  'Others',
];

const TRAININGS = [
  ['QA Matrix – Defect Occurrence On The Machine', 6],
  ['Web Inspection', 6],
  ['Risk assessment and BBS session', 4],
  ['Edge drop control refresher', 2],
];

const SKILLS = [
  ['Line operations', 'Edge drop control', 3],
  ['Troubleshooting', 'Web inspection – defect identification', 3],
  ['Safety', 'Behaviour-based safety (BBS)', 3],
  ['Autonomous Maintenance', 'Basic AM standards (CIL)', 2],
  ['Troubleshooting', 'QA Matrix – defect occurrence on machine', 3],
  ['Safety', 'Risk assessment and BBS session', 3],
];

async function main() {
  const passwordHash = await bcrypt.hash('skill123', 10);

  for (const name of ROLES) {
    await prisma.skillMatrixRole.upsert({
      where: { name },
      create: { name },
      update: {},
    });
  }

  for (const [code, sortOrder] of LEVELS) {
    await prisma.skillMatrixLevel.upsert({
      where: { code },
      create: { code, sortOrder },
      update: { sortOrder },
    });
  }

  for (const name of CATEGORIES) {
    await prisma.skillMatrixCategory.upsert({
      where: { name },
      create: { name },
      update: {},
    });
  }

  const workerRole = await prisma.skillMatrixRole.findUniqueOrThrow({
    where: { name: 'Worker' },
  });
  const managerRole = await prisma.skillMatrixRole.findUniqueOrThrow({
    where: { name: 'Line Manager' },
  });
  const etRole = await prisma.skillMatrixRole.findUniqueOrThrow({
    where: { name: 'E & T Admin' },
  });
  const oprLevel = await prisma.skillMatrixLevel.findUniqueOrThrow({
    where: { code: 'Opr' },
  });
  const cppCategory = await prisma.skillMatrixCategory.findUniqueOrThrow({
    where: { name: 'Line operations' },
  });

  const manager = await prisma.skillMatrixUser.upsert({
    where: { employeeNumber: '50021001' },
    create: {
      fullName: 'Sara Ahmed',
      email: 'sara.ahmed@packages.local',
      passwordHash,
      employeeNumber: '50021001',
      roleId: managerRole.id,
      levelId: oprLevel.id,
      categoryId: cppCategory.id,
      department: 'CPP',
      areaLine: 'Line 3',
      designation: 'Line Manager',
      status: 'Active',
      dateOfJoining: new Date('2018-03-01'),
    },
    update: { passwordHash },
  });

  const worker = await prisma.skillMatrixUser.upsert({
    where: { employeeNumber: '50021446' },
    create: {
      fullName: 'Abdul Latif',
      email: 'abdul.latif@packages.local',
      passwordHash,
      employeeNumber: '50021446',
      roleId: workerRole.id,
      levelId: oprLevel.id,
      categoryId: cppCategory.id,
      department: 'CPP',
      areaLine: 'Line 3',
      designation: 'Operator',
      lineManagerId: manager.id,
      status: 'Active',
      dateOfJoining: new Date('2022-08-15'),
    },
    update: { passwordHash, lineManagerId: manager.id },
  });

  await prisma.skillMatrixUser.upsert({
    where: { employeeNumber: '50021999' },
    create: {
      fullName: 'E&T Admin Demo',
      email: 'et.admin@packages.local',
      passwordHash,
      employeeNumber: '50021999',
      roleId: etRole.id,
      department: 'E&T',
      designation: 'E & T Admin',
      status: 'Active',
    },
    update: { passwordHash },
  });

  const extraWorkers = [
    ['50021444', 'Abdul Naeem'],
    ['50021450', 'Abdul Haseeb'],
    ['50021452', 'Imran Shah'],
  ];
  for (const [emp, name] of extraWorkers) {
    await prisma.skillMatrixUser.upsert({
      where: { employeeNumber: emp },
      create: {
        fullName: name,
        email: `${emp}@packages.local`,
        passwordHash,
        employeeNumber: emp,
        roleId: workerRole.id,
        levelId: oprLevel.id,
        department: 'CPP',
        lineManagerId: manager.id,
        status: 'Active',
      },
      update: { lineManagerId: manager.id, passwordHash },
    });
  }

  for (const [name, hours] of TRAININGS) {
    await prisma.skillMatrixTraining.upsert({
      where: { name },
      create: { name, durationHours: hours },
      update: { durationHours: hours },
    });
  }

  const allLevels = await prisma.skillMatrixLevel.findMany();
  for (const [catName, skillName, reqLevel] of SKILLS) {
    const category = await prisma.skillMatrixCategory.findUniqueOrThrow({
      where: { name: catName },
    });
    const skill = await prisma.skillMatrixSkill.upsert({
      where: {
        categoryId_name: { categoryId: category.id, name: skillName },
      },
      create: {
        name: skillName,
        categoryId: category.id,
        department: 'CPP',
        area: 'Line 3',
        description: `${skillName} competency`,
      },
      update: {},
    });

    for (const level of allLevels) {
      await prisma.skillMatrixSkillApplicableLevel.upsert({
        where: { skillId_levelId: { skillId: skill.id, levelId: level.id } },
        create: { skillId: skill.id, levelId: level.id },
        update: {},
      });
      await prisma.skillMatrixSkillRequirement.upsert({
        where: { skillId_levelId: { skillId: skill.id, levelId: level.id } },
        create: {
          skillId: skill.id,
          levelId: level.id,
          requiredLevel: reqLevel,
        },
        update: { requiredLevel: reqLevel },
      });
    }
  }

  await prisma.skillMatrixAssessmentCycle.upsert({
    where: { name: 'H2-2026' },
    create: {
      name: 'H2-2026',
      label: 'Assessment cycle: H2 2026 · Due 15 Oct 2026',
      dueDate: new Date('2026-10-15'),
      isActive: true,
    },
    update: { isActive: true, label: 'Assessment cycle: H2 2026 · Due 15 Oct 2026' },
  });

  console.log('Skill Matrix seed complete.');
  console.log('Worker login: 50021446 / skill123');
  console.log('Line Manager login: 50021001 / skill123');
  console.log('E&T Admin login: 50021999 / skill123');
  console.log('Worker user id:', worker.id);
  console.log('Manager user id:', manager.id);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
