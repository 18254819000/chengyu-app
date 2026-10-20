import { PrismaService } from '../prisma/prisma.service';

// 权益是否有效：active/grace 且未过期（grace 为苹果扣费重试宽限期，期内仍可访问）
export function isEntitlementValid(e: any): boolean {
  if (!e) return false;
  if (e.status === 'revoked' || e.status === 'refunded' || e.status === 'expired') return false;
  if (e.status === 'grace') return true;
  if (e.status === 'active') {
    if (e.expiresAt && new Date(e.expiresAt).getTime() < Date.now()) return false;
    return true;
  }
  return false;
}

export async function hasValidEntitlement(
  prisma: PrismaService,
  originalTransactionId: string | undefined,
): Promise<boolean> {
  if (!originalTransactionId) return false;
  const e = await prisma.entitlement.findUnique({
    where: { originalTransactionId },
  });
  return isEntitlementValid(e);
}
