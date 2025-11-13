# Script module loader for CommandWatch
Set-StrictMode -Version Latest

# Load private helpers first
Get-ChildItem -Path "$PSScriptRoot\Private" -Filter *.ps1 -File -ErrorAction SilentlyContinue |
  ForEach-Object { . $_.FullName }

# Load public functions
$public = Get-ChildItem -Path "$PSScriptRoot\Public" -Filter *.ps1 -File -ErrorAction SilentlyContinue
foreach ($f in $public) { . $f.FullName }

# Export only the public functions (basename matches function name) and any aliases they define
Export-ModuleMember -Function $public.BaseName -Alias *
