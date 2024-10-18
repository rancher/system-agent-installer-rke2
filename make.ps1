# Github action CI does not utilize these scripts, however they're still useful for local development.

Write-Host "
To build locally the following environment varables must be set
    `$env:TAG - The rke2 tag that should be packaged within the installer image. This should match a released version of rke2 (i.e. v1.30.2+rke2r1)
    `$env:NANOSERVER_VERSION (can be either ltsc2019 or 1809 for Windows server 2019 or ltsc2022 for Windows server 2022)
    `$env:REPO - The dockerhub repo the image will be pushed to
"

if ((-not $env:TAG) -or ($env:TAG -eq "")) {
    Write-Host "`$env:TAG must be set to a valid RKE2 release (such as 'v1.30.2+rke2r1')"
    exit 1
}

if ((-not $env:NANOSERVER_VERSION) -or ($env:NANOSERVER_VERSION -eq "")) {
    Write-Host "`$env:NANOSERVER_VERSION must be set to a valid server core base image version (Either 1809, ltsc2019, or ltsc2022)"
    exit 1
}

if ((-not $env:REPO) -or ($env:REPO -eq "")) {
    Write-Host "`$env:REPO must be set to a valid dockerhub repository"
    exit 1
}

if ($args.Count -eq 0) {
    $args = @("build")
}

if ($args[0] -eq "build") {
    Write-Host "Running build"
    scripts\windows\build.ps1
    exit
}

if ($args[0] -eq "publish") {
    Write-Host "Running publish"
    scripts\windows\publish.ps1
    exit
}

$script = $args[0]
if (Test-Path scripts\$($script).ps1) {
    scripts\$($args[0]).ps1
} else {
    Write-Host "Could not find script $script.ps1"
}