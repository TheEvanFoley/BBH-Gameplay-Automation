# Capture Workflow

## Goal

Capture reproducible gameplay video from the PC version in a format that is easy to sort, review, and analyze later.

## Current Recommendation

- use OBS as the recorder
- define one run as one `site`
- keep one folder per recorded run
- attach structured metadata to each run

## Why One Site Per Run

A single-site recording is easier to:

- label
- compare against arcade behavior
- revisit when checking site variants
- feed into later video-analysis tooling

A full trek or full animal run can still be useful operationally, but site-level files are the cleanest analysis unit.

## Proposed Run Layout

```text
E:/BigBuckHunterRecordings/2026-05-24/elk-trek3-site1-001/
  video.mp4
  metadata.json
  notes.md
```

## OBS Role

OBS can continue recording to its normal output location first.

The automation workflow should then:

1. create a run folder
2. prefill metadata
3. move or copy the newest OBS recording into that run folder
4. leave room for later notes or enriched annotations

The current OBS setup also has a dedicated scene:

- scene: `BigBuckHunter`
- source: `BigBuckHunterGame`
- OBS record directory: `E:/BigBuckHunterRecordings`

The current capture scripts now keep run bundles under `E:/BigBuckHunterRecordings` instead of inside this repo, so the recorded dataset stays separate from the automation codebase.

## Required Capture Metadata

- `gameMode`
- `weapon`
- `adventure`
- `trek`
- `site`
- `recordedAt`
- `notes`

## Optional Enrichment Metadata

These can be added after the recording if needed:

- `siteVersion`
- `isMirror`
- `isPlayed`
- `hasTrophy`
- `critterVersion`
- `bonusGameName`

## Recommended Operator Flow

1. Start or prepare a site run.
2. Start OBS recording.
3. Play or automate the site.
4. Stop OBS recording.
5. Create or finalize the run folder.
6. Attach the video plus metadata.
7. Add later analysis fields once the clip is reviewed.

## Next Implementation Slice

- a metadata stub generator for one site run
- a run-folder naming convention under the OBS recording root
- a helper that associates the newest OBS file with the current run
- a notes template for quick observations after each site

## Current Repo Scripts

- `experiments/windows/obs-capture.local.json`: local OBS CLI path and websocket settings
- `experiments/windows/Start-ObsSiteCapture.ps1`: create a run folder under `E:/BigBuckHunterRecordings`, write metadata, and start OBS recording
- `experiments/windows/Stop-ObsSiteCapture.ps1`: stop OBS recording and move the newest recording into the active run folder

## Example Commands

Start a site run:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Start-ObsSiteCapture.ps1 -GameMode classic -Weapon gun -Adventure Elk -Trek "Trek 3" -Site "Site 1" -Notes "Manual capture test"
```

Stop and finalize the active run:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Stop-ObsSiteCapture.ps1
```
