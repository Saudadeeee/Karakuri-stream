# Fonts

**Fredoka.ttf** — Fredoka (variable: wdth, wght), by Hafontia. Licensed under the
SIL Open Font License 1.1 — free to bundle and ship, including commercially.
Source: https://fonts.google.com/specimen/Fredoka

Round, bubbly, thick-stroked — the chunky-clay art style in letterform. Set
project-wide via `gui/theme/custom_font`, which also makes it
`ThemeDB.fallback_font`, so the 3D TextMesh wordmark picks it up too.

## The wordmark must stay ALL CAPS

`TextMesh` runs a convex decomposition over the glyph outlines, and it cannot
handle self-intersecting contours. Fredoka's lowercase descenders (`g`, `y`)
trip it:

    ERROR: Convex decomposing failed. Make sure the font doesn't contain
    self-intersecting lines, as these are not supported in TextMesh.

Capitals decompose cleanly, which is why `main_menu.gd` writes "KARAKURI",
"STREAM" and the subtitle in caps. This is a property of TextMesh, not of this
particular font — Baloo 2, used here previously, had exactly the same problem.
Ordinary 2D UI text is unaffected; use any casing there.

## Licence

`OFL.txt` carries the SIL Open Font License 1.1 plus Fredoka's copyright notice.
Unlike the CC0 audio, the OFL **requires** that file to travel with the font, so
it is listed in `include_filter` in every export preset — Godot exports resources
only, and a plain `.txt` would otherwise never reach the pack.
