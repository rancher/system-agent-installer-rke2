$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-LogInfo {
    Write-Host -NoNewline -ForegroundColor Blue "INFO: "
    Write-Host -ForegroundColor Gray ("{0,-44}" -f ($args -join " "))
}
function Write-LogWarn {
    Write-Host -NoNewline -ForegroundColor DarkYellow "WARN: "
    Write-Host -ForegroundColor Gray ("{0,-44}" -f ($args -join " "))
}
function Write-LogError {
    Write-Host -NoNewline -ForegroundColor DarkRed "ERROR: "
    Write-Host -ForegroundColor Gray ("{0,-44}" -f ($args -join " "))
}
function Write-LogFatal {
    Write-Host -NoNewline -ForegroundColor DarkRed "FATA: "
    Write-Host -ForegroundColor Gray ("{0,-44}" -f ($args -join " "))
    exit 255
}

function New-Directroy {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Path
    )
    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory | Out-Null
    }
}

function Get-StringHash {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Value
    )
    $stringAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stringAsStream)
    $writer.write($Value)
    $writer.Flush()
    $stringAsStream.Position = 0
    return (Get-FileHash -InputStream $stringAsStream -Algorithm SHA256).Hash.ToLower()
}

$rke2ServiceName = "rke2"
$SA_INSTALL_PREFIX = "c:/usr/local"
$SAI_FILE_DIR = "c:/var/lib/rancher/rke2/system-agent-installer"
$RESTART_STAMP_FILE = "$SAI_FILE_DIR/rke2_restart_stamp"
$PRIOR_RESTART_STAMP = ""
$RESTART = $false

New-Directroy -Path "c:/var/lib/rancher/rke2"
New-Directroy $SAI_FILE_DIR

if (Test-Path $RESTART_STAMP_FILE) {
    $PRIOR_RESTART_STAMP = Get-Content -Path $RESTART_STAMP_FILE
}

if ($env:RESTART_STAMP -and ($PRIOR_RESTART_STAMP -ne $env:RESTART_STAMP)) {
    $RESTART = true
}

$currentEnv = Get-ItemProperty HKLM:SYSTEM\CurrentControlSet\Services\$rke2ServiceName -Name Environment -ErrorAction SilentlyContinue
$currentHash = Get-StringHash -Value $($currentEnv | Out-String)

$newEnv = @()
$RKE2_ENV = Get-ChildItem env: | Where-Object { $_.Name -Like "RKE2_*" } | ForEach-Object { "$($_.Name)=$($_.Value)" }
if ($RKE2_ENV) {
    $newEnv += $RKE2_ENV
}

$PROXY_ENV_INFO = Get-ChildItem env: | Where-Object { $_.Name -Match "^(NO|HTTP|HTTPS)_PROXY" } | ForEach-Object { "$($_.Name)=$($_.Value)" }
if ($PROXY_ENV_INFO) {
    $newEnv += $PROXY_ENV_INFO
}

$newHash = Get-StringHash -Value $($newEnv | Out-String)
if ($newEnv -and ($newHash -ne $currentHash)) {
    Set-ItemProperty HKLM:SYSTEM\CurrentControlSet\Services\$rke2ServiceName -Name Environment -PropertyType MultiString -Value $fullEnv
    $RESTART = $true
}

Write-LogInfo "Checking if RKE2 agent service exists"
if ((Get-Service -Name $rke2ServiceName -ErrorAction SilentlyContinue)) {
    Write-LogInfo "RKE2 agent service found, stopping now"
    Stop-Service -Name $rke2ServiceName
    while ((Get-Service $rke2ServiceName).Status -ne 'Stopped') {
        Write-LogInfo "Waiting for RKE2 agent service to stop"
        Start-Sleep -s 5
    }
}

# if service doesn't exist, then install, otherwise check the binary and determine if it needs to be reinstalled, otherwise fall through to restart, skil enable, skip start
$env:INSTALL_RKE2_ARTIFACT_PATH = $env:CATTLE_AGENT_EXECUTION_PWD
$env:INSTALL_RKE2_TAR_PREFIX = $SA_INSTALL_PREFIX 
./install.ps1


if ($env:RESTART_STAMP) {
    Set-Content -Path $env:RESTART_STAMP_FILE -Value $env:RESTART_STAMP
}

if ($env:INSTALL_RKE2_SKIP_ENABLE -eq $true) {
    Write-LogInfo "Skipping RKE2 Service installation"
    exit 0
}
else {
    # Create Windows Service
    Write-LogInfo "RKE2 agent service not found, enabling agent service"
    Push-Location c:\usr\local\bin
    rke2.exe agent service --add
    Pop-Location
    Start-Sleep -s 5
}

if ($env:INSTALL_RKE2_SKIP_START -and ($env:INSTALL_RKE2_SKIP_START -eq $true)) {
    Write-LogInfo "Skipping starting of the RKE2 Service"
    exit 0
}

if ((Get-Service -Name $rke2ServiceName -ErrorAction SilentlyContinue)) {
    if ((Get-Service $rke2ServiceName).Status -eq 'Stopped') {
        Write-LogInfo "Starting for RKE2 agent service"
        Start-Service -Name $rke2ServiceName
    } 
    elseif (($RESTART = $true) -and ((Get-Service $rke2ServiceName).Status -eq 'Running')) {
        Restart-Service -Name $rke2ServiceName
    }
}
