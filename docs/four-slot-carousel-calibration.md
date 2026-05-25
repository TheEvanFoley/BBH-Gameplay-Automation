# Four-Slot Carousel Calibration

## Goal

Provide a reusable reset-and-drive probe for screens that show four visible tiles at once, such as the trek selection screen and likely later adventure-style selectors.

Important note:

Not every 4-choice screen has the same tile widths. The trek screen needs its own slot calibration because `Play All 3` is narrower than the trek tiles.

## Files

- `experiments/windows/calibration/four-slot-carousel.example.json`
- `experiments/windows/Probe-FourSlotCarousel.ps1`
- `experiments/windows/calibration/trek-selection.example.json`

## Current Screenshot-Based Slot Targets

- `slot1Safe`: `xPercent 0.28`, `yPercent 0.60`
- `slot2`: `xPercent 0.42`, `yPercent 0.60`
- `slot3`: `xPercent 0.60`, `yPercent 0.60`
- `slot4Safe`: `xPercent 0.74`, `yPercent 0.60`
- `back`: `xPercent 0.18`, `yPercent 0.22`

The `Safe` slot names reflect your guidance:

- leftmost tile clicks should bias to the right third of the tile
- rightmost tile clicks should bias to the left side of the tile

## Current Timing Model

- reset left hold: `6000 ms`
- full sweep: `5000 ms`
- middle probe: `2500 ms`
- after timed drive, return cursor to a neutral middle position so scrolling stops for inspection

## Commands

Probe the leftmost state:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Probe-FourSlotCarousel.ps1 -State left
```

Probe the middle state:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Probe-FourSlotCarousel.ps1 -State middle
```

Probe the rightmost state:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Probe-FourSlotCarousel.ps1 -State right
```

Override drive timing for live calibration:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Probe-FourSlotCarousel.ps1 -State middle -DriveMsOverride 2350
```

Hover each slot in the calibrated middle state:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Demo-FourSlotHover.ps1 -State middle
```

Select a specific slot from a chosen state:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Select-FourSlotChoice.ps1 -State left -SlotName slot3
```

## Current Adventure Mapping

Left state:

- `slot1Safe`: `Whitetail Deer`
- `slot2`: `Bighorn Sheep`
- `slot3`: `Caribou`
- `slot4Safe`: `Elk`

Middle state:

- `slot1Safe`: `Gemsbock`
- `slot2`: `Irish Elk`
- `slot3`: `Kudu`
- `slot4Safe`: `Moose`

Right state:

- `slot1Safe`: `Moose`
- `slot2`: `Wildebeast`
- `slot3`: `Buckzilla`
- `slot4Safe`: `Zombie Deer`

## Trek Screen Mapping

Use `experiments/windows/calibration/trek-selection.example.json` for the `Where are we headin'?` screen.

Left state:

- `slot1Safe`: `Trek 1`
- `slot2`: `Trek 2`
- `slot3`: `Trek 3`
- `slot4Safe`: `Play All 3`
