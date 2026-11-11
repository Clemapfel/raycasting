param(
    [switch]$Performance
)

$ErrorActionPreference = "Stop"

$ProjectRoot = $PSScriptRoot

$BuildDir = Join-Path $ProjectRoot "build"
$OutDir   = Join-Path $BuildDir "out"

$LoveFile = Join-Path $OutDir "raycasting.love"

$WindowsSource = Join-Path $BuildDir "windows\love12"
$LinuxSource   = Join-Path $BuildDir "linux\love12"

$WindowsOut = Join-Path $OutDir "windows"
$LinuxOut   = Join-Path $OutDir "linux"
$WebOut     = Join-Path $OutDir "web"

$GameTitle = "Raycasting"
$ExeName   = "raycasting"

$Memory = 67108864
$Port   = 8765

$MainLua = Join-Path $ProjectRoot "main.lua"

function Format-Path {
    param([string]$Path)

    if ($Path.StartsWith($ProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $Relative = $Path.Substring($ProjectRoot.Length).TrimStart('\', '/')

        if ($Relative -eq "") {
            return "."
        }

        return $Relative
    }

    return $Path
}

function Assert-Path {
    param(
        [string]$Path,
        [string]$Description
    )

    if (!(Test-Path -LiteralPath $Path)) {
        throw "$Description not found: $(Format-Path $Path)"
    }
}

function New-FusedExecutable {
    param(
        [Parameter(Mandatory)]
        [string]$BaseBinary,

        [Parameter(Mandatory)]
        [string]$LoveArchive,

        [Parameter(Mandatory)]
        [string]$Output
    )

    $OutputStream = [System.IO.File]::Open(
            $Output,
            [System.IO.FileMode]::Create,
            [System.IO.FileAccess]::Write
    )

    try {
        foreach ($Source in @($BaseBinary, $LoveArchive)) {

            $InputStream = [System.IO.File]::OpenRead($Source)

            try {
                $InputStream.CopyTo($OutputStream)
            }
            finally {
                $InputStream.Dispose()
            }
        }
    }
    finally {
        $OutputStream.Dispose()
    }
}

Assert-Path $MainLua "main.lua"
Assert-Path $WindowsSource "Windows runtime"
Assert-Path $LinuxSource "Extracted Linux runtime"

$npxCommand = Get-Command npx.cmd -ErrorAction SilentlyContinue

if (!$npxCommand) {
    throw "npx.cmd not found. Install Node.js and npm."
}

$Firefox = Get-Command firefox -ErrorAction SilentlyContinue

if (!$Firefox) {
    $FirefoxPath = Join-Path $env:ProgramFiles "Mozilla Firefox\firefox.exe"

    if (!(Test-Path $FirefoxPath)) {
        $FirefoxPath = Join-Path ${env:ProgramFiles(x86)} "Mozilla Firefox\firefox.exe"
    }

    if (!(Test-Path $FirefoxPath)) {
        $FirefoxPath = $null
    }
}
else {
    $FirefoxPath = $Firefox.Source
}

Write-Host "Preparing output: $(Format-Path $OutDir)"

if (Test-Path $OutDir) {
    Remove-Item $OutDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $OutDir |
        Out-Null

Write-Host "Creating archive: $(Format-Path $LoveFile)"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Archive = [System.IO.Compression.ZipFile]::Open(
        $LoveFile,
        [System.IO.Compression.ZipArchiveMode]::Create
)

try {
    $Files = Get-ChildItem `
        -LiteralPath $ProjectRoot `
        -File `
        -Recurse

    foreach ($File in $Files) {

        $RelativePath = $File.FullName.Substring(
                $ProjectRoot.Length
        ).TrimStart('\', '/')

        $TopLevel = $RelativePath.Split(
                [char[]]@('\', '/'),
                [System.StringSplitOptions]::RemoveEmptyEntries
        )[0]

        if ($TopLevel -in @(
            "build",
            ".git",
            "node_modules"
        )) {
            continue
        }

        if ($RelativePath -eq "make.ps1") {
            continue
        }

        $EntryName = $RelativePath.Replace('\', '/')

        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $Archive,
                $File.FullName,
                $EntryName
        ) | Out-Null
    }
}
finally {
    $Archive.Dispose()
}

Write-Host "Archive done: $(Format-Path $LoveFile)"

Write-Host "Building Windows: $(Format-Path $WindowsOut)"

New-Item -ItemType Directory -Force -Path $WindowsOut |
        Out-Null

Copy-Item `
    -Path (Join-Path $WindowsSource "*") `
    -Destination $WindowsOut `
    -Recurse `
    -Force

$WindowsLoveExe = Join-Path $WindowsOut "love.exe"

Assert-Path $WindowsLoveExe "Windows love.exe"

$WindowsGameExe = Join-Path $WindowsOut "$ExeName.exe"

New-FusedExecutable `
    -BaseBinary $WindowsLoveExe `
    -LoveArchive $LoveFile `
    -Output $WindowsGameExe

Write-Host "Windows done: $(Format-Path $WindowsGameExe)"

Write-Host "Building Linux: $(Format-Path $LinuxOut)"

New-Item -ItemType Directory -Force -Path $LinuxOut |
        Out-Null

Copy-Item `
    -Path (Join-Path $LinuxSource "*") `
    -Destination $LinuxOut `
    -Recurse `
    -Force

$LinuxLoveExe = Join-Path $LinuxOut "bin\love"
$LinuxGameExe = Join-Path $LinuxOut "bin\$ExeName"

Assert-Path $LinuxLoveExe "Linux love executable"

New-FusedExecutable `
    -BaseBinary $LinuxLoveExe `
    -LoveArchive $LoveFile `
    -Output $LinuxGameExe

Copy-Item `
    -LiteralPath $LinuxGameExe `
    -Destination $LinuxLoveExe `
    -Force

@"
After copying this folder to Linux, execute:

chmod +x AppRun bin/love bin/$ExeName

Then launch using:

./AppRun

Alternatively:

./bin/$ExeName
"@ | Set-Content `
    -Path (Join-Path $LinuxOut "README-LINUX.txt") `
    -Encoding UTF8

Write-Host "Linux done: $(Format-Path $LinuxGameExe)"

Write-Host "Building web: $(Format-Path $WebOut)"

New-Item -ItemType Directory -Force -Path $WebOut |
        Out-Null

$LoveArgs = @(
    "-t", $GameTitle,
    "-m", "$Memory"
)

if (!$Performance) {
    $LoveArgs += "-c"
}

$LoveArgs += @(
    $LoveFile,
    $WebOut
)

Push-Location $ProjectRoot

try {
    & $npxCommand.Source `
        --yes `
        --package=love.js `
        -- `
        love.js.cmd `
        @LoveArgs

    $LoveJsExitCode = $LASTEXITCODE

    if ($LoveJsExitCode -ne 0) {
        throw "love.js failed with exit code $LoveJsExitCode"
    }

    $IndexHtml = Join-Path $WebOut "index.html"

    if (!(Test-Path $IndexHtml)) {
        Get-ChildItem $WebOut -Recurse |
                Select-Object @{ Name = "Path"; Expression = { Format-Path $_.FullName } }

        throw "love.js completed but did not create index.html"
    }
}
finally {
    Pop-Location
}

Write-Host "Web done: $(Format-Path $WebOut)"

Write-Host "Verifying web: $(Format-Path $WebOut)"

$RequiredFiles = @(
    "index.html",
    "game.js",
    "game.data",
    "love.js",
    "love.wasm"
)

foreach ($File in $RequiredFiles) {
    $Path = Join-Path $WebOut $File

    if (!(Test-Path $Path)) {
        throw "Missing web build output: $File"
    }
}

Write-Host "Web verified: $(Format-Path $WebOut)"

Write-Host "Starting server for: $(Format-Path $WebOut)"

$Python = Get-Command python -ErrorAction SilentlyContinue

if (!$Python) {
    $Python = Get-Command python3 -ErrorAction SilentlyContinue
}

if (!$Python) {
    throw "Python is required to host the web build."
}

$Url = "http://127.0.0.1:$Port/"

$ExistingConnection = Get-NetTCPConnection `
    -LocalPort $Port `
    -State Listen `
    -ErrorAction SilentlyContinue

if ($ExistingConnection) {
    throw "Port $Port is already occupied."
}

Write-Host "Serving $(Format-Path $WebOut) at $Url"

$Server = Start-Process `
    -FilePath $Python.Source `
    -ArgumentList @(
    "-m",
    "http.server",
    "$Port",
    "--bind",
    "127.0.0.1"
) `
    -WorkingDirectory $WebOut `
    -PassThru `
    -NoNewWindow

Start-Sleep -Seconds 2

if ($Server.HasExited) {
    throw "HTTP server exited unexpectedly."
}

Write-Host "Opening Firefox: $Url"

if ($FirefoxPath) {
    Start-Process `
        -FilePath $FirefoxPath `
        -ArgumentList $Url
}
else {
    Write-Host "Open manually: $Url"
}

Write-Host "Done: build output in $(Format-Path $OutDir)"

try {
    while (!$Server.HasExited) {
        Start-Sleep -Seconds 1
    }
}
finally {
    if (!$Server.HasExited) {
        Stop-Process -Id $Server.Id -Force
    }
}