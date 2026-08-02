# Build Guide — Karakuri Stream

Two editions from one codebase, split by `QualityManager` (autoload):

| Edition | Profile | What differs |
|---|---|---|
| **Web (LITE)** | auto-detected via `OS.has_feature("web")` | shadows OFF, glow OFF, fill light OFF, particles halved, cloud-sea mesh halved. Measured +33% FPS in-game vs full profile on WebGL. |
| **App (FULL)** | desktop / Android / iOS | everything on (native GL is far faster than WebGL) |

> Do NOT enable `scaling_3d` on the web build — on WebGL compatibility it forces
> an offscreen render target and is SLOWER than native resolution (measured).

## Requirements (one-time)
- Godot **4.7.1 official** binary (the Steam build swallows export error text)
- Export templates 4.7.1.stable installed (`%APPDATA%/Godot/export_templates/4.7.1.stable/`)
  — the **full** `.tpz`, not a web/android-only subset

## Everything at once
```
powershell -ExecutionPolicy Bypass -File tools/package.ps1
powershell -ExecutionPolicy Bypass -File tools/package.ps1 -Only windows,web
powershell -ExecutionPolicy Bypass -File tools/package.ps1 -Godot "C:/path/Godot_console.exe"
```
Builds all four buildable platforms, drops a player-facing `README.txt` in each
folder, and zips each one. It wipes a platform folder before rebuilding it, so a
renamed or deleted file can never survive into the next package. Godot binary:
`-Godot`, else `$env:GODOT`, else `D:/Apps/Godot/Godot_v4.7.1-stable_win64_console.exe`.

```
export/
  windows/  KarakuriStream.exe + .pck + README.txt
  linux/    KarakuriStream.x86_64 + .pck + run.sh + README.txt
  android/  karakuri-stream.apk
  web/      index.* static site + README.txt
  ios/      README.md only — needs a Mac (see below)
  dist/     the shippable archives
```

**Measured** (4.7.1, `export_presets.cfg` as committed):

| Platform | Folder | Package | Zipped |
|---|---|---|---|
| Windows | 109.5 MB | `dist/KarakuriStream-windows.zip` | 41.5 MB |
| Linux | 75.5 MB | `dist/KarakuriStream-linux.zip` | 32.3 MB |
| Android | 32.7 MB | `dist/KarakuriStream-android-arm64.apk` | 32.5 MB |
| Web | 43.4 MB | `dist/KarakuriStream-web.zip` | 14.9 MB |

The rest of this document is the per-platform detail behind that script.

## Web (lite edition)
```
godot --headless --path . --export-release "Web" export/web/index.html
```
- `web_nothreads` template → no SharedArrayBuffer → hosts anywhere (itch.io, GitHub Pages, any static server), no COOP/COEP headers needed.
- Requires the project setting `textures/vram_compression/import_etc2_astc=true` (already on).

**Measured size** (4.7.1, release):

| Part | Size | Note |
|---|---|---|
| `index.wasm` | 37.7 MB | the Godot engine itself — fixed cost, not affected by your assets. Serve it gzip/brotli (~10 MB on the wire); a plain static server sending it raw is why a web build "feels" huge |
| `index.pck` | 5.1 MB | all game content. Was 14.0 MB before the asset cleanup — the single biggest item was one 22 MB gear-rattle WAV (24-bit/96 kHz), now a 395 KB OGG |
| total on disk | ~44 MB | |

`exclude_filter` in every preset drops `tests/*` and the model-authoring sources
(`blockbench/*`, `generated/*.py`, `*.bbmodel`) — those are build inputs, and
players should never receive the regression suite. Verified: `regression` appears
0× in the export log.

### Do not let Godot scan the export output
`export/.gdignore` is committed (`git add -f`, since `export/` itself is
gitignored). Without it Godot treats `export/web/*.png` as project assets,
generates `.import` files next to them, and folds them into the *next* export —
each build a little bigger than the last. If you add another output directory,
give it a `.gdignore` too.

## Desktop (full edition)
Templates for every desktop target now live in
`%APPDATA%/Godot/export_templates/4.7.1.stable/` (installed from
`Godot_v4.7.1-stable_export_templates.tpz`, 1.28 GB — the earlier install only
had web/android/ios, which is why desktop export failed with
*"No export template found"*).

```
mkdir -p export/windows export/linux
godot --headless --path . --export-release "Windows Desktop" export/windows/KarakuriStream.exe
godot --headless --path . --export-release "Linux"           export/linux/KarakuriStream.x86_64
```
The output directory must exist first — Godot does not create it and fails with
*"Prepare Template: The given export path doesn't exist."*

**Measured** (4.7.1, release, x86_64):

| Target | Binary | .pck | Ship |
|---|---|---|---|
| Windows | `KarakuriStream.exe` 104 MB | 5.4 MB | both files, same folder |
| Linux | `KarakuriStream.x86_64` 70 MB | 5.4 MB | both files + `chmod +x` |

- The `.pck` is the whole game; the binary is the engine. Ship them together, or
  set `binary_format/embed_pck=true` in the preset for a single self-contained
  file (same total size).
- `debug/export_console_wrapper=0` — no second console window on Windows.
- Windows builds are unsigned: SmartScreen shows "unknown publisher" until you
  buy a code-signing cert and fill `codesign/*` in the preset.
- Verify a build without a display: `KarakuriStream.exe --headless --quit-after 120`
  (exit 0 = boots, autoloads init, main menu loads).

### macOS
No preset yet — its options are Xcode-SDK-version specific, so add it in the
editor (Project → Export → Add → macOS) rather than by hand. `macos.zip` is
installed, so a Windows machine *can* produce an unsigned `.app`/`.zip`, but
Gatekeeper blocks it on any other Mac; signing + notarization need a Mac with
Xcode and an Apple Developer account (same constraint as iOS below).

## Android (full edition)
One-time machine setup (already done on this machine):
- JDK (17+; jdk-21 works) + `export/android/java_sdk_path` in Editor Settings
- Android SDK with `build-tools;34.0.0` + `platform-tools`
  (`sdkmanager --sdk_root=%LOCALAPPDATA%/Android/Sdk "build-tools;34.0.0" "platform-tools"`)
- Debug keystore at `%APPDATA%/Godot/keystores/debug.keystore`
  (alias `androiddebugkey`, pass `android`)

Build:
```
godot --headless --path . --export-debug "Android" export/android/karakuri-stream.apk
```
- arm64-v8a, signed with the debug keystore → installs directly on any device
  (enable "install unknown apps"). 32 MB (was 41 MB before the asset cleanup).
  Install: `adb install -r export/android/karakuri-stream.apk`.

### Play Store release (.aab)
Google Play refuses APKs for new apps — it wants an Android App Bundle, and an
`.aab` needs the Gradle build, not the prebuilt template:
1. Release keystore (keep it forever — losing it means losing the app listing):
   ```
   keytool -genkeypair -v -keystore karakuri-release.keystore -alias karakuri \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
   Store it **outside** the repo; put the path/user/password in
   `keystore/release*` in the preset, or the env vars
   `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` / `_USER` / `_PASSWORD` so no secret
   lands in `export_presets.cfg` (which is committed).
2. In the editor: Project → Install Android Build Template (writes `android/`).
3. In the Android preset set `gradle_build/use_gradle_build=true` and
   `gradle_build/export_format=1` (AAB).
4. Bump `version/code` (integer, must increase every upload) and `version/name`.
5. ```
   godot --headless --path . --export-release "Android" export/android/karakuri-stream.aab
   ```
Play also requires `architectures/armeabi-v7a` on **or** an arm64-only listing —
arm64-only is fine today and is what the preset ships.

## iOS (full edition) — REQUIRES A MAC
Cross-building an .ipa from Windows is impossible (Apple's signing toolchain
is macOS-only). The project is prepared:
- `ios.zip` export template installed, preset "iOS" configured
  (`com.saudade.karakuristream`, `export_project_only=true`).

On a Mac with Xcode + an Apple Developer account:
1. Open this project in Godot 4.7.1 (macOS).
2. Project → Export → iOS → set your Team ID + signing identity.
3. Export → produces an Xcode project → open it → Archive → distribute.
Touch controls (one-finger orbit, two-finger pinch zoom, tap to place) already work.

## Tests
```
godot --path . tests/regression.tscn     # expect "REGRESS ALL OK", 0 errors
```
