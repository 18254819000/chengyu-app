import { PrismaService } from '../prisma/prisma.service';

export interface IdiomInput {
  idiom?: string;
  pinyin?: string;
  pinyin_chars?: string | string[];
  definition_zh?: string;
  definition_en?: string;
  example_zh?: string;
  example_en?: string;
  story_zh?: string;
  story_en?: string;
  source?: string | null;
  tags?: string | null;
  image_url?: string | null;
  sort_order?: number;
  admin_remark?: string | null;
}

export function normalizePinyinChars(v: string | string[] | undefined): string {
  if (Array.isArray(v)) return v.map((s) => s.trim()).filter(Boolean).join(' ');
  return (v || '').trim().split(/\s+/).filter(Boolean).join(' ');
}

export function splitPinyinChars(stored: string): string[] {
  return (stored || '').trim().split(/\s+/).filter(Boolean);
}

export function charCount(s: string): number {
  return [...(s || '')].length;
}

/// 汉字数：只计 CJK 表意文字，标点（如 ，）不计入。
/// 带标点成语（如 狡兔死，良狗烹）的逐字拼音按汉字数对齐，标点不占拼音位。
export function hanCount(s: string): number {
  let n = 0;
  for (const ch of s || '') {
    const cp = ch.codePointAt(0) ?? 0;
    if (
      (cp >= 0x3400 && cp <= 0x4dbf) ||
      (cp >= 0x4e00 && cp <= 0x9fff) ||
      (cp >= 0xf900 && cp <= 0xfaff) ||
      (cp >= 0x20000 && cp <= 0x2a6df)
    ) n++;
  }
  return n;
}

// 发布校验：必填齐全 + 逐字拼音个数与汉字数一致。返回不通过原因列表（空 = 通过）
export function publishValidation(data: {
  idiom: string;
  pinyin: string;
  pinyinChars: string;
  definitionZh: string;
  definitionEn: string;
  exampleZh: string;
  exampleEn: string;
}): string[] {
  const reasons: string[] = [];
  const required: Array<[string, string]> = [
    ['idiom', '成语'],
    ['pinyin', '完整拼音'],
    ['definitionZh', '中文解释'],
    ['definitionEn', '英文解释'],
    ['exampleZh', '中文例句'],
    ['exampleEn', '例句英文翻译'],
  ];
  for (const [key, label] of required) {
    if (!(data as any)[key] || !String((data as any)[key]).trim()) reasons.push(`缺少必填字段：${label}`);
  }
  const parts = splitPinyinChars(data.pinyinChars);
  if (parts.length === 0) {
    reasons.push('缺少必填字段：逐字拼音');
  } else if (data.idiom && parts.length !== hanCount(data.idiom.trim())) {
    reasons.push(`逐字拼音个数（${parts.length}）与成语汉字数（${hanCount(data.idiom.trim())}）不一致`);
  }
  return reasons;
}

export type IdiomRow = Awaited<ReturnType<PrismaService['idiom']['findFirst']>>;

// App 端完整视图（有权访问时）
export function fullView(row: any, locked = false) {
  return {
    id: row.id,
    idiom: row.idiom,
    pinyin: row.pinyin,
    pinyin_chars: splitPinyinChars(row.pinyinChars),
    definition_zh: row.definitionZh,
    definition_en: row.definitionEn,
    example_zh: row.exampleZh,
    example_en: row.exampleEn,
    story_zh: row.storyZh ?? '',
    story_en: row.storyEn ?? '',
    tags: row.tags ?? '',
    image_url: row.imageUrl ?? '',
    sort_order: row.sortOrder,
    status: row.status,
    locked,
  };
}

// 锁定条目视图：只给名称与拼音，绝不带释义与例句
export function lockedView(row: any) {
  return { id: row.id, idiom: row.idiom, pinyin: row.pinyin, locked: true };
}

// 小组件/App 每日成语公开视图（不含例句）
export function dailyView(row: any, date: string, locked: boolean) {
  return {
    date,
    id: row.id,
    idiom: row.idiom,
    pinyin: row.pinyin,
    pinyin_chars: splitPinyinChars(row.pinyinChars),
    definition_zh: row.definitionZh,
    definition_en: row.definitionEn,
    sort_order: row.sortOrder,
    locked,
  };
}

// 后台视图（含免费计算标记由调用方按 free_count 传入）
export function adminView(row: any, freeCount: number) {
  return {
    ...fullView(row, false),
    is_free: row.sortOrder <= freeCount,
    source: row.source ?? '',
    tags: row.tags ?? '',
    admin_remark: row.adminRemark ?? '',
    created_at: row.createdAt,
    updated_at: row.updatedAt,
  };
}
