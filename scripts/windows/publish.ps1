$ErrorActionPreference = 'Stop'

Import-Module -Name @(
    "$PSScriptRoot\utils.psm1"
) -WarningAction Ignore -Force

Run-DockerLogin

$e = Get-Environment
$platformImage = $e.platform_image

docker push $platformImage

Write-Host "Pushed $platformImage"
