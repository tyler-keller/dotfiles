# Git worktree helpers: `wt new`, `wt rm`, `wt ls`.
# Worktrees live at <repo-root>/worktrees/<name>. The `worktrees/` dir is
# expected to be in your global gitignore (~/.config/git/ignore).

_wt_main_root() {
  # Resolve the main worktree root, even when invoked from inside a linked worktree.
  git worktree list --porcelain 2>/dev/null | awk '/^worktree / {print $2; exit}'
}

_wt_default_branch() {
  local ref
  ref=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null) || return 1
  print -- "${ref#refs/remotes/origin/}"
}

_wt_in_repo() {
  git rev-parse --git-dir >/dev/null 2>&1
}

wt() {
  local sub=$1
  shift 2>/dev/null
  case $sub in
    new) _wt_new "$@" ;;
    rm)  _wt_rm  "$@" ;;
    ls)  _wt_ls  "$@" ;;
    ""|-h|--help|help)
      cat <<'EOF'
wt — git worktree helpers (operate on the repo containing cwd)

  wt new <name> [base]   Create worktree at <repo>/worktrees/<name> on a new
                         branch <name>. Base defaults to origin/<default-branch>
                         (auto-fetched). cd's into the new worktree.

  wt new -t|--track <branch>
                         Check out an EXISTING upstream branch into a worktree
                         at <repo>/worktrees/<branch>. Fetches origin first.
                         If the local branch is absent it's created tracking
                         origin/<branch>. Tab-completes remote branches.

  wt rm [<name>] [--force]
                         Remove a worktree and its local branch. Without <name>,
                         operates on cwd's worktree. Safety checks (dirty tree,
                         unpushed commits) abort unless --force. Unmerged
                         branches require typing a capital Y to confirm.

  wt ls                  List worktrees with branch, dirty/clean state, and path.
EOF
      ;;
    *)
      print -u2 "wt: unknown subcommand '$sub' (try: wt help)"
      return 2
      ;;
  esac
}

_wt_new() {
  if ! _wt_in_repo; then
    print -u2 "wt new: not inside a git repository"
    return 1
  fi

  local track=0
  local -a positional
  local arg
  while (( $# )); do
    case $1 in
      -t|--track) track=1; shift ;;
      -h|--help)
        print -- "usage: wt new <name> [base]"
        print -- "       wt new -t|--track <branch>"
        return 0
        ;;
      --) shift; positional+=("$@"); break ;;
      -*) print -u2 "wt new: unknown flag '$1'"; return 2 ;;
      *)  positional+=("$1"); shift ;;
    esac
  done

  local main_root
  main_root=$(_wt_main_root) || { print -u2 "wt new: cannot resolve repo root"; return 1; }

  if (( track )); then
    _wt_new_track "$main_root" "${positional[@]}"
    return $?
  fi

  local name=${positional[1]}
  local base=${positional[2]}
  if [[ -z $name ]]; then
    print -u2 "wt new: missing <name>"
    print -u2 "usage: wt new <name> [base]"
    print -u2 "       wt new -t|--track <branch>"
    return 2
  fi

  if [[ -z $base ]]; then
    local default
    default=$(_wt_default_branch) || {
      print -u2 "wt new: cannot detect default branch (origin/HEAD not set?)"
      print -u2 "        try: git remote set-head origin --auto"
      return 1
    }
    base="origin/$default"
  fi

  print -- "wt new: fetching origin..."
  if ! git -C "$main_root" fetch origin --quiet; then
    print -u2 "wt new: fetch failed"
    return 1
  fi

  if git -C "$main_root" show-ref --verify --quiet "refs/heads/$name"; then
    print -u2 "wt new: branch '$name' already exists locally"
    return 1
  fi
  if git -C "$main_root" show-ref --verify --quiet "refs/remotes/origin/$name"; then
    print -u2 "wt new: branch '$name' already exists on origin"
    return 1
  fi

  local wt_path="$main_root/worktrees/$name"
  if [[ -e $wt_path ]]; then
    print -u2 "wt new: path already exists: $wt_path"
    return 1
  fi

  if ! git -C "$main_root" worktree add "$wt_path" -b "$name" "$base"; then
    print -u2 "wt new: git worktree add failed"
    return 1
  fi

  cd "$wt_path" || return 1
  print -- "wt new: created $wt_path on branch '$name' from $base"
}

_wt_new_track() {
  local main_root=$1
  local branch=$2
  if [[ -z $branch ]]; then
    print -u2 "wt new: --track requires a branch name"
    print -u2 "usage: wt new -t|--track <branch>"
    return 2
  fi

  print -- "wt new: fetching origin..."
  if ! git -C "$main_root" fetch origin --quiet; then
    print -u2 "wt new: fetch failed"
    return 1
  fi

  if ! git -C "$main_root" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    print -u2 "wt new: origin/$branch does not exist"
    return 1
  fi

  local wt_path="$main_root/worktrees/$branch"
  if [[ -e $wt_path ]]; then
    print -u2 "wt new: path already exists: $wt_path"
    return 1
  fi

  # If the local branch is already checked out somewhere, git will refuse the add.
  local existing_wt
  existing_wt=$(git -C "$main_root" worktree list --porcelain | awk -v b="refs/heads/$branch" '
    /^worktree / { path=$2 }
    $1=="branch" && $2==b { print path; exit }
  ')
  if [[ -n $existing_wt ]]; then
    print -u2 "wt new: branch '$branch' is already checked out at $existing_wt"
    return 1
  fi

  local -a add_args
  if git -C "$main_root" show-ref --verify --quiet "refs/heads/$branch"; then
    # Local branch exists — just check it out into the new worktree.
    add_args=("$wt_path" "$branch")
  else
    # No local branch — create one tracking origin/<branch>.
    add_args=(--track -b "$branch" "$wt_path" "origin/$branch")
  fi

  if ! git -C "$main_root" worktree add "${add_args[@]}"; then
    print -u2 "wt new: git worktree add failed"
    return 1
  fi

  cd "$wt_path" || return 1
  print -- "wt new: tracking '$branch' at $wt_path"
}

_wt_rm() {
  if ! _wt_in_repo; then
    print -u2 "wt rm: not inside a git repository"
    return 1
  fi

  local name=""
  local force=0
  local arg
  for arg in "$@"; do
    case $arg in
      --force|-f) force=1 ;;
      -*) print -u2 "wt rm: unknown flag '$arg'"; return 2 ;;
      *)
        if [[ -n $name ]]; then
          print -u2 "wt rm: extra argument '$arg'"
          return 2
        fi
        name=$arg
        ;;
    esac
  done

  local main_root
  main_root=$(_wt_main_root) || { print -u2 "wt rm: cannot resolve repo root"; return 1; }

  local wt_path
  if [[ -z $name ]]; then
    # Derive from cwd: walk up to the worktree root.
    local cur_root
    cur_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
      print -u2 "wt rm: cannot resolve current worktree"; return 1; }
    if [[ $cur_root == $main_root ]]; then
      print -u2 "wt rm: cwd is the main worktree; refuse to remove it"
      print -u2 "       pass a name: wt rm <name>"
      return 1
    fi
    wt_path=$cur_root
    name=${wt_path:t}
  else
    wt_path="$main_root/worktrees/$name"
  fi

  # Confirm it's a registered worktree.
  if ! git -C "$main_root" worktree list --porcelain | awk -v p="$wt_path" '
        /^worktree / { if ($2 == p) found=1 }
        END { exit !found }'; then
    print -u2 "wt rm: not a registered worktree: $wt_path"
    return 1
  fi

  # Resolve the branch attached to this worktree (porcelain block parsing).
  local branch
  branch=$(git -C "$main_root" worktree list --porcelain | awk -v p="$wt_path" '
    /^worktree / { in_block = ($2 == p) }
    in_block && /^branch / { sub("refs/heads/", "", $2); print $2; exit }
  ')
  if [[ -z $branch ]]; then
    print -u2 "wt rm: could not determine branch for $wt_path (detached?)"
    return 1
  fi

  if (( ! force )); then
    if [[ -n $(git -C "$wt_path" status --porcelain) ]]; then
      print -u2 "wt rm: worktree has uncommitted changes; commit/stash or pass --force"
      return 1
    fi

    # Unpushed = commits on $branch not reachable from ANY origin/* ref.
    # Handles the case where origin/$branch doesn't exist yet (fresh branch).
    local unpushed
    unpushed=$(git -C "$wt_path" rev-list "$branch" --not --remotes=origin 2>/dev/null)
    if [[ -n $unpushed ]]; then
      print -u2 "wt rm: branch '$branch' has unpushed commits; push or pass --force"
      return 1
    fi

    local default
    default=$(_wt_default_branch)
    if [[ -n $default ]]; then
      local unmerged
      unmerged=$(git -C "$wt_path" rev-list "$branch" "^origin/$default" 2>/dev/null)
      if [[ -n $unmerged ]]; then
        print -- "wt rm: branch '$branch' has commits not merged to origin/$default."
        printf "Remove anyway? [y/Y to confirm, anything else aborts]: "
        local reply
        read -r reply
        if [[ $reply != Y ]]; then
          print -- "wt rm: aborted"
          return 1
        fi
      fi
    fi
  fi

  # If cwd is inside the worktree, cd out before removing.
  local cwd_real wt_real
  cwd_real=${PWD:A}
  wt_real=${wt_path:A}
  if [[ $cwd_real == $wt_real* ]]; then
    cd "$main_root" || return 1
  fi

  local remove_args=("$wt_path")
  (( force )) && remove_args=(--force "$wt_path")
  if ! git -C "$main_root" worktree remove "${remove_args[@]}"; then
    print -u2 "wt rm: git worktree remove failed"
    return 1
  fi
  if ! git -C "$main_root" branch -D "$branch" >/dev/null; then
    print -u2 "wt rm: removed worktree but failed to delete local branch '$branch'"
    return 1
  fi
  print -- "wt rm: removed worktree and local branch '$branch'"
}

_wt_ls() {
  if ! _wt_in_repo; then
    print -u2 "wt ls: not inside a git repository"
    return 1
  fi

  local main_root
  main_root=$(_wt_main_root) || return 1

  # Build rows: branch \t state \t path
  local rows=()
  rows+=("BRANCH"$'\t'"STATE"$'\t'"PATH")

  local wt_path branch state
  local block_path="" block_branch=""
  while IFS= read -r line; do
    if [[ -z $line ]]; then
      [[ -n $block_path ]] && _wt_ls_row "$block_path" "$block_branch" rows
      block_path=""; block_branch=""
      continue
    fi
    case $line in
      "worktree "*) block_path=${line#worktree } ;;
      "branch "*)   block_branch=${${line#branch }#refs/heads/} ;;
      "detached")   block_branch="(detached)" ;;
    esac
  done < <(git -C "$main_root" worktree list --porcelain; printf '\n')

  printf '%s\n' "${rows[@]}" | column -t -s $'\t'
}

_wt_ls_row() {
  local path=$1 branch=$2
  local state="clean"
  [[ -z $branch ]] && branch="(unknown)"
  if [[ -n $(git -C "$path" status --porcelain 2>/dev/null) ]]; then
    state="dirty"
  fi
  # zsh: append to array passed by name
  local -a __rows
  __rows=(${(P)3})
  __rows+=("$branch"$'\t'"$state"$'\t'"$path")
  : ${(PA)3::=${__rows[@]}}
}

# --- zsh completion -----------------------------------------------------------

_wt_remote_branches() {
  _wt_in_repo || return 1
  local -a branches
  branches=(${(f)"$(git for-each-ref --format='%(refname)' refs/remotes/origin/ 2>/dev/null \
                     | grep -v '^refs/remotes/origin/HEAD$' \
                     | sed 's|^refs/remotes/origin/||')"})
  _describe -t remote-branches 'remote branch' branches
}

_wt_local_worktree_names() {
  _wt_in_repo || return 1
  local main_root
  main_root=$(_wt_main_root) || return 1
  local prefix="$main_root/worktrees/"
  local -a names
  names=(${(f)"$(git -C "$main_root" worktree list --porcelain \
                  | awk -v p="$prefix" '/^worktree / && index($2,p)==1 { sub(p,"",$2); print $2 }')"})
  _describe -t worktrees 'worktree' names
}

_wt() {
  local curcontext=$curcontext state line ret=1
  local -a subcommands
  subcommands=(
    'new:create a new worktree'
    'rm:remove a worktree'
    'ls:list worktrees'
    'help:show help'
  )

  _arguments -C \
    '1: :->subcommand' \
    '*:: :->args' && ret=0

  case $state in
    subcommand)
      _describe -t subcommands 'wt subcommand' subcommands && ret=0
      ;;
    args)
      case $line[1] in
        new)
          _arguments \
            '(-t --track)'{-t,--track}'[track an existing upstream branch]:remote branch:_wt_remote_branches' \
            '(-h --help)'{-h,--help}'[show help]' \
            '1:name' \
            '2:base' && ret=0
          ;;
        rm)
          _arguments \
            '(-f --force)'{-f,--force}'[force removal]' \
            '*:worktree:_wt_local_worktree_names' && ret=0
          ;;
      esac
      ;;
  esac

  return ret
}

compdef _wt wt
