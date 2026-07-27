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
| `Q` | houses |
| Same key / icon again | cycle that material's variant (pipe open↔closed, wood→dirt→moss→stone, chime note …) |
| `Ctrl+Z` | undo |
| `H` | hide UI · `U` move the sun · `P` screenshot |

17 block types, 4 map themes (Spring / Autumn / Snow / Night). Progress saves to
`user://` — save, load, and delete from the pause menu.

### Houses

You don't place a house, you place a house *cell*, and the building assembles
itself. Put two side by side and the wall between them disappears — they become
one wide house under one roof.

The roof isn't drawn per cell, which is what lets buildings actually merge: it's
one surface over the whole footprint, and its shape falls out of how deep each
point sits inside that footprint. So a single row gets a ridge with hipped ends,
a 2x2 gets a hip roof, a 3x3 peaks into a pyramid, and an L-shaped building grows
a valley where its two wings meet — none of which is special-cased anywhere.

Stack a cell and the lower roof becomes a floor, with a belt course marking the
storey. Knock a hole in a terrace and the two new ends close themselves up.

Nothing is allowed to float. Put a house in mid-air and it grows legs down to
whatever is actually beneath it — the ground, or the roof of the thing you built
under it. Jut a storey out past the one below and it braces itself sideways with
a corbel instead, because a cantilever propped on a pillar looks wrong. A raised
platform shares its posts between cells rather than stacking four in every hole.

Each building gets exactly one front door and one chimney however odd its shape,
and everything places itself the *same way every time*, so a village looks
identical after you reload it.

Some shapes are worth more than others, and the town will tell you so:

- Build **four storeys straight up, one cell thick** and the roof becomes a
  **spire** — the one landmark visible from anywhere on the island.
- **Ring an empty cell** with houses and the hole becomes a planted **courtyard**.
- Leave **exactly one cell of air** between two rooftops of the same height and
  **bunting** is strung across the gap.

None of these are random. The same shape gives the same answer every time, so
once you find one you can go and build it on purpose.

### Animals

Wildlife arrives because of what you built, and does something back:

- **Birds** need a house. They perch on your roofs, and a bird that lands on a
  bell, chime or drum **plays it** — the garden gets a second musician you didn't
  program. Building near them puts them up.
- **A cat** moves in once there are two houses. It walks the rooftops, will not
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
