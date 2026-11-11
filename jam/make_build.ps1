$ErrorActionPreference = "Stop"

$ProjectDir    = "C:\Users\cleme\Workspace\raycasting\jam"
$BuildDir      = Join-Path $ProjectDir "build"
$LoveFile      = Join-Path $BuildDir "game.love"
$WebDir        = Join-Path $BuildDir "web"
$Title         = "jam"
$MemoryBytes   = 67108864      # 64 MB
$Compatibility = $true # no pthreads for itch

$ExcludeDirs = @("build", ".git", ".vscode", ".idea")
$ExcludeExts = @(".ps1", ".tmx", ".md", ".love")

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw "Node.js not found. Install it from https://nodejs.org"
}
$NpxCmd = (Get-Command npx.cmd -ErrorAction Stop).Source

# output dirs
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
if (Test-Path $LoveFile) { Remove-Item $LoveFile -Force }
if (Test-Path $WebDir)   { Remove-Item $WebDir -Recurse -Force }

# zip
Write-Host "Packing $LoveFile ..."
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path $ProjectDir).Path.TrimEnd('\')
$zip  = [System.IO.Compression.ZipFile]::Open($LoveFile, [System.IO.Compression.ZipArchiveMode]::Create)
$count = 0
try {
    Get-ChildItem -Path $root -Recurse -File -Force | ForEach-Object {
        $rel = $_.FullName.Substring($root.Length + 1)
        $first = $rel.Split('\')[0]

        if ($ExcludeDirs -contains $first)              { return }
        if ($ExcludeExts -contains $_.Extension.ToLower()) { return }

        $entryName = $rel -replace '\\', '/'
        $entry  = $zip.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
        $out    = $entry.Open()
        $in     = [System.IO.File]::OpenRead($_.FullName)
        try { $in.CopyTo($out) } finally { $in.Dispose(); $out.Dispose() }
        $count++
    }
}
finally {
    $zip.Dispose()
}
Write-Host "Packed $count files."

if (-not ($zip -and (Test-Path $LoveFile))) { throw "Failed to create $LoveFile" }

# run love.js
$args = @("--yes", "love.js", "-t", $Title, "-m", $MemoryBytes)
if ($Compatibility) { $args += "-c" }
$args += @($LoveFile, $WebDir)

Write-Host "Running: npx $($args -join ' ')"
& $NpxCmd @args
if ($LASTEXITCODE -ne 0) { throw "love.js failed with exit code $LASTEXITCODE" }

Write-Host ""
Write-Host "Done. Web build in: $WebDir"
Write-Host "Test locally:  cd `"$WebDir`"; python -m http.server 8000   (then open http://localhost:8000)"
if (-not $Compatibility) {
    Write-Host "NOTE: non-compat build needs COOP/COEP headers; python's http.server does not send them."
}