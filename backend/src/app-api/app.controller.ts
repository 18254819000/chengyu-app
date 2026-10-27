import { Controller, Get, Headers, NotFoundException, Param, ParseIntPipe, Query, Res } from '@nestjs/common';
import type { Response } from 'express';
import { AppConfigService } from '../config/app-config.service';
import { PrismaService } from '../prisma/prisma.service';
import { addDays, dailyIndex, isValidDateStr, todayInBeijing } from '../common/daily';
import { dailyIdForToday, dailyView, fullView, lockedView } from '../idioms/idiom.util';
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

  /// 调用方当日：App 传本地日期；不传则默认北京时间。
  /// 新免费模型（2026-10-27）：免费 = 当日成语；锁定判定一律以后端算出的当日成语 id 为准，
  /// App 不再本地定免费，避免时区不一致导致“今日成语被锁”。
  private callerToday(today?: string) {
    return today && isValidDateStr(today) ? today : todayInBeijing();
  }

  // GET /api/v1/config 全局配置（商品 ID、内容版本；free_count 为保留字段，不再驱动锁定）
  @Get('config')
  async getConfig() {
    return this.config.getAll();
  }

  // GET /api/v1/idioms 已发布成语分页列表，锁定规则：非订阅用户仅当日成语免费
  @Get('idioms')
  async list(
    @Query('page') page = '1',
    @Query('pageSize') pageSize = '20',
    @Query('q') q = '',
    @Query('today') today = '',
    @Headers('x-original-transaction-id') txId?: string,
  ) {
    const p = Math.max(1, parseInt(page, 10) || 1);
    const ps = Math.min(200, Math.max(1, parseInt(pageSize, 10) || 20));
    const where: any = { status: 'published', deleted: false };
    if (q) where.OR = [{ idiom: { contains: q } }, { pinyin: { contains: q } }];
    const [total, rows, published] = await Promise.all([
      this.prisma.idiom.count({ where }),
      this.prisma.idiom.findMany({
        where,
        orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
        skip: (p - 1) * ps,
        take: ps,
      }),
      this.publishedList(),
    ]);
    const unlockedAll = await hasValidEntitlement(this.prisma, txId);
    const todayId = dailyIdForToday(published, this.callerToday(today));
    const items = rows.map((r) => {
      const locked = !unlockedAll && r.id !== todayId;
      return locked ? lockedView(r) : fullView(r, false);
    });
    return { total, page: p, pageSize: ps, items };
  }

  // GET /api/v1/idioms/:id 详情；非当日成语且无权益返回 403（不含释义与例句）
  @Get('idioms/:id')
  async detail(
    @Param('id', ParseIntPipe) id: number,
    @Res() res: Response,
    @Query('today') today = '',
    @Headers('x-original-transaction-id') txId?: string,
  ) {
    const row = await this.prisma.idiom.findFirst({
      where: { id, status: 'published', deleted: false },
    });
    if (!row) {
      return res.status(404).json({ statusCode: 404, message: '成语不存在或未发布' });
    }
    const unlockedAll = await hasValidEntitlement(this.prisma, txId);
    const todayId = dailyIdForToday(await this.publishedList(), this.callerToday(today));
    const locked = !unlockedAll && row.id !== todayId;
    if (locked) {
      // 403 且响应体不含释义与例句
      return res
        .status(403)
        .json({ id: row.id, idiom: row.idiom, pinyin: row.pinyin, locked: true, message: '该成语为订阅内容' });
    }
    return res.json(fullView(row, false));
  }

  // GET /api/v1/daily?date=YYYY-MM-DD 当日成语（公开字段，不含例句）
  // locked 语义：该日期的成语是否为调用方当日的免费成语（非当日则锁定；释义仍下发，供小组件时间线使用）
  @Get('daily')
  async daily(
    @Query('date') date?: string,
    @Query('today') today = '',
    @Headers('x-original-transaction-id') txId?: string,
  ) {
    const d = date && isValidDateStr(date) ? date : todayInBeijing();
    const rows = await this.publishedList();
    if (!rows.length) throw new NotFoundException('暂无已发布成语');
    const row = rows[dailyIndex(d, rows.length)];
    const unlockedAll = await hasValidEntitlement(this.prisma, txId);
    const todayId = dailyIdForToday(rows, this.callerToday(today));
    const locked = !unlockedAll && row.id !== todayId;
    return dailyView(row, d, locked);
  }

  // GET /api/v1/daily/week?from=YYYY-MM-DD 未来 7 天每日成语（供小组件预生成时间线）
  @Get('daily/week')
  async dailyWeek(
    @Query('from') from?: string,
    @Query('today') today = '',
    @Headers('x-original-transaction-id') txId?: string,
  ) {
    const start = from && isValidDateStr(from) ? from : todayInBeijing();
    const rows = await this.publishedList();
    if (!rows.length) throw new NotFoundException('暂无已发布成语');
    const unlockedAll = await hasValidEntitlement(this.prisma, txId);
    const todayId = dailyIdForToday(rows, this.callerToday(today));
    const days = [] as any[];
    for (let i = 0; i < 7; i++) {
      const d = addDays(start, i);
      const row = rows[dailyIndex(d, rows.length)];
      const locked = !unlockedAll && row.id !== todayId;
      days.push(dailyView(row, d, locked));
    }
    return { from: start, days };
  }
}
