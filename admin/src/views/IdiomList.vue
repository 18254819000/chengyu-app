<template>
  <div>
    <div class="toolbar">
      <el-input v-model="q" placeholder="按成语或拼音搜索" clearable style="width: 240px" @keyup.enter="reload" @clear="reload" />
      <el-select v-model="status" placeholder="全部状态" clearable style="width: 140px" @change="reload">
        <el-option label="草稿" value="draft" />
        <el-option label="已发布" value="published" />
        <el-option label="已下架" value="offline" />
      </el-select>
      <el-button @click="reload">搜索</el-button>
      <div class="spacer" />
      <span class="free-note">免费内容：当日成语（每天自动轮换）</span>
      <el-button type="primary" @click="router.push('/idioms/new')">新增成语</el-button>
      <el-button type="success" :loading="publishing" @click="publishAll">一键发布</el-button>
    </div>

    <el-card v-if="publishReport" class="report">
      <div class="summary">
        一键发布完成：共 {{ publishReport.total }} 条草稿，成功 <b class="ok">{{ publishReport.published }}</b> 条，失败 <b class="bad">{{ publishReport.failedCount }}</b> 条。
      </div>
      <el-table v-if="publishReport.failed && publishReport.failed.length" :data="publishReport.failed" border>
        <el-table-column prop="idiom" label="成语" width="140" />
        <el-table-column prop="reason" label="未发布原因" />
      </el-table>
      <div v-else class="ok">全部发布成功。</div>
    </el-card>

    <el-table :data="items" v-loading="loading" border style="width: 100%">
      <el-table-column prop="sort_order" label="排序" width="70" />
      <el-table-column prop="idiom" label="成语" width="120" />
      <el-table-column prop="pinyin" label="拼音" min-width="170" />
      <el-table-column label="分类" width="110">
        <template #default="{ row }">
          <span v-if="row.tags">{{ row.tags }}</span>
          <span v-else class="dim">—</span>
        </template>
      </el-table-column>
      <el-table-column label="故事" width="80">
        <template #default="{ row }">
          <el-tag v-if="row.story_zh" type="success">有</el-tag>
          <span v-else class="dim">无</span>
        </template>
      </el-table-column>
      <el-table-column label="状态" width="90">
        <template #default="{ row }">
          <el-tag v-if="row.status === 'published'" type="success">已发布</el-tag>
          <el-tag v-else-if="row.status === 'offline'" type="info">已下架</el-tag>
          <el-tag v-else type="warning">草稿</el-tag>
        </template>
      </el-table-column>
      <el-table-column label="是否免费" width="90">
        <template #default="{ row }">
          <el-tag v-if="row.is_free" type="primary">免费</el-tag>
          <span v-else class="dim">订阅</span>
        </template>
      </el-table-column>
      <el-table-column label="更新时间" min-width="160">
        <template #default="{ row }">{{ formatTime(row.updated_at) }}</template>
      </el-table-column>
      <el-table-column label="操作" width="250" fixed="right">
        <template #default="{ row }">
          <el-button size="small" @click="router.push(`/idioms/edit/${row.id}`)">编辑</el-button>
          <el-button v-if="row.status !== 'published'" size="small" type="success" @click="publish(row)">发布</el-button>
          <el-button v-else size="small" type="warning" @click="unpublish(row)">下架</el-button>
          <el-button size="small" type="danger" @click="remove(row)">删除</el-button>
        </template>
      </el-table-column>
    </el-table>

    <el-pagination
      class="pager"
      background
      layout="total, prev, pager, next, sizes"
      :total="total"
      :page-size="pageSize"
      :current-page="page"
      :page-sizes="[10, 20, 50, 100]"
      @current-change="(p: number) => { page = p; load(); }"
      @size-change="(s: number) => { pageSize = s; page = 1; load(); }"
    />
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { ElMessage, ElMessageBox } from 'element-plus';
import { api } from '../api';

const router = useRouter();
const items = ref<any[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(20);
const q = ref('');
const status = ref('');
const loading = ref(false);

const publishing = ref(false);
const publishReport = ref<any>(null);

function formatTime(t: string) {
  return t ? new Date(t).toLocaleString('zh-CN', { hour12: false }) : '';
}

async function load() {
  loading.value = true;
  try {
    const params = new URLSearchParams({
      page: String(page.value),
      pageSize: String(pageSize.value),
      q: q.value,
      status: status.value,
    });
    const r = await api(`/admin/idioms?${params}`);
    items.value = r.items;
    total.value = r.total;
  } catch (e: any) {
    ElMessage.error(e.message);
  } finally {
    loading.value = false;
  }
}
function reload() {
  page.value = 1;
  load();
}
async function publish(row: any) {
  try {
    await api(`/admin/idioms/${row.id}/publish`, { method: 'POST' });
    ElMessage.success('发布成功');
    load();
  } catch (e: any) {
    ElMessage.error(e.message);
  }
}
async function publishAll() {
  let draftTotal = 0;
  try {
    const c = await api('/admin/idioms?page=1&pageSize=1&status=draft');
    draftTotal = c.total || 0;
  } catch (e: any) {
    ElMessage.error(e.message);
    return;
  }
  if (!draftTotal) {
    ElMessage.info('没有草稿可发布');
    return;
  }
  try {
    await ElMessageBox.confirm(
      `确定一键发布全部 ${draftTotal} 条草稿吗？校验不通过的会留在草稿并在下方逐条报告原因。`,
      '一键发布',
      { type: 'success', confirmButtonText: '发布', cancelButtonText: '取消' },
    );
  } catch (e: any) {
    if (e === 'cancel' || e === 'close') return;
    ElMessage.error(e?.message || '操作取消');
    return;
  }
  publishing.value = true;
  try {
    const r = await api('/admin/idioms/publish-all', { method: 'POST' });
    publishReport.value = r;
    ElMessage.success(`一键发布完成：成功 ${r.published} 条，失败 ${r.failedCount} 条`);
    load();
  } catch (e: any) {
    ElMessage.error(e.message);
  } finally {
    publishing.value = false;
  }
}
async function unpublish(row: any) {
  try {
    await api(`/admin/idioms/${row.id}/unpublish`, { method: 'POST' });
    ElMessage.success('已下架');
    load();
  } catch (e: any) {
    ElMessage.error(e.message);
  }
}
async function remove(row: any) {
  await ElMessageBox.confirm(`确定删除成语「${row.idiom}」吗？删除为软删除，可由数据库恢复。`, '删除确认', {
    type: 'warning',
    confirmButtonText: '删除',
    cancelButtonText: '取消',
  });
  try {
    await api(`/admin/idioms/${row.id}`, { method: 'DELETE' });
    ElMessage.success('已删除');
    load();
  } catch (e: any) {
    ElMessage.error(e.message);
  }
}

onMounted(async () => {
  load();
});
</script>

<style scoped>
.toolbar { display: flex; gap: 10px; align-items: center; margin-bottom: 16px; flex-wrap: wrap; }
.spacer { flex: 1; }
.free-note { color: #9aa1a9; font-size: 13px; }
.dim { color: #9aa1a9; }
.pager { margin-top: 16px; justify-content: flex-end; }
.report { margin-bottom: 16px; }
.summary { margin-bottom: 14px; font-size: 14px; }
</style>
