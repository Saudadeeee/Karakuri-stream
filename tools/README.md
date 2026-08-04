# tools/ — what each one is for

None of this ships: every export preset drops `tools/*`. They exist because most
of what can go wrong in this project cannot be seen by reading the code — a mix
that is 7 dB out, a UI that is being upscaled, a web build that loads and then
does nothing. Each tool turns one of those into a number or a picture.

Run everything from the project root with an **official** Godot 4.7.1 binary
(the Steam build swallows error text).

## Build and ship

| Tool | What it does |
|---|---|
| `package.ps1` | Builds and zips all four platforms into `export/`. `-Only windows,web` to narrow. The one command that matters before sending a build to anyone. |
| `gen_icon.gd` + `gen_icon.py` | `icon.svg` → the seven PNG sizes → `icon.ico`. Only needed when the icon art changes. Windows takes an .ico or nothing, which is why this exists. |
| `record.gd` (`record.tscn`) | Runs a working karakuri, orbits it, writes one PNG per tick for the store GIF. A still image cannot show water falling onto something that plays a note. |

## Look at it

| Tool | What it does |
|---|---|
| `shoot.gd` (`shoot.tscn`) | Screenshot any scene with a REAL renderer — headless renders nothing. Flags: `scene= out= theme= zoom= pitch= yaw= crop=` plus `build` (sample garden), `ui` (keep the HUD), `settings` / `journal` / `gardens` / `credits` (open that panel first). |
| `uiprobe.gd` (`uiprobe.tscn`) | Prints window size, content-scale size and every hotbar SubViewport size. Written the day the toolbar turned out to be a 720p canvas upscaled to 1080p. |

## Measure it

| Tool | What it does |
|---|---|
| `perf.gd` (`perf.tscn`) | Frame-time probe. `lite=0/1 blocks=N wood=N houses=N`. Read `worst=` and `over16ms=`; `draw_calls` is the number that moves on this renderer. **Always A/B in one session** — the machine drifts between them. |
| `audiotest.gd` (`audiotest.tscn`) | Records the game's own Master bus while it plays each sound through the real `AudioManager` call, so the levels include bus volume, 3D attenuation and pitch. Cannot run headless: the dummy driver records silence. |
| `webtest.mjs` | Drives Chromium from the Playwright cache over CDP and waits for the Godot shell to hand over to the engine. The web build is the one target whose failure mode is "the page loads and nothing happens". Needs a static server on the export first. |
| `isohash.gd` | md5 of the isosurface vertex/index buffers for fixed synthetic fields. Run before and after touching `IsoSurface`: identical hashes = identical mesh. |

## Poke it

| Tool | What it does |
|---|---|
| `uitest.gd` (`uitest.tscn`) | Presses every button in the menus twice and prints the label before/after, so a toggle that does not toggle shows up as a repeated value. This UI is built entirely in code — there is no scene file to inspect for a broken wire. |

## One-shot generators (kept for the next art change)

| Tool | What it does |
|---|---|
| `gen_theme.gd` | Regenerates `ui/karakuri_theme.tres`. |
| `apply_pixel_font.gd` | Puts the pixel face into the theme. See `docs/MAINTAIN.md`. |
| `font/gen_font.lua` | Aseprite script that draws the pixel font atlas. |
