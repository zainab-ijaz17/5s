import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

class AssessmentAttachmentDto {
  @IsOptional()
  @IsString()
  localPath?: string;

  @IsOptional()
  @IsString()
  url?: string;
}

class AssessmentItemDto {
  @IsString()
  question: string;

  @IsString()
  answer: string;

  @IsOptional()
  @IsString()
  remarks?: string;

  @IsBoolean()
  isFlagged: boolean;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => AssessmentAttachmentDto)
  attachments?: AssessmentAttachmentDto[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  imagePaths?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  imageUrls?: string[];
}

export class CreateAssessmentDto {
  @IsString()
  @IsNotEmpty()
  id: string;

  @IsString()
  company: string;

  @IsOptional()
  @IsString()
  bu?: string;

  @IsOptional()
  @IsString()
  section?: string;

  @IsString()
  auditorName: string;

  @IsString()
  auditeeName: string;

  @IsOptional()
  @IsString()
  auditorEmail?: string;

  @IsOptional()
  @IsString()
  auditeeEmail?: string;

  @IsOptional()
  @IsString()
  userName?: string;

  @IsOptional()
  @IsInt()
  employeeId?: number;

  @IsInt()
  score: number;

  @IsBoolean()
  isFlagged: boolean;

  @IsOptional()
  @IsString()
  followUpDueAt?: string;

  @IsOptional()
  @IsBoolean()
  followUpSent?: boolean;

  @IsOptional()
  @IsBoolean()
  resolved?: boolean;

  @IsOptional()
  @IsString()
  resolvedAt?: string;

  @IsOptional()
  @IsString()
  resolvedBy?: string;

  @IsOptional()
  @IsDateString()
  date?: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => AssessmentItemDto)
  items: AssessmentItemDto[];
}
