import { Injectable, NotFoundException } from '@nestjs/common';
import { marked } from 'marked';
import { PrismaService } from '../prisma/prisma.service';

export interface PageView {
  key: string;
  title: string;
  updated_at: Date;
}

// 渲染后消毒：内容源是管理员本人，做基础防护即可——去掉脚本/嵌入类标签、事件属性与 javascript: 链接
export function sanitizeHtml(html: string): string {
  return html
    .replace(/<\s*(script|iframe|object|embed|form|style)\b[\s\S]*?<\s*\/\s*\1\s*>/gi, '')
    .replace(/<\s*(script|iframe|object|embed|form|style|link|meta|base)\b[^>]*>/gi, '')
    .replace(/\son\w+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi, '')
    .replace(/(href|src)\s*=\s*("|')\s*javascript:[^"']*\2/gi, '$1="#"');
}

export function renderMarkdown(md: string): string {
  const html = marked.parse(md || '', { async: false }) as string;
  return sanitizeHtml(html);
}

// 公开 HTML 页模板：完整文档、纸面色、移动端可读
export function pageHtml(title: string, bodyHtml: string): string {
  const safeTitle = String(title || '').replace(/[<>&"]/g, '');
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${safeTitle} · Daily Chengyu</title>
<style>
  body { margin: 0; background: #faf8f4; color: #23272b; font-family: -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; line-height: 1.75; }
  main { max-width: 720px; margin: 0 auto; padding: 32px 20px 64px; }
  h1 { font-size: 26px; line-height: 1.35; margin: 8px 0 20px; }
  h2 { font-size: 19px; margin: 30px 0 10px; }
  h3 { font-size: 16px; margin: 22px 0 8px; }
  p, li { font-size: 15.5px; color: #33383d; }
  a { color: #b8402f; }
  hr { border: none; border-top: 1px solid #e7e2d8; margin: 28px 0; }
  strong { color: #23272b; }
  footer { max-width: 720px; margin: 0 auto; padding: 0 20px 40px; font-size: 13px; color: #9aa1a9; }
</style>
</head>
<body>
<main>
${bodyHtml}
</main>
<footer>Daily Chengyu · Tai'an Mengma Software Service Co., Ltd.</footer>
</body>
</html>`;
}

export function notFoundHtml(): string {
  return pageHtml('Not Found', '<h1>Page Not Found</h1><p>The page you are looking for does not exist.</p>');
}

@Injectable()
export class PagesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(): Promise<PageView[]> {
    const rows = await this.prisma.contentPage.findMany({ orderBy: { id: 'asc' } });
    return rows.map((r) => ({ key: r.key, title: r.title, updated_at: r.updatedAt }));
  }

  async getRaw(key: string) {
    const row = await this.prisma.contentPage.findUnique({ where: { key } });
    if (!row) throw new NotFoundException('内容页不存在');
    return row;
  }

  async getView(key: string) {
    const row = await this.getRaw(key);
    return { key: row.key, title: row.title, content: row.content, updated_at: row.updatedAt };
  }

  // 保存编辑：只更新标题与正文，updatedAt 由 Prisma @updatedAt 自动刷新；不 bump content_version
  async update(key: string, data: { title?: string; content?: string }) {
    await this.getRaw(key);
    const patch: { title?: string; content?: string } = {};
    if (data.title !== undefined) patch.title = String(data.title);
    if (data.content !== undefined) patch.content = String(data.content);
    const row = await this.prisma.contentPage.update({ where: { key }, data: patch });
    return { key: row.key, title: row.title, content: row.content, updated_at: row.updatedAt };
  }

  async renderPageHtml(key: string): Promise<string> {
    const row = await this.getRaw(key);
    return pageHtml(row.title, renderMarkdown(row.content));
  }
}
