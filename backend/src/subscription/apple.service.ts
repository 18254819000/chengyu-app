import { Injectable, Logger } from '@nestjs/common';

// StoreKit 2 签名交易 / App Store Server Notifications 的解码与校验。
//
// 两条路径：
// 1) 生产路径：环境变量配齐（APPLE_BUNDLE_ID、APPLE_KEY_ID、APPLE_ISSUER_ID、
//    APPLE_PRIVATE_KEY、APPLE_APP_ID）时，用官方 @apple/app-store-server-library 的
//    AppStoreServerAPIClient 按 transactionId 向苹果服务器查询交易，再解码其返回的
//    signedTransactionInfo 作为权威数据（服务端二次确认，不只信客户端提交的内容）。
// 2) 开发模式（dev-only）：环境变量未配齐时，仅 base64url 解码 JWS 的 payload 段取
//    字段，不做签名验证。仅供本地开发/联调，生产环境禁止使用（日志会明确警告）。

export interface TransactionPayload {
  transactionId?: string;
  originalTransactionId?: string;
  productId?: string;
  bundleId?: string;
  type?: string;
  expiresDate?: number; // ms epoch
  revocationDate?: number; // ms epoch
  environment?: string;
  [k: string]: any;
}

export function decodeJwsPayload(jws: string): any {
  const parts = String(jws || '').split('.');
  if (parts.length < 2) throw new Error('无效的 JWS 格式');
  const b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
  const padded = b64 + '='.repeat((4 - (b64.length % 4)) % 4);
  return JSON.parse(Buffer.from(padded, 'base64').toString('utf8'));
}

export function appleConfigured(): boolean {
  return Boolean(
    process.env.APPLE_BUNDLE_ID &&
      process.env.APPLE_KEY_ID &&
      process.env.APPLE_ISSUER_ID &&
      process.env.APPLE_PRIVATE_KEY &&
      process.env.APPLE_APP_ID,
  );
}

@Injectable()
export class AppleService {
  private readonly logger = new Logger(AppleService.name);

  // 校验一笔交易：返回权威 payload
  async verifyTransaction(jws: string): Promise<{ payload: TransactionPayload; mode: 'production' | 'dev-only' }> {
    const decoded = decodeJwsPayload(jws) as TransactionPayload;
    if (!appleConfigured()) {
      // dev-only：未配置苹果参数，跳过签名验证（仅开发联调用）
      this.logger.warn('DEV-ONLY 模式：未配置苹果参数，JWS 未做签名验证');
      return { payload: decoded, mode: 'dev-only' };
    }
    const authoritative = await this.fetchFromApple(decoded.transactionId, decoded.environment);
    return { payload: authoritative, mode: 'production' };
  }

  // 通知处理：生产模式下同样向苹果查询交易做二次确认；dev 模式直接解码
  async resolveNotificationTransaction(
    signedTransactionInfo: string,
  ): Promise<{ payload: TransactionPayload; mode: 'production' | 'dev-only' }> {
    return this.verifyTransaction(signedTransactionInfo);
  }

  private async fetchFromApple(transactionId: string | undefined, environment?: string): Promise<TransactionPayload> {
    if (!transactionId) throw new Error('交易缺少 transactionId，无法向苹果校验');
    // 动态引入官方库，避免 dev 模式下也强依赖其初始化
    const lib: any = await import('@apple/app-store-server-library');
    const env = environment === 'Sandbox' ? lib.Environment.SANDBOX : lib.Environment.PRODUCTION;
    const privateKey = String(process.env.APPLE_PRIVATE_KEY).replace(/\\n/g, '\n');
    const client = new lib.AppStoreServerAPIClient(
      privateKey,
      process.env.APPLE_KEY_ID,
      process.env.APPLE_ISSUER_ID,
      process.env.APPLE_BUNDLE_ID,
      env,
    );
    const resp = await client.getTransactionInfo(transactionId);
    if (!resp?.signedTransactionInfo) throw new Error('苹果服务器未返回交易信息');
    return decodeJwsPayload(resp.signedTransactionInfo) as TransactionPayload;
  }
}

// 由交易字段推导权益状态
export function deriveStatus(p: TransactionPayload): 'active' | 'expired' | 'revoked' {
  if (p.revocationDate) return 'revoked';
  if (p.expiresDate && p.expiresDate < Date.now()) return 'expired';
  return 'active';
}
