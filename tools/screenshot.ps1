# Capture the screen (or one window) so Claude can look at it.
#
# Claude cannot see your screen on its own. This writes a PNG that it
# reads. Nothing is captured unless you or it runs this, and nothing
# leaves the machine -- the file stays in a local folder.
#
# Usage:
#   .\screenshot.ps1                      # the Cinder & Crown window
#   .\screenshot.ps1 -Window "Godot"      # first window whose title matches
#   .\screenshot.ps1 -Desktop             # the whole screen (shows everything)
#   .\screenshot.ps1 -Seconds 8           # record 8s of video instead
#
# Prefer a window over -Desktop: it keeps the rest of your screen private
# and gives a much sharper image of the game.

param(
    [string]$Window = "Cinder & Crown",
    [switch]$Desktop,
    [int]$Seconds = 0,
    [string]$OutDir = "$env:TEMP\claude-shots"
)

$ffmpeg = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $ffmpeg) { $ffmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source }
if (-not $ffmpeg) { Write-Error "ffmpeg not found."; exit 1 }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format "HHmmss"

if ($Desktop) {
    $input = @("-f", "gdigrab", "-i", "desktop")
    $label = "desktop"
} else {
    # gdigrab matches the window title exactly, so resolve a partial match first.
    $proc = Get-Process | Where-Object {
        $_.MainWindowTitle -and $_.MainWindowTitle -like "*$Window*"
    } | Select-Object -First 1
    if (-not $proc) {
        Write-Host "No window matching '$Window'. Open windows:"
        Get-Process | Where-Object { $_.MainWindowTitle } |
            Select-Object -ExpandProperty MainWindowTitle | ForEach-Object { "  $_" }
        exit 1
    }
    $title = $proc.MainWindowTitle
    Write-Host "capturing window: $title"
    $input = @("-f", "gdigrab", "-i", "title=$title")
    $label = "window"
}

if ($Seconds -gt 0) {
    $out = Join-Path $OutDir "$label-$stamp.mp4"
    & $ffmpeg -v error -framerate 30 @input -t $Seconds -pix_fmt yuv420p $out -y
} else {
    $out = Join-Path $OutDir "$label-$stamp.png"
    & $ffmpeg -v error -framerate 1 @input -frames:v 1 $out -y
}

if (Test-Path $out) {
    "{0}  ({1:N2} MB)" -f $out, ((Get-Item $out).Length / 1MB)
} else {
    Write-Error "capture failed"
}
