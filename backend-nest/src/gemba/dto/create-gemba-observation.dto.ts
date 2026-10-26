import {
  IsArray,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateGembaObservationDto {
  @IsString()
  @IsNotEmpty()
  title: string;

  @IsString()
  @IsNotEmpty()
  location: string;

  @IsString()
  @IsNotEmpty()
  category: string;

  @IsString()
  @IsNotEmpty()
  assignedEmployeeNumber: string;

  @IsOptional()
  @IsString()
  assignedEmployeeName?: string;

  @IsOptional()
  @IsString()
  remarks?: string;

  @IsString()
  @IsNotEmpty()
  company: string;

  @IsOptional()
  @IsString()
  bu?: string;

  @IsOptional()
  @IsString()
  section?: string;

  @IsOptional()
  @IsString()
  machineValue?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  beforePhotoUrls?: string[];
}
