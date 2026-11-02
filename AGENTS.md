# AGENTS.md

Guidance for AI coding agents (and human contributors) working in this repository.

## Project

**Winnie IT Support Toolkit** — a portable Windows diagnostics collector that produces a self-contained HTML dashboard and an AI-ready Markdown summary. Primary use case: field tech toolkit run on customer machines, minimal footprint, no installs.

## Tech stack

- **PowerShell 5.1+** (Windows PowerShell). Do **not** use PowerShell 7-only features; field machines may only have 5.1.
- **Vanilla HTML/CSS/JS** for the dashboard. No build step, no frameworks, no bundler.
- **JSON** as the intermediate data contract (`output/data.json`).
- Optional LLM calls via `Invoke-RestMethod` (OpenAI/Anthropic/Ollama).

## Repository layout

```
collect.ps1                 # orchestrator: runs collectors, scores health, writes outputs
modules/                    # one file per collector, each exposes a Get-* function
dashboard/template.html      # self-contained dashboard; __DATA_PLACEHOLDER__ replaced at run time
ai/summarize.ps1            # builds output/summary.md (AI-ready, token-budgeted)
ai/analyze.ps1              # optional LLM API call -> output/analysis.md
ai/prompt-template.md       # manual paste prompt
config/config.json          # thresholds, ping targets, AI settings
tests/smoke.ps1             # end-to-end smoke test
output/                     # generated artifacts (gitignored)
```

## Prerequisites

- Windows 10/11, PowerShell 5.1+
- For full diagnostics: run elevated (Administrator).
- Node.js is **not** required at runtime; only used in development for JS syntax checks.

## Running

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\collect.ps1                       # writes output/data.json + output/dashboard.html
.\output\dashboard.html             # open dashboard
.\ai\summarize.ps1                  # writes output/summary.md
.\ai\analyze.ps1                    # optional; configure config/config.json first
.\tests\smoke.ps1                   # validate end-to-end
```

Always run `tests\smoke.ps1` after changing collectors or the dashboard template.

## Architecture & data flow

1. `collect.ps1` dot-sources every `modules/*.ps1`, then calls each `Get-*` collector inside `Invoke-Collector` (try/catch wrapper that records errors without aborting).
2. Collectors return `[pscustomobject]` hashtables. Add new fields there; keep them JSON-serializable (no scriptblocks, no live CIM objects, no dates as raw objects — convert to strings).
3. Health scoring lives in `collect.ps1` (search for `# ---- Health scoring ----`). Add new rules there, assigning severity `critical|high|medium|low` with weights 25/12/6/2.
4. `data.json` is the single source of truth consumed by both the dashboard and the AI summary.
5. Dashboard: `collect.ps1` reads `dashboard/template.html`, replaces `__DATA_PLACEHOLDER__` with the JSON, writes `output/dashboard.html`. The JSON must not contain a literal `</script>` (already escaped).
6. `ai/summarize.ps1` reads `data.json`, renders Markdown, truncates to `config.ai.maxSummaryChars`.

## Coding conventions

### PowerShell
- Target **PowerShell 5.1**. Avoid `??`, ternary, `ForEach-Object -Parallel`, and other 7+ syntax. Use `if/else` and traditional loops.
- Every collector must be wrapped in `try/catch` and return an object containing an `error` property on failure rather than throwing. See `Invoke-Collector` in `collect.ps1`.
- Use `Get-CimInstance` over `Get-WmiObject` (WMI is deprecated).
- Suppress errors with `-ErrorAction SilentlyContinue` on optional/privileged calls; use `-ErrorAction Stop` inside try blocks where you want to catch.
- Keep functions pure: no global state, no writes to disk, no `Write-Host` inside modules. Return data only.
- Prefer `[math]::Round(..., 2)` for numeric output; convert dates via `.ToString('o')`.
- Indent with 4 spaces; braces on same line (K&R). Match existing style.
- File naming: `Get-<Area>Info.ps1` containing function `Get-<Area>Info`.

### Dashboard (HTML/JS)
- Single file, vanilla JS only. No external CDN dependencies (must work offline on a customer machine).
- All data comes from `window.__DATA__`. Do not fetch.
- Escape all dynamic text with the `esc()` helper before inserting into HTML.
- Tables use the `table(headers, rows, filterId)` helper; add a filter id for long lists.
- Keep the dark theme variables in `:root`; do not hardcode colors.
- The JS must run under file:// (no module imports, no fetch).

### Data contract
- Adding a field: update collector, dashboard section, and `summarize.ps1` section together. Keep them in sync.
- Never remove a field without updating consumers.
- Booleans must be real booleans, not strings, so the dashboard renders "Yes/No" correctly.

## Security

- Treat `output/` and `config/` as sensitive: they may contain usernames, paths, installed software, security posture. They are gitignored.
- API keys live in `config/config.json`. Never commit a populated key. Never log keys.
- `ai/analyze.ps1` must not send data unless `provider` is explicitly set to a non-`export` value.
- Collectors must not execute remote code or download anything.
- Redact before external AI use: consider adding a redaction pass (usernames, IPs, paths) before export — currently manual.
- Run elevated only when needed; collectors degrade gracefully when not elevated.

## Testing

- `tests\smoke.ps1` is the canonical check: runs collector, validates required sections (`meta`, `system`, `health`, `storage`, `network`, `performance`), runs summarizer, verifies `summary.md`.
- For dashboard JS changes, run the node-based smoke check used in development:
  ```powershell
  node -e "const fs=require('fs');const h=fs.readFileSync('output/dashboard.html','utf8');const m=h.match(/<script>([\s\S]*?)<\/script>/g);m.forEach((b,i)=>fs.writeFileSync('C:/temp/s'+i+'.js',b.replace(/<\/?script>/g,'')));"
  node --check C:/temp/s0.js; node --check C:/temp/s1.js
  ```
- There are no unit tests yet. If adding Pester, put specs under `tests/` and name them `*.Tests.ps1`.

## Git workflow

- Branch from `main`. Keep commits focused (collector / dashboard / ai / docs).
- Do not commit anything under `output/` (gitignored).
- Commit messages: imperative mood, short subject, optional body.
- Line endings: Windows CRLF. If cross-platform contributors appear, add `.gitattributes`.

## AI agent guidance

When modifying this repo, agents should:

1. Read `collect.ps1`, the relevant module, `dashboard/template.html`, and `ai/summarize.ps1` before editing — they must stay in sync.
2. Prefer `edit` for targeted changes; use `write` only for new files or full rewrites.
3. After any change, run `tests\smoke.ps1` and confirm it passes.
4. After dashboard template changes, run the node syntax check on the extracted scripts.
5. Do not introduce dependencies (npm, pip, modules) — portability is a core requirement.
6. Do not change the data contract fields without updating all three consumers.
7. Preserve graceful degradation: every collector must catch errors and return `{ error }`.
8. Keep the dashboard working from `file://` with no network.
9. Ask before adding elevation requirements or network calls.

## Out of scope (do not add without discussion)

- Electron/desktop wrapper, web server, database, or cloud backend.
- Telemetry or automatic data upload.
- Breaking PowerShell 5.1 compatibility.
