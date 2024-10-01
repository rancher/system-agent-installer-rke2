$ErrorActionPreference = 'Stop'

.$PSScriptRoot/version.ps1

Set-Location $PSScriptRoot/../..

$DOCKERFILE = "package/Dockerfile.windows"

docker image build --build-arg NANOSERVER_VERSION=$env:NANOSERVER_VERSION -f $DOCKERFILE -t $env:IMAGE-windows-$env:ARCH .

Write-Host "Built $env:IMAGE-$env:OS-$env:ARCH"
