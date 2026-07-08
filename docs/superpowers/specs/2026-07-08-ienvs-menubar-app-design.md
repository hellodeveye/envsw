# iEnvs 菜单栏 App 设计文档

日期：2026-07-08
状态：已确认（用户认可）

## 背景与目标

envsw 是一个 bash CLI：以 `~/.envsw/<group>/<profile>.env` 文件 + 每组一个 `current` 软链接管理环境变量配置组，配合 shell 启动钩子让新进程自动加载激活的配置（"环境变量版 iHosts"）。

本项目为其构建 macOS 原生菜单栏 App（暂定名 **iEnvs**），提供与 [iHosts](https://github.com/toolinbox/iHosts) 同构的交互：菜单栏点选即切换配置。GUI 是 `~/.envsw` 的"遥控器"，不引入自己的数据格式，与 CLI 完全互通。

**评估结论（前置）：** 可行且比 iHosts 更容易 —— 所有文件在用户主目录，无需特权/提权；状态层（文件 + 软链接）已由 CLI 定义好。固有限制与 CLI 相同：环境变量在进程启动时继承，切换只影响**新**进程，GUI 需在 UI 中显式说明。

## 技术选型

- SwiftUI 原生 App，macOS 13+，入口为 `MenuBarExtra`，无 Dock 图标（LSUIElement）。
- 代码放在本 repo 的 `app/` 子目录，与 CLI 同仓维护。
- 分发：MVP 阶段本地构建；签名公证 + GitHub Release / Homebrew Cask 属二期。

## 架构原则

**文件系统是唯一数据源。** App 的一切读写落在 `~/.envsw`（尊重 `ENVSW_ROOT` 环境变量，默认 `~/.envsw`）。不建数据库、不做缓存持久化；CLI 与 GUI 通过文件系统天然保持一致。

## 模块划分

### 1. ProfileStore（纯逻辑层，无 UI 依赖）

- 数据读取：扫描根目录得到分组列表、每组的配置列表、`current` 软链接指向的激活配置。
- 操作：`use(group, profile)`（`ln -sfn` 语义重指软链接）、`off(group)`（删软链接）、`createGroup` / `createProfile` / `deleteProfile` / `deleteGroup`、`read` / `write` 配置文件内容。
- 权限：创建目录 `700`、文件 `600`，与 CLI 一致。
- danger 判断与 CLI 完全一致：配置名为 `prod` / `production` / `online` / `live` 视为危险。
- 根目录可注入（构造参数），用于单元测试。

### 2. DirectoryWatcher

- FSEvents 监听根目录（含子目录），事件去抖（~300ms）后通知 ProfileStore 重载。
- 覆盖场景：CLI 执行 `use`/`off`/`edit`、用户手动改文件，菜单状态自动刷新。

### 3. MenuBarView（菜单栏 UI）

- 菜单栏图标：常态为模板图标；**任一分组激活了 danger 配置时图标变红**。
- 下拉菜单结构：
  - 每个分组为一节：分组名（节标题）→ 配置项列表，● 标记激活项，danger 配置名显示红色；每组末尾附"关闭（off）"项（仅激活时可用）。
  - 分组内含"新建配置…"，节末含"编辑…"入口（打开 EditorWindow）。
  - 底部：新建分组… / 设置… / 退出。
- 空状态（无根目录或无分组）：显示引导文案 + "新建分组"入口。

### 4. EditorWindow（内置编辑窗口）

- 等宽字体纯文本编辑器 + 保存按钮，编辑 `.env` 原文（KEY=VALUE 行）。
- 新建配置时预填注释模板（同 CLI `edit`：`# <group> / <profile> — KEY=VALUE per line, no "export"`）。
- 保存时保持 `600` 权限。
- 二期方向：结构化 KEY/VALUE 表格编辑 + 值脱敏显示。

## 首次启动引导与设置

- 首次启动检测 shell 钩子是否已安装：检查 `~/.zshenv`（zsh）/ `~/.bashrc`（bash）中是否含 envsw 钩子标记。
- 未安装时弹窗说明原理（无钩子则切换不生效）并提供"一键安装"：追加与 `install.sh` 相同的钩子片段；写入前提示会修改哪个文件。
- 设置面板：
  - 开机自启（`SMAppService.mainApp`）。
  - 重新检测/安装钩子。

## 关键交互细节

- 切换到 danger 配置时发系统通知："⚠ prod 已激活，仅对新进程生效"。
- 所有切换操作后以菜单副标题/通知提示"新终端/进程生效"——把 Unix 固有限制显式讲出来，避免用户以为"切了没生效"是 bug。

## 错误处理

- 坏软链接（指向不存在的文件）：视为该组"未激活"，不崩溃。
- 文件读写失败：NSAlert 报错并保留原文件内容。
- 删除分组/配置为破坏性操作，需确认弹窗；删除当前激活配置时同时移除 `current` 软链接。

## 测试策略

- ProfileStore 单元测试：注入临时目录，覆盖 use / off / 创建删除 / 权限位 / 坏软链接 / danger 判断。
- DirectoryWatcher：临时目录内改文件断言回调触发。
- UI（菜单、编辑窗、引导）：手动验收清单。

## MVP 范围（已确认）

列表 / 切换 / 关闭 / 内置编辑 / prod 高亮（含图标变红）/ 新建·删除分组与配置 / 首次启动钩子检测与一键安装 / 开机自启 / FSEvents 实时同步 CLI 操作。

明确不做（二期）：结构化表格编辑、签名公证与分发渠道、App 内更新、跨平台。
