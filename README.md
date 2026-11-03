# Winnie IT Support Toolkit

A portable, self-contained Windows diagnostics collector + dashboard + AI-ready summary generator.

## Features

- **Universal diagnostics**: system, hardware, storage, network, processes, services, event logs, updates, drivers, software, security, performance, users, reliability.
- **Clean dashboard**: single self-contained HTML file with health score, status badges, searchable tables, charts.
- **AI-ready output**: Markdown summary sized for an LLM, plus optional direct API call (OpenAI/Anthropic/Ollama).
- **Field-friendly**: runs from a USB stick, no installs, elevated optional, outputs a zippable folder.

## Quick start

```powershell
# Run as Administrator for full diagnostics
Set-ExecutionPolicy -Scope Process Bypass
.\collect.ps1                  # Quick mode (default)
.\collect.ps1 -Mode Deep       # Deep forensic mode (V3-class)
.\collect.ps1 -Mode Deep -DeepScan  # Deep + SFC/DISM/chkdsk
.\collect.ps1 -SaveBaseline    # Save current run as baseline
.\collect.ps1 -ShareSafe       # (via summarize) redact hostnames/IPs for sharing

# Or launch the GUI (choose Quick/Deep in the dropdown)
.\gui.ps1

# Open the dashboard
.\output\dashboard.html

# Generate AI summary
.\ai\summarize.ps1

# Optional: call an LLM API
.\ai\analyze.ps1
```

## Portable build

```powershell
.\build\portable.ps1
# -> dist\ITSupportToolkit.zip  (extract anywhere, run Run.bat)
```

## Single-file .exe (optional)

```powershell
.\build\exe.ps1 -InstallPS2EXE
# -> dist\ITSupport.exe  (requires PS2EXE module; may trigger SmartScreen)
```

## Output

Everything lands in `output\`:

- `data.json` - structured diagnostics (source of truth)
- `dashboard.html` - self-contained visual dashboard
- `summary.md` - AI-ready findings + prompt
- `analysis.md` - (optional) LLM response
- `errors.log` - collector errors

## Configuration

Edit `config\config.json`:

```json
{
  "toolVersion": "1.0.0",
  "eventLogHours": 72,
  "topProcesses": 25,
  "pingTargets": ["8.8.8.8","1.1.1.1"],
  "ai": { "provider": "openai", "model": "gpt-4o-mini", "apiKey": "" }
}
```

## Architecture

```
collect.ps1 -> modules/*.ps1 -> output/data.json
                              -> dashboard/template.html + data -> output/dashboard.html
ai/summarize.ps1 -> output/summary.md
ai/analyze.ps1   -> (optional API) -> output/analysis.md
```

## Security notes

- Run elevated for full data; non-elevated runs skip protected collectors.
- API keys stored in config.json - keep output/ and config/ private.
- No data leaves the machine unless you run analyze.ps1 with an API provider.
