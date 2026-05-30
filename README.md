# dotfiles

Managed with [chezmoi](https://chezmoi.io). Supports five machine profiles:

| Profile | Machine |
|---------|---------|
| `mac` | Personal MacBook |
| `work-mac` | Work MacBook |
| `jackbot` | Home Linux server |
| `hetz` | Hetzner VPS |
| `linux-3090` | Linux GPU machine |

---

## Quickstart — new machine

### 1. Install chezmoi

**Mac:**
```sh
brew install chezmoi
```

**Linux:**
```sh
sh -c "$(curl -fsLS get.chezmoi.io)"
```

### 2. Initialize and apply

```sh
chezmoi init --apply https://github.com/tylerkeller/dotfiles
```

Chezmoi will prompt once: **Machine profile (mac/work-mac/jackbot/hetz/linux-3090)**. Pick the right one. The answer is stored and never asked again on this machine.

That's it. Your dotfiles are deployed.

---

## Quickstart — existing machine (this repo already cloned)

```sh
chezmoi init --apply --source ~/Code/dotfiles
```

Or if you've already run `chezmoi init` and just want to apply changes:

```sh
chezmoi apply
```

---

## Day-to-day workflow

| Task | Command |
|------|---------|
| Pull latest and apply | `chezmoi update` |
| Preview what would change | `chezmoi diff` |
| Edit a managed file | `chezmoi edit ~/.zshrc` |
| Add a new dotfile | `chezmoi add ~/.foo` |
| Re-run install scripts | delete state with `chezmoi state delete-bucket --bucket=scriptState` then `chezmoi apply` |

After editing files in the source directory (`~/Code/dotfiles`), commit and push as you would any git repo. On other machines, `chezmoi update` pulls and applies.

---

## Adding a new machine

1. Add a row to the profile table above
2. In `.chezmoi.toml.tmpl`, add a `is<Name>` boolean if you need machine-specific behavior
3. Update `.chezmoiignore` if the machine should skip certain files
4. Update any `.tmpl` files that branch on profile
5. Install chezmoi on the new machine and run `chezmoi init --apply`

---

## What's managed

| File | Target | Notes |
|------|--------|-------|
| `dot_zshrc.tmpl` | `~/.zshrc` | p10k on Mac, philips theme + GPG on Linux |
| `dot_gitconfig.tmpl` | `~/.gitconfig` | SSH signing on Mac, GPG key on Linux |
| `dot_zshenv` | `~/.zshenv` | Linux only — adds `~/.local/bin` to PATH |
| `dot_p10k.zsh` | `~/.p10k.zsh` | Mac only |
| `dot_vimrc` | `~/.vimrc` | All machines |
| `dot_zsh/worktree.zsh` | `~/.zsh/worktree.zsh` | Git worktree helpers (`wt new/rm/ls/cd`) |
| `dot_zsh/et.zsh` | `~/.zsh/et.zsh` | Personal Mac only — Eternal Terminal helpers |
| `dot_config/nvim/` | `~/.config/nvim/` | LazyVim — all machines |
| `dot_config/git/ignore` | `~/.config/git/ignore` | All machines |
| `dot_config/ghostty/config` | `~/.config/ghostty/config` | Mac only — Challenger Deep theme |
| `dot_config/zellij/` | `~/.config/zellij/` | Linux servers only |
| `dot_config/claude/statusline-command.sh` | `~/.config/claude/statusline-command.sh` | jackbot + linux-3090 |
| `dot_local/share/swiftbar/dexcom.2m.py` | `~/.local/share/swiftbar/dexcom.2m.py` | work-mac only |

**Not chezmoi-managed** (stored in repo for reference):
- `settings.json` / `keybindings.json` — VS Code; manually copy to `~/Library/Application Support/Code/User/`
- `chat-personalization-settings.txt` — Claude AI personalization

---

## Install scripts

`run_once_install-nvim.sh` and `run_once_install-et.sh` run automatically on `chezmoi apply` (once per machine). They're skipped on platforms where they don't apply (ET install is Linux-only, nvim install skipped on Mac since you likely use brew).

To re-run an install script after updating it, chezmoi detects the content change and re-runs automatically on next `chezmoi apply`.

---

## Changing your profile

If you set the wrong profile:
```sh
chezmoi state delete-bucket --bucket=persistentState
chezmoi init --apply
```
