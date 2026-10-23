#!/usr/bin/env bash
# Shared helpers for the game-dev-team hooks.
# Pure bash + coreutils so it works in Git Bash on Windows without jq/python.
# If jq is installed it is used for JSON parsing; otherwise a regex fallback.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
if command -v cygpath >/dev/null 2>&1; then
  PROJECT_DIR="$(cygpath -u "$PROJECT_DIR")"
fi
STATE_DIR="$PROJECT_DIR/.claude/.state"
mkdir -p "$STATE_DIR" 2>/dev/null

HOOK_INPUT=""
read_input() {
  HOOK_INPUT="$(cat)"
}

# json_get <key>  -> prints the value of the first "key": "string" (or bool/number)
# found anywhere in HOOK_INPUT, unescaped. Good enough for hook payload fields
# such as file_path, command, agent_type, agent_id, stop_hook_active.
json_get() {
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$HOOK_INPUT" | jq -r --arg k "$key" '
      [.. | objects | select(has($k)) | .[$k]] | first // empty
      | if type == "string" then . else tostring end' 2>/dev/null
    return
  fi
  local raw
  raw="$(printf '%s' "$HOOK_INPUT" | tr -d '\r' | tr '\n' ' ' |
    grep -oE "\"$key\"[[:space:]]*:[[:space:]]*(\"([^\"\\\\]|\\\\.)*\"|true|false|-?[0-9]+)" |
    head -n1 | sed -E "s/^\"$key\"[[:space:]]*:[[:space:]]*//")"
  if [[ "$raw" == \"*\" ]]; then
    raw="${raw:1:${#raw}-2}"
    raw="${raw//\\\\/$'\x01'}"
    raw="${raw//\\\"/\"}"
    raw="${raw//\\n/$'\n'}"
    raw="${raw//\\t/$'\t'}"
    raw="${raw//\\\//\/}"
    raw="${raw//$'\x01'/\\}"
  fi
  printf '%s' "$raw"
}

# json_escape <string> -> JSON string literal (with quotes)
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/}"
  s="${s//$'\n'/\\n}"
  printf '"%s"' "$s"
}

# to_unix_path <path> -> POSIX path (handles D:\foo on Git Bash)
to_unix_path() {
  local p="$1"
  if command -v cygpath >/dev/null 2>&1 && [[ "$p" =~ ^[A-Za-z]:[\\/] ]]; then
    cygpath -u "$p"
  else
    printf '%s' "${p//\\//}"
  fi
}

# rel_path <abs-or-rel path> -> path relative to project dir (forward slashes)
rel_path() {
  local p
  p="$(to_unix_path "$1")"
  local root_lc p_lc
  root_lc="$(printf '%s' "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]')"
  p_lc="$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')"
  if [[ "$p_lc" == "$root_lc/"* ]]; then
    printf '%s' "${p:${#PROJECT_DIR}+1}"
  else
    printf '%s' "${p#./}"
  fi
}

# deny_pretool <reason>  -> PreToolUse deny decision
deny_pretool() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$(json_escape "$1")"
  exit 0
}

# ask_pretool <reason>  -> PreToolUse ask the human
ask_pretool() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":%s}}\n' "$(json_escape "$1")"
  exit 0
}

# post_feedback <text> -> PostToolUse context shown to Claude next to the tool result
post_feedback() {
  printf '{"decision":"block","reason":%s}\n' "$(json_escape "$1")"
  exit 0
}

# find_godot -> prints the Godot 4 executable or nothing
find_godot() {
  if [[ -n "${GODOT_BIN:-}" ]]; then
    to_unix_path "$GODOT_BIN"
    return
  fi
  local c
  for c in godot4 godot Godot godot.windows.opt.tools.64; do
    if command -v "$c" >/dev/null 2>&1; then
      command -v "$c"
      return
    fi
  done
  # Common Windows install locations (Steam / Scoop / manual)
  local g
  for g in "/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe" \
           "$HOME"/scoop/apps/godot/current/godot.exe \
           /c/Program\ Files/Godot/Godot*.exe \
           "$HOME"/Godot/Godot_v4*_win64.exe; do
    if [[ -x "$g" ]]; then printf '%s' "$g"; return; fi
  done
}

have() { command -v "$1" >/dev/null 2>&1; }
