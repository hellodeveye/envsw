# envsw

**Global environment-variable profile switcher — think "iHosts, but for env vars".**

[中文文档](README.zh-CN.md)

Switch a whole group of environment variables (dev / staging / prod database credentials, API keys, …) with one command, globally. Your scripts and tools stay completely unaware — they just read env vars as usual. No per-command prefix, no per-directory setup.

```console
$ envsw use myapp prod
myapp → prod (new shells/processes will pick it up)
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

`envsw` takes the [iHosts](https://github.com/toolinbox/iHosts) approach instead: a global state file (a `current` symlink per group) plus a tiny shell-startup hook. Flip the switch once; every **new** shell and process picks it up automatically — including non-interactive ones.

## Install

One-line install:

```bash
curl -fsSL https://raw.githubusercontent.com/hellodeveye/envsw/main/install.sh | bash
```

Or install from a local clone:

```bash
git clone https://github.com/hellodeveye/envsw.git
cd envsw && ./install.sh
```

The installer copies `envsw` to `~/.local/bin` and appends the auto-load hook to `~/.zshenv` (zsh) or `~/.bashrc` (bash). Or do it manually:

```bash
install -m 755 envsw ~/.local/bin/envsw
```

then add to `~/.zshenv`:

```zsh
# envsw: auto-load the active env profile of each group
for _envsw_f in "$HOME"/.envsw/*/current(N); do
  set -a; source "$_envsw_f"; set +a
done
unset _envsw_f
```

(bash: use `for _envsw_f in "$HOME"/.envsw/*/current; do [ -f "$_envsw_f" ] && { set -a; . "$_envsw_f"; set +a; }; done` in `~/.bashrc`.)

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

Environment variables are inherited at process start — nothing can change them inside an already-running process. `envsw use` just repoints a symlink (`~/.envsw/<group>/current`); the shell-startup hook sources every group's `current` file, so each **new** shell/process gets the active profile. Terminals you already have open keep their old values until you open a new one — that's Unix, not a bug.

Set `ENVSW_ROOT` to relocate the profile directory (default `~/.envsw`).

## License

[MIT](LICENSE)
