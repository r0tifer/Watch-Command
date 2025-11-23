# CommandWatch

Over the past three years CommandWatch has been a passion project of mine to bringing the spirit of the Linux `watch` command to PowerShell. The CommandWatch project: a focused, script-first way to run commands on a cadence, see crisp headers with exit codes and timing, and capture rich results you can automate against.

---

## What it does
- Repeats an expression or external command on a schedule (precise or best-effort).
- Clears the console between iterations (unless you opt out) and prints a compact header with interval, timestamp, exit code, and iteration.
- Highlights changes between runs, can stop on change or error, and can beep to get your attention.
- Streams native output live when you want the classic `watch` feel, or collects diffable text when you need comparisons.
- Emits typed `CommandWatch.TickResult` objects when you want to script against the results.
- Persists defaults (interval, output options, log path) so you can set it once and forget it.

---

## Quick start
Downdload the offical release from PowerShell Gallery.
```powershell
Copy and Paste the following command to install this package using PowerShellGet More Info

Install-Module -Name CommandWatch

For Devolpment Version, get the module and import from the manifest so metadata, formats, and the alias load correctly::

git clone https://github.com/r0tifer/Watch-Command.git
Import-Module (Join-Path $PWD 'CommandWatch/CommandWatch.psd1') -Force
```

Make it global: copy the `CommandWatch` folder into any path in `$env:PSModulePath`, then `Import-Module CommandWatch`.

Run a few essentials:
```powershell
# Live watch-style ping with streaming output
Invoke-CommandWatch -n 3 -UseExec ping -Args '-n','1','1.1.1.1' -StreamOutput

# Expression mode with change highlighting and exit-on-change
Invoke-CommandWatch -Command "'tick-' + (Get-Random)" -Differences -Color -ChangeExit

# Legacy-friendly alias
Watch-Command -n 2 Get-Service

# Linux muscle-memory alias
watch -n 2 Get-Service
```

Sample output (streaming ping):
```
Every 3s: ping -n 1 1.1.1.1 2025-11-13 08:44:46 [exit:0] [iter:1]

Pinging 1.1.1.1 with 32 bytes of data:
Reply from 1.1.1.1: bytes=32 time=40ms TTL=58
Ping statistics for 1.1.1.1:
    Packets: Sent = 1, Received = 1, Lost = 0 (0% loss),
Approximate round trip times in milli-seconds:
    Minimum = 40ms, Maximum = 40ms, Average = 40ms
```
Tip: the console clears before each loop. Use `-Count 1` or `-NoClear` to keep the last output visible. Use `-StreamOutput` when you want native output live during each iteration.

---

## Everyday switches
- `-Interval` / `-n` set the cadence; `-Count` stops after N iterations.
- `-UseExec` (plus `-Args`) runs external commands via `&`; the default is expression mode.
- `-StreamOutput` mirrors native command output live while still capturing text for logs.
- `-NoTitle`, `-NoClear`, `-NoWrap` tame the console for CI or logging.
- `-PassThru` yields `CommandWatch.TickResult` objects (timestamp, iteration, exit code, body).
- `-Differences`, `-DifferencesPermanent`, `-Color` highlight changes between runs.
- `-ChangeExit`, `-ErrorExit`, `-Beep` control stop/alert behavior.
- `-LogPath` appends timestamped summaries per iteration.
- Legacy `-waitTime`/`-waitInterval` map to `-Interval` with a friendly warning.

---

## Configuration and logging
- View defaults: `Get-CommandWatchConfig`
- Persist overrides: `Set-CommandWatchConfig -Defaults @{ Interval = 1.5; NoClear = $true }`
- Config lives at `%APPDATA%\CommandWatch\config.json` unless `COMMANDWATCH_CONFIG_PATH` overrides it.
- Store a default `LogPath` for archival runs; an ad-hoc `-LogPath` wins for that invocation.

PassThru objects carry the `CommandWatch.TickResult` type name. `formats\CommandWatch.Format.ps1xml` ships a table view (timestamp, command, exit code, iteration) so piping to `Format-Table` or exporting stays readable.

---

## Project layout
```
CommandWatch/
|-- CommandWatch.psd1   # manifest (explicit exports + metadata)
|-- CommandWatch.psm1   # strict-mode loader (dot-sources private, then public)
|-- Public/             # exported functions
|-- Private/            # internal helpers
|-- formats/, types/    # ps1xml stubs for custom views/types
|-- en-US/              # external help stub
|-- tests/              # Pester specs
`-- examples/           # runnable samples
```

The manifest exports the public surface (`Invoke-CommandWatch`, `Get-CommandWatchConfig`, `Set-CommandWatchConfig`, alias `Watch-Command`). The loader dot-sources private helpers first so shared state is ready before public cmdlets are defined, then exports whatever the scripts declare.

---

## Contributing and tests
- Pester (v5): `Invoke-Pester -Path '.\CommandWatch\tests'`
- ScriptAnalyzer: `Invoke-ScriptAnalyzer -Path .\CommandWatch -Settings .\.config\PSScriptAnalyzerSettings.psd1`
- Examples: `examples\examples.ps1` is runnable smoke coverage for expression and exec usage.
