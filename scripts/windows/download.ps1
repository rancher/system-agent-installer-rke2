$ErrorActionPreference = 'Stop'

.$PSScriptRoot/version.ps1

Set-Location $PSScriptRoot/../..

# This script serves to download/stage the installer

New-Item -ItemType Directory -Path artifacts -Force | Out-Null

if (-not $env:LOCAL_ARTIFACTS) {
    curl.exe -fL https://raw.githubusercontent.com/rancher/rke2/master/install.ps1 > artifacts/installer.ps1

    # skip unsupported arm64 arch
    if (($env:ARCH -eq "arm64") -and ($env:VERSION -match '^v1\.(20|24|25|26)\.')) {
        Write-Host "Skipping arm64 - not supported for this version."
        exit
    }

    Push-Location artifacts

    if ($env:PRIME_RIBS) {
        curl.exe -fL -O -R "https://$($env:PRIME_RIBS)/rke2/$($env:URI_VERSION)/rke2.windows-$env:ARCH.tar.gz"
        curl.exe -fL -O -R "https://$($env:PRIME_RIBS)/rke2/$($env:URI_VERSION)/rke2-images.windows-$env:ARCH.txt"
        curl.exe -fL -O -R "https://$($env:PRIME_RIBS)/rke2/$($env:URI_VERSION)/sha256sum-$env:ARCH.txt"
    }
    else {
        curl.exe -fL -O -R "https://github.com/rancher/rke2/releases/download/$env:URI_VERSION/rke2.windows-$env:ARCH.tar.gz"
        curl.exe -fL -O -R "https://github.com/rancher/rke2/releases/download/$env:URI_VERSION/rke2-images.windows-$env:ARCH.txt"
        curl.exe -fL -O -R "https://github.com/rancher/rke2/releases/download/$env:URI_VERSION/sha256sum-$env:ARCH.txt"
    }

    Pop-Location
}
else {
    Copy-Item local/* artifacts
}
