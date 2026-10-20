import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface AppConfigView {
  free_count: number;
  monthly_product_id: string;
  yearly_product_id: string;
  content_version: number;
}

const DEFAULTS: Record<string, string> = {
  free_count: '20',
  monthly_product_id: '',
  yearly_product_id: '',
  content_version: '1',
};

@Injectable()
export class AppConfigService {
  constructor(private readonly prisma: PrismaService) {}

  private async get(key: string): Promise<string> {
    const row = await this.prisma.appConfig.findUnique({ where: { key } });
    if (row) return row.value;
    await this.prisma.appConfig.create({ data: { key, value: DEFAULTS[key] ?? '' } });
    return DEFAULTS[key] ?? '';
  }

  private async set(key: string, value: string): Promise<void> {
    await this.prisma.appConfig.upsert({
      where: { key },
      update: { value },
      create: { key, value },
    });
  }

  async getAll(): Promise<AppConfigView> {
    const [freeCount, monthly, yearly, version] = await Promise.all([
      this.get('free_count'),
      this.get('monthly_product_id'),
      this.get('yearly_product_id'),
      this.get('content_version'),
    ]);
    return {
      free_count: parseInt(freeCount, 10) || 0,
      monthly_product_id: monthly,
      yearly_product_id: yearly,
      content_version: parseInt(version, 10) || 1,
    };
  }

  async getFreeCount(): Promise<number> {
    return parseInt(await this.get('free_count'), 10) || 0;
  }

  // 任何影响已发布内容 / 排序 / 免费数量的变更后调用，content_version 自增
  async bumpContentVersion(): Promise<number> {
    const cur = parseInt(await this.get('content_version'), 10) || 1;
    const next = cur + 1;
    await this.set('content_version', String(next));
    return next;
  }

  async update(partial: Partial<{ free_count: number; monthly_product_id: string; yearly_product_id: string }>) {
    const before = await this.getAll();
    if (partial.free_count !== undefined) await this.set('free_count', String(partial.free_count));
    if (partial.monthly_product_id !== undefined) await this.set('monthly_product_id', partial.monthly_product_id);
    if (partial.yearly_product_id !== undefined) await this.set('yearly_product_id', partial.yearly_product_id);
    if (partial.free_count !== undefined && partial.free_count !== before.free_count) {
      await this.bumpContentVersion();
    }
    return this.getAll();
  }
}
