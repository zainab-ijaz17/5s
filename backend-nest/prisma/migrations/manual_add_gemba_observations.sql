-- Digital Gemba observations (run via: npx prisma db push  OR  npx prisma migrate dev)

CREATE TABLE IF NOT EXISTS `GembaObservation` (
  `id` VARCHAR(191) NOT NULL,
  `title` VARCHAR(191) NOT NULL,
  `location` VARCHAR(191) NOT NULL,
  `category` VARCHAR(191) NOT NULL,
  `status` VARCHAR(191) NOT NULL DEFAULT 'In-progress',
  `assignedEmployeeNumber` VARCHAR(191) NOT NULL,
  `assignedEmployeeName` VARCHAR(191) NULL,
  `createdByEmployeeNumber` VARCHAR(191) NOT NULL,
  `createdByName` VARCHAR(191) NULL,
  `remarks` TEXT NOT NULL,
  `company` VARCHAR(191) NOT NULL,
  `bu` VARCHAR(191) NULL,
  `section` VARCHAR(191) NULL,
  `machineValue` VARCHAR(191) NULL,
  `afterRemarks` TEXT NULL,
  `completedByEmployeeNumber` VARCHAR(191) NULL,
  `completedByName` VARCHAR(191) NULL,
  `completedAt` DATETIME(3) NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updatedAt` DATETIME(3) NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `GembaObservation_status_idx` (`status`),
  INDEX `GembaObservation_assignedEmployeeNumber_idx` (`assignedEmployeeNumber`),
  INDEX `GembaObservation_createdByEmployeeNumber_idx` (`createdByEmployeeNumber`),
  INDEX `GembaObservation_createdAt_idx` (`createdAt`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `GembaObservationPhoto` (
  `id` VARCHAR(191) NOT NULL,
  `observationId` VARCHAR(191) NOT NULL,
  `kind` VARCHAR(191) NOT NULL,
  `url` VARCHAR(191) NOT NULL,
  `sortOrder` INT NOT NULL DEFAULT 0,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  INDEX `GembaObservationPhoto_observationId_kind_idx` (`observationId`, `kind`),
  CONSTRAINT `GembaObservationPhoto_observationId_fkey`
    FOREIGN KEY (`observationId`) REFERENCES `GembaObservation`(`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
