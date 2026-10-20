<template>
  <el-container class="layout">
    <el-aside width="210px" class="aside">
      <div class="logo">每日成语</div>
      <div class="logo-sub">管理后台</div>
      <el-menu :default-active="route.path" router class="menu">
        <el-menu-item index="/idioms">成语管理</el-menu-item>
        <el-menu-item index="/import">批量导入</el-menu-item>
        <el-menu-item index="/daily">每日轮换预览</el-menu-item>
        <el-menu-item index="/config">参数配置</el-menu-item>
      </el-menu>
      <div class="aside-foot">
        <el-button text @click="logout">退出登录</el-button>
      </div>
    </el-aside>
    <el-container>
      <el-header class="header">
        <span class="header-title">{{ (route.meta.title as string) || '' }}</span>
      </el-header>
      <el-main class="main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup lang="ts">
import { useRoute, useRouter } from 'vue-router';
import { clearToken } from '../api';

const route = useRoute();
const router = useRouter();
function logout() {
  clearToken();
  router.push('/login');
}
</script>

<style scoped>
.layout { height: 100vh; }
.aside { background: #23272b; color: #fff; display: flex; flex-direction: column; }
.logo { font-size: 20px; font-weight: 700; letter-spacing: 0.2em; padding: 22px 20px 2px; }
.logo-sub { font-size: 12px; color: #9aa1a9; padding: 0 20px 14px; letter-spacing: 0.3em; }
.menu { background: transparent; border-right: none; flex: 1; }
.menu :deep(.el-menu-item) { color: #cfd4d9; }
.menu :deep(.el-menu-item.is-active) { color: #fff; background: #b8402f; }
.aside-foot { padding: 14px 12px; }
.aside-foot :deep(.el-button) { color: #9aa1a9; }
.header { background: #fff; border-bottom: 1px solid #e7e2d8; display: flex; align-items: center; }
.header-title { font-size: 16px; font-weight: 600; letter-spacing: 0.08em; }
.main { background: #faf8f4; }
</style>
