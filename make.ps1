if (!(Test-Path .dapper.exe)) {
    $dapperURL = "https://releases.rancher.com/dapper/latest/dapper-Windows-x86_64.exe"
    Write-Host "no .dapper.exe, downloading $dapperURL"
    curl.exe -sfL -o .dapper.exe $dapperURL
}

if ($args.Count -eq 0) {
    $args = @("build")
}

if ($args[0] -eq "build") {
    Write-Host "Running build"
    .dapper.exe -f Dockerfile-windows.dapper build
    scripts\windows\build.ps1
    exit
}

if ($args[0] -eq "publish") {
    Write-Host "Running publish"
    .dapper.exe -f Dockerfile-windows.dapper publish
    scripts\windows\publish.ps1
    exit
}

if ($args[0] -eq "clean") {
    Remove-Item .dapper.exe
    Remove-Item Dockerfile-windows.dapper* -Exclude "Dockerfile-windows.dapper"
}

if (Test-Path scripts\$($args[0]).ps1) {
    .dapper.exe -f Dockerfile-windows.dapper $($args[0])
    exit
}