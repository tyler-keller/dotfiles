#!/usr/bin/env bash
# Sync live jackbot dotfiles into this repo, and (optionally) pull Mac
# VS Code configs via a reverse SSH tunnel.
#
# Usage:  ./sync-dotfiles.sh
#
# Mac VS Code sync requires a reverse SSH tunnel from your Mac to jackbot.
# One-time setup on your Mac, in ~/.ssh/config under the Host jackbot block:
#
#     RemoteForward 2222 localhost:22
#
# and put jackbot's ~/.ssh/id_*.pub into your Mac's ~/.ssh/authorized_keys
# (and enable Remote Login in System Settings → Sharing). After that,
# every `ssh jackbot` opens port 2222 on jackbot back to the Mac.
#
# Env overrides: MAC_SSH_USER, MAC_SSH_HOST, MAC_SSH_PORT, MAC_VSCODE_DIR.

set -euo pipefail

JACKBOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$JACKBOT_DIR/.." && pwd)

JACKBOT_FILES=(
  ".zshrc"
  ".zshenv"
  ".gitconfig"
  ".zsh/worktree.zsh"
  ".config/git/ignore"
)

printf 'syncing jackbot dotfiles → %s\n' "$JACKBOT_DIR"
for rel in "${JACKBOT_FILES[@]}"; do
  src="$HOME/$rel"
  dest="$JACKBOT_DIR/$rel"
  if [[ ! -f $src ]]; then
    printf '  skip (missing): %s\n' "$rel"
    continue
  fi
  mkdir -p "$(dirname "$dest")"
  if cmp -s "$src" "$dest"; then
    printf '  ok:      %s\n' "$rel"
  else
    cp -p "$src" "$dest"
    printf '  updated: %s\n' "$rel"
  fi
done

MAC_SSH_USER=${MAC_SSH_USER:-${USER}}
MAC_SSH_HOST=${MAC_SSH_HOST:-localhost}
MAC_SSH_PORT=${MAC_SSH_PORT:-2222}
MAC_VSCODE_DIR=${MAC_VSCODE_DIR:-"Library/Application Support/Code/User"}
MAC_FILES=(settings.json keybindings.json)

printf '\nsyncing Mac VS Code configs ← %s@%s:%s\n' \
  "$MAC_SSH_USER" "$MAC_SSH_HOST" "$MAC_SSH_PORT"

if ! (exec 3<>"/dev/tcp/${MAC_SSH_HOST}/${MAC_SSH_PORT}") 2>/dev/null; then
  printf '  skip: no reverse tunnel listening on %s:%s\n' "$MAC_SSH_HOST" "$MAC_SSH_PORT"
  printf '        see header of this script for one-time Mac setup.\n'
else
  exec 3<&- 3>&- 2>/dev/null || true
  for f in "${MAC_FILES[@]}"; do
    if rsync -q -e "ssh -p $MAC_SSH_PORT -o BatchMode=yes -o StrictHostKeyChecking=accept-new" \
        "${MAC_SSH_USER}@${MAC_SSH_HOST}:${MAC_VSCODE_DIR}/${f}" \
        "${REPO_ROOT}/${f}"; then
      printf '  updated: %s\n' "$f"
    else
      printf '  fail:    %s (rsync exited non-zero)\n' "$f"
    fi
  done
fi

printf '\ndone. review: git -C %s status\n' "$REPO_ROOT"
