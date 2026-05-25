# Site Capture Runner

## Goal

Automate the practical site-capture flow:

1. route to a target site-selection screen
2. start OBS recording
3. select the requested site
4. wait for gameplay to finish
5. stop OBS when the game returns to site selection

## Script

- `experiments/windows/Invoke-BBHSiteCaptureRun.ps1`

## Current Scope

The first version is designed for the common site loop inside a trek:

- route menus with `Invoke-BBHMenuRouter.ps1`
- start a one-site OBS capture using `Start-ObsSiteCapture.ps1`
- click the requested site with `Select-SiteChoice.ps1`
- move the reticle to a configurable bottom-right rest position for cleaner gameplay footage
- record for a fixed duration, currently defaulting to `35` seconds
- finalize the recording with `Stop-ObsSiteCapture.ps1`

## Command

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Invoke-BBHSiteCaptureRun.ps1 -Adventure "Elk" -Trek "Trek 3" -Site 2 -PlayerName "CODEX"
```

## Notes

- This currently works best for Sites 1-4, where the game is expected to return to site selection after the run.
- Site 5 likely leads into a bonus-game path, and that end condition is not recognized yet.
- The runner supports a minimum gameplay time so it does not immediately stop on a false-positive early screen read.
- The runner currently uses fixed-duration capture via `-MaxRecordingSeconds`, defaulting to `35`.
- The OBS capture config can define `restReticleTarget` so the cursor is parked near the bottom-right after selecting a site.
- Silent captures are best handled in OBS itself by disabling audio tracks in the recording profile, since the repo tools currently finalize OBS's output file as-is.
- End-of-run screen detection is intentionally disabled for now; if different adventures need different lengths, the capture duration can be looked up before each run.
