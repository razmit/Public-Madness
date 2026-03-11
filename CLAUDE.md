# Claude Code Instructions for razmit/my-scripts

## Script Organization

All PnP PowerShell scripts must be saved in:

```
Windows/RSM-related/PnP/
```

Do not place PnP scripts in the repo root or any other subdirectory.

---

## PowerShell Coding Conventions

Based on the established style of scripts in this repo:

### Structure
- Full comment-based help block at the top: `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER` (one per param), `.EXAMPLE` (multiple), `.NOTES`
- `[CmdletBinding()]` immediately before `param()`
- Module availability check (`Get-Module -ListAvailable`) before `Import-Module`

### Authentication
- Default `ClientId = "f6666fe0-04e6-419a-b4bb-4025060af8f5"` (shared tenant app registration)
- Use `Connect-PnPOnline -Url $SiteUrl -ClientId $ClientId -Interactive`
- Always `Disconnect-PnPOnline` in a `finally` block

### Logging
- Include a `Write-Log` helper with timestamp (`yyyy-MM-dd HH:mm:ss`) and `-Level` parameter
- Accepted levels: `Info` (White), `Success` (Green), `Warning` (Yellow), `Error` (Red), `Action` (Cyan), `Verbose` (DarkGray)
- Support an optional `-LogPath` parameter that mirrors console output to a file via `Add-Content`

### Long-Running Operations
- Use `Write-Progress` for operations over many items
- Process items in configurable batches (default 500); expose as `-BatchSize`
- Add brief `Start-Sleep` pauses between batches to reduce throttling risk
- Handle throttling with exponential back-off (2 / 4 / 8 / 16 s)

### Error Handling
- `try/catch` around individual operations within loops
- Accumulate failures in a `[System.Collections.Generic.List[PSCustomObject]]`
- Export failure list to a CSV at the end (default path under `$env:TEMP`)
- Wrap main body in a top-level `try/catch` that calls `exit 1` on fatal errors

### Output Style
- Section headers use `═══` box-drawing characters
- `Author : Claude` and `Date : <yyyy-MM-dd>` in `.NOTES`
- Summary block at the end with counts for successes, failures, skips

### WhatIf Support
- Include a `[switch]$WhatIf` parameter on any script that mutates data
- Gate all mutating calls behind `if (-not $WhatIf)` checks
- Annotate WhatIf output with `[WHATIF]` prefix in log lines
