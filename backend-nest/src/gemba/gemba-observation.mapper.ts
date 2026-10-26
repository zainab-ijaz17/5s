import {
  GembaObservation,
  GembaObservationPhoto,
} from '@prisma/client';

export type GembaObservationWithPhotos = GembaObservation & {
  photos: GembaObservationPhoto[];
};

export function mapGembaObservation(row: GembaObservationWithPhotos) {
  const before = row.photos
    .filter((photo) => photo.kind === 'before')
    .sort((a, b) => a.sortOrder - b.sortOrder)
    .map((photo) => photo.url);
  const after = row.photos
    .filter((photo) => photo.kind === 'after')
    .sort((a, b) => a.sortOrder - b.sortOrder)
    .map((photo) => photo.url);

  return {
    id: row.id,
    title: row.title,
    location: row.location,
    category: row.category,
    status: row.status,
    assignedEmployeeNumber: row.assignedEmployeeNumber,
    assignedEmployeeName: row.assignedEmployeeName,
    createdByEmployeeNumber: row.createdByEmployeeNumber,
    createdByName: row.createdByName,
    remarks: row.remarks,
    company: row.company,
    bu: row.bu,
    section: row.section,
    machineValue: row.machineValue,
    photoPaths: before,
    afterPhotoPaths: after,
    photoCount: before.length,
    afterRemarks: row.afterRemarks,
    completedByEmployeeNumber: row.completedByEmployeeNumber,
    completedByName: row.completedByName,
    completedAt: row.completedAt?.toISOString() ?? null,
    createdAt: row.createdAt.toISOString(),
  };
}
