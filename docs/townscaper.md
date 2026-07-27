# Making the town feel like Townscaper

Working document. What we borrowed, what we deliberately did not, and what is
left. Written after repeatedly "fixing" this by guessing and being wrong — every
row below is judged against a rendered screenshot, not against intent.

## Why a Townscaper street reads as a street

Three properties, in order of how much they matter:

1. **No two buildings look alike.** Colour does most of this work. A red one, a
   blue one, a yellow one — not eight shades of beige.
2. **Nothing is a box.** The grid is a relaxed quad mesh, so no wall is straight,
   no corner is 90°, and every silhouette is slightly hand-made.
3. **The town reacts.** Drop one block and the buildings around it visibly
   re-form. The satisfaction is in the ripple, not in the block.

Everything else — arches, balconies, roof gardens — is decoration hung on those.

## Status

| | State | Notes |
|---|---|---|
| Merged walls | done | shared walls vanish; a row is one building |
| Roof as a height field | done | gable / hip / pyramid / valley from one rule |
| One door, one chimney per building | done | via component flood, cached on grid version |
| Stilts, corbels, arches | done | arch spans up to 4 cells |
| Per-building colour | done | 8 saturated colourways, building-level roll |
| Balcony / awning / shutters / planter / roof garden | done | gated on `decor_tier` |
| Reflow pop on neighbours | done | the "town reacts" beat |
| Corner chamfers | done | 45° post on every corner where two exposed walls meet |
| Wall jitter | done | sub-centimetre, from the cell hash |
| Dormers | done | tier 1+, only where the roof slopes to an outside edge |
| District colour harmony | done | neighbours share a tone; ~1 in 5 ignores it |
| Ground-level paving / plazas | **attempted, reverted** | see below |
| Walkways between separate buildings | todo | arches only span within one building |

## Not doing: the irregular grid

Townscaper's cells come from a relaxed quad mesh, which is where most of its
charm lives. We are on a strict cubic grid, and that grid is load-bearing for
*everything else in the game* — stream routing, gear meshing, the water
isosurface, pipe ports, save format. Replacing it is not a feature, it is a
different game.

So the plan is to **fake the symptoms rather than change the cause**: chamfer the
corners and jitter the panels so the silhouette stops being perfectly square,
which is what the eye actually reads.

## Plan

**1. Corner chamfers.** Every vertical corner where two exposed walls meet gets a
small 45° post. A cube with cut corners stops looking like a cube from any angle,
and it costs one box per corner in the existing batch. Highest impact per line of
code left on the list.

**2. Wall jitter.** Deterministic per-cell offsets of a few centimetres on wall
panel position and thickness, from the existing cell hash. Individually
invisible, collectively the difference between "printed" and "built". Must come
from `_h`, never `randf()`, or reloads reshuffle the town.

**3. Dormers.** A small gabled window pushing out of a roof slope, on tier-2
buildings, on the side that faces out. Rooflines are the largest blank surfaces
in a dense town and currently say nothing.

**4. District colour harmony.** Done by quantising the building's anchor cell
into 4x4 districts rather than searching for neighbours — same curated feel, no
extra flood fill. One building in five ignores the district on purpose: a town
where *everything* agrees looks planned rather than grown.

## Ground level: attempted, reverted, notes for the next attempt

The space between buildings is still bare grass, and it is the biggest remaining
gap. An attempt at paved aprons — a stone slab along every exposed ground-floor
wall, so that neighbouring aprons meet and the gap becomes a street — was built
and then removed rather than shipped half-working. What was learned:

- The island is a **sculpted mesh with a jittered surface**, not a flat plane at
  y=0. A thin slab laid on y=0 vanishes inside it. Thickening to 0.14 and lifting
  clear of the sculpting fixed that much.
- Deriving the paving colour from the building's trim produced a pale grey
  almost exactly the colour of the lawn: the slab rendered perfectly and was
  invisible. Paving contrasts with GRASS, which is the same for every building,
  so it needs a fixed stone colour, not a per-building one.
- After both fixes the slab still did not appear while the terrace RAIL built
  beside it did — same batch, same frame, so it is not the batching. The next
  attempt should start by dumping the built vertex positions rather than
  adjusting numbers and re-rendering, which is what burned the time here.

**Walkways** between separate buildings turned out to need nothing: a player who
bridges a gap with house cells makes the two into ONE component, so the existing
arch rule already spans it.

## What is worth doing next instead

The house itself is in good shape. The bare ground is a SCENERY problem more than
a house problem — `DecorManager` and `SceneryManager` already place props on and
around the grid and would be a better home for paving and steps than
`house_block`, which can only ever see one cell.

## Rules that must survive any change here

- **Deterministic.** Everything derives from `HouseShape._h` / `building_roll`.
  A `randf()` anywhere means the town reshuffles on reload.
- **Building-level vs cell-level.** Anything that is "this house's character"
  uses `building_roll`; only per-window detail uses `_h`. Getting this backwards
  makes one house noisy instead of making two houses different — the mistake that
  made the first colour attempt do nothing.
- **Batch by colour.** Detail is free in draw calls as long as it reuses palette
  colours. A new colour is a new surface on every cell that uses it.
- **Check by rendering.** `tools/shoot.gd`. Three separate bugs in this feature
  were invisible in code and obvious in a screenshot.
