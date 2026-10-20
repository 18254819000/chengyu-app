<template>
  <el-card class="card">
    <el-form label-width="170px" style="max-width: 560px">
      <el-form-item label="免费成语数量">
        <el-input-number v-model="form.free_count" :min="0" :max="10000" />
        <div class="tip">排序靠前的这个数量为免费内容，其余需订阅。修改后 App 端随下一次同步生效，并自动递增内容版本。</div>
      </el-form-item>
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
        <div class="tip">发布、下架、删除或修改免费数量后自动递增，App 靠它判断是否需要同步新内容。</div>
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
const form = reactive({ free_count: 20, monthly_product_id: '', yearly_product_id: '', content_version: 1 });

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
        free_count: form.free_count,
        monthly_product_id: form.monthly_product_id,
        yearly_product_id: form.yearly_product_id,
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
