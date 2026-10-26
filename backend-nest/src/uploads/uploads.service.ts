import { Injectable } from '@nestjs/common';

@Injectable()
export class UploadsService {
  buildPublicUrl(fileName: string) {
    return `/uploads/${fileName}`;
  }
}
