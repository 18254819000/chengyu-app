<template>
  <div>
    <el-card class="card">
      <el-form label-width="90px">
        <el-form-item label="文档标识">
          <span>{{ key }}</span>
          <span class="tip-inline">公开地址：/pages/{{ key }}</span>
        </el-form-item>
        <el-form-item label="标题">
          <el-input v-model="form.title" placeholder="如 Privacy Policy" style="max-width: 420px" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" :loading="saving" @click="save">保存</el-button>
          <el-button @click="router.push('/pages')">返回列表</el-button>
          <span class="tip-inline">保存后立即对外生效，App 内打开与公开页都会显示新内容。</span>
        </el-form-item>
      </el-form>
    </el-card>

    <div class="editor-wrap">
      <el-card class="editor-card">
        <template #header><span>正文（Markdown 格式）</span></template>
        <el-input
          v-model="form.content"
          type="textarea"
          :rows="30"
          resize="none"
          class="md-input"
          placeholder="在此编辑 Markdown 原文"
        />
      </el-card>
      <el-card class="editor-card">
        <template #header><span>实时预览</span></template>
        <div class="preview" v-html="previewHtml"></div>
      </el-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ElMessage } from 'element-plus';
import { marked } from 'marked';
import DOMPurify from 'dompurify';
import { api } from '../api';

const route = useRoute();
const router = useRouter();
const key = String(route.params.key || '');
const saving = ref(false);
const form = reactive({ title: '', content: '' });

const previewHtml = computed(() => {
  const raw = marked.parse(form.content || '', { async: false }) as string;
  return DOMPurify.sanitize(raw);
});

async function load() {
  try {
    const r = await api(`/admin/pages/${key}`);
    form.title = r.title || '';
    form.content = r.content || '';
  } catch (e: any) {
    ElMessage.error(e.message);
  }
}
async function save() {
  saving.value = true;
  try {
    const r = await api(`/admin/pages/${key}`, {
      method: 'PUT',
      body: { title: form.title, content: form.content },
    });
    form.title = r.title;
    form.content = r.content;
    ElMessage.success('保存成功，已对外生效');
  } catch (e: any) {
    ElMessage.error(e.message);
  } finally {
    saving.value = false;
  }
}
onMounted(load);
</script>

<style scoped>
.card { margin-bottom: 16px; }
.tip-inline { font-size: 12px; color: #9aa1a9; margin-left: 12px; }
.editor-wrap { display: flex; gap: 16px; align-items: flex-start; }
.editor-card { flex: 1; min-width: 0; }
.md-input :deep(textarea) { font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 13px; line-height: 1.6; }
.preview { background: #faf8f4; border-radius: 6px; padding: 18px 20px; min-height: 480px; line-height: 1.75; color: #23272b; word-break: break-word; }
.preview :deep(h1) { font-size: 24px; margin: 6px 0 16px; }
.preview :deep(h2) { font-size: 18px; margin: 24px 0 8px; }
.preview :deep(h3) { font-size: 16px; margin: 18px 0 6px; }
.preview :deep(p), .preview :deep(li) { font-size: 14.5px; color: #33383d; }
.preview :deep(a) { color: #b8402f; }
</style>
