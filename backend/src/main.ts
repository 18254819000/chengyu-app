import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api/v1');
  app.enableCors();
  const port = parseInt(process.env.PORT || '3000', 10);
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`每日成语后端已启动：http://localhost:${port}/api/v1`);
}
bootstrap();
