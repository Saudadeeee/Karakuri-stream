# KARAKURI STREAM

*a water garden toy* — a relaxing sandbox inspired by Japanese karakuri
automata. Drop blocks on a floating island, let water find its way through
them, and listen: everything the stream touches plays a note. There is no
goal, no score, no failure — just a small machine garden that sings.

![Karakuri Stream](screenshot.png)

## How it plays

Water flows from a **spout**, through **bamboo pipes**, off **jelly
trampolines**, past **sluice gates** — and everything it lands on makes a
sound. Ponds power **gears**, gears drive **music boxes** and **scoops**,
scoops ladle new streams back out of the pond: water → mechanism → music,
in a loop you build yourself.

Every impact snaps to a shared **beat grid**, so several machines play in
time; sources come in three tempos, and polyrhythms fall out naturally.
All pitched sounds draw from one **pentatonic scale** — whatever you build,
it stays consonant.

### The palette (13 blocks)

| Block | What it does |
|---|---|
| Wood | Building block — the whole island is a marimba: placement pitch follows height |
| Water | Still pond — powers any gear touching it; four dye colours |
| Spout | Pours a stream straight down; three tempos |
| Pipe | Self-connecting bamboo — closed, open, or **alternator** (deals water to its exits beat-by-beat) |
| Gear | Spins against water, meshes with neighbours to transfer power |
| Bell | Rings when struck by a stream or a turning gear |
| Jelly | Trampoline — a falling stream bounces up-and-over it |
| Shishi-odoshi | Fills, then tips with the classic double knock; three capacities chain into clock dividers |
| Drum | Deep taiko hit from streams or gears |
| Chime | Five fixed pentatonic notes by colour — line them up to write a melody |
| Music box | Plays a tune while a powered gear turns beside it |
| Scoop | Beside a pond and a spinning gear, ladles out a new stream — in the pond's colour |
| Sluice gate | Click it in the world to open/close a whole branch of the machine |

### Controls

- **Left click** place · **Right click** remove · **Middle drag** orbit · **Scroll** zoom
- **1–0, -, =** select blocks · click a hotbar icon again to cycle its variant
- **Ctrl+Z / Ctrl+Y** undo/redo · **H** hide UI · **U** move the sun · **P** screenshot
- Touch: one finger orbits, two fingers pinch-zoom

### Four maps

Spring (sakura & petals), Autumn (amber & falling leaves), Snow (hushed
white), Night (fireflies — percussion sparks light). Same garden, different
world; ambience and palette retune per map.

## The sound

No looping soundtrack. A generative composer improvises over one pentatonic
collection: a slow harmonic clock wanders between its five modal rotations
(major and minor colours from the same pitches — nothing the player strikes
can clash), melodies walk stepwise in short call-and-response phrases, and
the density breathes over minutes. Instrument voices are a mix of CC0
recordings and in-house synthesis (see [CREDITS.md](CREDITS.md)).

## Running it

Made with **Godot 4.7.1** (GL Compatibility renderer). Open the project and
run — the main scene boots a menu with a live island behind it.

- Build instructions (Windows / Web / Android / iOS): [BUILD.md](BUILD.md)
- Full regression suite: `godot --headless --path . tests/regression.tscn`
  → expect `REGRESS ALL OK`
- Art style bible: [artstyle.md](artstyle.md) · development log: [plan.md](plan.md)

## Project layout

```
scenes/          menu, game, block scenes
scripts/
  autoload/      grid, streams, gears, isosurface renderer, audio, composer
  blocks/        per-block behaviour (shishi, gate, jelly, chime, ...)
  data/          block registry, variants, iso surface, map themes
  ui/            hotbar, menus, theme
shaders/         wood / water / stream / cloud-sea
assets/          sounds, fonts (incl. the Aseprite-drawn pixel font), models
tools/           dev harnesses: perf probe, screenshot rig, font generator
tests/           regression suite
```

All third-party assets are CC0; the font is OFL — details in
[CREDITS.md](CREDITS.md). Version: 0.0.0.
