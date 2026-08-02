# Build every shippable platform into export/<platform>/ and zip each one into
# export/dist/. One command, no editor. See docs/BUILD.md for the whys.
#
#   pwsh tools/package.ps1                  # all platforms
#   pwsh tools/package.ps1 -Only windows    # one platform
#   pwsh tools/package.ps1 -Godot "C:/path/Godot_console.exe"
#
# iOS is absent on purpose: Apple's signing toolchain is macOS-only.

param(
    [string]   $Godot = $(if ($env:GODOT) { $env:GODOT } else { "D:/Apps/Godot/Godot_v4.7.1-stable_win64_console.exe" }),
    [string[]] $Only  = @("windows", "linux", "android", "web")
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root "export/dist"

if (-not (Test-Path $Godot)) {
    throw "Godot binary not found: $Godot`nPass -Godot <path> or set `$env:GODOT. Use an OFFICIAL build - the Steam build swallows export error text."
}

# preset name, output subdir, output file, export mode, what to ship
$targets = @(
    @{ key = "windows"; preset = "Windows Desktop"; dir = "windows"; out = "KarakuriStream.exe";     mode = "--export-release" }
    @{ key = "linux";   preset = "Linux";           dir = "linux";   out = "KarakuriStream.x86_64";  mode = "--export-release" }
    @{ key = "android"; preset = "Android";         dir = "android"; out = "karakuri-stream.apk";    mode = "--export-debug"   }
    @{ key = "web";     preset = "Web";             dir = "web";     out = "index.html";             mode = "--export-release" }
)

# Set-Content -Encoding UTF8 on Windows PowerShell 5.1 emits a BOM, which shows
# up as a stray glyph on the first line of a README a player opens. Write plain.
function WriteText([string]$path, [string]$text) {
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Human([long]$bytes) {
    if ($bytes -ge 1MB) { return "{0:N1} MB" -f ($bytes / 1MB) }
    return "{0:N0} KB" -f ($bytes / 1KB)
}

New-Item -ItemType Directory -Force -Path $dist | Out-Null
# Godot must never re-import its own output as project assets.
New-Item -ItemType File -Force -Path (Join-Path $root "export/.gdignore") | Out-Null

$results = @()

foreach ($t in $targets) {
    if ($Only -notcontains $t.key) { continue }

    $outDir  = Join-Path $root "export/$($t.dir)"
    $outFile = Join-Path $outDir $t.out

    # Wipe the platform dir so a rename or a dropped asset can't leave a stale
    # file behind that then gets zipped into the package.
    if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    Write-Host "`n=== $($t.preset) ===" -ForegroundColor Cyan
    & $Godot --headless --path $root $t.mode $t.preset $outFile 2>&1 |
        Select-String -Pattern "ERROR|WARNING: |error:" -CaseSensitive |
        Where-Object { $_ -notmatch "port9080|build tools" } |
        ForEach-Object { Write-Host $_ -ForegroundColor Yellow }

    if (-not (Test-Path $outFile)) { throw "$($t.preset): export produced no $($t.out) - rerun without the log filter to see why." }

    # Per-platform extras a player actually needs.
    switch ($t.key) {
        "windows" {
            WriteText (Join-Path $outDir "README.txt") @"
KARAKURI STREAM - Windows (x86_64)

Run KarakuriStream.exe. Keep the .pck next to it - it IS the game.
Unsigned build: SmartScreen may warn. More info -> Run anyway.
"@
        }
        "linux" {
            # LF endings + exec bit are what make this runnable after unzip.
            $sh = "#!/bin/sh`nexec `"`$(dirname `"`$0`")/KarakuriStream.x86_64`" `"`$@`"`n"
            [System.IO.File]::WriteAllText((Join-Path $outDir "run.sh"), $sh)
            WriteText (Join-Path $outDir "README.txt") @"
KARAKURI STREAM - Linux (x86_64)

chmod +x KarakuriStream.x86_64 run.sh && ./run.sh
(the zip cannot carry the exec bit, hence the chmod; run.sh just launches the
binary from its own folder so you can start it from anywhere)
Keep the .pck next to the binary - it IS the game.
"@
        }
        "web" {
            WriteText (Join-Path $outDir "README.txt") @"
KARAKURI STREAM - Web (LITE profile)

Upload the whole folder to any static host (itch.io, GitHub Pages, S3).
No COOP/COEP headers needed (web_nothreads template).
Serve index.wasm with gzip/brotli or players download 37 MB raw.
"@
        }
    }

    # Package. Android ships as the .apk itself - zipping it helps nobody.
    if ($t.key -eq "android") {
        $zip = Join-Path $dist "KarakuriStream-android-arm64.apk"
        Copy-Item $outFile $zip -Force
    } else {
        $zip = Join-Path $dist "KarakuriStream-$($t.key).zip"
        if (Test-Path $zip) { Remove-Item -Force $zip }
        Compress-Archive -Path (Join-Path $outDir "*") -DestinationPath $zip
    }

    $payload = (Get-ChildItem -Recurse -File $outDir | Measure-Object Length -Sum).Sum
    $results += [pscustomobject]@{
        Platform = $t.key
        Folder   = "export/$($t.dir)"
        Payload  = Human $payload
        Package  = "export/dist/" + (Split-Path -Leaf $zip)
        Zipped   = Human (Get-Item $zip).Length
    }
}

New-Item -ItemType Directory -Force -Path (Join-Path $root "export/ios") | Out-Null
WriteText (Join-Path $root "export/ios/README.md") @"
# iOS - build this on a Mac

Windows cannot produce an .ipa: Apple's signing toolchain is macOS-only, so
this folder stays empty on this machine. The project itself is ready.

1. Mac with Xcode + an Apple Developer account, Godot 4.7.1 (official).
2. Open the project, Project -> Export -> iOS.
3. Fill App Store Team ID + signing identity (the preset leaves them blank).
4. Export -> the preset has export_project_only=true, so you get an Xcode
   project -> open it -> Archive -> Distribute App.

Bundle id: com.saudade.karakuristream | arm64 | iPad+iPhone.
Touch controls already work: one finger orbits, two fingers pinch-zoom, tap places.
"@

Write-Host ""
$results | Format-Table -AutoSize
Write-Host "iOS: needs a Mac with Xcode - see export/ios/README.md." -ForegroundColor DarkGray
