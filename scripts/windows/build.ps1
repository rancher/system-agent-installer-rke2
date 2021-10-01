$ErrorActionPreference = 'Stop'

Push-Location $PSScriptRoot

./download.ps1
./package.ps1
