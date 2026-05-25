# Name Entry Calibration

## Goal

Type a short leaderboard name from the on-screen QWERTY keyboard and confirm it.

## Files

- `experiments/windows/calibration/name-entry.example.json`
- `experiments/windows/Enter-PlayerName.ps1`

## Current V1 Coverage

- letters `A-Z`
- `BACKSPACE`
- bottom-right `CONFIRM`

V1 intentionally skips punctuation and menu-side buttons because the main need is entering a simple leaderboard name.

## Command

Enter `CODEX`:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Enter-PlayerName.ps1 -Name CODEX
```
