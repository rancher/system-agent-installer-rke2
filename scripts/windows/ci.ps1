$ErrorActionPreference = 'Stop'

Import-Module -Name @(
    "$PSScriptRoot\utils.psm1"
) -WarningAction Ignore -Force

Run-Script download
Run-Script package
Run-Script publish
Run-Script manifest