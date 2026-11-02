# Comparison: Winnie IT Support Toolkit vs. System Diagnostics Collector (V3)

This document compares the **Winnie IT Support Toolkit** (this repo) with the **System Diagnostics Collector** (`I:\#General IT Scripts\DiagnosticsCollector\DiagnosticsTool\V3`, a more mature, single-file collector with a rich WinForms GUI in V2). Use it to decide what to adopt, merge, or keep separate.

## At a glance

| Dimension | Winnie (this repo) | System Diagnostics Collector (V3) |
|---|---|---|
| Shape | Modular: `collect.ps1` + `modules/*.ps1` + `dashboard/template.html` + `ai/*` | Single ~2000-line script; GUI is a separate file |
| Primary output | `data.json` + self-contained `dashboard.html` + `summary.md` (AI-ready) | Timestamped folder of CSV/JSON/TXT/EVTX/DMP + `Index.html` + `Summary.txt` + `AI_Analysis_Report.txt` + zip |
| Audience | Field tech + AI agent | Deep forensic collection + AI agent |
| Maturity | Starter scaffold (v1.0) | Mature (v1.1.1), many edge cases handled |
| GUI | Simple (6 buttons, log, progress) | Rich (every option, settings persistence, progress per section, live findings count, cancel) |
| Portability | Portable zip + optional PS2EXE exe | V3 ships `.exe` + zip; V2 GUI alongside |

## 1. Diagnostics coverage

### Winnie covers (14 collectors)
System identity, hardware (battery/GPU/mobo/NICs), storage + SMART, network (IP/DNS/ping/listening ports/proxy), processes (top CPU/mem + suspicious), services (failed auto-start), event logs (errors/warnings + BSOD), Windows Updates, drivers/devices, installed software + startup, security (firewall/Defender/BitLocker/SecureBoot/TPM/UAC), performance counters, user accounts/admins, reliability monitor + minidumps.

### V3 covers (everything above, plus)
- Monitors (WmiMonitorID), sound devices, USB controllers, thermal zones
- **Pending reboot** detection (CBS/WU/PendingFileRename)
- **HotFixes**, full driver inventory (Win32_PnPSignedDriver), device problem devices
- **SMART**: native WMI attribute parser (MSStorageDriver_FailurePredict*) **and** optional smartctl (NVMe/USB)
- Storage Spaces, partitions/volumes with dirty bit, Win32_DiskDrive/LogicalDisk
- **Battery report** (powercfg) + wear % + cycle count
- **Licensing**: Windows + Office keys (BIOS OEM, registry-decoded), activation state, slmgr/ospp
- **Crash analysis**: BSOD history, dump header parsing (bugcheck codes), WER reports, dump/pagefile config, optional cdb `!analyze -v`
- **Event logs**: ~20 logs exported as CSV + raw EVTX, per-log summaries, curated "interesting events" roll-up (WHEA, NTFS, etc.)
- Network: Wi-Fi, proxy, hosts, shares, time sync, connectivity tests, routes, connections with process names
- Software: AppX packages, scheduled tasks
- Security: AV products, audit policy, gpresult, dsregcmd (Entra/AD join), hardening checks, password policy
- Sensitive (opt-in): BitLocker recovery keys, Wi-Fi cleartext keys, Security EVTX
- Deep scan (opt-in): SFC, DISM, chkdsk, powercfg /energy

### Verdict
V3 is **far deeper** in forensic/low-level diagnostics (SMART attribute parsing, dump header parsing, licensing, WHEA, pending reboot). Winnie is **broader at the "what's wrong right now" level** (health score, listening ports, suspended services, top processes) but shallower in disk/crash forensics. Winnie's collectors are easier to extend (one file per area); V3 is a monolith.

## 2. Output & visualization

| | Winnie | V3 |
|---|---|---|
| Structure | Single `data.json` + embedded dashboard | Folder of ~dozens of CSV/JSON/TXT + EVTX + DMP + zip |
| Dashboard | Rich self-contained HTML: health score, cards, collapsible sections, searchable tables, charts (bars) | Simple `Index.html` file browser with findings table and links |
| Health scoring | 0–100 score with severity-weighted issues | Findings list (Critical/Warning/Info) with counts; exit code 2 if critical |
| AI readiness | `summary.md` (token-budgeted Markdown) + optional direct API call | `AI_Analysis_Report.txt` (redacted, size-budgeted, with suggested prompt) |

### Verdict
Winnie wins on **dashboard UX** (searchable, collapsible, visual). V3 wins on **data depth and AI-report redaction** (it explicitly strips env vars, command lines, keys, Wi-Fi passwords, masks licence keys, and shrinks to a size budget). V3's report also includes a suggested request and privacy note — good practice to adopt.

## 3. AI integration

- **Winnie**: structured Markdown summary sized to `maxSummaryChars`; optional direct call to OpenAI/Anthropic/Ollama via `analyze.ps1`; `prompt-template.md` for manual paste.
- **V3**: consolidated redacted text report with auto-shrinking detail scale, copied both inside and outside the run folder; suggested prompt embedded.

### Verdict
Both produce AI-ready text. V3's **redaction + size-budget shrinking** is more mature. Winnie's **direct API call** and **dashboard** are unique. Merge opportunity: add redaction to Winnie's `summarize.ps1` and adopt V3's "shrink until it fits" loop.

## 4. GUI

- **Winnie (`gui.ps1`)**: minimal — 6 buttons, log pane, progress marquee, elevation restart. Good for quick field use.
- **V3 V2 GUI**: full options form (all collector switches), settings persistence (LOCALAPPDATA), progress per section, live findings counter, cancel that kills the process tree, remembers last settings (never sensitive/full-dump).

### Verdict
V3's GUI is **substantially more capable**. Winnie's GUI is simpler but sufficient for its scope. If Winnie grows, adopt V2's settings-persistence + per-section progress pattern.

## 5. Portability / deployment

- **Winnie**: portable zip (`build/portable.ps1`) + optional single `.exe` via PS2EXE (`build/exe.ps1`); no installs.
- **V3**: ships `.exe` + zip; smartctl can be dropped next to the script.

### Verdict
Roughly equivalent. Winnie's PS2EXE build is optional and documented; V3 leans on a pre-built exe. Both are portable.

## 6. Extensibility & code quality

- **Winnie**: modular (one file per collector, pure functions returning data, `Invoke-Collector` error isolation). Easy to add a collector: create `modules/Get-X.ps1`, register in `collect.ps1`, add dashboard section + summary section. Follows AGENTS.md conventions. PowerShell 5.1 compatible.
- **V3**: monolithic but well-structured with `Invoke-Collect` helper, `Add-Finding`, `Save-Output`, `Find-Executable`. Highly consistent, with friendly error notes and manifest tracking. More mature error handling and redaction.

### Verdict
Winnie is **easier to extend** (modular). V3 is **more robust in production** (manifest of every step's status, friendly notes, size budgets, redaction). Winnie should adopt V3's manifest/findings discipline.

## 7. Performance

- **Winnie**: ~seconds to a minute; collectors are lightweight.
- **V3**: can run minutes (event exports, smartctl, deep scan, cdb analysis); designed with caps (`MaxEventsPerLog`, `AgentReportMaxKB`) and progress reporting.

### Verdict
V3 is heavier by design (forensic depth). Winnie is faster for "quick health check." Both are appropriate for different jobs.

## 8. Privacy / safety

- **Winnie**: `output/` and `config/` gitignored; no network unless `analyze.ps1` configured; API keys in config. **No redaction yet** — user names, IPs, paths go into the AI summary verbatim.
- **V3**: explicit redaction (env vars, command lines, BitLocker keys, Wi-Fi passwords, licence-key masking, secret-pattern masking) and a privacy note in the report.

### Verdict
V3 is **safer for sharing**. Winnie should add a redaction pass before AI export (listed in AGENTS.md as a future improvement).

## Recommended merge strategy

Keep both tools (they serve different jobs), but cross-pollinate:

1. **Adopt into Winnie (high value, low risk)**
   - Redaction pass in `ai/summarize.ps1` (mask keys, strip env vars/command lines, privacy note).
   - Size-budget shrinking loop (V3's `Write-AgentReport` approach) instead of hard truncation.
   - Manifest of collector status (`errors.log` already exists; make it structured with OK/EMPTY/FAILED + notes).
   - Pending-reboot detection, battery wear, SMART attribute parsing (V3's native WMI SMART) as new collectors.
   - Exit codes: 0 = healthy, 2 = critical findings (useful for scripting/monitoring).
   - `Find-Executable` pattern for optional tools (smartctl) with graceful skip.

2. **Adopt into V3 (lower priority)**
   - Winnie's modular structure (split monolith into `modules/`) for maintainability.
   - Winnie's richer HTML dashboard (searchable tables, health score, cards).
   - Winnie's direct LLM API call option.

3. **Keep separate**
   - V3's deep forensic features (dump analysis, licensing, WHEA, dsregcmd) belong in a "deep scan" mode, not the default quick dashboard.
   - Winnie stays the fast, clean, AI-first field tool.

## Summary

- **Use Winnie** for: quick health checks, portable field toolkit, AI-assisted triage, clean dashboard.
- **Use V3** for: deep forensic collection, incident tickets, licensing/activation issues, crash dump analysis, sharing redacted reports with AI.
- **Best of both**: bring V3's redaction, manifest discipline, and SMART/pending-reboot collectors into Winnie; bring Winnie's dashboard and modularity into V3's roadmap.
