param(
    [Parameter(Mandatory=$false,Position=0)]
    [string]$Command = "build",
    [Parameter(Mandatory=$false,Position=1)]
    [string[]]$Args
)

$commandPath = "./scripts/windows/$Command.ps1"

if (-not (Test-Path $commandPath)) {
    throw "$commandPath does not exist"
}

Write-Host "Running $Command..."
& $commandPath @Args