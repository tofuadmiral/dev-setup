#!/usr/bin/env bash
# Claude Code status line script

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // empty')
output_tokens=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // empty')
worktree_name=$(echo "$input" | jq -r '.worktree.name // ""')

# Shorten home directory
cwd="${cwd/#$HOME/~}"

# Git branch (skip optional locks)
git_branch=""
if [ -n "$cwd" ]; then
  expanded_cwd="${cwd/#\~/$HOME}"
  git_branch=$(git -C "$expanded_cwd" --no-optional-locks branch --show-current 2>/dev/null)
fi

# Build segments
segments=()

# Directory
if [ -n "$cwd" ]; then
  segments+=("$(printf '\033[34m%s\033[0m' "$cwd")")
fi

# Git branch
if [ -n "$git_branch" ]; then
  segments+=("$(printf '\033[33m\xef\x9c\xa9 %s\033[0m' "$git_branch")")
fi

# Git worktree name (only shown when inside a worktree)
if [ -n "$worktree_name" ]; then
  segments+=("$(printf '\033[33mworktree:%s\033[0m' "$worktree_name")")
fi

# Model
if [ -n "$model" ]; then
  segments+=("$(printf '\033[36m%s\033[0m' "$model")")
fi

# Tokens
if [ -n "$input_tokens" ] && [ -n "$output_tokens" ]; then
  total_tokens=$((input_tokens + output_tokens))
  if [ "$total_tokens" -ge 1000 ]; then
    token_str=$(printf "%.1fk" "$(echo "scale=1; $total_tokens / 1000" | bc)")
  else
    token_str="${total_tokens}"
  fi
  segments+=("$(printf '\033[35mtokens:%s\033[0m' "$token_str")")
fi

# Context window usage
if [ -n "$used_pct" ]; then
  pct_int=$(printf "%.0f" "$used_pct")
  if [ "$pct_int" -ge 80 ]; then
    color='\033[31m'
  elif [ "$pct_int" -ge 50 ]; then
    color='\033[33m'
  else
    color='\033[32m'
  fi
  segments+=("$(printf "${color}ctx:%s%%\033[0m" "$pct_int")")
fi

# Join with separator
result=""
for seg in "${segments[@]}"; do
  if [ -z "$result" ]; then
    result="$seg"
  else
    result="$result $(printf '\033[90m|\033[0m') $seg"
  fi
done

printf "%s" "$result"
