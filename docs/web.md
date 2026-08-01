# The `web` branch

One goal: a garden that runs smoothly in a browser tab. Everything below is a
decision made against that, with the measurement that justified it.

The short version: **the web build's problem was never triangles.** It is the
number of distinct shader programs the browser has to compile before it can draw
anything, and it started as 41 seconds of frozen tab before anyone saw a pixel.
A first visit now reaches the menu in about 31 seconds with a progress bar the
whole way, and every visit after that in about 4.

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

The six that remain: lit opaque, lit vertex-coloured, unshaded opaque, unshaded
alpha, unshaded additive, and the particle billboard. Emissive is not among them
— see below; it turned out to be the most expensive single feature in the whole
build.

### The boot screen

`scenes/boot.tscn` is the first thing that runs, and it exists only for the
browser. It draws one thing per frame so the driver compiles one program per
frame, with a progress bar between each.

Two mistakes were made building it and both are worth not repeating:

1. **The warm-up light had shadows on.** The web profile runs without them, so it
   was compiling the depth-pass variant of every material — a second full set of
   programs the game never uses. Warming went 65 s → 37 s on that one line.
2. **It warmed inside a `SubViewport`.** A compiled program is keyed to the render
   target it was compiled for. Warming somewhere with a different size or format
   risks paying twice. It now warms in the main viewport, behind the opaque
   background panel.

## Where the first visit actually goes

`tools/floor.gd` is the harness that answered this. It boots a scene that adds
one thing at a time and reports what each cost, so an engine floor can be told
apart from something the game chose.

The answer was not what any amount of staring at the game would have suggested:

    FLOOR 2d-only                180 ms
    FLOOR camera only         26 229 ms      <- a Camera3D. Nothing drawn yet.
    FLOOR environment, colour     19 ms
    FLOOR procedural sky       1 091 ms
    FLOOR fog                    712 ms
    FLOOR tonemap AGX             27 ms
    FLOOR colour adjustment      742 ms
    FLOOR glow                   172 ms
    FLOOR directional light      708 ms
    FLOOR one lit box             19 ms      <- the first actual geometry
    FLOOR second box, colour      21 ms      <- colour is free, as promised
    FLOOR unshaded               673 ms
    FLOOR emissive             8 611 ms      <- one material feature
    FLOOR omni light           1 477 ms

So: the sky, the fog, the grade, the lights and the meshes together cost about
four seconds. A **camera** costs twenty-six, and **emissive** costs nine.

That reframed everything. Cutting geometry was never going to help.

## What was cut after that, and what each was worth

**Emissive → unshaded.** `ShaderBudget.glow()` is now the only way anything in
the game says "this glows", and it answers differently per profile. Emission
exists to feed bloom; the web profile has no bloom, so emission there only makes
a surface brighter — which is what unshaded already does, for a program that was
already paid for. Measured: 8.6 s → 0.6 s.

**Three custom shaders → one.** `wood`, `water` and `stream` became
`surface.gdshader` with a `surface_mode` uniform. A uniform does not multiply
programs and the branch is dynamically uniform, so the GPU picks one side per
draw. Two of them only ever differed by `diffuse_burley` vs `diffuse_lambert`;
the stream was held apart by `blend_mix`, which is a render_mode and therefore
compile-time — but its alpha was 0.98, and this game's water has been
deliberately opaque since the isosurface rewrite, so making it honestly opaque
let it join. 7.8 + 7.8 + 7.4 s of compile became 7.4 s.

**GPU particles → CPU particles.** Every `GPUParticles3D` became
`CPUParticles3D`, which needs no `ParticleProcessMaterial` — that was a whole
shader, 7.4 s of it. Nothing in this game emits more than a few dozen quads and
the web profile already halves the counts, so the simulation is not worth a GPU
pass. Measured after: 0.5 s.

## Result

Real Chrome, ANGLE → D3D11, RTX 3060, served locally, whole flow driven by
script — load, boot, menu, Play, place blocks:

| | before this pass | after |
|---|---|---|
| menu, first ever visit | 66–74 s | **22–33 s** |
| game running, first visit | 70 s | **26–36 s** |
| menu, returning visit | 5 s | **4 s** |
| on the wire | 14.35 MB | **10.01 MB** |
| frame rate while playing | 103 fps | 116–122 fps |

The returning number is the one most players see: Chrome keeps ANGLE's compiled
binaries in the browser profile, so **the compile is a one-off per machine**.

What is left on a first visit is roughly 8 s of WASM (37.7 MB, 9.6 MB gzipped),
14 s of engine baseline, and 7.4 s for the one remaining custom shader. Serving
Brotli instead of gzip would take the download to about 7 MB.

> A caution about the numbers above: this machine was running exports throughout,
> and the same build measured anywhere from 13.8 s to 25.2 s for the identical
> first item across the session. Per-item costs and the totals were re-measured
> back to back at the end, but treat any single figure as ±50%, and the ratios as
> the real result.

## Making it a demo: weight, and a look worth showing

**Audio: 3.72 MB → 0.92 MB.** Everything that plays through an
`AudioStreamPlayer3D` is now mono — Godot cannot pan a stereo stream on a 3D
player, so this is smaller *and* more correct — at 32 kHz and a low Vorbis
quality. The two uncompressed WAVs went to Vorbis (460 KB → 17 KB for the
chimes). Music and rain keep their stereo width because they are 2D. Filenames
still carry the Freesound IDs, so `CREDITS.md` can still be checked against them.

**Brotli instead of gzip: 9.59 MB → 7.56 MB for the engine.** `tools/serve_web.py`
compresses once, caches it, and falls back to gzip if `brotli` is not on PATH.

    total on the wire   14.35 MB  ->  10.01 MB

**The opening shot.** The starter garden used to be scattered from x=-5 to x=-1
with the camera at `spring_length = 15`, which framed the whole island: a bare
green disc with a few specks on one edge. It is now built tight around the
origin — spout, shishi, drum, three chimes, a pond turning a gear that plays a
music box — and the camera starts at 7. The starting distance lives on the
scene's `SpringArm3D`, not in `orbit_camera.gd`; `_ready` reads it from the node,
so editing the script constant alone does nothing.

## The isosurface: a wrong diagnosis, and what was actually true

A previous pass here claimed the isosurface's vertex normals were broken and
replaced them with a screen-space derivative normal forced to face the camera.
**That was wrong, and it is now reverted.** Recording it because the mistake is
more instructive than the fix.

The evidence for it came from sampling a PIXEL out of a render and decoding it as
a normal. That is indirect, and the pixel was in the wrong place — a later probe
returned a "normal" longer than 1, which should have been the tell.

`tools/normcheck.gd` reads the mesh arrays instead. On a flat slab: **45 top-face
vertices point up, none point down.** The normals were always correct.

What the derivative version actually did was force every visible fragment's
normal toward the camera, which floods everything with light. That is why the
timber and the pond looked brighter after it — not because anything was fixed.
It also made adjacent triangles shade in a visible checkerboard wherever the
winding alternated, and being camera-relative it changed as the camera moved.
That is almost certainly what was reported as "seeing through blocks while
orbiting".

Two things that ARE true and were measured on the way:

- **Culling cannot simply be turned on.** The builder's winding is the opposite
  of Godot's front-face rule: switching either isosurface material to `cull_back`
  makes the near wall of a pool vanish outright. `cull_disabled` is load-bearing,
  and the bright wedges along a silhouette are the price.
- **The scene lights any surface at about 0.45.** Measured by rendering the
  isosurface with a pure white albedo: 0.40 on slopes, 0.60 on the top, and the
  island grass sits in the same range. So `#D4A373` genuinely renders as a dark
  chocolate here; the wooden PROPS look paler because their model albedo is
  paler, not because the block is shaded differently. Both isosurface looks now
  carry a modest `EMISSION` lift so a placed block reads as the palette colour
  it advertises, which is what the pond branch was already doing.

The vertex-AO rewrite from the same pass DOES stand: it used to probe fixed
offsets, which on any flat surface walked into the block's own neighbours and
returned a constant 0.52 — no crevice detail, just a flat darkening. It now
probes outward along the vertex normal, with three rays rather than seven,
because each ray is a dictionary lookup per vertex and on an 80-block deck the
bake alone was 19 ms of the 74 ms a single placement cost.

## Known console noise, and why it is left alone

`ERROR: Parameter "material" is null.` — a handful, when blocks that carry an
imported model are placed.

It comes from `MeshInstance3D.set_surface_override_material`. Assigning a
per-surface override makes the engine refresh that surface's instance shader
parameters, and it queries the slot before anything is in it; the storage
back-end logs a null-guard and returns. Nothing in this game uses instance
shader parameters, so nothing is affected — the frame draws, the colours are
right, the frame rate is unchanged.

Measured, so this is not a guess:

- pre-existing, not introduced here: the same probe returns **29** against this
  branch's `mesh_fit.gd` and **29** against the previous branch's.
- `MeshFit.matte` no longer duplicates a material per instance, which removed
  most of them: **29 → 4** headless, **32 → 8** in the browser.
- the rest come from `MeshFit.tint`, which recolours only the surfaces whose
  albedo is near the model's base colour. That genuinely needs a per-surface
  override; `material_override` covers the whole mesh and would repaint the
  chime's frame along with its tube.

Removing the last few means duplicating the *mesh* per instance so the material
can be set on the surface itself. That trades a harmless log line for real
per-instance vertex memory, on the one platform where memory matters most. Not
worth it.

`ERROR: Parse JSON failed` during a regression run is `_sec_save_corruption`
feeding the loader a deliberately broken file, and `resources still in use at
exit` is shutdown ordering. Both expected.

## Still on the table

Not done, with the measurement that says what each is worth:

- **The engine baseline is ~14 s and nothing here touches it.** `tools/floor.gd`
  pins it to the moment a `Camera3D` exists, before a single triangle is drawn,
  so it is Godot's own shader set rather than anything the game asked for. No
  project setting found so far moves it; `rendering/shader_compiler/shader_cache`
  is for the RD renderers and does nothing on compat.
- **`surface.gdshader` still costs ~7.4 s.** It is now one program doing timber,
  water and stream, so the only way to cut it further is to give one of those
  looks up.
- **Brotli instead of gzip** would take the 9.6 MB download to roughly 7 MB. A
  hosting choice, not a code one.
- ~~**`VoxelSurfaceManager` re-solves its whole group on every edit**~~ —
  RESOLVED, in three layers, none of which change the geometry (proved by
  `tools/isohash.gd`: md5 of the mesh buffers, identical before and after):

  1. **The dead signature.** `_built` declared a compare-first optimization that
     was never implemented — placing a BELL re-solved the wood AND water
     isosurfaces for nothing. Group cell-set signatures now skip untouched
     groups; that alone took the non-wood placement spike from 60 ms to 4 ms.
  2. **The density field is cached per group.** An edit only disturbs samples
     within its cell's reach (~0.66), so the field is patched (~200 samples)
     instead of resampled (~10 000); outgrowing the box row-copies the overlap.
  3. **The solve is a worker coroutine.** Surface Nets + smoothing + normals +
     AO now yield every ~4.5 ms of accumulated work and commit the mesh
     atomically at the end — the old mesh stays up while the new one cooks. An
     80-cell re-solve became several 5 ms frames instead of one 50 ms hitch.
     Edits landing mid-solve don't restart it (continuous water flow would
     starve the build); the snapshot finishes, then the worker goes again.

  Measured, LITE, same harness (`place=1`, wood placed on an 80-cell deck):

  | | before | after |
  |---|---|---|
  | worst frame | 60.7 ms | **13.8 ms** |
  | frames over 16.7 ms | 14 / 420 | **0 / 420** |

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
