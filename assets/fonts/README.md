# Fonts

**Baloo2.ttf** — Baloo 2 (variable), by Ek Type. Licensed under the SIL Open
Font License 1.1 (OFL) — free to bundle & ship, including commercially.
Source: https://fonts.google.com/specimen/Baloo+2
Rounded, chunky, warm — matches the chunky-clay art style. Set project-wide via
`gui/theme/custom_font`; also becomes `ThemeDB.fallback_font` so the 3D TextMesh
wordmark uses it too (all-caps only — Baloo2's lowercase rounds self-intersect
under TextMesh's convex decomposition, so the wordmark + subtitle are caps).
