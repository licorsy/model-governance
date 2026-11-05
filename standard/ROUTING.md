# Model routing standard

The single owner of "which model does which job" across Licorsy repositories.
Other documents point here; they do not restate it. Read on demand: this file
is **not** injected into sessions.

## Why route at all

Two reasons, in this order:

1. **A different model family catches different mistakes.** A reviewer from the
   same family as the author shares its blind spots, and a fresh context only
   removes some of them.
2. **Credits are separate pools.** Work that does not need the executing Claude
   session can run on quota that is already paid for elsewhere.

## The table

| Job | Goes to | Why |
|---|---|---|
| Executing the task, writing files, reconciling answers, verifying findings | the current Claude session | it holds the context and does the writing |
| Cross-model research: one answer per family | `agy` `gemini-4-argon-high` · `copilot` `auto` · optionally `agy` `gpt-oss-120b-medium` | three families answering independently |
| Second opinion on a diff, spec or plan | `agy` `gemini-4-argon-high` (default) · `copilot` `auto` (second voice) | a family other than the author's |
| Cheap triage, a quick factual check | `agy` `gemini-3.8-flash-low` | seconds, not minutes |
| A guaranteed GPT-family voice | `agy` `gpt-oss-120b-medium` | Copilot auto-routing cannot be pinned to a family |
| Claude credits exhausted | `agy` `claude-opus-5-5-*` / `claude-sonnet-5-5-*` | the same family on another quota. **This is a fallback, not a second opinion** |
| Long-form web research (Deep Research in a browser UI) | done by hand, exported as a file into the same folder | no CLI path, so it enters as input to the reconciliation |

Model ids come from `agy models` and change with the catalog. When an id here
stops working, run `agy models`, update this table and bump the plugin version.

## Rules

- **R1. The record decides the family, not the request.** Every answer written
  by `scripts/ask.sh` carries a `model that answered:` line. A review counts as
  "a different model" only if that line names a non-Claude model. Copilot on an
  auto-routing plan picks the model itself, so its line is the only evidence.
- **R2. No client or patient data leaves the machine.** Only questions and
  non-sensitive content go to Google or GitHub. `ask.sh` enforces a local
  deny-pattern list, and blocks the call if the list does not exist. A blocked
  call is answered by asking the human, never by editing the list to get past it.
- **R3. Run from a neutral directory.** Both CLIs load instruction files
  (`AGENTS.md` and similar) from their working directory. `ask.sh` always runs
  them from an empty temp directory. Never call them by hand from inside a
  client repository.
- **R4. Claude verifies before anything is accepted.** A finding or claim from
  another model is input, not output. It reaches the human only after the
  Claude session checked it against the source (code, docs, primary reference).
- **R5. State the cost.** Each Copilot prompt spends one premium request;
  `ask.sh` records the count. Each `agy` call spends Google quota. A skill that
  fans out to three models says so before it runs.

## Known limits (verified 2026-11-05)

- `agy --mode plan` is read-only. Without the "answer directly" preamble that
  `ask.sh` adds, it may answer with a plan artifact instead of text.
- Copilot plans that include only auto-routing reject every `--model <name>`
  with "not available". Asking the model to name itself returns "Auto", so that
  answer is no evidence; only the JSON event stream says which model answered.
- One prompt is capped at 100 000 bytes (Linux limits a single argv string to
  128 KiB). Larger material must be split or summarized first.
