import { BadRequestException, Body, Controller, Get, Post, Query } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AppleService, decodeJwsPayload, deriveStatus } from './apple.service';
import { isEntitlementValid } from './entitlement.util';

@Controller()
export class SubscriptionController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly apple: AppleService,
  ) {}

  private async upsertFromPayload(payload: any, statusOverride?: string) {
    const originalTransactionId = payload.originalTransactionId || payload.transactionId;
    if (!originalTransactionId) throw new BadRequestException('交易缺少 originalTransactionId');
    const status = statusOverride || deriveStatus(payload);
    const data = {
      productId: payload.productId || '',
      status,
      expiresAt: payload.expiresDate ? new Date(payload.expiresDate) : null,
      environment: payload.environment || '',
      rawLatestTransaction: JSON.stringify(payload),
    };
    const row = await this.prisma.entitlement.upsert({
      where: { originalTransactionId },
      update: data,
      create: { originalTransactionId, ...data },
    });
    return row;
  }

  private view(row: any) {
    return {
      originalTransactionId: row.originalTransactionId,
      product_id: row.productId,
      status: row.status,
      expires_at: row.expiresAt,
      environment: row.environment,
      entitled: isEntitlementValid(row),
    };
  }

  // POST /api/v1/subscription/verify 客户端提交 StoreKit 2 签名交易，服务端校验后开通/更新权益
  @Post('subscription/verify')
  async verify(@Body() body: { jws?: string }) {
    if (!body?.jws) throw new BadRequestException('缺少 jws 字段');
    let payload: any;
    let mode: string;
    try {
      const r = await this.apple.verifyTransaction(body.jws);
      payload = r.payload;
      mode = r.mode;
    } catch (e: any) {
      throw new BadRequestException(`交易校验失败：${e.message}`);
    }
    const row = await this.upsertFromPayload(payload);
    return { ...this.view(row), verify_mode: mode };
  }

  // GET /api/v1/subscription/status?originalTransactionId= 查询权益状态
  @Get('subscription/status')
  async status(@Query('originalTransactionId') id?: string) {
    if (!id) return { entitled: false, status: 'none' };
    const row = await this.prisma.entitlement.findUnique({ where: { originalTransactionId: id } });
    if (!row) return { entitled: false, status: 'none', originalTransactionId: id };
    return this.view(row);
  }

  // POST /api/v1/apple/notifications App Store Server Notifications V2 回调
  @Post('apple/notifications')
  async notifications(@Body() body: { signedPayload?: string }) {
    if (!body?.signedPayload) throw new BadRequestException('缺少 signedPayload');
    let outer: any;
    try {
      outer = decodeJwsPayload(body.signedPayload);
    } catch {
      throw new BadRequestException('signedPayload 解码失败');
    }
    const type: string = outer.notificationType || '';
    const subtype: string = outer.subtype || '';
    const signedTx: string | undefined = outer?.data?.signedTransactionInfo;
    if (!signedTx) return { ok: true, notificationType: type, handled: false, reason: '无交易信息' };

    const { payload } = await this.apple.resolveNotificationTransaction(signedTx);

    let statusOverride: string | undefined;
    if (type === 'EXPIRED' || type === 'GRACE_PERIOD_EXPIRES') statusOverride = 'expired';
    else if (type === 'REFUND') statusOverride = 'refunded';
    else if (type === 'REVOKE') statusOverride = 'revoked';
    else if (type === 'DID_FAIL_TO_RENEW' && subtype === 'GRACE_PERIOD') statusOverride = 'grace';
    // DID_RENEW / SUBSCRIBED 等：按交易字段推导（通常 active 且到期时间更新）

    const row = await this.upsertFromPayload(payload, statusOverride);
    return {
      ok: true,
      notificationType: type,
      subtype,
      originalTransactionId: row.originalTransactionId,
      status: row.status,
    };
  }
}
