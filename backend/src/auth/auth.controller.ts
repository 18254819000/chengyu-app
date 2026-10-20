import { Body, Controller, HttpCode, Post, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import * as jwt from 'jsonwebtoken';
import { PrismaService } from '../prisma/prisma.service';
import { JWT_SECRET } from './jwt.guard';

@Controller('admin')
export class AuthController {
  constructor(private readonly prisma: PrismaService) {}

  // POST /api/v1/admin/login 管理员登录，成功返回 JWT
  @Post('login')
  @HttpCode(200)
  async login(@Body() body: { username?: string; password?: string }) {
    const username = (body?.username || '').trim();
    const password = body?.password || '';
    const admin = await this.prisma.adminUser.findUnique({ where: { username } });
    if (!admin || !(await bcrypt.compare(password, admin.passwordHash))) {
      throw new UnauthorizedException('用户名或密码不正确');
    }
    const token = jwt.sign({ sub: admin.id, username: admin.username }, JWT_SECRET, { expiresIn: '2h' });
    return { token, username: admin.username };
  }
}
