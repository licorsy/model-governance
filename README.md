# model-governance

The single owner of **model routing** across Licorsy repositories: which model
family does which job, and two procedures that use more than one family.

- **`cross-research`** asks one question to Gemini, a GPT-family model and
  optionally GPT-OSS, saves each answer to a file, and writes one
  reconciliation: consensus, divergences, single-source claims, and what to
  check at the source.
- **`second-opinion`** sends a diff, spec or plan to a reviewer from another
  family, then verifies every finding against the source before any of them is
  accepted.

The routing table and its rules live in [`standard/ROUTING.md`](standard/ROUTING.md).
Other repositories point there instead of restating it. Nothing here is
injected at SessionStart: the skills load when they are invoked, and the
standard is read on demand.

## Requirements

| Tool | Used for | Check |
|---|---|---|
| Antigravity CLI (`agy`) | Gemini, GPT-OSS, and Claude on Google quota | `agy models` lists models |
| GitHub Copilot CLI (`copilot`) | a GPT-family voice through Copilot | `copilot login` done |

`scripts/check-clis.sh` verifies both without spending a model request, and
fails loudly when either is missing or signed out.

## Install

```bash
claude plugin marketplace add licorsy/model-governance
claude plugin install model-governance@model-governance
```

Then create the local deny list. **Every call is blocked until this file
exists**:

```bash
mkdir -p ~/.config/model-governance
$EDITOR ~/.config/model-governance/deny-patterns
```

One extended regular expression per line, matched case-insensitively against
every prompt; `#` starts a comment. Put in it whatever must never leave your
machine: client and private-repository names, patient or customer data markers,
internal hostnames. The list stays on your machine and is never committed here.
A file holding only comments is accepted: it records that you made the decision.

## How a call is protected

`scripts/ask.sh` is the only path the skills use to reach another model. In
order, it:

1. blocks the prompt if it matches the deny list, or if the list is missing;
2. runs the CLI from a fresh empty temp directory, because both CLIs load
   `AGENTS.md` and similar files from where they run;
3. keeps the call read-only (`agy --mode plan`; Copilot with no allowed tools
   and its built-in MCP servers disabled);
4. writes the answer with a header recording the model that **actually**
   answered, which is what decides whether a review came from another family.

## License

MIT. See [LICENSE](LICENSE).
