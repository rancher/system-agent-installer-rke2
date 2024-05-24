$ErrorActionPreference = 'Stop'

Import-Module -Name @(
    "$PSScriptRoot\utils.psm1"
) -WarningAction Ignore -Force

Run-DockerLogin

$e = Get-Environment
$image = $e.image
$platformImage = $e.platform_image

$env:DOCKER_CLI_EXPERIMENTAL= $true

docker manifest create --amend $image $platformImage
docker manifest push $image

Write-Host "Pushed manifest list for $image"
