# Screen Recognition V2

## Goal

Recognize the current BBH menu screen by comparing a screenshot against a catalog of labeled reference frames and returning a stable screen family.

## Script

- `experiments/windows/Recognize-BBHScreen.ps1`
- `experiments/windows/screen-recognition-catalog.example.json`

## How It Works

The current recognizer uses a simple perceptual fingerprint:

- resize image to a small grayscale grid
- compute an average-hash bit string
- compare the current frame against labeled references using Hamming distance
- return the closest known reference plus a confidence score
- map the exact reference to a stable `screenFamily`
- return `unknown` when confidence falls below the configured threshold

This is still not the final recognition system, but it is a practical intermediate step for replacing timing guesses with "best known screen family."

## Current Assumptions

- reference screenshots live under `output/frames`
- a catalog maps reference labels to screen families
- temporary captures like `recognizer-current` are ignored as references
- the target frame is either provided explicitly or inferred as the newest PNG

## Commands

Recognize a specific image:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Recognize-BBHScreen.ps1 -ImagePath output\frames\2026-05-24\2026-05-24T14-12-31-720-main-menu.png
```

Capture a fresh frame and then recognize it:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Recognize-BBHScreen.ps1 -CaptureCurrent
```

## Expected Output

```json
{
  "screenFamily": "main-menu",
  "confidence": 0.9915,
  "matchedReference": "...",
  "referenceLabel": "main-menu",
  "isKnown": true,
  "threshold": 0.93
}
```

## Current Family Catalog

- `landing-page`
- `main-menu`
- `game-mode-selection`
- `big-buck-hunter-mode-selection`
- `classic-player-count`
- `classic-weapon-selection`
- `classic-adventure-carousel`
- `classic-trek-selection`
- `tip-screen`
- `name-selection-screen`
- `classic-site-selection-screen`
