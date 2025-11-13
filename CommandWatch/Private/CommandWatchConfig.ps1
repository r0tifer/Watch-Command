function Get-CommandWatchConfigDefaultSettings {
    [CmdletBinding()]
    param()

    return @{
        Interval = 2
        NoTitle  = $false
        NoWrap   = $false
        NoClear  = $false
        Width    = $null
        LogPath  = $null
    }
}

function Get-CommandWatchConfigPath {
    [CmdletBinding()]
    param(
        [switch]$EnsureDirectory
    )

    $override = $env:COMMANDWATCH_CONFIG_PATH
    if ($override) {
        if ($EnsureDirectory) {
            $dir = Split-Path -Parent $override
            if ($dir -and -not (Test-Path -LiteralPath $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }
        return $override
    }

    $onWindows = $false
    try {
        $onWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
    } catch {
        $onWindows = ([Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)
    }

    if ($onWindows) {
        $base = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'CommandWatch'
    } else {
        $configHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
        $base = Join-Path $configHome 'CommandWatch'
    }

    if ($EnsureDirectory -and -not (Test-Path -LiteralPath $base)) {
        New-Item -ItemType Directory -Path $base -Force | Out-Null
    }

    return Join-Path $base 'config.json'
}

function Read-CommandWatchConfig {
    [CmdletBinding()]
    param()

    $defaults = Get-CommandWatchConfigDefaultSettings
    try {
        $path = Get-CommandWatchConfigPath
        if (-not (Test-Path -LiteralPath $path)) {
            return $defaults
        }

        $raw = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $defaults
        }

        $data = $raw | ConvertFrom-Json -ErrorAction Stop
        foreach ($prop in $data.PSObject.Properties) {
            $defaults[$prop.Name] = $prop.Value
        }
    } catch {
        # Fall back to defaults if parsing fails
    }

    return $defaults
}

function Write-CommandWatchConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Settings
    )

    $path = Get-CommandWatchConfigPath -EnsureDirectory
    $json = $Settings | ConvertTo-Json -Depth 4
    $json | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}
