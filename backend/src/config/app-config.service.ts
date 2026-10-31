import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface AppConfigView {
  free_count: number;
  monthly_product_id: string;
  yearly_product_id: string;
  content_version: number;
  // 强制更新：开关关着时任何版本都不弹；开关开着时，低于 minimum_version 的客户端弹不可关闭的更新弹窗。
  minimum_version: string;
  force_update_enabled: boolean;
  store_url: string;
}

const DEFAULTS: Record<string, string> = {
  free_count: '20',
  monthly_product_id: '',
  yearly_product_id: '',
  content_version: '1',
  minimum_version: '1.0.0',
  force_update_enabled: 'false',
  store_url: '',
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
    const [freeCount, monthly, yearly, version, minimumVersion, forceEnabled, storeUrl] = await Promise.all([
      this.get('free_count'),
      this.get('monthly_product_id'),
      this.get('yearly_product_id'),
      this.get('content_version'),
      this.get('minimum_version'),
      this.get('force_update_enabled'),
      this.get('store_url'),
    ]);
    return {
      free_count: parseInt(freeCount, 10) || 0,
      monthly_product_id: monthly,
      yearly_product_id: yearly,
      content_version: parseInt(version, 10) || 1,
      minimum_version: minimumVersion || '1.0.0',
      force_update_enabled: forceEnabled === 'true',
      store_url: storeUrl,
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

  async update(partial: Partial<{
    free_count: number;
    monthly_product_id: string;
    yearly_product_id: string;
    minimum_version: string;
    force_update_enabled: boolean;
    store_url: string;
  }>) {
    const before = await this.getAll();
    if (partial.free_count !== undefined) await this.set('free_count', String(partial.free_count));
    if (partial.monthly_product_id !== undefined) await this.set('monthly_product_id', partial.monthly_product_id);
    if (partial.yearly_product_id !== undefined) await this.set('yearly_product_id', partial.yearly_product_id);
    // 强制更新字段与内容无关，改动不触发 content_version 自增
    if (partial.minimum_version !== undefined) await this.set('minimum_version', partial.minimum_version);
    if (partial.force_update_enabled !== undefined) await this.set('force_update_enabled', partial.force_update_enabled ? 'true' : 'false');
    if (partial.store_url !== undefined) await this.set('store_url', partial.store_url);
    if (partial.free_count !== undefined && partial.free_count !== before.free_count) {
      await this.bumpContentVersion();
    }
    return this.getAll();
  }
}
