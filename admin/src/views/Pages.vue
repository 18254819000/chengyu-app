<template>
  <el-card class="card">
    <el-table :data="rows" v-loading="loading" style="width: 100%">
      <el-table-column prop="title" label="文档标题" min-width="200" />
      <el-table-column prop="key" label="标识" width="140" />
      <el-table-column label="最后修改时间" width="210">
        <template #default="{ row }">{{ formatTime(row.updated_at) }}</template>
      </el-table-column>
      <el-table-column label="公开页面" width="130">
        <template #default="{ row }">
          <el-link type="primary" :href="publicUrl(row.key)" target="_blank">查看公开页</el-link>
        </template>
      </el-table-column>
      <el-table-column label="操作" width="110">
        <template #default="{ row }">
          <el-button type="primary" size="small" @click="router.push(`/pages/edit/${row.key}`)">编辑</el-button>
        </template>
      </el-table-column>
    </el-table>
    <div class="tip">
      公开页地址为「后端域名/pages/privacy」与「后端域名/pages/terms」，可直接填到 App Store Connect 的隐私政策与用户协议链接处。在此处修改保存后，App 内打开与公开页都会立即显示新内容。
    </div>
  </el-card>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { ElMessage } from 'element-plus';
import { api } from '../api';

const router = useRouter();
const loading = ref(false);
const rows = ref<any[]>([]);

function formatTime(v: string) {
  if (!v) return '';
  const d = new Date(v);
  return isNaN(d.getTime()) ? v : d.toLocaleString('zh-CN', { hour12: false });
}

// 公开页不带 /api/v1 前缀：由接口基址推导后端根地址
function publicUrl(key: string) {
  const base = (import.meta as any).env?.VITE_API_BASE_URL as string | undefined;
  const origin = base ? base.replace(/\/api\/v1\/?$/, '') : '';
  return `${origin}/pages/${key}`;
}

async function load() {
  loading.value = true;
  try {
    rows.value = await api('/admin/pages');
  } catch (e: any) {
    ElMessage.error(e.message);
  } finally {
    loading.value = false;
  }
}
onMounted(load);
</script>

<style scoped>
.card { max-width: 900px; }
.tip { font-size: 12px; color: #9aa1a9; line-height: 1.7; margin-top: 14px; }
</style>
