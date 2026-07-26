# Karakuri Stream

A calm 3D sandbox where you build a Japanese water-garden on a floating island and
let it play itself. Place a bamboo spout, and the stream it pours falls cell by cell
through pipes, spins wooden gears, tips a shishi-odoshi, rings bells and wind-chimes,
and drives a music box — a *karakuri* (からくり, clockwork automaton) you assemble
one block at a time. No score, no fail state. You build the machine; the machine
makes the music.

Built with **Godot 4.7** / GDScript, `gl_compatibility` renderer, no external addons.

## Run

```
godot --path .                        # opens the main menu (scenes/main_menu.tscn)
godot --path . tests/regression.tscn  # regression suite → expect "REGRESS ALL OK", 0 errors
```

Use an **official** Godot 4.7.1 binary. The Steam build swallows export error text.

## Controls

| Input | Action |
|---|---|
| Left click | place a block |
| Right click | remove a block |
| Middle drag | orbit camera |
| Scroll | zoom |
| `1`–`0`, `-`, `=` | pick material (Wood, Water, Source, Pipe, Gear, Bell, Jelly, Shishi, Drum, Chime, Music box, Scoop) |
| Same key / icon again | cycle that material's variant (pipe open↔closed, wood→dirt→moss→stone, chime note …) |
| `Ctrl+Z` | undo |
| `H` | hide UI · `U` move the sun · `P` screenshot |

16 block types, 4 map themes (Spring / Autumn / Snow / Night). Progress saves to
`user://` — save, load, and delete from the pause menu.

## Build

Two editions from one codebase, split by the `QualityManager` autoload:
**Web (LITE)** drops shadows/glow and halves particles; **desktop / Android / iOS
(FULL)** runs everything. Output goes to `build/`.

```
godot --headless --path . --export-release "Web"     build/web/index.html
godot --headless --path . --export-debug   "Android" build/android/karakuri-stream.apk
```

Web must be served over HTTP (WASM/CORS blocks `file://`). Web build is ~44 MB on
disk: 37.7 MB of that is `index.wasm`, the engine itself — serve it gzipped and it
lands around 10 MB on the wire. Game content (`index.pck`) is 5.1 MB. Full
per-platform setup, keystores, and the measured performance traps:
**[docs/BUILD.md](docs/BUILD.md)**.

> `build/.gdignore` is committed on purpose (`git add -f`). Without it Godot
> re-imports the PNGs inside the export output back into the project, which then
> get baked into the *next* export — a loop that silently inflates build size.

## Docs

| File | What it is |
|---|---|
| [docs/CODEMAP.md](docs/CODEMAP.md) | **Read first before touching code.** Current-state map of every scene, autoload, and shader, plus the core invariants (grid convention, stream routing, isosurface rules) — break one and the whole system goes. |
| [docs/BUILD.md](docs/BUILD.md) | Export guide for Web / Windows / Android / iOS |
| [docs/artstyle.md](docs/artstyle.md) | Art direction: chunky beveled low-poly, matte flat, fixed pastel palette |
| [docs/plan.md](docs/plan.md) | Session-by-session design & bugfix log — history, not reference |

## Third-party assets

Baloo 2 font by Ek Type (SIL OFL 1.1). Sound effects from Freesound, filenames
keep their original Freesound IDs and author handles. 3D models are generated from
source scripts in `assets/3DModel/generated/` (Blender) and
`assets/3DModel/blockbench/` (Blockbench → GLB bridge).
