import { IsOptional, IsString, MinLength } from 'class-validator';

export class GembaSfLoginDto {
  /** Employee number or SAP username (preferred). */
  @IsOptional()
  @IsString()
  @MinLength(1)
  username?: string;

  /** Legacy clients may send the same value as `email`. */
  @IsOptional()
  @IsString()
  @MinLength(1)
  email?: string;

  @IsString()
  @MinLength(1)
  password!: string;
}

export function gembaLoginIdentifierFromDto(dto: GembaSfLoginDto): string {
  return (dto.username ?? dto.email ?? '').trim();
}
