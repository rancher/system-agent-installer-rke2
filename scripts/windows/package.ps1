$ErrorActionPreference = 'Stop'

.$PSScriptRoot/version.ps1

Set-Location $PSScriptRoot/..

$DOCKERFILE = package/Dockerfile.windows

docker image build -f $DOCKERFILE -t $env:IMAGE-$env:OS-$env:ARCH .

Write-Host "Built $env:IMAGE-$env:OS-$env:ARCH"
