function Log-Info {
    Write-Host -NoNewline -ForegroundColor Blue "INFO "
    Write-Host -ForegroundColor Gray ("{0,-44}" -f ($args -join " "))
}

function Log-Warn {
    Write-Host -NoNewline -ForegroundColor DarkYellow "WARN "
    Write-Host -ForegroundColor Gray ("{0,-44}" -f ($args -join " "))
}

function Log-Error {
    Write-Host -NoNewline -ForegroundColor DarkRed "ERRO "
    Write-Host -ForegroundColor Gray ("{0,-44}" -f ($args -join " "))
}

function Log-Fatal {
    Write-Host -NoNewline -ForegroundColor DarkRed "FATA "
    Write-Host -ForegroundColor Gray ("{0,-44}" -f ($args -join " "))

    exit 255
}

function Get-RootDir {
    return Split-Path (Split-Path -Path ($PSScriptRoot) -Parent) -Parent
}

function Get-RKE2Version {
    param(
        [Parameter(Mandatory=$false)]
        [string]$FallbackVersion = "v1.20.4+rke2r1"
    )

    $rkeVersion = $FallbackVersion

    $rateLimit = Invoke-RestMethod -Uri https://api.github.com/rate_limit
    if ($rateLimit.rate.remaining -eq 0) {
        return $rkeVersion
    }
    
    # Get the latest version when possible
    $rke2Info = Invoke-RestMethod -Uri "https://api.github.com/repos/rancher/rke2/releases"
    $rke2Tags = $rke2Info | Sort-Object tag_name -Descending | Select-Object tag_name
    if ($rke2Tags.Count -gt 0) {
        $latest = $rke2Tags[0].tag_name
        if (-not [string]::IsNullOrEmpty($latest)) {
            $rkeVersion = $latest
        }
    }
    return $rkeVersion
}

function Get-RKE2Artifact {
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [string]$Artifact
    )

    switch ($Artifact) {
        "installer.ps1" {
           $artifactUrl = "https://raw.githubusercontent.com/rancher/rke2/master/install.ps1"
        }
        default {
            $artifactUrl = "https://github.com/rancher/rke2/releases/download/$env:URI_VERSION/$Artifact"
        }
    }

    $artifactsDir = "$(Get-RootDir)/artifacts"
    New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null

    Log-Info "Installing $artifactURL into $artifactsDir/$Artifact..."
    curl.exe -sS -fL -o "$artifactsDir/$Artifact" $artifactUrl
}

function Run-DockerLogin {
    if ((-not [string]::IsNullOrEmpty($env:DOCKER_USERNAME)) -and (-not [string]::IsNullOrEmpty($env:DOCKER_PASSWORD))) {
        Log-Info "Using provided credentials from environment variables..."
        docker login -u $env:DOCKER_USERNAME -p $env:DOCKER_PASSWORD
    } else {
        Log-Warn "Skipping docker login since credentials were not provided..."
    }
}

function Run-Script {
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [String]$Script
    )

    $scriptPath = "$(Get-RootDir)/scripts/windows/$Script.ps1"

    if (-not (Test-Path $scriptPath)) {
        throw "cannot find $scriptPath"
    }

    try {
        & "$scriptPath"
    }
    catch {
        throw "$_.Exception.Message"
        exit $_.Exception.HResult
    }
}

function Get-Environment {
    param(
    [Parameter(Mandatory=$false)]    
    [string]$Org = $env:ORG,
    [Parameter(Mandatory=$false)]    
    [string]$Repo = $env:REPO,
    [Parameter(Mandatory=$false)]    
    [string]$OS = $env:OS,
    [Parameter(Mandatory=$false)]    
    [string]$Arch = $env:ARCH,
    [Parameter(Mandatory=$false)]
    [string]$Commit = $env:COMMIT,
    [Parameter(Mandatory=$false)]    
    [string]$Tag = $env:TAG
    )

    # default org
    if ([string]::IsNullOrEmpty($Org)) {
        $Org = "rancher"
    }

    # default repo
    if ([string]::IsNullOrEmpty($Repo)) {
        $Repo = "system-agent-installer-rke2"
    }

    # default os
    if (([string]::IsNullOrEmpty($OS)) -or ($OS -eq "Windows_NT")) {
        $OS = "windows"
    }

    # default arch
    if ([string]::IsNullOrEmpty($Arch)) {
        $Arch = "amd64"
    }

    if ([string]::IsNullOrEmpty($Commit)) {
        # if $env:COMMIT is not provided, default to $env:DRONE_COMMIT
        $Commit = $env:DRONE_COMMIT
    }
    if ([string]::IsNullOrEmpty($Commit)) {
        # if $env:DRONE_COMMIT is not provided, use $env:GITHUB_SHA
        $Commit = $env:GITHUB_SHA
    }

    if ([string]::IsNullOrEmpty($Tag)) {
        # if $env:TAG is not provided, default to $env:DRONE_TAG
        $Tag = $env:DRONE_TAG
    }
    if ([string]::IsNullOrEmpty($Tag)) {
        # if $env:DRONE_TAG is not provided, use $env:GITHUB_TAG
        $Tag = $env:GITHUB_TAG
    }

    # get git info
    $Dirty = $false
    try {
        Push-Location (Get-RootDir)
        $Dirty = (-not [string]::IsNullOrEmpty((git status --porcelain --untracked-files=no)))
        if ([string]::IsNullOrEmpty($Commit)) {
            # if no env vars are set to manually override the commit, override it
            $Commit = $(git rev-parse --short HEAD)
        }
        if ([string]::IsNullOrEmpty($Tag)) {
            # if no env vars are set to manually override the tag, override it
            $Tag = $(git tag -l --contains HEAD | Select-Object -First 1)
        }
    } finally {
        Pop-Location
    }

    if ($Dirty -and [string]::IsNullOrEmpty($env:TAG)) {
        # In the event of us doing a build with no corresponding tag that we can discern, we'll go ahead and just build the package assuming we were dealing with master.
        # This means we'll go to GitHub and pull the latest RKE2 release, and parse it to what we are expecting.
        $Version = Get-RKE2Version # v0.00.0-dev+rke2r0
    } else {
        $Version = $Tag
    }

    # validate the version format and create our VERSION variable
    if (-not ($Version -match '^v[0-9]{1}\.[0-9]{2}\.[0-9]+-*[a-zA-Z0-9]*\+rke2r[0-9]+$')) {
        Log-Fatal "Version '$Version' does not match our expected format. Exiting."
    }

    $Version = $Version.Replace("+", "-")

    $image = "{0}/{1}:{2}" -f $Org, $Repo, $Version
    $platformImage = "$image-$os-$arch"

    return @{
        image = $image
        platform_image = $platformImage
        os = $OS
        arch = $Arch
        tag = $Tag
        commit = $Commit
        version = $Version
        uri_version = [uri]::EscapeDataString($Version)
        dirty = $Dirty
    }
}

function Get-WindowsVersion() {
    # Based on https://learn.microsoft.com/en-us/windows-server/get-started/windows-server-release-info
    $version = "{0}.{1}.{2}" -f `
        [System.Environment]::OSVersion.Version.Major.ToString(), `
        [System.Environment]::OSVersion.Version.Minor.ToString(), `
        [System.Environment]::OSVersion.Version.Build.ToString()

    switch ($version) {
        "10.0.17763" { return "ltsc2019" }
        "10.0.19041" { return "ltsc2022" }
        default { throw "Unknown Windows version $version" }
    }
}

Export-ModuleMember -Function Log-Info
Export-ModuleMember -Function Log-Warn
Export-ModuleMember -Function Log-Error
Export-ModuleMember -Function Log-Fatal
Export-ModuleMember -Function Get-RootDir
Export-ModuleMember -Function Get-RKE2Version
Export-ModuleMember -Function Get-RKE2Artifact
Export-ModuleMember -Function Run-DockerLogin
Export-ModuleMember -Function Run-Script
Export-ModuleMember -Function Get-Environment
Export-ModuleMember -Function Get-WindowsVersion
