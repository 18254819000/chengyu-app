import { Body, Controller, Get, Put, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { AppConfigService } from '../config/app-config.service';

@Controller('admin/config')
@UseGuards(JwtAuthGuard)
export class AdminConfigController {
  constructor(private readonly config: AppConfigService) {}

  // GET /api/v1/admin/config 读取参数配置
  @Get()
  async get() {
    return this.config.getAll();
  }

  // PUT /api/v1/admin/config 更新参数（free_count 变更会自动 bump content_version）
  @Put()
  async put(
    @Body()
    body: Partial<{ free_count: number; monthly_product_id: string; yearly_product_id: string }>,
  ) {
    const partial: any = {};
    if (body.free_count !== undefined) partial.free_count = Number(body.free_count);
    if (body.monthly_product_id !== undefined) partial.monthly_product_id = String(body.monthly_product_id);
    if (body.yearly_product_id !== undefined) partial.yearly_product_id = String(body.yearly_product_id);
    return this.config.update(partial);
  }
}
