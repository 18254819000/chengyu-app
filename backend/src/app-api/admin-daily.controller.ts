import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { PrismaService } from '../prisma/prisma.service';
import { addDays, dailyIndex, isValidDateStr, todayInBeijing } from '../common/daily';

@Controller('admin/daily')
@UseGuards(JwtAuthGuard)
export class AdminDailyController {
  constructor(private readonly prisma: PrismaService) {}

  // GET /api/v1/admin/daily/preview?days=14 未来 N 天轮换预览（与 App/小组件同一公式）
  @Get('preview')
  async preview(@Query('days') days = '14', @Query('from') from?: string) {
    const n = Math.min(60, Math.max(1, parseInt(days, 10) || 14));
    const start = from && isValidDateStr(from) ? from : todayInBeijing();
    const rows = await this.prisma.idiom.findMany({
      where: { status: 'published', deleted: false },
      orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
    });
    const items: any[] = [];
    for (let i = 0; i < n; i++) {
      const date = addDays(start, i);
      if (!rows.length) {
        items.push({ date, idiom: null });
        continue;
      }
      const row = rows[dailyIndex(date, rows.length)];
      items.push({
        date,
        id: row.id,
        idiom: row.idiom,
        pinyin: row.pinyin,
        sort_order: row.sortOrder,
      });
    }
    return { from: start, days: n, published_total: rows.length, items };
  }
}
