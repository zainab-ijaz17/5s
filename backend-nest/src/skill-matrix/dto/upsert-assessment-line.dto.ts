import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class UpsertAssessmentLineDto {
  @IsString()
  skillId!: string;

  @IsInt()
  @Min(0)
  @Max(5)
  selfRating!: number;

  @IsOptional()
  @IsString()
  selfComment?: string;
}
