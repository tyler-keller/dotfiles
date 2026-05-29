#!/usr/bin/env bash
input=$(cat)

# ANSI colors
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
RESET=$'\033[0m'

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
used_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_tokens=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
repo=$(echo "$input" | jq -r '.workspace.repo | if . then .owner + "/" + .name else empty end')

fmt_tokens() {
  local val=$1
  if ! [[ "$val" =~ ^[0-9]+$ ]]; then
    printf "?"
    return
  fi
  if [ "$val" -ge 1000 ]; then
    awk -v v="$val" 'BEGIN { printf "%.1fK", v / 1000 }'
  else
    printf "%d" "$val"
  fi
}

# Returns "Xh Ym" or "Xm" remaining given a resets_at value (epoch ms or ISO string)
fmt_time_remaining() {
  local raw=$1
  local reset_epoch
  # Try epoch milliseconds (13 digits)
  if [[ "$raw" =~ ^[0-9]{13}$ ]]; then
    reset_epoch=$(( raw / 1000 ))
  # Try epoch seconds (10 digits)
  elif [[ "$raw" =~ ^[0-9]{10}$ ]]; then
    reset_epoch=$raw
  # Try ISO 8601
  elif [[ "$raw" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
    reset_epoch=$(date -d "$raw" +%s 2>/dev/null)
  fi

  if [ -z "$reset_epoch" ]; then return; fi

  local now
  now=$(date +%s)
  local diff=$(( reset_epoch - now ))
  if [ "$diff" -le 0 ]; then
    printf "resetting"
    return
  fi
  local hrs=$(( diff / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))
  if [ "$hrs" -gt 0 ]; then
    printf "%dh %dm" "$hrs" "$mins"
  else
    printf "%dm" "$mins"
  fi
}

parts=()

# Model name
parts+=("$model")

# Context window usage with color
if [ -n "$used_pct" ]; then
  pct_int=$(printf "%.0f" "$used_pct")
  used_fmt=$(fmt_tokens "$used_tokens")
  total_fmt=$(fmt_tokens "$total_tokens")
  if [ "$pct_int" -lt 20 ]; then
    color="$GREEN"
  elif [ "$pct_int" -lt 40 ]; then
    color="$YELLOW"
  else
    color="$RED"
  fi
  parts+=("ctx: ${color}${used_fmt}/${total_fmt} (${pct_int}%)${RESET}")
fi

# Git branch
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    if [ -n "$repo" ]; then
      parts+=("$repo:$branch")
    else
      parts+=("$branch")
    fi
  fi
fi

# Rate limits (5-hour session)
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
if [ -n "$five_pct" ]; then
  five_int=$(printf "%.0f" "$five_pct")
  five_str="5h: ${five_int}%"

  # Try common field names for reset time
  resets_raw=$(echo "$input" | jq -r '
    .rate_limits.five_hour.resets_at //
    .rate_limits.five_hour.reset_at //
    .rate_limits.five_hour.reset_time //
    .rate_limits.five_hour.resetsAt //
    empty')
  if [ -n "$resets_raw" ]; then
    time_left=$(fmt_time_remaining "$resets_raw")
    if [ -n "$time_left" ]; then
      five_str="${five_str} (${time_left})"
    fi
  fi

  parts+=("$five_str")
fi

# Join parts with separator
output=""
for part in "${parts[@]}"; do
  if [ -z "$output" ]; then
    output="$part"
  else
    output="$output | $part"
  fi
done

printf "%s" "$output"
