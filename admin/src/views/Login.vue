<template>
  <div class="wrap">
    <div class="card">
      <div class="title">每日成语</div>
      <div class="sub">管理后台登录</div>
      <el-form @submit.prevent="submit">
        <el-form-item>
          <el-input v-model="form.username" placeholder="用户名" size="large" />
        </el-form-item>
        <el-form-item>
          <el-input v-model="form.password" type="password" placeholder="密码" size="large" show-password @keyup.enter="submit" />
        </el-form-item>
        <el-button type="primary" size="large" class="btn" :loading="loading" @click="submit">登 录</el-button>
      </el-form>
      <div class="hint">开发默认账号：admin / admin123（上线前务必修改）</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue';
import { useRouter } from 'vue-router';
import { ElMessage } from 'element-plus';
import { api, setToken } from '../api';

const router = useRouter();
const loading = ref(false);
const form = reactive({ username: 'admin', password: '' });

async function submit() {
  if (!form.username || !form.password) {
    ElMessage.warning('请输入用户名和密码');
    return;
  }
  loading.value = true;
  try {
    const r = await api('/admin/login', { method: 'POST', body: { ...form } });
    setToken(r.token);
    ElMessage.success('登录成功');
    router.push('/idioms');
  } catch (e: any) {
    ElMessage.error(e.message || '登录失败');
  } finally {
    loading.value = false;
  }
}
</script>

<style scoped>
.wrap { min-height: 100vh; display: flex; align-items: center; justify-content: center; background: #faf8f4; }
.card { width: 360px; background: #fff; border: 1px solid #e7e2d8; border-radius: 16px; padding: 36px 32px 26px; }
.title { font-size: 24px; font-weight: 700; letter-spacing: 0.22em; text-align: center; }
.sub { text-align: center; color: #9aa1a9; margin: 8px 0 24px; letter-spacing: 0.3em; font-size: 12px; }
.btn { width: 100%; background: #b8402f; border-color: #b8402f; }
.hint { margin-top: 16px; font-size: 12px; color: #9aa1a9; text-align: center; }
</style>
