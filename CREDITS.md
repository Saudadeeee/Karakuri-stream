# Credits & third-party licences

Every third-party asset shipped in this game is **CC0 (public domain)** except
the font, which is **SIL OFL 1.1**. Licences were checked against the source
pages, not assumed from filenames. Freesound filenames keep their original
sound ID and author handle, so any claim below can be re-checked at
`freesound.org/s/<id>/`.

## Sound effects — Freesound, all CC0

CC0 requires no attribution. Credited here anyway, because these people made
the game sound like something.

| Sound | ID | Author | Licence |
|---|---|---|---|
| Wood block hit — marimba/shishi/gate knocks, repitched | [218460](https://freesound.org/s/218460/) | thomasjaunism | CC0 |
| Water stream, looped | [249666](https://freesound.org/s/249666/) | tymorafarr | CC0 |
| Wooden gear / sprocket rattle | [461166](https://freesound.org/s/461166/) | hisoul | CC0 |
| Jelly bounce | [463590](https://freesound.org/s/463590/) | Mixtos | CC0 |
| Chimes | [517660](https://freesound.org/s/517660/) | SamuelGremaud | CC0 |

## Sound effects — synthesized in-house (original, no licence needed)

Generated with [rfxgen](https://raylibtech.itch.io/rfxgen) (zlib) and FFmpeg
filter synthesis; parameters live in the project history, so each can be
regenerated from source:

| Sound | Made with |
|---|---|
| `taiko_boom.ogg` — drum membrane hit (45–110 Hz sweep + noise slap) | FFmpeg `aevalsrc` |
| `music_box_tine.ogg` — struck tine, inharmonic 6.27× partial | FFmpeg `aevalsrc` |
| `splash_soft.ogg` — band-passed noise burst + bubble chirp | FFmpeg |
| `water_plop.ogg` — rising sine bloop | rfxgen |
| `ui_pop.ogg` — soft round UI pop | rfxgen |
| `paper_flutter.ogg` — pinwheel paper flutter | rfxgen |

## Music & ambience — OpenGameArt, all CC0

| Track | Source | Author | Licence |
|---|---|---|---|
| `chill_ambient.ogg` — the still ambient pad under everything | [Ambient Relaxing Loop](https://opengameart.org/content/ambient-relaxing-loop) | isaiah658 | CC0 |
| `rain_loop.ogg` — quiet rain layer | [Rain (loopable)](https://opengameart.org/content/rain-loopable) | Ylmir | CC0 |

## Fonts

- **Baloo 2** by Ek Type — SIL OFL 1.1, via
  [Google Fonts](https://fonts.google.com/specimen/Baloo+2). See
  [`assets/fonts/README.md`](assets/fonts/README.md).
- **KarakuriPop** (`assets/fonts/pixel/`) — original pixel font drawn by
  Aseprite from `tools/font/gen_font.lua`. No licence needed; regenerate with
  one command.

## 3D models

All original. Nothing downloaded. They are generated from the scripts committed
alongside them, so they can be rebuilt from source:

- `assets/3DModel/generated/` — Blender, via `stylekit.py` + `gen_assets.py`
- `assets/3DModel/blockbench/` — modelled in Blockbench, converted by `bb_bridge.py`
- Houses, animals, gears and pipes are built in GDScript at runtime and exist
  only as code

## Engine

Built with [Godot Engine](https://godotengine.org) 4.7 (MIT). Godot's own
copyright notice ships inside the exported binary.
