$ErrorActionPreference = 'Stop'

Import-Module -Name @(
    "$PSScriptRoot\utils.psm1"
) -WarningAction Ignore -Force

$e = Get-Environment
$platformImage = $e.platform_image

$windowsVersion = (Get-WindowsVersion)

docker build --build-arg SERVERCORE_VERSION=$windowsVersion -f "package/Dockerfile.windows" -t $platformImage .
Log-Info "Built $platformImage"