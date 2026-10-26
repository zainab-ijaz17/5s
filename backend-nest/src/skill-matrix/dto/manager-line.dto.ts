import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class ManagerAssessmentLineDto {
  @IsString()
  lineId!: string;

  @IsInt()
  @Min(0)
  @Max(5)
  managerRating!: number;

  @IsOptional()
  @IsString()
  managerComment?: string;
}
