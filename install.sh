#!/usr/bin/env bash
# envsw installer: copies the script to ~/.local/bin and adds the
# auto-load hook to your shell startup file (zsh: ~/.zshenv, bash: ~/.bashrc).
set -euo pipefail

BIN_DIR="${ENVSW_BIN_DIR:-$HOME/.local/bin}"
RAW_BASE="${ENVSW_RAW_BASE:-https://raw.githubusercontent.com/hellodeveye/envsw/main}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd 2>/dev/null || pwd)"
LOCAL_SRC="$SCRIPT_DIR/envsw"
MARKER="# envsw: auto-load the active env profile"

mkdir -p "$BIN_DIR"
if [ -f "$LOCAL_SRC" ]; then
  SRC="$LOCAL_SRC"
else
  TMP_SRC="$(mktemp)"
  trap 'rm -f "$TMP_SRC"' EXIT
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$RAW_BASE/envsw" -o "$TMP_SRC"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$TMP_SRC" "$RAW_BASE/envsw"
  else
    echo "error: curl or wget is required for one-line install" >&2
    exit 1
  fi
  SRC="$TMP_SRC"
fi

install -m 755 "$SRC" "$BIN_DIR/envsw"
echo "installed: $BIN_DIR/envsw"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "note: $BIN_DIR is not in your PATH — add it to your shell profile" ;;
esac

shell_name="$(basename "${SHELL:-/bin/zsh}")"
if [ "$shell_name" = "zsh" ]; then
  rc="$HOME/.zshenv"
  hook="$MARKER of each group
for _envsw_f in \"\$HOME\"/.envsw/*/current(N); do
  set -a; source \"\$_envsw_f\"; set +a
done
unset _envsw_f"
else
  rc="$HOME/.bashrc"
  hook="$MARKER of each group
for _envsw_f in \"\$HOME\"/.envsw/*/current; do
  [ -f \"\$_envsw_f\" ] && { set -a; . \"\$_envsw_f\"; set +a; }
done
unset _envsw_f"
fi

if [ -f "$rc" ] && grep -qF "$MARKER" "$rc"; then
  echo "hook already present in $rc"
else
  printf '\n%s\n' "$hook" >> "$rc"
  echo "hook added to $rc"
fi

echo "done — open a new shell, then: envsw edit <group> <profile>"
