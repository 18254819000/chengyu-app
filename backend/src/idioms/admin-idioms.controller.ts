import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  ParseIntPipe,
  Post,
  Put,
  Query,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { AppConfigService } from '../config/app-config.service';
import { PrismaService } from '../prisma/prisma.service';
import { CSV_TEMPLATE_HEADER, parseCsv } from '../common/csv';
import {
  IdiomInput,
  adminView,
  normalizePinyinChars,
  publishValidation,
} from './idiom.util';

@Controller('admin/idioms')
@UseGuards(JwtAuthGuard)
export class AdminIdiomsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: AppConfigService,
  ) {}

  private toData(body: IdiomInput, existing?: any) {
    return {
      idiom: body.idiom !== undefined ? String(body.idiom).trim() : existing?.idiom ?? '',
      pinyin: body.pinyin !== undefined ? String(body.pinyin).trim() : existing?.pinyin ?? '',
      pinyinChars:
        body.pinyin_chars !== undefined
          ? normalizePinyinChars(body.pinyin_chars)
          : existing?.pinyinChars ?? '',
      definitionZh:
        body.definition_zh !== undefined ? String(body.definition_zh) : existing?.definitionZh ?? '',
      definitionEn:
        body.definition_en !== undefined ? String(body.definition_en) : existing?.definitionEn ?? '',
      exampleZh: body.example_zh !== undefined ? String(body.example_zh) : existing?.exampleZh ?? '',
      exampleEn: body.example_en !== undefined ? String(body.example_en) : existing?.exampleEn ?? '',
      storyZh: body.story_zh !== undefined ? String(body.story_zh) : existing?.storyZh ?? '',
      storyEn: body.story_en !== undefined ? String(body.story_en) : existing?.storyEn ?? '',
      source: body.source !== undefined ? body.source || null : existing?.source ?? null,
      tags: body.tags !== undefined ? body.tags || null : existing?.tags ?? null,
      adminRemark:
        body.admin_remark !== undefined ? body.admin_remark || null : existing?.adminRemark ?? null,
      sortOrder:
        body.sort_order !== undefined ? Number(body.sort_order) || 0 : existing?.sortOrder ?? 0,
    };
  }

  // GET /api/v1/admin/idioms 分页列表（搜索 + 状态筛选）
  @Get()
  async list(
    @Query('page') page = '1',
    @Query('pageSize') pageSize = '20',
    @Query('q') q = '',
    @Query('status') status = '',
  ) {
    const p = Math.max(1, parseInt(page, 10) || 1);
    const ps = Math.min(200, Math.max(1, parseInt(pageSize, 10) || 20));
    const where: any = { deleted: false };
    if (status && ['draft', 'published', 'offline'].includes(status)) where.status = status;
    if (q) {
      where.OR = [{ idiom: { contains: q } }, { pinyin: { contains: q } }];
    }
    const [total, rows] = await Promise.all([
      this.prisma.idiom.count({ where }),
      this.prisma.idiom.findMany({
        where,
        orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
        skip: (p - 1) * ps,
        take: ps,
      }),
    ]);
    const freeCount = await this.config.getFreeCount();
    return { total, page: p, pageSize: ps, items: rows.map((r) => adminView(r, freeCount)) };
  }

  @Get('template')
  template() {
    return {
      filename: 'idioms-template.csv',
      content:
        CSV_TEMPLATE_HEADER +
        '\n1,示例成语,shì lì chéng yǔ,shì lì chéng yǔ,中文解释示例,English definition example,这是示例例句。,This is an example sentence.,,,draft\n',
    };
  }

  @Get(':id')
  async detail(@Param('id', ParseIntPipe) id: number) {
    const row = await this.prisma.idiom.findFirst({ where: { id, deleted: false } });
    if (!row) throw new NotFoundException('成语不存在');
    return adminView(row, await this.config.getFreeCount());
  }

  // POST /api/v1/admin/idioms 新增（默认草稿）
  @Post()
  async create(@Body() body: IdiomInput) {
    const data = this.toData(body);
    if (!data.idiom) throw new BadRequestException('成语不能为空');
    const dup = await this.prisma.idiom.findUnique({ where: { idiom: data.idiom } });
    if (dup) throw new BadRequestException(`成语「${data.idiom}」已存在，不能重复录入`);
    if (!body.sort_order) {
      const max = await this.prisma.idiom.aggregate({ _max: { sortOrder: true } });
      data.sortOrder = (max._max.sortOrder ?? 0) + 1;
    }
    const row = await this.prisma.idiom.create({ data: { ...data, status: 'draft' } });
    return adminView(row, await this.config.getFreeCount());
  }

  // PUT /api/v1/admin/idioms/:id 编辑
  @Put(':id')
  async update(@Param('id', ParseIntPipe) id: number, @Body() body: IdiomInput) {
    const existing = await this.prisma.idiom.findFirst({ where: { id, deleted: false } });
    if (!existing) throw new NotFoundException('成语不存在');
    const data = this.toData(body, existing);
    if (!data.idiom) throw new BadRequestException('成语不能为空');
    if (data.idiom !== existing.idiom) {
      const dup = await this.prisma.idiom.findUnique({ where: { idiom: data.idiom } });
      if (dup) throw new BadRequestException(`成语「${data.idiom}」已存在，不能重复录入`);
    }
    // 已发布条目再编辑时，必须仍满足发布校验，避免线上出现残缺内容
    if (existing.status === 'published') {
      const reasons = publishValidation(data);
      if (reasons.length) throw new BadRequestException(reasons.join('；'));
    }
    const row = await this.prisma.idiom.update({ where: { id }, data });
    if (existing.status === 'published') await this.config.bumpContentVersion();
    return adminView(row, await this.config.getFreeCount());
  }

  // DELETE /api/v1/admin/idioms/:id 软删除（标记 deleted 并下架，可由数据库恢复）
  @Delete(':id')
  async remove(@Param('id', ParseIntPipe) id: number) {
    const existing = await this.prisma.idiom.findFirst({ where: { id, deleted: false } });
    if (!existing) throw new NotFoundException('成语不存在');
    await this.prisma.idiom.update({ where: { id }, data: { deleted: true, status: 'offline' } });
    await this.config.bumpContentVersion();
    return { ok: true, id };
  }

  // POST /api/v1/admin/idioms/:id/publish 发布（严格校验）
  @Post(':id/publish')
  async publish(@Param('id', ParseIntPipe) id: number) {
    const row = await this.prisma.idiom.findFirst({ where: { id, deleted: false } });
    if (!row) throw new NotFoundException('成语不存在');
    const reasons = publishValidation(row);
    if (reasons.length) throw new BadRequestException(`无法发布：${reasons.join('；')}`);
    const updated = await this.prisma.idiom.update({ where: { id }, data: { status: 'published' } });
    await this.config.bumpContentVersion();
    return adminView(updated, await this.config.getFreeCount());
  }

  // POST /api/v1/admin/idioms/publish-all 一键发布全部草稿
  // 逐条复用单个发布的严格校验：不通过的留在草稿并逐条报告原因；
  // 整批只 bump 一次 content_version，App 的新成语提醒一整批只弹一次
  @Post('publish-all')
  async publishAll() {
    const drafts = await this.prisma.idiom.findMany({
      where: { deleted: false, status: 'draft' },
      orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
    });
    const failed: Array<{ id: number; idiom: string; reason: string }> = [];
    let published = 0;
    for (const row of drafts) {
      const reasons = publishValidation(row);
      if (reasons.length) {
        failed.push({ id: row.id, idiom: row.idiom, reason: reasons.join('；') });
        continue;
      }
      try {
        await this.prisma.idiom.update({ where: { id: row.id }, data: { status: 'published' } });
        published++;
      } catch (err: any) {
        failed.push({ id: row.id, idiom: row.idiom, reason: `发布失败：${err?.message || '未知错误'}` });
      }
    }
    if (published > 0) await this.config.bumpContentVersion();
    return { total: drafts.length, published, failedCount: failed.length, failed };
  }

  // POST /api/v1/admin/idioms/:id/unpublish 下架
  @Post(':id/unpublish')
  async unpublish(@Param('id', ParseIntPipe) id: number) {
    const row = await this.prisma.idiom.findFirst({ where: { id, deleted: false } });
    if (!row) throw new NotFoundException('成语不存在');
    const updated = await this.prisma.idiom.update({ where: { id }, data: { status: 'offline' } });
    await this.config.bumpContentVersion();
    return adminView(updated, await this.config.getFreeCount());
  }

  // POST /api/v1/admin/idioms/import 批量导入 CSV，逐行校验，成功行以 draft 入库
  @Post('import')
  @UseInterceptors(FileInterceptor('file'))
  async importCsv(@UploadedFile() file: any) {
    if (!file) throw new BadRequestException('请上传 CSV 文件（表单字段名 file）');
    const text: string = file.buffer.toString('utf8');
    const rows = parseCsv(text);
    if (rows.length < 2) throw new BadRequestException('CSV 内容为空或只有表头');
    const header = rows[0].map((h) => h.trim());
    const col = (name: string) => header.indexOf(name);
    const idx = {
      sort_order: col('sort_order'),
      idiom: col('idiom'),
      pinyin: col('pinyin'),
      pinyin_chars: col('pinyin_chars'),
      definition_zh: col('definition_zh'),
      definition_en: col('definition_en'),
      example_zh: col('example_zh'),
      example_en: col('example_en'),
      story_zh: col('story_zh'),
      story_en: col('story_en'),
    };
    if (idx.idiom < 0) throw new BadRequestException('CSV 缺少 idiom 列，请使用模板格式');

    const get = (r: string[], i: number) => (i >= 0 ? (r[i] ?? '').trim() : '');
    const failed: Array<{ row: number; idiom: string; reason: string }> = [];
    let success = 0;
    const seenInFile = new Set<string>();
    let maxSort =
      (await this.prisma.idiom.aggregate({ _max: { sortOrder: true } }))._max.sortOrder ?? 0;

    for (let i = 1; i < rows.length; i++) {
      const lineNo = i + 1; // 表头为第 1 行
      const r = rows[i];
      const idiomText = get(r, idx.idiom);
      const data = {
        idiom: idiomText,
        pinyin: get(r, idx.pinyin),
        pinyinChars: normalizePinyinChars(get(r, idx.pinyin_chars)),
        definitionZh: get(r, idx.definition_zh),
        definitionEn: get(r, idx.definition_en),
        exampleZh: get(r, idx.example_zh),
        exampleEn: get(r, idx.example_en),
        storyZh: get(r, idx.story_zh),
        storyEn: get(r, idx.story_en),
      };
      const fail = (reason: string) => failed.push({ row: lineNo, idiom: idiomText, reason });
      if (!idiomText) {
        fail('成语为空');
        continue;
      }
      if (seenInFile.has(idiomText)) {
        fail('文件内重复');
        continue;
      }
      seenInFile.add(idiomText);
      const reasons = publishValidation(data);
      if (reasons.length) {
        fail(reasons.join('；'));
        continue;
      }
      const dup = await this.prisma.idiom.findUnique({ where: { idiom: idiomText } });
      if (dup) {
        fail('成语已存在于数据库');
        continue;
      }
      const sortOrder = parseInt(get(r, idx.sort_order), 10) || ++maxSort;
      if (sortOrder > maxSort) maxSort = sortOrder;
      // 单行入库异常也只记为该行失败，不中断整批、不让请求空响应
      try {
        await this.prisma.idiom.create({ data: { ...data, sortOrder, status: 'draft' } });
      } catch (err: any) {
        fail(`入库失败：${err?.message || '未知错误'}`);
        continue;
      }
      success++;
    }
    return { total: rows.length - 1, success, failedCount: failed.length, failed };
  }
}
