# Data Schema

## Purpose

Keep capture and parity notes lightweight, readable, and structured enough for later tooling.

## Capture Session Record

Use one record per recording session.

```json
{
  "sessionId": "2026-05-23-evening-run-01",
  "recordedAt": "2026-05-23T21:30:00-05:00",
  "operator": "manual",
  "platform": "pc",
  "buildLabel": "unknown",
  "adventure": "World of Change",
  "trek": "Trek Name",
  "site": "Site Name",
  "assumedVariant": "unknown",
  "assumedMirrorState": "unknown",
  "captureMethod": "obs-game-capture",
  "videoPath": "captures/2026-05-23/evening-run-01.mp4",
  "notesPath": "notes/2026-05-23-evening-run-01.md",
  "tags": ["parity", "manual-run"],
  "runNotes": "Observed spawn timing on first buck entry."
}
```

## Site Capture Record

Use one record per recorded site clip.

```json
{
  "runId": "2026-05-24-elk-trek3-site1-001",
  "recordedAt": "2026-05-24T18:30:00-05:00",
  "gameMode": "classic",
  "weapon": "gun",
  "adventure": "Elk",
  "trek": "Trek 3",
  "site": "Site 1",
  "notes": "Manual confirmation that this site matches known arcade behavior.",
  "videoPath": "captures/2026-05-24/elk-trek3-site1-001/video.mp4",
  "metadataVersion": 1,
  "siteVersion": null,
  "isMirror": null,
  "isPlayed": null,
  "hasTrophy": null,
  "critterVersion": null,
  "bonusGameName": null
}
```

## Parity Finding Record

Use one record per concrete observation, not one record per opinion.

```json
{
  "findingId": "2026-05-23-site-a-buck-entry-01",
  "recordedAt": "2026-05-23T21:42:00-05:00",
  "adventure": "World of Change",
  "trek": "Trek Name",
  "site": "Site Name",
  "category": "buck-path",
  "pcObservation": "Buck enters from left ridge after critter exit.",
  "arcadeExpectation": "Expected same left ridge entry based on player memory.",
  "parityAssessment": "unknown",
  "confidence": "low",
  "evidence": [
    "captures/2026-05-23/evening-run-01.mp4",
    "notes/2026-05-23-evening-run-01.md"
  ],
  "followUp": "Compare against direct arcade footage before trusting this pattern."
}
```

## Suggested Value Sets

### `category`

- `site-layout`
- `site-variant`
- `mirror-state`
- `buck-path`
- `critter-behavior`
- `shot-window`
- `scoring`
- `input-behavior`
- `capture-behavior`

### `parityAssessment`

- `match`
- `possible-match`
- `unclear`
- `possible-mismatch`
- `mismatch`

### `confidence`

- `low`
- `medium`
- `high`

## Storage Approach

- Start with Markdown notes plus embedded JSON snippets when convenient.
- Move to dedicated JSON or NDJSON exports once capture volume makes manual notes too slow.
- Keep file paths relative to the repo when possible so later tools can relocate the dataset cleanly.
- Prefer one folder per recorded site run once OBS capture organization is implemented.
