import { IsOptional, IsString } from 'class-validator';

export class CreateQuestionDto {
  @IsString()
  question: string;

  @IsOptional()
  @IsString()
  details?: string;

  @IsOptional()
  @IsString()
  category?: string;
}
