---
name: cross-research
description: Ask the same research question to models from different families (Gemini via the Antigravity CLI, GPT-family via Copilot, optionally GPT-OSS), save each answer to a file, and write one reconciliation (consensus, divergences, single-source claims, what to check at the source). Use when the user wants a question researched "in Gemini and ChatGPT too", asks for a cross-check or a reconciliation across models, says "pesquisa cruzada", or would otherwise copy and paste one question into several chat UIs.
---

# Cross-model research

Replaces the copy-and-paste routine: the same question goes to several model
families, and this session writes the reconciliation. Routing and rules:
`../../standard/ROUTING.md` (paths here are relative to this skill's base
directory). Read it once per session before the first run.

## Before running

1. Run `../../scripts/check-clis.sh`. If it fails, report the failing line and
   stop. Never fall back to "Claude only" while calling the result cross-model.
2. Confirm the question contains no client or patient data (ROUTING R2). If it
   does, stop and ask the user to rephrase it generically.
3. Tell the user the cost in one line: one Copilot premium request, plus one or
   two `agy` calls on Google quota.

## Run

1. Create the run folder. Use the user's choice if given; otherwise
   `${TMPDIR:-/tmp}/model-governance/<YYYY-MM-DD>-<slug>/`. Never write it
   inside a client repository.
2. Write the question to `question.md`, verbatim, plus any constraints the user
   gave (period, language, output length).
3. Write **this session's own answer** to `claude.md` before reading any other
   answer, so the reconciliation is not anchored on another model's framing.
4. Run the other models in parallel, each from `ask.sh`:

   ```bash
   S="<this skill's base directory>/../../scripts"; D=<run folder>
   $S/ask.sh agy gemini-4-argon-high "$D/question.md" "$D/gemini.md" &
   $S/ask.sh copilot auto "$D/question.md" "$D/copilot.md" &
   $S/ask.sh agy gpt-oss-120b-medium "$D/question.md" "$D/gpt-oss.md" &   # optional
   wait
   ```

   An exit code of 3 means the data guard blocked the question: ask the user,
   do not edit the deny list. An exit code of 2 means that model failed: report
   it and continue with the others.
5. If the user exported Deep Research reports from a browser UI, copy them into
   the same folder. They are inputs like the others.

## Reconcile

Write `reconciliation.md` in the run folder, in the user's language:

1. **Header.** List each source by file name and its `model that answered:` line
   (ROUTING R1), so the reader sees which families actually took part.
2. **Consensus.** Claims that two or more sources agree on, each tagged with its
   sources.
3. **Divergences.** Where the sources contradict each other. State each side,
   then say which one the evidence favours and why.
4. **Single source.** Claims that only one source made. Tag each one.
5. **To check at the source.** Every load-bearing claim from sections 3 and 4,
   plus any number, date, price or version. Check the ones that decide the
   user's question against a primary source before presenting them as fact
   (ROUTING R4), and mark which ones you checked.

Then give the user the conclusion in a few lines, with a link to
`reconciliation.md`. Do not paste the raw answers into the chat.
