# Examples for CommandWatch

Import-Module (Join-Path $PSScriptRoot '..\CommandWatch.psd1') -Force

# Exec mode
Invoke-CommandWatch -n 1.5 -UseExec -- ping 1.1.1.1

# Expression mode
Invoke-CommandWatch -n 2 -- Get-Process | Select-Object -First 1

# Back-compat alias
Watch-Command -n 2 -- Get-Service

# Highlight differences with color and exit on change
Invoke-CommandWatch -Command "'tick-' + (Get-Random)" -Differences -Color -ChangeExit

# Persist defaults for interval/wrapping
Set-CommandWatchConfig -Defaults @{ Interval = 1.5; NoClear = $true }
Get-CommandWatchConfig | Format-List

# Write iteration summaries to a log file
$logPath = Join-Path $PSScriptRoot 'logs\watch.log'
Invoke-CommandWatch -Command "'log-demo'" -Count 1 -LogPath $logPath -NoTitle
