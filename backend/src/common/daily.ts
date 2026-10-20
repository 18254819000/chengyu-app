// 每日成语轮换：纯函数，与需求/技术方案口径一致。
// published 按 sort_order 升序；index = (目标日期距 2026-01-01 的天数) mod 已发布总数。
export const BASE_DATE = '2026-01-01';

export function dateToDays(dateStr: string): number {
  const [y, m, d] = dateStr.split('-').map((x) => parseInt(x, 10));
  const [by, bm, bd] = BASE_DATE.split('-').map((x) => parseInt(x, 10));
  const t = Date.UTC(y, m - 1, d);
  const b = Date.UTC(by, bm - 1, bd);
  return Math.floor((t - b) / 86400000);
}

export function addDays(dateStr: string, n: number): string {
  const [y, m, d] = dateStr.split('-').map((x) => parseInt(x, 10));
  const t = new Date(Date.UTC(y, m - 1, d) + n * 86400000);
  return t.toISOString().slice(0, 10);
}

// 今天（按 UTC+8，即北京时间）
export function todayInBeijing(now: Date = new Date()): string {
  const t = new Date(now.getTime() + 8 * 3600 * 1000);
  return t.toISOString().slice(0, 10);
}

export function dailyIndex(dateStr: string, total: number): number {
  if (total <= 0) return -1;
  const days = dateToDays(dateStr);
  return ((days % total) + total) % total;
}

export function isValidDateStr(s: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(s) && !isNaN(Date.parse(s + 'T00:00:00Z'));
}
