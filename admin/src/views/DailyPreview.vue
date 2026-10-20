<template>
  <div>
    <div class="toolbar">
      <span>展示天数</span>
      <el-input-number v-model="days" :min="1" :max="60" @change="load" />
      <el-button @click="load">刷新</el-button>
      <span class="note">与 App 和小组件同一套轮换公式：已发布成语按排序轮换，一轮内不重复。当前已发布 {{ total }} 条。</span>
    </div>
    <el-table :data="items" v-loading="loading" border>
      <el-table-column prop="date" label="日期" width="140" />
      <el-table-column label="星期" width="90">
        <template #default="{ row }">{{ weekday(row.date) }}</template>
      </el-table-column>
      <el-table-column prop="idiom" label="每日成语" width="140" />
      <el-table-column prop="pinyin" label="拼音" min-width="180" />
      <el-table-column prop="sort_order" label="排序" width="80" />
    </el-table>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { ElMessage } from 'element-plus';
import { api } from '../api';

const days = ref(14);
const items = ref<any[]>([]);
const total = ref(0);
const loading = ref(false);

function weekday(d: string) {
  const names = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return names[new Date(d + 'T00:00:00').getDay()];
}

async function load() {
  loading.value = true;
  try {
    const r = await api(`/admin/daily/preview?days=${days.value}`);
    items.value = r.items;
    total.value = r.published_total;
  } catch (e: any) {
    ElMessage.error(e.message);
  } finally {
    loading.value = false;
  }
}
onMounted(load);
</script>

<style scoped>
.toolbar { display: flex; gap: 10px; align-items: center; margin-bottom: 16px; flex-wrap: wrap; }
.note { color: #9aa1a9; font-size: 13px; }
</style>
