# GTM 单任务专注台（Focus Desk）

> 仓库 `flow-us` 是本项目的代码仓库，主文件 `focus-desk.html`，线上域名 **https://flow-us.com**

一个强制「一次只专注一个任务」的个人工作台，为海外广告投放（GTM）场景定制。

## 架构

| 层 | 方案 | 说明 |
|---|---|---|
| 前端 | Cloudflare Pages | 纯静态单文件，推 GitHub 即自动部署 |
| 云同步 | Cloudflare Worker + KV（`worker/`） | 同步码隔离数据，**无需登录任何账号**，多设备填同一个码即同步 |
| 兜底 | localStorage | 未配置同步或断网时自动降级本地，不丢数据 |

已不再依赖 WorkBuddy 资料库（原方案需要登录态，部署到自有域名后不可用）。

## 核心机制

主区域只展示当前选中的**唯一任务**，其余任务全部折叠进任务池。软提醒模式——想切换随时可以，但视觉和交互始终把你拉回「只盯这一个」。

## 功能模块

| 模块 | 说明 |
|---|---|
| 今天要处理（置顶） | 自动聚合逾期 / 今天到期 / 今日标记的任务。逾期红色标注 + 显示逾期天数，一键「专注」或「完成」。昨天没做完的自动滚到今天，不会消失 |
| 当前专注（主区） | 唯一任务卡片 + 番茄钟（15/25/45 分钟）+ 今日进展记录 |
| 任务池（双维度筛选） | 第一维「场景」：投放执行 / 数据分析诊断 / 周报汇报 / 对外沟通 / 个人项目<br>第二维「业务线」：**Readdy-GG / Readdy-其他 / 个人项目** |
| 本周概览 | 完成数 / 专注分钟 / 待办剩余 / 逾期项 四个指标卡 + 场景专注时长分布 |
| 专注热力图 | 近 15 周专注分钟热力图（4 档色阶），悬停看每周数值，下方汇总活跃周数与本周环比 |
| WoW 环比 | 按业务线录入周费用 / Leads，自动算 CPL 和三项环比（红涨绿跌）。自动预警：费用涨超 15% 但 Leads 未同步增长、Leads 归零 |
| 项目进度（阶段目标管理） | 项目 = 名称 + 有序阶段清单 + 当前阶段 + 目标日期 + **可验收成功标准**。卡片显示阶段 N/M、完成度、任务 x/y、DDL 倒计时（逾期标红）。点阶段胶囊推进下一阶段，走到最后一段自动放烟花 |
| 周报导出 | 一键生成结构化周报（整体判断 / 已完成 / 进行中 / 时间投入 / 业务线 WoW / 项目阶段进展 / 下一步计划） |

## 视觉与反馈

- 主题色樱花粉 `#ec4899`（`--pri`），改这一个变量即可全局换色
- 单击任意位置落 3 片樱花；完成一个任务放烟花（主束放大 1.6 倍 + 外扩光环强化视觉重心，两侧副束错峰）
- `CELEB` 常量可切 `firework` / `bloom` / `mixed` 三种庆祝效果；`fx-demo.html` 是本地对比预览，不部署
- 并发上限 80、`animationend` 自动清理 DOM、`prefers-reduced-motion` 下全部特效关闭

## 云同步说明

- 页面右上角「同步」按钮 → 填**同步码**（自定义，建议 8 位以上）+ **API 地址**（Worker 的 https 地址，同源部署可留空）
- 多设备填同一个同步码即同步；同步码经 SHA-256 后作为 KV key，不明文落盘
- 同步策略：**全量快照覆盖**，以 `updatedAt` 时间戳判定新旧，落后快照不会覆盖本地
- 写入做 500ms 防抖合并，避免频繁改动打爆请求

## 数据结构

一份 JSON 快照，字段如下：

```
{
  updatedAt, curId,
  tasks:    [{ _id, 任务, 场景, 状态, 优先级, 截止日期, 今日处理, 业务线, 项目, 备注 }],
  projects: [{ _id, 名称, 阶段: [阶段名...], 当前阶段, 目标日期, 成功标准 }],
  focus:    [{ _id, 日期, 任务, 场景, 专注分钟, 备注 }],
  wow:      [{ _id, 业务线, 周起始日, 费用, Leads }],
  notes:    [{ id, n, a }]
}
```

任务的 `项目` 字段存项目名（字符串），与 `projects[].名称` 对应；留空表示不属于任何项目。

场景：投放执行 / 数据分析诊断 / 周报汇报 / 对外沟通 / 个人项目
业务线：Readdy-GG / Readdy-其他 / 个人项目

## 部署

### 1. Cloudflare Pages（前端）

Workers & Pages → Create → Pages → Connect to Git → 选 `Mireia9868/flow-us`

- Framework preset：**None**
- Build command：**留空**
- Output directory：**`/`**

Save and Deploy 后，到 Custom domains 绑定 `flow-us.com`。域名 DNS 现在在 Wix，CF 会提示把 NS 改到 Cloudflare，按提示去 Wix 域名后台改即可（改完等 10 分钟生效，HTTPS 证书自动签发）。

`_redirects` 已配置：根路径 `/` 直接返回工作台，地址栏不变。

### 2. Cloudflare Worker（同步后端）

```bash
cd worker
npx wrangler login                        # 浏览器授权
npx wrangler kv:namespace create FOCUS_KV # 复制返回的 id
# 把 id 填进 wrangler.toml 的 REPLACE_WITH_KV_NAMESPACE_ID
npx wrangler deploy                       # 记下输出的地址 https://flow-us-sync.<xxx>.workers.dev
```

### 3. 连起来

打开 https://flow-us.com → 点右上角「同步」→ 填同步码 + Worker 地址 → 保存并同步。

## 技术要点

- 单文件 HTML，CSS/JS 全内联，**零外部依赖**（无 CDN / 框架 / 图表库）
- 图标与图表全部手写内联 SVG
- 渲染层单向调用链：`renderToday / renderFocus / renderLines / renderPool / renderStats / renderHeat / renderWow / renderPm` 互不调用，统一由 `refreshAll()` 调度
- 写入统一走 `commit()`：改内存 → 落 localStorage → 防抖推云端

## 本地使用

直接双击 `focus-desk.html` 用浏览器打开即可（未配置同步时自动走本地模式）。

## 注意事项

- 同步码是数据隔离的钥匙，**不是加密**。别用 `123456` 这类简单码，也别分享给别人
- 数据明文存在你自己的 Cloudflare KV 里，不要写入客户名单、合同金额等敏感信息
- 全量覆盖同步：单人使用没问题；多人同时编辑同一同步码会互相覆盖
- 仓库里示例任务的费用 / Leads 是虚构数字，实际使用请替换
