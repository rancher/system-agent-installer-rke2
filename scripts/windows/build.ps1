$ErrorActionPreference = 'Stop'

Push-Location $PSScriptRoot

./download.ps1
Push-Location $PSScriptRoot
./package.ps1
