import {
  ArrayMinSize,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  Max,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

class SkillLevelRequirementDto {
  @IsString()
  levelId!: string;

  @IsInt()
  @Min(1)
  @Max(5)
  requiredLevel!: number;
}

export class CreateSkillDto {
  @IsString()
  @MinLength(1)
  name!: string;

  @IsString()
  categoryId!: string;

  @IsOptional()
  @IsString()
  department?: string;

  @IsOptional()
  @IsString()
  area?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsArray()
  @ArrayMinSize(1)
  @IsString({ each: true })
  applicableLevelIds!: string[];

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(5)
  defaultRequiredLevel?: number;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SkillLevelRequirementDto)
  requirements?: SkillLevelRequirementDto[];
}
