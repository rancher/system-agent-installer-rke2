$ErrorActionPreference = 'Stop'

.$PSScriptRoot/version.ps1

Set-Location $PSScriptRoot/../..

# This script serves to download/stage the installer

mkdir -p artifacts -f

if (-not $env:LOCAL_ARTIFACTS) {
    curl.exe -fL https://raw.githubusercontent.com/rancher/rke2/master/install.ps1 > artifacts/installer.ps1
    Push-Location artifacts
    curl.exe -fL -O -R https://github.com/rancher/rke2/releases/download/$env:URI_VERSION/rke2.windows-$env:ARCH.tar.gz
    curl.exe -fL -O -R https://github.com/rancher/rke2/releases/download/$env:URI_VERSION/sha256sum-$env:ARCH.txt
    Pop-Location

}
else {
    Copy-Item local/* artifacts
}
