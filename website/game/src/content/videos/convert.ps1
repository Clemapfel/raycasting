param([Parameter(Mandatory)][string]$InputFile)

$out = [IO.Path]::ChangeExtension($InputFile, $null).TrimEnd('.') + "_web.mp4"

ffmpeg -i $InputFile -an `
  -c:v libx264 -profile:v high -level 4.0 -crf 23 -preset slow `
  -pix_fmt yuv420p -movflags +faststart $out