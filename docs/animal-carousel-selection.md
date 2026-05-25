# Animal Carousel Selection

## Goal

Select an animal by name from the rotating `What are we huntin'?` carousel using a deterministic reset plus timed motion.

## Files

- `experiments/windows/Select-AnimalFromCarousel.ps1`
- `experiments/windows/calibration/animal-carousel.example.json`
- `experiments/windows/calibration/animal-carousel.local.json`

## Model

- The carousel is treated as a constant-speed conveyor.
- A far-left reset is performed by moving the cursor to the left edge and holding for `6000 ms`.
- A full sweep is estimated at `5000 ms`.
- The starting per-step estimate is `714 ms`.

## Current Ordered Animal List

1. `Whitetail Deer`
2. `Bighorn Sheep`
3. `Caribou`
4. `Elk`
5. `Gemsbock`
6. `Irish Elk`
7. `Kudu`
8. `Moose`
9. `Wildebeast`
10. `Buckzilla`
11. `Zombie Deer`

## Current State Mapping

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

## Commands

Dry run the default `Elk` path:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Select-AnimalFromCarousel.ps1 -DryRun
```

Attempt `Elk` for real:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Select-AnimalFromCarousel.ps1
```

Attempt another animal by name:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Select-AnimalFromCarousel.ps1 -AnimalName "Caribou"
```

Override the current drive timing for a live calibration pass:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Select-AnimalFromCarousel.ps1 -AnimalName "Kudu" -MoveMsOverride 2400
```

Run the current end-to-end `launch -> title -> menus -> Elk` flow:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Start-ElkAdventure.ps1
```

## Calibration Workflow

1. Start from the animal carousel screen.
2. Run the script for a named target.
3. Observe where the carousel lands.
4. Adjust only the target's `moveMs` value or, if needed, the drive position.
5. Repeat until the target is reliable from reset.

## Why This Stops At Selection

V1 is intentionally limited to choosing an animal. That keeps the timing problem isolated and lets later work build on a repeatable known menu path.
