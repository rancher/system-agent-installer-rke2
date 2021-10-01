$ErrorActionPreference = 'Stop'

if (-not $env:ARCH) {
    $env:ARCH = "amd64"
}
$env:OS = "windows"

$FALLBACK_VERSION = "v1.20.4+rke2r1"

# This version script expects either a tag of format: <rke2-version> or no tag at all.
$TREE_STATE = "clean"
$COMMIT = $env:DRONE_COMMIT
$TAG = $env:DRONE_TAG

if (-not $TAG) {
    if (Test-Path -Path $env:DAPPER_SOURCE\.git) {
        Push-Location $env:DAPPER_SOURCE
        if ("$(git status --porcelain --untracked-files=no)") {
            $env:DIRTY = "dirty"
            $TREE_STATE = "dirty"
        }

        if (-not $GIT_TAG -and $TREE_STATE -eq "clean") {
            $TAG = $(git tag -l --contains HEAD | Select-Object -First 1)
        }

        $COMMIT = $(git rev-parse --short HEAD)
        if (-not $COMMIT) {
            $COMMIT = $(git rev-parse --short HEAD)
            Write-Host $COMMIT
            exit 1
        }
        Pop-Location
    }

    if (-not $TAG) {
        if ($TREE_STATE -eq "clean") {
            $VERSION = $TAG # We will only accept the tag as our version if the tree state is clean and the tag is in fact defined.
        }
    }    
}
else {
    $VERSION = $TAG
}

# In the event of us doing a build with no corresponding tag that we can discern, we'll go ahead and just build the package assuming we were dealing with master.
# This means we'll go to GitHub and pull the latest RKE2 release, and parse it to what we are expecting.
if (-not $VERSION) {
    if (-not $COMMIT) {
        # Validate our commit hash to make sure it's actually known, otherwise our version will be off.
        Write-Host "Unknown commit hash. Exiting."
        exit 1
    }

    # If our GitHub API Rate Limit remaining is 0, don't even try calling the GitHub API.
    if ( $(Invoke-RestMethod -Uri https://api.github.com/rate_limit).rate.remaining -eq 0) {
        $VERSION = $FALLBACK_VERSION
    }
    else {
        $VERSION = $($(Invoke-RestMethod -Uri https://api.github.com/repos/rancher/rke2/releases) | Sort-Object tag_name -Descending | Select-Object tag_name)[0].tag_name
        if (-not $VERSION) {
            # Fall back to a known good RKE2 version because we had an error pulling the latest
            $VERSION = $FALLBACK_VERSION
        }
    }
}
else {
    # validate the tag format and create our VERSION variable
    if (-not ($TAG -match '^v[0-9]{1}\.[0-9]{2}\.[0-9]+-*[a-zA-Z0-9]*\+rke2r[0-9]+$')) {
        Write-Host "Tag does not match our expected format. Exiting."
        exit 1
    }

    $VERSION = $TAG
}

$env:URI_VERSION = [uri]::EscapeDataString($VERSION)
$VERSION = $VERSION.Replace('+', '-')

#export stuff out 
$env:VERSION = $VERSION
$env:COMMIT = $COMMIT
$env:REPO = "rancher"
$env:IMAGE = "$REPO/system-agent-installer-rke2:$VERSION"
