import {
  BadRequestException,
  Controller,
  Logger,
  Post,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { existsSync, mkdirSync } from 'fs';
import { extname } from 'path';
import { GembaJwtAuthGuard } from './gemba-jwt-auth.guard';

const uploadsDir = './uploads/gemba';
if (!existsSync(uploadsDir)) {
  mkdirSync(uploadsDir, { recursive: true });
}

@Controller('gemba/uploads')
@UseGuards(GembaJwtAuthGuard)
export class GembaUploadsController {
  private readonly logger = new Logger(GembaUploadsController.name);

  @Post('images')
  @UseInterceptors(
    FilesInterceptor('files', 20, {
      storage: diskStorage({
        destination: uploadsDir,
        filename: (_, file, callback) => {
          const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
          callback(null, `${unique}${extname(file.originalname) || '.jpg'}`);
        },
      }),
    }),
  )
  uploadImages(@UploadedFiles() files: Express.Multer.File[]) {
    if (!files?.length) {
      throw new BadRequestException('No image files received.');
    }

    const mapped = files.map((file) => ({
      originalName: file.originalname,
      fileName: file.filename,
      path: file.path,
      url: `/uploads/gemba/${file.filename}`,
    }));

    this.logger.log(`Uploaded ${mapped.length} Gemba image(s)`);
    return { files: mapped };
  }
}
