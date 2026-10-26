import { IsArray, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CompleteGembaObservationDto {
  @IsString()
  @IsNotEmpty()
  afterRemarks: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  afterPhotoUrls?: string[];
}
