# Karakuri Stream

A calm 3D sandbox where you build a Japanese water-garden on a floating island and
let it play itself. Place a bamboo spout, and the stream it pours falls cell by cell
through pipes, spins wooden gears, tips a shishi-odoshi, rings bells and wind-chimes,
and drives a music box — a *karakuri* (からくり, clockwork automaton) you assemble
one block at a time. No score, no fail state. You build the machine; the machine
makes the music.

Built with **Godot 4.7** / GDScript, `gl_compatibility` renderer, no external addons.

> **This is the `web` branch.** Everything here is bent toward one thing: a
> garden that runs smoothly in a browser tab. Houses and their whole
> Townscaper-style shape system are gone — they were half the draw calls in a
> village and most of the per-click rebuild cost — and what is left is the part
> the game was always about: water finding its way downhill and hitting things
> that make a sound. See **[docs/web.md](docs/web.md)** for what was cut, what it
> bought, and the measurements behind both.

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

### Animals

Wildlife arrives because of what you built, and does something back:

- **Birds** are drawn by the things that make a noise. They perch on whatever is
  open to the sky, and a bird that lands on a bell, chime or drum **plays it** —
  the garden gets a second musician you didn't program. Building near them puts
  them up.
- **A cat** moves in once the garden has a few instruments. It walks the tops, will not
  step on water, and on the night map goes and sits by a lit stone lantern.
- **Ducks** need a real pond — three open water cells or more — and paddle it,
  dipping to feed.
- **A deer** only comes out when the machine is *quiet*, and leaves the moment
  water starts running again. Switching your garden off is the only way to see it.

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

Every third-party asset is **CC0 (public domain)** except the font (Fredoka), which is
**SIL OFL 1.1** and ships its licence in `assets/fonts/OFL.txt`. All 3D models are
original. Full list with sources and licences: **[CREDITS.md](CREDITS.md)**.
