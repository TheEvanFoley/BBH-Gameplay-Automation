# Windows Environment And Capture

## Goal

Establish the smallest reliable workflow for:

1. launching or locating the PC game
2. identifying the correct process and window
3. confirming what input surfaces are available
4. capturing footage with enough metadata to compare against arcade behavior

## Current Progress

The launch and control side is now in a much better place than when this document started:

- the game process and window are known
- launch can be scripted
- menu flows can be driven into real site gameplay
- the next capture question is no longer "can we get into gameplay?" but "how do we record and organize one site cleanly?"

## Why Start Here

Before building aim or menu automation, we need confidence in two boring but important layers:

- can we consistently find and focus the game window?
- can we capture repeatable footage tied to a known run context?

If either of those is unstable, later automation work becomes hard to trust.

## Initial Assumptions

- Host OS is Windows.
- Early automation should prefer native tooling and low-dependency scripts.
- Parity is a hypothesis, not a starting truth.
- Manual observation is still part of the workflow even when automation helps.

## Control Surfaces To Investigate

### Window and process layer

- executable name
- process id
- window title
- whether the game runs borderless, fullscreen, or windowed
- whether the window can be focused programmatically

### Input layer

- mouse movement
- mouse click
- keyboard navigation
- controller input
- whether raw input or anti-automation protections interfere

### Capture layer

- OBS Game Capture
- OBS Window Capture
- desktop capture fallback
- whether overlays or cursor state affect recording quality

## Recommended First Tests

1. Launch the game manually and run `experiments/windows/Get-GameSurface.ps1`.
2. Record which process and window title actually correspond to gameplay.
3. Verify whether the game accepts mouse and keyboard in menus.
4. Test whether OBS can capture the game consistently.
5. Save notes using the schema in `docs/data-schema.md`.

### Useful commands

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Get-GameSurface.ps1
```

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Get-GameSurface.ps1 -AsJson
```

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Get-GameSurface.ps1 -NamePattern Steam
```

Use `-IncludeWindowTitleSearch` only when needed. It is broader, which can produce false positives from browser tabs or notes that mention the game by name.

## Tradeoffs

### PowerShell first

Pros:

- already available on Windows
- easy to inspect and modify
- good for process and window discovery

Cons:

- not ideal for advanced real-time computer vision
- UI automation is possible but less elegant than dedicated tools

### OBS for capture

Pros:

- common and reliable
- supports scene collections and recording profiles
- easy to pair with manual or scripted workflows

Cons:

- requires separate setup
- capture mode reliability can vary by game renderer

## What Success Looks Like

We should be able to say all of the following with evidence:

- how the game is launched
- which process and window are the real gameplay surface
- which control methods work in practice
- how footage is recorded reproducibly
- how each capture is tagged for later parity review

See also:

- `docs/project-status.md`
- `docs/capture-workflow.md`
