import { createRouter, createWebHashHistory } from 'vue-router';
import { getToken } from './api';
import MainLayout from './layout/MainLayout.vue';
import Login from './views/Login.vue';
import IdiomList from './views/IdiomList.vue';
import IdiomEdit from './views/IdiomEdit.vue';
import ImportPage from './views/Import.vue';
import DailyPreview from './views/DailyPreview.vue';
import ConfigPage from './views/Config.vue';

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/login', component: Login },
    {
      path: '/',
      component: MainLayout,
      redirect: '/idioms',
      children: [
        { path: 'idioms', component: IdiomList, meta: { title: '成语管理' } },
        { path: 'idioms/new', component: IdiomEdit, meta: { title: '新增成语' } },
        { path: 'idioms/edit/:id', component: IdiomEdit, meta: { title: '编辑成语' } },
        { path: 'import', component: ImportPage, meta: { title: '批量导入' } },
        { path: 'daily', component: DailyPreview, meta: { title: '每日轮换预览' } },
        { path: 'config', component: ConfigPage, meta: { title: '参数配置' } },
      ],
    },
  ],
});

router.beforeEach((to) => {
  if (to.path !== '/login' && !getToken()) return '/login';
  if (to.path === '/login' && getToken()) return '/idioms';
  return true;
});

export default router;
