<template>
  <div>
    <el-card>
      <div class="row-line">
        <el-upload :auto-upload="false" :show-file-list="false" accept=".csv" :on-change="onFile">
          <el-button type="primary">选择 CSV 文件</el-button>
        </el-upload>
        <span class="file-name">{{ fileName || '未选择文件' }}</span>
        <el-button type="success" :disabled="!file" :loading="uploading" @click="doImport">开始导入</el-button>
        <el-button @click="downloadTemplate">下载导入模板</el-button>
      </div>
      <div class="tip">
        列格式：sort_order、idiom、pinyin、pinyin_chars、definition_zh、definition_en、example_zh、example_en、status。
        逐行校验（必填、逐字拼音个数与汉字数一致、不与已有成语重复），成功行以草稿入库，失败行不入库并在下方报告原因。
      </div>
    </el-card>

    <el-card v-if="report" class="report">
      <div class="summary">
        导入完成：共 {{ report.total }} 行，成功 <b class="ok">{{ report.success }}</b> 行，失败 <b class="bad">{{ report.failedCount }}</b> 行。
      </div>
      <el-table v-if="report.failed && report.failed.length" :data="report.failed" border>
        <el-table-column prop="row" label="行号" width="80" />
        <el-table-column prop="idiom" label="成语" width="140" />
        <el-table-column prop="reason" label="失败原因" />
      </el-table>
      <div v-else class="ok">全部行导入成功。</div>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { ElMessage } from 'element-plus';
import { api, getToken } from '../api';

const file = ref<File | null>(null);
const fileName = ref('');
const uploading = ref(false);
const report = ref<any>(null);

function onFile(f: any) {
  file.value = f.raw as File;
  fileName.value = f.name;
  report.value = null;
}

async function doImport() {
  if (!file.value) return;
  uploading.value = true;
  try {
    const form = new FormData();
    form.append('file', file.value);
    const res = await fetch('/api/v1/admin/idioms/import', {
      method: 'POST',
      headers: { Authorization: `Bearer ${getToken()}` },
      body: form,
    });
    const json = await res.json();
    if (!res.ok) throw new Error(json?.message || '导入失败');
    report.value = json;
    ElMessage.success('导入完成');
  } catch (e: any) {
    ElMessage.error(e.message);
  } finally {
    uploading.value = false;
  }
}

async function downloadTemplate() {
  try {
    const r = await api('/admin/idioms/template');
    const blob = new Blob(['\ufeff' + r.content], { type: 'text/csv;charset=utf-8' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = r.filename || 'idioms-template.csv';
    a.click();
    URL.revokeObjectURL(a.href);
  } catch (e: any) {
    ElMessage.error(e.message);
  }
}
</script>

<style scoped>
.row-line { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
.file-name { color: #5c636b; font-size: 13px; }
.tip { margin-top: 14px; font-size: 12.5px; color: #9aa1a9; line-height: 1.8; }
.report { margin-top: 18px; }
.summary { margin-bottom: 14px; font-size: 14px; }
.ok { color: #67c23a; }
.bad { color: #f56c6c; }
</style>
