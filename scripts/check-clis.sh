#!/usr/bin/env bash
# check-clis.sh — verify the non-Claude CLIs this plugin drives are installed
# and signed in. Fails loudly (exit 1) on the first unusable tool, so a skill
# never silently falls back to "Claude only" while claiming a cross-model run.
#
# Usage: scripts/check-clis.sh [agy|copilot]...   (default: both)
# Exit:  0 all requested tools usable · 1 at least one is not.
#
# Cost: zero model requests. `agy models` is a catalog call; the Copilot check
# reads its local config, because every Copilot prompt spends a premium request.

set -u

find_bin() { # $1 = name, rest = fallback paths
  local name=$1; shift
  if command -v "$name" >/dev/null 2>&1; then command -v "$name"; return 0; fi
  local p
  for p in "$@"; do [ -x "$p" ] && { echo "$p"; return 0; }; done
  return 1
}

status=0
fail() { echo "FAIL  $1" >&2; status=1; }
ok()   { echo "ok    $1"; }

check_agy() {
  local bin
  bin=$(find_bin agy "$HOME/.gemini/bin/agy") \
    || { fail "agy: not installed (expected on PATH or at ~/.gemini/bin/agy)"; return; }
  local out
  out=$(cd "$(mktemp -d)" && timeout 60 "$bin" models 2>&1)
  if printf '%s' "$out" | grep -qi 'sign in'; then
    fail "agy: not signed in — run \`$bin\` once and complete the Google login"
  elif ! printf '%s' "$out" | grep -qE '^[a-z0-9.-]+[[:space:]]'; then
    fail "agy: \`agy models\` returned no model list: $(printf '%s' "$out" | head -1)"
  else
    ok "agy $("$bin" --version 2>/dev/null) — $(printf '%s\n' "$out" | grep -cE '^[a-z0-9.-]+[[:space:]]') models"
  fi
}

check_copilot() {
  local bin
  bin=$(find_bin copilot "$HOME/.local/bin/copilot") \
    || { fail "copilot: not installed (expected on PATH or at ~/.local/bin/copilot)"; return; }
  local cfg="$HOME/.copilot/config.json"
  # config.json starts with // comment lines; strip them before parsing.
  if [ -f "$cfg" ] && sed '/^[[:space:]]*\/\//d' "$cfg" \
      | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin).get("loggedInUsers") else 1)' 2>/dev/null; then
    ok "$("$bin" --version 2>/dev/null | head -1)"
  else
    fail "copilot: not signed in — run \`$bin login\`"
  fi
}

tools=("$@"); [ ${#tools[@]} -eq 0 ] && tools=(agy copilot)
for t in "${tools[@]}"; do
  case $t in
    agy) check_agy ;;
    copilot) check_copilot ;;
    *) fail "unknown tool: $t (expected agy or copilot)" ;;
  esac
done
exit $status
