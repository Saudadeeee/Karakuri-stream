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

## Web (lite edition)
```
godot --headless --path . --export-release "Web" build/web/index.html
```
- `web_nothreads` template → no SharedArrayBuffer → hosts anywhere (itch.io, GitHub Pages, any static server), no COOP/COEP headers needed.
- ~51 MB. Requires the project setting `textures/vram_compression/import_etc2_astc=true` (already on).

## Android (full edition)
One-time machine setup (already done on this machine):
- JDK (17+; jdk-21 works) + `export/android/java_sdk_path` in Editor Settings
- Android SDK with `build-tools;34.0.0` + `platform-tools`
  (`sdkmanager --sdk_root=%LOCALAPPDATA%/Android/Sdk "build-tools;34.0.0" "platform-tools"`)
- Debug keystore at `%APPDATA%/Godot/keystores/debug.keystore`
  (alias `androiddebugkey`, pass `android`)

Build:
```
godot --headless --path . --export-debug "Android" build/android/karakuri-stream.apk
```
- arm64-v8a, signed with the debug keystore → installs directly on any device
  (enable "install unknown apps"). ~41 MB.
- For a Play-Store release: create a release keystore, fill
  `keystore/release*` in the preset, and use `--export-release`.

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
