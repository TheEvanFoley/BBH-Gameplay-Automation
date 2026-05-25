# Site Capture Runner

## Goal

Automate the practical site-capture flow:

1. route to a target site-selection screen
2. start OBS recording
3. select the requested site
4. record for a fixed duration
5. stop OBS and finalize the run folder

## Script

- `experiments/windows/Invoke-BBHSiteCaptureRun.ps1`

## Current Scope

The current reliable version is designed for the common site loop inside a trek:

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

- This runner now intentionally avoids gameplay-end detection.
- The fixed-duration model is currently preferred because it has proven more predictable than live polling.
- Site 5 may continue into trophy or bonus-game paths, but `35` seconds has been sufficient to capture the important gameplay portion in the tested Elk flows.
- The runner currently uses fixed-duration capture via `-MaxRecordingSeconds`, defaulting to `35`.
- The OBS capture config can define `restReticleTarget` so the cursor is parked near the bottom-right after selecting a site.
- Silent captures are best handled in OBS itself by disabling audio tracks in the recording profile, since the repo tools currently finalize OBS's output file as-is.
- If different adventures need different lengths, the capture duration can be looked up or configured before each run.
