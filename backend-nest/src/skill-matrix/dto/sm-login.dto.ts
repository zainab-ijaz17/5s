import { IsString, MinLength } from 'class-validator';

export class SmLoginDto {
  @IsString()
  @MinLength(1)
  employeeNumber!: string;

  @IsString()
  @MinLength(1)
  password!: string;
}
