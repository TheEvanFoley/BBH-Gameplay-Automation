# Menu Layout Observations

## May 23, 2026

Observed during automation-driven menu traversal in Big Buck Hunter: Ultimate Trophy.

### Stable elements so far

- `Back` button remains in the same upper-left position across tested screens.
- Left choice target around `xPercent 0.36`, `yPercent 0.53` has worked for:
  - `Big Buck Hunter`
  - `Classic`
- Right choice target around `xPercent 0.65`, `yPercent 0.53` appears reusable for corresponding right-side options.

### Interpretation

The game appears to reuse a common menu composition pattern:

- fixed back button
- left and right primary choice lanes
- similar vertical alignment of large choice tiles

This is encouraging for near-term automation because we may be able to navigate a meaningful portion of the flow with a small set of calibrated targets before needing heavier vision tooling.
