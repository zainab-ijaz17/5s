-- Gemba roles and admin users (run after prisma db push)

CREATE TABLE IF NOT EXISTS `gemba_roles` (
  `id` VARCHAR(191) NOT NULL,
  `name` VARCHAR(191) NOT NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE INDEX `gemba_roles_name_key` (`name`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `admin_users` (
  `id` VARCHAR(191) NOT NULL,
  `employeeNumber` VARCHAR(191) NOT NULL,
  `roleId` VARCHAR(191) NOT NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updatedAt` DATETIME(3) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `admin_users_employeeNumber_key` (`employeeNumber`),
  INDEX `admin_users_roleId_idx` (`roleId`),
  CONSTRAINT `admin_users_roleId_fkey`
    FOREIGN KEY (`roleId`) REFERENCES `gemba_roles`(`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Default roles (IDs are examples — Prisma upsert creates these on server start too)
-- INSERT INTO gemba_roles (id, name, createdAt) VALUES ('seed_user', 'user', NOW(3)), ('seed_admin', 'admin', NOW(3));

-- Grant admin by employee number (replace EMP# and role id after roles exist):
-- INSERT INTO admin_users (id, employeeNumber, roleId, createdAt, updatedAt)
-- SELECT UUID(), '10009729', id, NOW(3), NOW(3) FROM gemba_roles WHERE name = 'admin' LIMIT 1;
