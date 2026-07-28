# The `web` branch

One goal: a garden that runs smoothly in a browser tab. Everything below is a
decision made against that, with the measurement that justified it.

The short version: **the web build's problem was never triangles.** It was the
number of distinct shader programs, and it cost 41 seconds of frozen tab before
anyone saw a single pixel.

## What was cut, and what it bought

### Houses

The whole Townscaper-style house system — `house_block`, `HouseShape`, the roof
height field, spires, terraces, courtyards, arches, corbels, bunting — is gone,
along with its 8 palettes and its regression sections.

| | with houses | without |
|---|---|---|
| draw calls, 24-block garden | 442 | 373 |
| draw calls attributable to 24 house cells | 246 | — |
| distinct shader variants | 11 | 9 |

A house cell was ~1000 triangles and ~10 draw calls **each**, because detail was
built as relief geometry in many colours and `MeshBatch` cuts a surface per
colour. On a desktop that was affordable and it looked lovely. On a phone
browser it is half the frame for something that makes no sound.

Wildlife used to be driven by how many houses stood; it is now driven by how many
**instruments** stand, which is both the only thing left to count and the better
rule — a bird is drawn to the bell it is going to land on and ring.

### Shader variants: 11 → 6

`gl_compatibility` compiles one program per unique **combination of material
feature flags**, synchronously, the first time something wearing that combination
is drawn. Albedo colour is free; a hundred colours share one program. Flags are
not.

`ShaderBudget` (`scripts/data/shader_budget.gd`) is the fixed set, and everything
arriving from outside gets normalised into it on the way in — via `MeshFit.matte`,
which every imported `.glb` already went through.

What was merged and why:

- **Every scenery model shipped double-sided.** Blender and most glTF exporters
  do that by habit. It cost a program *and* doubled the raster work on rocks,
  bushes and tree trunks that can never be seen from the inside. Verified by
  render that nothing vanished.
- **The placement ghost was lit and transparent**, alone in that combination. It
  is now unshaded, which merged it with the rest of the transparent UI bits and
  arguably reads better as a preview anyway.
- **A near-miss worth recording:** setting `specular_mode = SPECULAR_DISABLED` on
  imported materials only *moved* the split from `cull_mode` to `specular_mode` —
  the count came back at 9 either way. Specular is killed with the *strength*
  uniform instead, which is free. Flag versus uniform is the whole distinction
  this file is about.

The six that remain: lit opaque, lit emissive, lit vertex-coloured, unshaded
alpha, unshaded additive, and the particle billboard.

### The boot screen

`scenes/boot.tscn` is the first thing that runs, and it exists only for the
browser. It draws one thing per frame so the driver compiles one program per
frame, with a progress bar between each.

Measured in real Chrome, ANGLE → D3D11, RTX 3060, served locally:

| | first ever visit | every visit after |
|---|---|---|
| first picture on screen | 6.0 s | 1.7 s |
| menu up and interactive | 42.3 s | **3.8 s** |

The second column is the important one. Chrome keeps ANGLE's compiled program
binaries in the browser profile, so **the compile is a one-off per machine**, not
per visit. The screen's "first visit only" line is literally true.

The first column is not fast, but it is now 42 seconds of a title and a moving
bar rather than 41 seconds of a blank tab, which anyone sensible reads as broken
and closes.

Per-item costs, which is where any further work should start:

| item | ms |
|---|---|
| first lit program | 13 849 |
| particle billboard | 4 596 |
| `wood.gdshader` | 4 490 |
| lit emissive | 4 376 |
| `water.gdshader` | 4 226 |
| `stream.gdshader` | 3 957 |
| unshaded additive | 368 |
| unshaded alpha | 85 |
| lit vertex-coloured | 13 |

Two mistakes were made building this and both are worth not repeating:

1. **The warm-up light had shadows on.** The web profile runs without them, so it
   was compiling the depth-pass variant of every material — a second full set of
   programs the game never uses. Warming went 65 s → 37 s on that one line.
2. **It warmed inside a `SubViewport`.** A compiled program is keyed to the render
   target it was compiled for. Warming somewhere with a different size or format
   risks paying twice. It now warms in the main viewport, behind the opaque
   background panel.

## Still on the table

Not done, with the measurement that says what each is worth:

- **Emissive → unshaded on LITE (−4.4 s).** Glow is disabled in the web profile,
  so emission only makes a surface brighter regardless of lighting — which is
  exactly what unshaded already does, and unshaded is already compiled (85 ms).
  Lanterns and fireflies would look the same.
- **`wood.gdshader` → a plain material on LITE (−4.5 s).** The deck loses its
  grain. A real look-versus-boot trade; worth rendering both before choosing.
- **The first lit program is 13.8 s on its own** and nothing here touches it. It
  is probably not one program but Godot's scene shader plus ANGLE's first-ever
  pipeline setup. Splitting that apart is the next real investigation.
- **~21 ms per click goes to `VoxelSurfaceManager`** re-solving its isosurface.
  Identical for placing and removing, and flat in the number of blocks, so it is
  not the blocks — it is the marching-cubes pass itself.

## Frame times

Real renderer, LITE profile, with a block being placed and removed inside the
sample window (`tools/perf.gd`, `place=1`):

| garden | p50 | p99 | worst | frames over 16.7 ms |
|---|---|---|---|---|
| 24 blocks | 2.79 ms | 10.64 | 11.39 | 0 / 420 |
| 80 blocks | 3.71 ms | 11.37 | 11.86 | 0 / 420 |

For comparison, the same harness on the branch this came from, with 80 houses:
worst 161 ms and 14 dropped frames per 420.

> `tools/perf.gd`'s `churn=1` used to only dirty the isosurface — it never placed
> or removed anything. Every performance run this project ever did was measuring
> a finished garden being *looked at*, never the act of building, which is the
> only thing the player does. That is why a cost scaling with garden size stayed
> invisible for so long. `place=1` is now the default.
