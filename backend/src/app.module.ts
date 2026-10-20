import { Module } from '@nestjs/common';
import { AdminConfigController } from './config/admin-config.controller';
import { AppConfigService } from './config/app-config.service';
import { AuthController } from './auth/auth.controller';
import { AdminIdiomsController } from './idioms/admin-idioms.controller';
import { AppController } from './app-api/app.controller';
import { AdminDailyController } from './app-api/admin-daily.controller';
import { PrismaService } from './prisma/prisma.service';
import { AppleService } from './subscription/apple.service';
import { SubscriptionController } from './subscription/subscription.controller';

@Module({
  controllers: [
    AuthController,
    AdminIdiomsController,
    AdminConfigController,
    AdminDailyController,
    AppController,
    SubscriptionController,
  ],
  providers: [PrismaService, AppConfigService, AppleService],
})
export class AppModule {}
