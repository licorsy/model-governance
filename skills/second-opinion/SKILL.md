---
name: second-opinion
description: Send a diff, spec, plan or document to a reviewer from a different model family (Gemini via the Antigravity CLI by default, Copilot as a second voice), then verify every finding against the source before accepting it. Use when the user asks for a second opinion, a cross-model review or "revisão por outro modelo", before closing a spec or plan, or when a review step asks for an independent reviewer on a different model than the one that wrote the work.
---

# Cross-model second opinion

A reviewer from another family catches mistakes this session shares with its
own reviewers. Routing and rules: `../../standard/ROUTING.md` (paths here are
relative to this skill's base directory). Read it once per session before the
first run.

## Before running

1. Run `../../scripts/check-clis.sh agy` (add `copilot` when you plan to use
   it). If it fails, report the failing line and stop.
2. **Data check (ROUTING R2).** Material from a client repository (specs,
   diffs, data, names) does not go out. `ask.sh` blocks matches against the
   local deny list, but the list only catches what someone wrote into it. If
   the material is a client's, stop and tell the user. Do not offer to strip
   it down yourself.
3. Tell the user the cost in one line.

## Run

1. Pick the material and save it into the run folder
   (`${TMPDIR:-/tmp}/model-governance/<YYYY-MM-DD>-review-<slug>/`):
   - a branch: `git diff <base>...HEAD > material.diff`
   - a spec, plan or document: copy the file as it is.
   Keep it under 100 000 bytes. If it is larger, review it one section at a
   time instead of summarizing, because a summary hides the very defects the
   review is looking for.
2. Write `prompt.md`: the review brief below, followed by the material.

   ```text
   You are reviewing work written by another AI model. Find defects, not style
   preferences. For each finding give: location (file:line or section),
   severity (blocker / major / minor), the defect in one sentence, and the
   evidence from the material. Finish with "no findings" if you found nothing.
   Do not invent context that the material does not contain.

   What this work is meant to do: <one paragraph from the user or the spec>

   --- MATERIAL ---
   ```

3. Run the reviewer, plus the second voice when the stakes justify the cost:

   ```bash
   S="<this skill's base directory>/../../scripts"; D=<run folder>
   $S/ask.sh agy gemini-4-argon-high "$D/prompt.md" "$D/review-gemini.md" &
   $S/ask.sh copilot auto "$D/prompt.md" "$D/review-copilot.md" &   # optional
   wait
   ```

   An exit code of 3 means the data guard blocked the material: ask the user.

## Verify (ROUTING R4)

For every finding, open the cited location in the real source and classify it:

- **Confirmed.** The defect is there. Say what breaks.
- **Rejected.** The defect is not there, or the reviewer misread the material.
  Give the reason in one line.
- **Plausible.** You cannot confirm it from the material alone. Say what would
  settle it.

Write `verdicts.md` in the run folder. Report to the user only the confirmed and
plausible findings, plus the count of rejected ones, together with the
`model that answered:` line of each review (ROUTING R1). Apply fixes only when
the user asks.

## Fit with review steps that ask for a different model

When a process asks the independent reviewer to use "a different model (or at
least a fresh context)", this skill fulfils the "different model" option only
when the `model that answered:` line names a non-Claude model. A Claude model
reached through `agy` is the same family on another quota, so it counts as a
fresh context, not a different model.
