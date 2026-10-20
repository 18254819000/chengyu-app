import { Body, Controller, Get, Param, Put, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt.guard';
import { PagesService } from './pages.service';

@Controller('admin/pages')
@UseGuards(JwtAuthGuard)
export class AdminPagesController {
  constructor(private readonly pages: PagesService) {}

  // GET /api/v1/admin/pages 协议与政策列表（key、标题、最后修改时间）
  @Get()
  async list() {
    return this.pages.list();
  }

  // GET /api/v1/admin/pages/:key 单篇全文（Markdown 原文）
  @Get(':key')
  async get(@Param('key') key: string) {
    return this.pages.getView(key);
  }

  // PUT /api/v1/admin/pages/:key 保存标题与正文（不影响 content_version）
  @Put(':key')
  async put(@Param('key') key: string, @Body() body: { title?: string; content?: string }) {
    return this.pages.update(key, body || {});
  }
}
