<template>
  <div class="cols">
    <el-card class="form-card">
      <el-form label-width="110px">
        <el-form-item label="成语" required>
          <el-input v-model="form.idiom" placeholder="如：画蛇添足" />
        </el-form-item>
        <el-form-item label="排序值" required>
          <el-input-number v-model="form.sort_order" :min="1" />
          <span class="tip">决定列表顺序与免费范围</span>
        </el-form-item>
        <el-form-item label="完整拼音" required>
          <el-input v-model="form.pinyin" placeholder="如：huà shé tiān zú" />
        </el-form-item>
        <el-form-item label="逐字拼音" required>
          <el-input v-model="pinyinCharsText" placeholder="按空格分隔，如：huà shé tiān zú" />
          <div class="tip" :class="{ ok: pinyinOk, bad: !pinyinOk && pinyinCharsText }">
            汉字 {{ charCount }} 个，逐字拼音 {{ pinyinParts.length }} 个
            <span v-if="pinyinParts.length && pinyinOk">，一致，可以发布</span>
            <span v-else-if="pinyinParts.length">，不一致，发布会被拒绝</span>
          </div>
        </el-form-item>
        <el-form-item label="中文解释" required>
          <el-input v-model="form.definition_zh" type="textarea" :rows="3" />
        </el-form-item>
        <el-form-item label="英文解释" required>
          <el-input v-model="form.definition_en" type="textarea" :rows="3" />
        </el-form-item>
        <el-form-item label="中文例句" required>
          <el-input v-model="form.example_zh" type="textarea" :rows="2" />
        </el-form-item>
        <el-form-item label="例句英文翻译" required>
          <el-input v-model="form.example_en" type="textarea" :rows="2" />
        </el-form-item>
        <el-form-item label="出处（预留）">
          <el-input v-model="form.source" placeholder="可空，第一版不在 App 展示" />
        </el-form-item>
        <el-form-item label="标签（预留）">
          <el-input v-model="form.tags" placeholder="可空，多个标签用逗号分隔" />
        </el-form-item>
        <el-form-item label="管理备注">
          <el-input v-model="form.admin_remark" placeholder="仅后台可见" />
        </el-form-item>
        <el-form-item>
          <el-button @click="router.back()">返回</el-button>
          <el-button type="primary" :loading="saving" @click="save(false)">保存草稿</el-button>
          <el-button type="success" :loading="saving" @click="save(true)">保存并发布</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <div class="preview-wrap">
      <div class="preview-title">App 详情页预览</div>
      <div class="phone">
        <div class="p-idiom">
          <div v-for="(c, i) in idiomChars" :key="i" class="p-unit">
            <div class="p-py">{{ pinyinParts[i] || '—' }}</div>
            <div class="p-hz">{{ c }}</div>
          </div>
          <div v-if="!idiomChars.length" class="p-empty">成语预览</div>
        </div>
        <div class="p-div" />
        <div class="p-label">释 义</div>
        <div class="p-def-zh">{{ form.definition_zh || '中文解释预览' }}</div>
        <div class="p-def-en">{{ form.definition_en || 'English definition preview' }}</div>
        <div class="p-example">
          <div class="p-label">例 句</div>
          <div class="p-ex-zh">{{ form.example_zh || '中文例句预览' }}</div>
          <div class="p-ex-en">{{ form.example_en || 'Example sentence in English' }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ElMessage } from 'element-plus';
import { api } from '../api';

const route = useRoute();
const router = useRouter();
const saving = ref(false);
const id = computed(() => (route.params.id ? Number(route.params.id) : null));

const form = reactive<any>({
  idiom: '',
  sort_order: 1,
  pinyin: '',
  definition_zh: '',
  definition_en: '',
  example_zh: '',
  example_en: '',
  source: '',
  tags: '',
  admin_remark: '',
});
const pinyinCharsText = ref('');

const idiomChars = computed(() => [...(form.idiom || '')]);
const charCount = computed(() => idiomChars.value.length);
const pinyinParts = computed(() => pinyinCharsText.value.trim().split(/\s+/).filter(Boolean));
const pinyinOk = computed(() => pinyinParts.value.length > 0 && pinyinParts.value.length === charCount.value);

onMounted(async () => {
  if (id.value) {
    try {
      const r = await api(`/admin/idioms/${id.value}`);
      Object.assign(form, {
        idiom: r.idiom,
        sort_order: r.sort_order,
        pinyin: r.pinyin,
        definition_zh: r.definition_zh,
        definition_en: r.definition_en,
        example_zh: r.example_zh,
        example_en: r.example_en,
        source: r.source || '',
        tags: r.tags || '',
        admin_remark: r.admin_remark || '',
      });
      pinyinCharsText.value = (r.pinyin_chars || []).join(' ');
    } catch (e: any) {
      ElMessage.error(e.message);
    }
  } else {
    try {
      const r = await api('/admin/idioms?page=1&pageSize=1');
      form.sort_order = (r.total || 0) + 1;
    } catch { /* 忽略 */ }
  }
});

async function save(publish: boolean) {
  if (!form.idiom.trim()) {
    ElMessage.warning('请先填写成语');
    return;
  }
  saving.value = true;
  try {
    const body = { ...form, pinyin_chars: pinyinCharsText.value.trim() };
    let savedId = id.value;
    if (savedId) {
      await api(`/admin/idioms/${savedId}`, { method: 'PUT', body });
    } else {
      const r = await api('/admin/idioms', { method: 'POST', body });
      savedId = r.id;
    }
    if (publish) {
      await api(`/admin/idioms/${savedId}/publish`, { method: 'POST' });
      ElMessage.success('保存并发布成功');
    } else {
      ElMessage.success('已保存为草稿');
    }
    router.push('/idioms');
  } catch (e: any) {
    ElMessage.error(e.message);
  } finally {
    saving.value = false;
  }
}
</script>

<style scoped>
.cols { display: flex; gap: 22px; align-items: flex-start; flex-wrap: wrap; }
.form-card { flex: 1; min-width: 460px; }
.tip { font-size: 12px; color: #9aa1a9; margin-left: 8px; }
.tip.ok { color: #67c23a; }
.tip.bad { color: #f56c6c; }
.preview-title { font-size: 13px; color: #9aa1a9; letter-spacing: 0.2em; margin-bottom: 10px; text-align: center; }
.phone {
  width: 330px; background: #faf8f4; border-radius: 30px; padding: 30px 24px 34px;
  box-shadow: 0 14px 34px rgba(35,35,30,.18), 0 0 0 8px #17181a;
}
.p-idiom { display: flex; justify-content: space-between; padding: 0 4px; min-height: 92px; }
.p-unit { display: flex; flex-direction: column; align-items: center; gap: 5px; }
.p-py { font-size: 13px; color: #5c636b; font-family: Georgia, serif; }
.p-hz { font-size: 46px; font-weight: 600; line-height: 1.05; color: #23272b; }
.p-empty { color: #9aa1a9; font-size: 20px; margin: auto; }
.p-div { margin-top: 20px; height: 1px; background: #e7e2d8; position: relative; }
.p-div::after { content: ''; position: absolute; left: 0; top: 0; width: 38px; height: 1px; background: #b8402f; }
.p-label { margin-top: 18px; font-size: 11px; letter-spacing: 0.3em; color: #9aa1a9; font-weight: 600; }
.p-def-zh { margin-top: 8px; font-size: 15.5px; line-height: 1.65; font-weight: 500; color: #23272b; }
.p-def-en { margin-top: 6px; font-size: 13.5px; line-height: 1.6; color: #5c636b; font-family: Georgia, serif; }
.p-example { margin-top: 20px; background: #f2efe8; border-radius: 14px; padding: 14px 16px; }
.p-example .p-label { margin-top: 0; }
.p-ex-zh { margin-top: 7px; font-size: 14.5px; line-height: 1.7; color: #23272b; }
.p-ex-en { margin-top: 5px; font-size: 12.5px; line-height: 1.6; color: #5c636b; font-family: Georgia, serif; }
</style>
