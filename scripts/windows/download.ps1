$ErrorActionPreference = 'Stop'

Import-Module -Name @(
    "$PSScriptRoot\utils.psm1"
) -WarningAction Ignore -Force

$e = Get-Environment
$arch = $e.arch

# This script serves to download/stage the installer

if (-not $env:LOCAL_ARTIFACTS) {
    Get-RKE2Artifact "installer.ps1"
    Get-RKE2Artifact "rke2.windows-$arch.tar.gz"
    Get-RKE2Artifact "sha256sum-$arch.txt"
}
else {
    Copy-Item local/* artifacts
}
