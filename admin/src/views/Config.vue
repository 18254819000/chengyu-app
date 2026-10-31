<template>
  <el-card class="card">
    <el-form label-width="170px" style="max-width: 560px">
      <el-form-item label="月订阅商品 ID">
        <el-input v-model="form.monthly_product_id" placeholder="如 com.dailyidiom.monthly" />
        <div class="tip">需与 App Store Connect 中创建的商品 ID 完全一致（字段名：monthly_product_id）。</div>
      </el-form-item>
      <el-form-item label="年订阅商品 ID">
        <el-input v-model="form.yearly_product_id" placeholder="如 com.dailyidiom.yearly" />
        <div class="tip">需与 App Store Connect 中创建的商品 ID 完全一致（字段名：yearly_product_id）。</div>
      </el-form-item>
      <el-form-item label="内容版本（只读）">
        <span>{{ form.content_version }}</span>
        <div class="tip">发布、下架或删除后自动递增，App 靠它判断是否需要同步新内容。</div>
      </el-form-item>
      <el-form-item label="最低版本">
        <el-input v-model="form.minimum_version" placeholder="如 1.1.0" />
        <div class="tip">强制更新开启时，低于此版本的 App 会弹不可关闭的更新弹窗。</div>
      </el-form-item>
      <el-form-item label="强制更新">
        <el-switch v-model="form.force_update_enabled" />
        <div class="tip">关着时任何版本都不弹；开着时，低于最低版本的客户端强制更新到商店链接的版本。</div>
      </el-form-item>
      <el-form-item label="商店链接">
        <el-input v-model="form.store_url" placeholder="如 https://apps.apple.com/app/id1234567890" />
        <div class="tip">更新弹窗按钮跳转的地址；App Store Connect 建好 App 记录拿到 Apple ID 后填入。链接为空时不弹窗。</div>
      </el-form-item>
      <el-form-item>
        <el-button type="primary" :loading="saving" @click="save">保存配置</el-button>
      </el-form-item>
    </el-form>
  </el-card>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import { ElMessage } from 'element-plus';
import { api } from '../api';

const saving = ref(false);
const form = reactive({ monthly_product_id: '', yearly_product_id: '', content_version: 1, minimum_version: '1.0.0', force_update_enabled: false, store_url: '' });

async function load() {
  try {
    const r = await api('/admin/config');
    Object.assign(form, r);
  } catch (e: any) {
    ElMessage.error(e.message);
  }
}
async function save() {
  saving.value = true;
  try {
    const r = await api('/admin/config', {
      method: 'PUT',
      body: {
        monthly_product_id: form.monthly_product_id,
        yearly_product_id: form.yearly_product_id,
        minimum_version: form.minimum_version,
        force_update_enabled: form.force_update_enabled,
        store_url: form.store_url,
      },
    });
    Object.assign(form, r);
    ElMessage.success('保存成功');
  } catch (e: any) {
    ElMessage.error(e.message);
  } finally {
    saving.value = false;
  }
}
onMounted(load);
</script>

<style scoped>
.card { max-width: 760px; }
.tip { font-size: 12px; color: #9aa1a9; line-height: 1.7; margin-top: 4px; }
</style>
