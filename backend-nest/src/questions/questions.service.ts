import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateQuestionDto } from './dto/create-question.dto';
import { UpdateQuestionDto } from './dto/update-question.dto';

@Injectable()
export class QuestionsService {
  constructor(private readonly prisma: PrismaService) {}

  findAll() {
    return this.prisma.question.findMany({ orderBy: { order: 'asc' } });
  }

  async create(dto: CreateQuestionDto) {
    const last = await this.prisma.question.findFirst({
      orderBy: { order: 'desc' },
    });
    const order = (last?.order ?? 0) + 1;
    return this.prisma.question.create({
      data: {
        question: dto.question,
        details: dto.details ?? '',
        category: dto.category ?? 'SORT',
        order,
      },
    });
  }

  update(id: string, dto: UpdateQuestionDto) {
    return this.prisma.question.update({ where: { id }, data: dto });
  }

  remove(id: string) {
    return this.prisma.question.delete({ where: { id } });
  }
}
