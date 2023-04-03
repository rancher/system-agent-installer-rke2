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
    if(Test-Path -Path HKLM:SYSTEM\CurrentControlSet\Services\$rke2ServiceName) {
        Set-ItemProperty HKLM:SYSTEM\CurrentControlSet\Services\$rke2ServiceName -Name Environment -Value $([string]$newEnv)
    }
    else {
        New-Item HKLM:SYSTEM\CurrentControlSet\Services\$rke2ServiceName
        New-ItemProperty HKLM:SYSTEM\CurrentControlSet\Services\$rke2ServiceName -Name Environment -PropertyType MultiString -Value $([string]$newEnv)
    }
    $RESTART = $true
}

Write-LogInfo "Checking if RKE2 agent service exists"
if ((Get-Service -Name $rke2ServiceName -ErrorAction SilentlyContinue)) {
    Write-LogInfo "RKE2 agent service found, stopping now"
    # allow some time for the service to come up, so we can  then properly stop it
    Start-Sleep -s 5
    Stop-Service -Name $rke2ServiceName
    while ((Get-Service $rke2ServiceName).Status -ne 'Stopped') {
        Write-LogInfo "Waiting for RKE2 agent service to stop"
    }
    # allow time for all processes to stop, and for ports to be freed
    Start-Sleep -s 30
}

# if service doesn't exist, then install, otherwise check the binary and determine if it needs to be reinstalled, otherwise fall through to restart, skil enable, skip start
./installer.ps1 -TarPrefix $SA_INSTALL_PREFIX  -ArtifactPath $env:CATTLE_AGENT_EXECUTION_PWD

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


if ((Get-Service -Name $rke2ServiceName -ErrorAction SilentlyContinue))
{
    $successfulStart = $false
    $maxAttempts = 2
    For ($attempts = 0; $attempts -le $maxAttempts; $attempts++) {
        if ((Get-Service $rke2ServiceName).Status -eq 'Stopped')
        {
            try
            {
                Write-LogInfo "Attempting to start $rke2ServiceName"
                Start-Service -Name $rke2ServiceName
                $successfulStart = $true
                break
            }
            catch
            {
                # The failure to start may be temporary, give the service some time to see if it can come up on its own.
                # If it still cannot start after this time, we should manually attempt to start it again, as this would indicate
                # that the service never properly transitioned into the running state and therefore will not be automatically
                # restarted by the Windows Service Manager.
                # see https://learn.microsoft.com/en-us/windows/win32/api/winsvc/ns-winsvc-service_failure_actionsa
                #     https://learn.microsoft.com/en-us/windows/win32/services/service-status-transitions
                #     https://github.com/rancher/rke2/blob/master/pkg/windows/service_windows.go#L26-L49
                # RKE2 is configured to restart every 30 seconds after a failure is detected during the running state
                #     https://github.com/rancher/rke2/blob/master/pkg/cli/cmds/agent_service_windows.go#L102-L106
                For ($waitAttempts = 0; $waitAttempts -lt 3; $waitAttempts++) {
                    Start-Sleep -s 35
                    if ((Get-Service $rke2ServiceName).Status -eq 'Running')
                    {
                        $successfulStart = $true
                        break
                    }
                    else
                    {
                        Write-LogInfo "Still waiting for $rke2ServiceName to start..."
                    }
                }
            }
        }
        elseif (($RESTART = $true) -and ((Get-Service $rke2ServiceName).Status -eq 'Running'))
        {
            # if the WSM throws an error on restart we should try again to make sure
            # the service actually gets restarted. In some cases a failure to restart will
            # transition the service into a 'stopped' state, at which point we will start it again
            # in the above condition.
            try
            {
                Write-LogInfo "Restarting $rke2ServiceName"
                Restart-Service -Name $rke2ServiceName
                $successfulStart = $true
            } catch {
                Start-Sleep -s 5
            }
        }
    }

    if ($successfulStart -eq $true)
    {
        Write-LogInfo "Succesfully started $rke2ServiceName"
    } else {
        $rke2Logs = $(Get-EventLog -LogName Application -Source rke2 | Select-Object ReplacementStrings | Format-Table -Wrap | Out-String)
        Write-LogError "$rke2ServiceName service could not be started properly"
        # Print out the RKE2 logs so we can do a deeper analysis of what went wrong.
        Write-LogFatal "RKE2 Logs: $rke2Logs"
    }
}
