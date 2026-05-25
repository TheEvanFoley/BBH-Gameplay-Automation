# Menu Router

## Goal

Use OBS-backed screen recognition and context extraction to navigate BBH menus by state instead of relying only on fixed timing.

## Scripts

- `experiments/windows/Get-BBHState.ps1`
- `experiments/windows/Invoke-BBHMenuRouter.ps1`
- `experiments/windows/menu-router.example.json`

## Current Scope

The first router handles the core path into a classic site run:

- `landing-page`
- `main-menu`
- `game-mode-selection`
- `big-buck-hunter-mode-selection`
- `classic-player-count`
- `classic-weapon-selection`
- `classic-adventure-carousel`
- `classic-trek-selection`
- `tip-screen`
- `bonus-report`
- `post-trek-menu`
- `name-selection-screen`
- `classic-site-selection-screen`

It reuses the existing calibrated scripts for:

- adventure selection
- trek selection
- site selection
- confirming the existing name entry

## Command

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Invoke-BBHMenuRouter.ps1 -Adventure "Elk" -Trek "Trek 3" -Site 2 -PlayerName "CODEX"
```

## Current Behavior

The router loops like this:

1. capture the current OBS frame
2. classify it with the recognizer/context layer
3. choose the next action for the recognized screen family
4. repeat until the target site is selected or the router hits an unknown state

## Notes

- This is intentionally a polling controller, not a continuous stream service.
- It is designed to replace brittle timing in menus first.
- It stops after site selection for now.
- The current `tip-screen` behavior is a continuous left-click hold intended to skip the adventure intro video and tutorial in one pass.
- `bonus-report` is treated as a blocking interstitial and is advanced with a single left click.
- `post-trek-menu` is treated as a stable post-run decision screen and currently defaults to clicking `Next`.
- For now, unknown screens immediately after `tip-screen` or `name-selection-screen` are treated as short intro/tutorial videos and allowed to play through via a timed wait.
- Unknown or unsupported families fail fast so the next missing state is visible.
