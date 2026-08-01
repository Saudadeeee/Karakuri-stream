# Build Guide — Karakuri Stream

Two editions from one codebase, split by `QualityManager` (autoload):

| Edition | Profile | What differs |
|---|---|---|
| **Web (LITE)** | auto-detected via `OS.has_feature("web")` | shadows OFF, glow OFF, fill light OFF, particles halved, cloud-sea mesh halved. Measured +33% FPS in-game vs full profile on WebGL. |
| **App (FULL)** | desktop / Android / iOS | everything on (native GL is far faster than WebGL) |

> Do NOT enable `scaling_3d` on the web build — on WebGL compatibility it forces
> an offscreen render target and is SLOWER than native resolution (measured).

## Requirements (one-time)
- Godot **4.7.1 official** binary (the Steam build swallows export error text) —
  kept at `D:\Apps\Godot\Godot_v4.7.1-stable_win64_console.exe` on this machine
- Export templates 4.7.1.stable installed (`%APPDATA%/Godot/export_templates/4.7.1.stable/`)

## Web (lite edition)
```
godot --headless --path . --export-release "Web" build/web/index.html
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
`build/.gdignore` is committed (`git add -f`, since `build/` itself is
gitignored). Without it Godot treats `build/web/*.png` as project assets,
generates `.import` files next to them, and folds them into the *next* export —
each build a little bigger than the last. If you add another output directory,
give it a `.gdignore` too.

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
