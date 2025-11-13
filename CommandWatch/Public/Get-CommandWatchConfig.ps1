<#
.SYNOPSIS
    Gets the current CommandWatch default settings and config path.

.DESCRIPTION
    Reads the persisted configuration (if any) and merges it with built-in defaults. The config
    file location can be overridden with the COMMANDWATCH_CONFIG_PATH environment variable.

.EXAMPLE
    Get-CommandWatchConfig
    Returns the resolved config path and defaults currently stored on disk.
#>
function Get-CommandWatchConfig {
    [CmdletBinding()]
    param()

    $defaults = Read-CommandWatchConfig
    $path = Get-CommandWatchConfigPath -EnsureDirectory:$false

    $result = [pscustomobject]@{
        Path     = $path
        Defaults = $defaults
    }
    $result.PSObject.TypeNames.Insert(0, 'CommandWatch.Config')
    return $result
}
