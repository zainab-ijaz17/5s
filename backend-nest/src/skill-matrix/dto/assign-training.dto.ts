import { IsDateString, IsOptional, IsString } from 'class-validator';

export class AssignTrainingDto {
  @IsString()
  workerId!: string;

  @IsString()
  trainingId!: string;

  @IsOptional()
  @IsString()
  skillId?: string;

  @IsOptional()
  @IsDateString()
  dueDate?: string;
}
