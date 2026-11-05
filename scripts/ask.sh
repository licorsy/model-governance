#!/usr/bin/env bash
# ask.sh — send one prompt to one non-Claude model and write the answer to a file.
#
# Usage: scripts/ask.sh <agy|copilot> <model> <prompt-file> <out-file>
#   agy      <model> is an id from `agy models`, e.g. gemini-4-argon-high
#   copilot  <model> is `auto` (the only choice on auto-routing plans) or a
#            name your plan accepts; the model that actually answered is
#            read from the JSON event stream and recorded, never assumed.
#
# Exit: 0 answered · 1 usage/tool error · 2 model error · 3 blocked by the
#       data-protection guard.
#
# Guarantees, in order:
#   1. Data guard. The prompt is matched against the deny patterns in
#      ${MODEL_GOV_DENY_FILE:-~/.config/model-governance/deny-patterns}
#      (one extended regex per line, case-insensitive, # comments). A match
#      blocks the call. A missing file also blocks it: the list is a local,
#      deliberate decision, never shipped in this public repository.
#   2. Neutral directory. Both CLIs load instruction files (AGENTS.md and
#      similar) from the directory they run in. Every call runs from a fresh
#      empty temp directory, so no repository's instructions or files travel
#      with the prompt.
#   3. Read-only. agy runs in --mode plan; Copilot gets no --allow-tool and
#      its built-in MCP servers are disabled.

set -u
here=$(cd "$(dirname "$0")" && pwd)

[ $# -eq 4 ] || { sed -n '2,10p' "$0" >&2; exit 1; }
tool=$1 model=$2 prompt_file=$3 out=$4
[ -r "$prompt_file" ] || { echo "ask.sh: cannot read prompt file: $prompt_file" >&2; exit 1; }

timeout_s=${MODEL_GOV_TIMEOUT:-600}
max_bytes=100000   # Linux caps one argv string at 128 KiB; stay well under it.

# --- 1. data guard -----------------------------------------------------------
deny=${MODEL_GOV_DENY_FILE:-$HOME/.config/model-governance/deny-patterns}
if [ ! -f "$deny" ]; then
  cat >&2 <<EOF
ask.sh: BLOCKED — no deny-pattern file at $deny
Create it (it may hold only comments) to confirm you decided what must never
leave this machine: client names, patient data markers, private repo names.
EOF
  exit 3
fi
patterns=$(grep -vE '^[[:space:]]*(#|$)' "$deny" || true)
if [ -n "$patterns" ]; then
  hit=$(printf '%s\n' "$patterns" | while IFS= read -r p; do
    grep -qiE -- "$p" "$prompt_file" && { echo "$p"; break; }
  done)
  if [ -n "$hit" ]; then
    echo "ask.sh: BLOCKED — prompt matches deny pattern: $hit" >&2
    exit 3
  fi
fi

size=$(wc -c < "$prompt_file")
[ "$size" -le "$max_bytes" ] || {
  echo "ask.sh: prompt is $size bytes (limit $max_bytes). Split or summarize it." >&2; exit 1; }

"$here/check-clis.sh" "$tool" >/dev/null || exit 1
prompt=$(cat "$prompt_file")

# --- 2. neutral directory -----------------------------------------------------
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
started=$(date -Iseconds)
t0=$(date +%s)

case $tool in
  agy)
    bin=$(command -v agy || echo "$HOME/.gemini/bin/agy")
    preamble="Answer directly in plain text. Do not create a plan, an artifact or any file."
    (cd "$work" && "$bin" -p="$preamble

$prompt" --model "$model" --mode plan --output-format text \
       --print-timeout "${timeout_s}s") > "$work/answer.txt" 2> "$work/stderr.txt"
    rc=$?
    used=$model
    extra=""
    ;;
  copilot)
    bin=$(command -v copilot || echo "$HOME/.local/bin/copilot")
    margs=(); [ "$model" != auto ] && margs=(--model "$model")
    (cd "$work" && timeout "$timeout_s" "$bin" -p "$prompt" --no-color \
       --output-format json --disable-builtin-mcps "${margs[@]}") \
       > "$work/events.jsonl" 2> "$work/stderr.txt"
    rc=$?
    # Final answer = assistant.message events; model = what Copilot reports it used.
    python3 - "$work/events.jsonl" "$work/answer.txt" "$work/meta.txt" <<'PY'
import json, sys
src, ans, meta = sys.argv[1:4]
texts, models, premium = [], [], None
for line in open(src, encoding="utf-8"):
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        ev = json.loads(line)
    except ValueError:
        continue
    t, d = ev.get("type"), ev.get("data") or {}
    if t == "assistant.message" and d.get("content"):
        texts.append(d["content"])
        if d.get("model"):
            models.append(d["model"])
    elif t == "result":
        premium = (ev.get("usage") or {}).get("premiumRequests")
open(ans, "w", encoding="utf-8").write("\n\n".join(texts))
used = ", ".join(dict.fromkeys(models)) or "unknown"
open(meta, "w", encoding="utf-8").write(f"{used}\t{premium if premium is not None else 'unknown'}")
PY
    IFS=$'\t' read -r used premium < "$work/meta.txt"
    extra="- premium requests: $premium"
    ;;
  *) echo "ask.sh: unknown tool: $tool (expected agy or copilot)" >&2; exit 1 ;;
esac

secs=$(( $(date +%s) - t0 ))
mkdir -p "$(dirname "$out")"
{
  echo "<!-- model-governance/ask.sh -->"
  echo "- tool: $tool"
  echo "- model requested: $model"
  echo "- model that answered: $used"
  echo "- started: $started"
  echo "- seconds: $secs"
  echo "- exit: $rc"
  [ -n "$extra" ] && echo "$extra"
  echo
  echo "---"
  echo
  cat "$work/answer.txt"
} > "$out"

if [ $rc -ne 0 ] || [ ! -s "$work/answer.txt" ]; then
  echo "ask.sh: $tool/$model failed (exit $rc). stderr:" >&2
  head -20 "$work/stderr.txt" >&2
  exit 2
fi
echo "$out"
