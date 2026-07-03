#!/usr/bin/env bash
# envsw installer: copies the script to ~/.local/bin and adds the
# auto-load hook to your shell startup file (zsh: ~/.zshenv, bash: ~/.bashrc).
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
SRC="$(cd "$(dirname "$0")" && pwd)/envsw"
MARKER="# envsw: auto-load the active env profile"

mkdir -p "$BIN_DIR"
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
