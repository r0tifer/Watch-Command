@{
    RootModule        = 'CommandWatch.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a8d0d7e5-6d6f-4c6d-bb78-7e5f5bc1c5a1'
    Author            = 'Michael Levesque'
    CompanyName       = 'Deeptree, Inc'
    Copyright         = 'Copyright (c) 2025 Michael Levesque'
    Description       = 'A watch-like command runner for PowerShell.'

    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop','Core')

    FunctionsToExport = @('Invoke-CommandWatch','Get-CommandWatchConfig','Set-CommandWatchConfig')
    AliasesToExport   = @('Watch-Command')
    CmdletsToExport   = @()
    VariablesToExport = @()

    FormatsToProcess  = @('formats\CommandWatch.Format.ps1xml')
    TypesToProcess    = @('types\CommandWatch.Types.ps1xml')

    FileList = @()
    PrivateData = @{
        PSData = @{
            Tags         = @('watch','monitor','terminal','utilities')
            ProjectUri   = 'https://github.com/r0tifer/Watch-Command'
            LicenseUri   = 'https://github.com/r0tifer/Watch-Command/blob/main/LICENSE.txt'
            ReleaseNotes = 'Initial module packaging.'
        }
    }
}
