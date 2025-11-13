# CommandWatch

CommandWatch is a PowerShell module that mimics the Linux `watch` command: it repeatedly runs an expression or external program, clears the console (unless you opt out), and prints a header with timing, exit status, and iteration info. Output can be wrapped or truncated, and `-PassThru` returns rich objects for automation.

---

## For Users

### Get the module
```powershell
git clone https://github.com/r0tifer/Watch-Command.git
```

Import directly from the manifest so metadata, formats, and aliases load correctly:
```powershell
Import-Module (Join-Path $PWD 'CommandWatch/CommandWatch.psd1') -Force
```

Want it available everywhere? Copy the `CommandWatch` folder into a path listed in `$env:PSModulePath`, then `Import-Module CommandWatch`.

### Run commands
```powershell
Invoke-CommandWatch -n 1.5 -Count 1 -UseExec ping -Args '1.1.1.1'
Invoke-CommandWatch -n 3 -UseExec ping -Args '-n','1','1.1.1.1' -StreamOutput   # watch-style live ping
Invoke-CommandWatch -n 2 -t -Command 'Get-Process'
Watch-Command -n 2 Get-Service   # legacy-friendly alias
Invoke-CommandWatch -Command "'tick-' + (Get-Random)" -Differences -Color -ChangeExit
```

Sample output for the live command:
```
Every 3s: ping -n 1 1.1.1.1 2025-11-13 08:44:46 [exit:0] [iter:1]

Pinging 1.1.1.1 with 32 bytes of data:
Reply from 1.1.1.1: bytes=32 time=40ms TTL=58
Ping statistics for 1.1.1.1:
    Packets: Sent = 1, Received = 1, Lost = 0 (0% loss),
Approximate round trip times in milli-seconds:
    Minimum = 40ms, Maximum = 40ms, Average = 40ms
```
Tip: the console is cleared before each iteration, so adding `-Count 1` (as above) or `-NoClear` keeps the ping output visible when the command finishes; use `-StreamOutput` when you want native command output to appear live during each loop.

### Key switches
- `-Interval` / `-n` tune the cadence; `-Count` stops after N iterations.
- `-UseExec` (with `-Args` for native parameters) executes external commands via `&`.
- `-StreamOutput` mirrors native command output live (great for ping/traceroute) while still capturing text for logs.
- `-NoTitle`, `-NoClear`, `-NoWrap` tailor output for CI or logging.
- `-PassThru` yields `CommandWatch.TickResult` objects (timestamp, iteration, exit code, body) for piping or exporting.
- `-Differences`, `-DifferencesPermanent`, and `-Color` highlight changes between runs.
- `-ChangeExit`, `-ErrorExit`, and `-Beep` control stop/alert behavior.
- `-LogPath` appends timestamped summaries per iteration.
- Legacy `-waitTime`/`-waitInterval` map to `-Interval`; you’ll see a warning so you can modernize scripts.

### Configuration & logging
- View defaults: `Get-CommandWatchConfig`.
- Persist overrides: `Set-CommandWatchConfig -Defaults @{ Interval = 1.5; NoClear = $true }`.
- Config lives at `%APPDATA%\CommandWatch\config.json` unless `COMMANDWATCH_CONFIG_PATH` overrides it.
- Store a default `LogPath` in config for archival runs; ad-hoc `-LogPath` wins for that invocation.

### PassThru formatting
PassThru objects are tagged with the `CommandWatch.TickResult` type name. `formats\CommandWatch.Format.ps1xml` ships a table view (timestamp, command, exit code, iteration) so piping to `Format-Table` or exporting stays readable.

---

## For Developers

### Module structure
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

The manifest exports the public surface (`Invoke-CommandWatch`, `Get-CommandWatchConfig`, `Set-CommandWatchConfig`, alias `Watch-Command`). The loader dot-sources private helpers first so shared state is ready before public cmdlets are defined, then exports whatever functions/aliases the scripts declare.

### Public vs. private API
- Public commands live under `Public/` and are the only exported functions.
- Internal helpers stay under `Private/` and are dot-sourced only inside the module; keep their scope script-local.
- PassThru objects advertise `CommandWatch.TickResult`; extend that via `types/` or `formats/` if you add fields.

### Testing & tooling
- Pester: `Invoke-Pester -Script '.\CommandWatch\tests'` (covers config plumbing, PassThru objects, and command behavior).
- ScriptAnalyzer: `Invoke-ScriptAnalyzer -Path .\CommandWatch -Settings .\.config\PSScriptAnalyzerSettings.psd1`.
- Examples: `examples\examples.ps1` is runnable smoke coverage for expression and exec usage.

### Contribution tips
- Follow the existing strict-mode pattern in new scripts.
- Keep exports explicit in `CommandWatch.psd1` and add new public functions under `Public/`.
- Update README (user + developer sections) when adding switches or changing behavior.
- Add/adjust tests alongside new features so CI keeps pace with the public contract.
