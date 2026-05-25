# Menu Coordinate Calibration

## Purpose

Store screenshot-based target coordinates for menu automation without confusing them with true screen center or gameplay reticle position.

## Current Calibrated Screen

`Big Buck Hunter` vs `Bonus Only`

Saved in:

- `experiments/windows/calibration/menu-targets.json`
- `experiments/windows/calibration/classic-versus-targets.json`
- `experiments/windows/calibration/animal-carousel.example.json`

## Current Relative Targets

- `Back`: `xPercent 0.18`, `yPercent 0.22`
- `Big Buck Hunter`: `xPercent 0.36`, `yPercent 0.53`
- `Bonus Only`: `xPercent 0.65`, `yPercent 0.53`

## Important Note

These values are screenshot-estimated menu targets.

They are not:

- the exact visual center of the game window
- the true resting center of the reticle
- a gameplay aiming calibration

## Current Reuse Findings

- The `Back` button has remained stable at roughly `xPercent 0.18`, `yPercent 0.22` across the menu screens tested so far.
- The left-choice lane around `xPercent 0.36`, `yPercent 0.53` has remained usable across multiple two-choice tile screens.
- The right-choice lane around `xPercent 0.65`, `yPercent 0.53` has also remained usable across multiple two-choice tile screens.

This suggests the game is using a fairly consistent menu layout template, which is good news for early automation.

## Animal Carousel Note

The `What are we huntin'?` screen is the first confirmed break from the static two-choice layout. V1 handles it with a timed reset-plus-drive model instead of fixed button positions.

## How To Use

Example move step:

```json
{
  "type": "moveMouse",
  "xPercent": 0.65,
  "yPercent": 0.53
}
```

Example right-click select step:

```json
{
  "type": "click",
  "button": "Right",
  "xPercent": 0.65,
  "yPercent": 0.53
}
```

For tile-style menus discovered so far, live behavior suggests left click is the practical selection action even when the controls screen wording implies otherwise.
