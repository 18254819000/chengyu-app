import { Controller, Get, Headers, NotFoundException, Param, ParseIntPipe, Query, Res } from '@nestjs/common';
import type { Response } from 'express';
import { AppConfigService } from '../config/app-config.service';
import { PrismaService } from '../prisma/prisma.service';
import { addDays, dailyIndex, isValidDateStr, todayInBeijing } from '../common/daily';
import { dailyView, fullView, lockedView } from '../idioms/idiom.util';
import { hasValidEntitlement } from '../subscription/entitlement.util';

@Controller()
export class AppController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: AppConfigService,
  ) {}

  private async publishedList() {
    return this.prisma.idiom.findMany({
      where: { status: 'published', deleted: false },
      orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
    });
  }

  // GET /api/v1/config 全局配置（免费数量、商品 ID、内容版本）
  @Get('config')
  async getConfig() {
    return this.config.getAll();
  }

  // GET /api/v1/idioms 已发布成语分页列表，付费条目按权益锁定
  @Get('idioms')
  async list(
    @Query('page') page = '1',
    @Query('pageSize') pageSize = '20',
    @Query('q') q = '',
    @Headers('x-original-transaction-id') txId?: string,
  ) {
    const p = Math.max(1, parseInt(page, 10) || 1);
    const ps = Math.min(200, Math.max(1, parseInt(pageSize, 10) || 20));
    const where: any = { status: 'published', deleted: false };
    if (q) where.OR = [{ idiom: { contains: q } }, { pinyin: { contains: q } }];
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
    const unlockedAll = await hasValidEntitlement(this.prisma, txId);
    const items = rows.map((r) => {
      const locked = !unlockedAll && r.sortOrder > freeCount;
      return locked ? lockedView(r) : fullView(r, false);
    });
    return { total, page: p, pageSize: ps, items };
  }

  // GET /api/v1/idioms/:id 详情；无权访问付费内容返回 403（不含释义与例句）
  @Get('idioms/:id')
  async detail(
    @Param('id', ParseIntPipe) id: number,
    @Res() res: Response,
    @Headers('x-original-transaction-id') txId?: string,
  ) {
    const row = await this.prisma.idiom.findFirst({
      where: { id, status: 'published', deleted: false },
    });
    if (!row) {
      return res.status(404).json({ statusCode: 404, message: '成语不存在或未发布' });
    }
    const freeCount = await this.config.getFreeCount();
    const unlockedAll = await hasValidEntitlement(this.prisma, txId);
    const locked = !unlockedAll && row.sortOrder > freeCount;
    if (locked) {
      // 403 且响应体不含释义与例句
      return res
        .status(403)
        .json({ id: row.id, idiom: row.idiom, pinyin: row.pinyin, locked: true, message: '该成语为订阅内容' });
    }
    return res.json(fullView(row, false));
  }

  // GET /api/v1/daily?date=YYYY-MM-DD 当日成语（公开字段，不含例句）
  @Get('daily')
  async daily(@Query('date') date?: string, @Headers('x-original-transaction-id') txId?: string) {
    const d = date && isValidDateStr(date) ? date : todayInBeijing();
    const rows = await this.publishedList();
    if (!rows.length) throw new NotFoundException('暂无已发布成语');
    const row = rows[dailyIndex(d, rows.length)];
    const freeCount = await this.config.getFreeCount();
    const unlockedAll = await hasValidEntitlement(this.prisma, txId);
    const locked = !unlockedAll && row.sortOrder > freeCount;
    return dailyView(row, d, locked);
  }

  // GET /api/v1/daily/week?from=YYYY-MM-DD 未来 7 天每日成语（供小组件预生成时间线）
  @Get('daily/week')
  async dailyWeek(@Query('from') from?: string, @Headers('x-original-transaction-id') txId?: string) {
    const start = from && isValidDateStr(from) ? from : todayInBeijing();
    const rows = await this.publishedList();
    if (!rows.length) throw new NotFoundException('暂无已发布成语');
    const freeCount = await this.config.getFreeCount();
    const unlockedAll = await hasValidEntitlement(this.prisma, txId);
    const days = [] as any[];
    for (let i = 0; i < 7; i++) {
      const d = addDays(start, i);
      const row = rows[dailyIndex(d, rows.length)];
      const locked = !unlockedAll && row.sortOrder > freeCount;
      days.push(dailyView(row, d, locked));
    }
    return { from: start, days };
  }
}
