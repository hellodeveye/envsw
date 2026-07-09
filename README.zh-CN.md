# envsw

**全局环境变量 profile 切换器 —— 「环境变量界的 iHosts」。**

[English](README.md)

一条命令全局切换一组环境变量（开发/测试/线上的数据库连接、API Key 等）。你的脚本和工具完全无感——照常读环境变量即可，不需要每条命令加前缀，也不依赖目录。

```console
$ envsw use myapp prod
myapp → prod (new shells/processes pick it up; open interactive shells refresh before the next command)
⚠ production profile active — every new command now targets prod; switch back with envsw use myapp dev

$ envsw list
myapp
  ○ dev
  ● prod (active)
```

## 为什么造这个轮子

现有工具解决的是另外两种形态的问题：

- **direnv / shadowenv**：按*目录*切换而不是按*环境*，且依赖交互式 shell 钩子（编辑器、AI Agent 等跑的非交互命令经常不生效）。
- **envchain / dotenvx / dotenv-cli**：每条命令都要加前缀（`dotenvx run -f .env.prod -- cmd`）。

`envsw` 采用 [iHosts](https://github.com/toolinbox/iHosts) 的思路：全局状态文件（每组一个 `current` 软链）+ shell 钩子。切换一次，之后所有**新开**的 shell 和进程自动生效；已经打开的交互式 zsh/bash 终端会在下一条命令执行前刷新。

## 安装

一键安装：

```bash
curl -fsSL https://raw.githubusercontent.com/hellodeveye/envsw/main/install.sh | bash
```

或者从本地 clone 安装：

```bash
git clone https://github.com/hellodeveye/envsw.git
cd envsw && ./install.sh
```

安装脚本会把 `envsw` 拷到 `~/.local/bin`，并把自动加载钩子追加或升级到 `~/.zshenv`（zsh）或 `~/.bashrc`（bash）。也可以手动安装二进制：

```bash
install -m 755 envsw ~/.local/bin/envsw
```

标准 hook 片段以 [`install.sh`](install.sh) 为准；它会在 shell 启动时加载 active profile，并让交互式终端在每条命令执行前刷新。

## 用法

```bash
envsw edit myapp dev      # 用 $EDITOR 创建/编辑 profile（KEY=VALUE 格式）
envsw edit myapp prod
envsw use  myapp dev      # 激活
envsw list                # 所有组和 profile，● 标记激活项
envsw show [myapp]        # 查看激活 profile 内容（值打码）
envsw off  myapp          # 停用某组
```

Profile 就是 `~/.envsw/<组>/<profile>.env` 的纯文本 `KEY=VALUE` 文件（自动设为 `600` 权限）：

```
# myapp / dev
MYAPP_ENV=dev
MYAPP_DB_URL=mysql://user:pass@dev-host:3306/mydb
```

## 安全细节

- 名为 `prod` / `production` / `online` / `live` 的 profile 显示为**红色**，切换过去会打印警告，提醒用完切回。
- `envsw show` 只显示每个值的前 4 个字符，其余打码。
- Profile 文件和目录以 `600` / `700` 权限创建。
- 颜色只在终端输出时启用，遵守 [`NO_COLOR`](https://no-color.org/) 约定；`ENVSW_COLOR=1` 可强制着色。

## 原理（以及唯一的限制）

环境变量在进程启动时继承，任何工具都改不到已经运行的子进程内部。`envsw use` 只是重指一个软链（`~/.envsw/<组>/current`）；shell 钩子会 source 每组的 `current` 文件，所以每个**新**进程都拿到激活的 profile。已经打开的交互式 zsh/bash 终端会在下一条命令执行前刷新，但已经运行中的程序仍然需要重启。

用 `ENVSW_ROOT` 环境变量可以改 profile 存放目录（默认 `~/.envsw`）。

## 桌面版（iEnvs）

[`app/`](app/) 目录内置 macOS 原生菜单栏 App：点选即切换配置，激活 prod 类
配置时图标变红，内置配置编辑器，并自动与 CLI 保持同步。

**下载：**去 [Releases 页面](https://github.com/hellodeveye/envsw/releases)
下载最新的 `iEnvs-*.zip`，解压后把 `iEnvs.app` 拖进 `/Applications`。目前还
没有付费 Apple Developer 账号做公证（notarize），所以首次打开需要绕过
Gatekeeper：右键 `iEnvs.app` → **打开** → 在确认弹窗里再点一次**打开**。

也可以自己构建：

```bash
app/scripts/make-app.sh && open app/build/iEnvs.app
```

构建需要 macOS 13+ 与 Xcode 命令行工具。

## 许可

[MIT](LICENSE)
