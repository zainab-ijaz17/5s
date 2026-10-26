export const SM_JWT_PREFIX = 'sm:';

export const SM_ROLE = {
  worker: 'Worker',
  lineManager: 'Line Manager',
  etAdmin: 'E & T Admin',
} as const;

export type SmRoleName = (typeof SM_ROLE)[keyof typeof SM_ROLE];
