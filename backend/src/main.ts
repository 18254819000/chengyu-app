import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { PagesService, notFoundHtml } from './pages/pages.service';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api/v1');
  app.enableCors();

  // 公开 HTML 页（隐私政策/用户协议）不带 /api/v1 前缀，供 App Store 链接直达。
  // 不能用 setGlobalPrefix 的 exclude 实现：exclude 按路径模式匹配，
  // 会把同为 pages/:key 的公开 JSON 接口一并排除出前缀。故在此用 Express 层直挂。
  const pagesService = app.get(PagesService);
  const server: any = app.getHttpAdapter().getInstance();
  server.get('/pages/:key', async (req: any, res: any) => {
    try {
      const html = await pagesService.renderPageHtml(req.params.key);
      res.status(200).type('text/html').send(html);
    } catch {
      res.status(404).type('text/html').send(notFoundHtml());
    }
  });

  const port = parseInt(process.env.PORT || '3000', 10);
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`每日成语后端已启动：http://localhost:${port}/api/v1`);
}
bootstrap();
