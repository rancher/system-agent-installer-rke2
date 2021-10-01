$ErrorActionPreference = 'Stop'

.$PSScriptRoot/version.ps1

Set-Location $PSScriptRoot/..

docker login -u $env:DOCKER_USERNAME -p $env:DOCKER_PASSWORD

DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create --amend $env:IMAGE $env:IMAGE-$env:OS-$env:ARCH
DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push $env:IMAGE

Write-Host "Pushed manifest list for $env:IMAGE"
