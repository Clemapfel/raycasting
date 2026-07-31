$sourceDir = "C:\Users\cleme\Workspace\raycasting\synth"
$targetDir = "C:\Users\cleme\AppData\Local\SuperCollider\Extensions"

if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

# Remove existing symlinks in the target directory
Get-ChildItem -Path $targetDir -File -Force | Where-Object {
    $_.LinkType -eq "SymbolicLink"
} | ForEach-Object {
    try {
        Remove-Item -Path $_.FullName -Force -ErrorAction Stop
        Write-Host "removed old symlink: $($_.FullName)"
    }
    catch {
        Write-Host "failed to remove symlink: $($_.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Create new symlinks
Get-ChildItem -Path $sourceDir -Filter "*.sc" -File | ForEach-Object {
    $linkPath = Join-Path $targetDir $_.Name
    $targetPath = $_.FullName

    if (-not (Test-Path $linkPath)) {
        try {
            New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath -ErrorAction Stop | Out-Null
            Write-Host "succesfully linked: $linkPath -> $targetPath"
        }
        catch {
            Write-Host "failed to link: $($_.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
