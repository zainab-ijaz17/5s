import { IsNumber, IsOptional, IsString, MinLength } from 'class-validator';

export class CreateTrainingDto {
  @IsString()
  @MinLength(1)
  name!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsNumber()
  durationHours?: number;
}
