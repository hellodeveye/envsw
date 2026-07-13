# envsw

**Global environment-variable profile switcher — think "iHosts, but for env vars".**

[中文文档](README.zh-CN.md)

Switch a whole group of environment variables (dev / staging / prod database credentials, API keys, …) with one command, globally. Your scripts and tools stay completely unaware — they just read env vars as usual. No per-command prefix, no per-directory setup.

```console
$ envsw use myapp prod
myapp → prod (new shells/processes pick it up; open interactive shells refresh before the next command)
⚠ production profile active — every new command now targets prod; switch back with envsw use myapp dev

$ envsw list
myapp
  ○ dev
  ● prod (active)
```

## Why

Existing tools solve a different shape of this problem:

- **direnv / shadowenv** switch env by *directory*, not by *environment*, and rely on interactive-shell hooks (they often don't fire in non-interactive shells, e.g. commands run by editors or AI agents).
- **envchain / dotenvx / dotenv-cli** require a *prefix on every command* (`dotenvx run -f .env.prod -- cmd`).

`envsw` takes the [iHosts](https://github.com/toolinbox/iHosts) approach instead: a global state file (a `current` symlink per group) plus a tiny shell hook. Flip the switch once; every **new** shell and process picks it up automatically, and already-open interactive zsh/bash shells refresh before the next command.

## Install

One-line install:

```bash
curl -fsSL https://raw.githubusercontent.com/postdare/envsw/main/install.sh | bash
```

Or install from a local clone:

```bash
git clone https://github.com/postdare/envsw.git
cd envsw && ./install.sh
```

The installer copies `envsw` to `~/.local/bin` and appends or upgrades the auto-load hook in `~/.zshenv` (zsh) or `~/.bashrc` (bash). Or install the binary manually:

```bash
install -m 755 envsw ~/.local/bin/envsw
```

The canonical hook snippet lives in [`install.sh`](install.sh); it loads active profiles at shell startup and refreshes interactive shells before each command.

## Usage

```bash
envsw edit myapp dev      # create/edit a profile in $EDITOR (KEY=VALUE lines)
envsw edit myapp prod
envsw use  myapp dev      # activate
envsw list                # groups & profiles, ● marks active
envsw show [myapp]        # active profile contents, values masked
envsw off  myapp          # deactivate a group
```

Profiles are plain `KEY=VALUE` files in `~/.envsw/<group>/<profile>.env` (created with `600` permissions):

```
# myapp / dev
MYAPP_ENV=dev
MYAPP_DB_URL=mysql://user:pass@dev-host:3306/mydb
```

## Safety touches

- Profiles named `prod` / `production` / `online` / `live` are shown in **red**, and switching to one prints a warning reminding you to switch back.
- `envsw show` masks values after the first 4 characters.
- Profile files and directories are created with `600` / `700` permissions.
- Colors are tty-only and respect [`NO_COLOR`](https://no-color.org/); force with `ENVSW_COLOR=1`.

## How it works (and its one limitation)

Environment variables are inherited at process start — nothing can change them inside an already-running child process. `envsw use` just repoints a symlink (`~/.envsw/<group>/current`); the shell hook sources every group's `current` file, so each **new** shell/process gets the active profile. Already-open interactive zsh/bash terminals reload before the next command, but programs that are already running still need to be restarted.

Set `ENVSW_ROOT` to relocate the profile directory (default `~/.envsw`).

## Desktop app (iEnvs)

A native macOS menu bar companion lives in [`app/`](app/) — click to switch
profiles, red icon when a prod-like profile is active, built-in profile
editor, and it stays in sync with the CLI automatically.

**Download:** grab the latest `iEnvs-*.zip` from the
[Releases page](https://github.com/postdare/envsw/releases), unzip, and
drag `iEnvs.app` to `/Applications`. The build isn't notarized (no paid Apple
Developer account yet), so the first launch needs a Gatekeeper bypass:
right-click `iEnvs.app` → **Open** → **Open** in the confirmation dialog.

Or build it yourself:

```bash
app/scripts/make-app.sh && open app/build/iEnvs.app
```

Requires macOS 13+ and Xcode command line tools to build.

## License

[MIT](LICENSE)
