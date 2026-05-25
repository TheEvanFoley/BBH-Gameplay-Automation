# Launching The Game

## Goal

Let the repo start the game for you so the first automation step is reproducible and easy to inspect.

## Files

- `experiments/windows/Launch-Game.ps1`
- `experiments/windows/game-launch.example.json`
- `experiments/windows/game-launch.local.json` for your machine-specific settings

## Setup

1. Copy `experiments/windows/game-launch.example.json` to `experiments/windows/game-launch.local.json`.
2. Choose one launch method:
3. Use `preferredMethod: "steam"` if Steam is the stable entry point.
4. Use `preferredMethod: "direct"` if you want to launch the game executable directly.

## Example Local Config

```json
{
  "preferredMethod": "steam",
  "steamAppId": "3102290",
  "steamExePath": "C:\\Program Files (x86)\\Steam\\steam.exe",
  "postLaunchWaitSeconds": 10,
  "surfaceNamePattern": "Buck|Hunter|Reloaded|Ultimate Trophy"
}
```

## Commands

Dry run:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Launch-Game.ps1 -DryRun
```

Launch and then inspect likely game surfaces:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Launch-Game.ps1 -InspectAfterLaunch
```

## Tradeoffs

### Steam launch

Pros:

- often the least brittle starting point
- lets Steam handle updates and prerequisites

Cons:

- may open launcher or overlay paths we do not fully control yet
- can be less precise if we later want direct process attachment

### Direct executable launch

Pros:

- more explicit and easier to reason about
- useful if we later need tight window/process matching

Cons:

- depends on a stable install path
- may bypass launcher behavior that matters for parity or input setup

## Current Note

As of May 23, 2026, this machine's visible Steam library manifests did not show an installed Big Buck Hunter entry in the scanned locations, so the repo ships an example config rather than assuming the local install state. Steam app `3102290` corresponds to Big Buck Hunter: Ultimate Trophy on Steam: [store page](https://store.steampowered.com/app/3102290/Big_Buck_Hunter_Ultimate_Trophy/).
