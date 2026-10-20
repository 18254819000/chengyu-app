import { Controller, Get, Param } from '@nestjs/common';
import { PagesService } from './pages.service';

@Controller('pages')
export class PagesController {
  constructor(private readonly pages: PagesService) {}

  // GET /api/v1/pages/:key 公开 JSON：{ key, title, content(Markdown), updated_at }
  @Get(':key')
  async get(@Param('key') key: string) {
    return this.pages.getView(key);
  }
}
