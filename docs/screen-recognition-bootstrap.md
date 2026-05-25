# Screen Recognition Bootstrap

## Goal

Create the first OBS-backed bridge for future screen recognition work without jumping straight into a full long-running service.

## Recommended First Step

Start with:

- an OBS scene switcher / output starter
- on-demand frame capture from the `BigBuckHunterGame` source

That is simpler to debug than a full streaming service and gives us labeled screenshots for later recognition work.

## Current OBS Assumptions

- websocket URL: `obsws://localhost:4455/...`
- scene: `BigBuckHunter`
- source: `BigBuckHunterGame`
- OBS record directory: `E:/BigBuckHunterRecordings`

## Scripts

- `experiments/windows/Start-ObsVisionBridge.ps1`
- `experiments/windows/Capture-BBHFrame.ps1`
- `experiments/windows/obs-vision.local.json`

## Suggested Workflow

1. Switch OBS to the BBH scene.
2. Optionally start virtual camera or streaming.
3. Capture labeled screenshots from known screens.
4. Build a reference catalog of menu states.
5. Add a recognizer on top of those captured frames.

## Commands

Prepare the OBS bridge:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Start-ObsVisionBridge.ps1
```

Prepare the bridge and start virtual camera:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Start-ObsVisionBridge.ps1 -StartVirtualCamera
```

Capture a labeled frame:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Capture-BBHFrame.ps1 -Label site-select
```
