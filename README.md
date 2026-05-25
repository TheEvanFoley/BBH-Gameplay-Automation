# BBH Gameplay Automation

Research and tooling around parity testing, menu automation, and reproducible gameplay capture for Big Buck Hunter Reloaded / Ultimate Trophy on PC.

## Purpose

This project is the experimental branch for deeper technical work that may or may not be needed long-term:

- determine whether the PC game matches arcade site behavior closely enough
- automate gameplay input
- capture reproducible site behavior
- explore TAS-like score-maximizing runs

## Scope

This project is intentionally separate from both the qualification tracker and the video-analysis tool. It should produce experiments, findings, and tooling that can later support the other projects.

## Early Deliverables

1. Confirm whether PC gameplay has practical parity with arcade sites.
2. Document input methods and automation constraints.
3. Capture reproducible site runs for analysis.
4. Determine whether automation is worth pursuing beyond parity checks.

## Current Status

This repo is already usable for practical capture work, even though some workflows still need supervision.

What is already working:

- the PC game can be launched reliably from script
- the BBH window can be found, focused, and controlled
- menus can be navigated through a mix of keyboard and calibrated mouse automation
- animal, trek, site, and name-entry flows are scriptable
- OBS-backed fixed-duration site recording is working well for real site footage collection
- a local GUI can trigger the common launch, route, site-capture, trek-capture, and adventure-capture workflows
- a screenshot-based screen recognizer can classify known menu families and resolve some adventure / trek context

What this means:

- we can now capture real site footage without relying on arcade recording
- multiple `Elk` trek 3 sites were recognized from prior arcade experience, which is a strong early parity signal
- the repo is now a useful “capture operator tool,” not just a pile of experiments

## Current Capture Model

The current reliable path is intentionally simple:

1. route to the desired site-selection screen
2. start OBS recording
3. click the desired site
4. move the reticle to a rest position near the bottom-right
5. record for a fixed duration, currently `35` seconds
6. stop OBS and file the recording

This fixed-duration model is preferred right now over live gameplay-end detection because it has proven much more predictable in practice.

Recordings are filed under:

- `E:\BigBuckHunterRecordings`

with one run folder per recording plus metadata and notes.

## First Practical Workflow

The first useful version of this repo is not a full gameplay bot. It is a repeatable workflow for:

1. finding the running game process and window reliably
2. recording what launch and input surfaces exist on the PC version
3. capturing footage plus structured metadata
4. writing parity observations in a format that can later feed video analysis

That approach keeps the project valuable even if the PC version turns out not to match arcade behavior closely enough.

## Directory Notes

- `docs/`: technical notes and findings
- `experiments/`: prototype scripts or automation tests
- `notes/`: parity observations, setup instructions, findings

## Current Starting Points

- `docs/parity-checklist.md`: high-level parity criteria
- `docs/windows-environment-and-capture.md`: Windows setup, capture, and control assumptions
- `docs/launching-the-game.md`: config-backed launch workflow for Steam or direct executable startup
- `docs/game-controls-and-sequences.md`: first control layer for focus, clicks, keys, and menu automation steps
- `docs/control-findings.md`: currently observed in-game bindings and menu-navigation discoveries
- `docs/menu-coordinate-calibration.md`: screenshot-based relative coordinates for menu targets
- `docs/animal-carousel-selection.md`: timed reset-and-drive workflow for selecting animals by name
- `docs/four-slot-carousel-calibration.md`: reset-and-drive probe plus slot coordinates for 4-tile carousel screens
- `docs/name-entry-calibration.md`: screenshot-based key coordinates for the on-screen name keyboard
- `docs/site-selection-calibration.md`: screenshot-based site coordinates for the 5-site selection screen
- `docs/screen-recognition-bootstrap.md`: first OBS-backed bridge for capturing frames and preparing future screen recognition
- `docs/screen-recognition-first-pass.md`: family-based screenshot recognizer for labeled BBH menu frames
- `docs/current-handoff.md`: best single-file resume point for a fresh thread
- `docs/capture-workflow.md`: planned OBS-based site capture and organization flow
- `docs/project-status.md`: current findings, proven automation steps, and where to resume later
- `docs/gui-runner.md`: current GUI options, limitations, and emergency-stop behavior
- `docs/site-capture-runner.md`: current one-site fixed-duration capture behavior
- `docs/data-schema.md`: lightweight metadata shapes for captures and parity findings
- `experiments/windows/Get-GameSurface.ps1`: inventory running processes and visible windows for launch/focus experiments
- `experiments/windows/Launch-Game.ps1`: launch helper with optional post-launch process/window inspection
- `experiments/windows/Run-ControlSequence.ps1`: run readable control steps from JSON for early menu automation
- `experiments/windows/Select-AnimalFromCarousel.ps1`: select carousel animals by name from a deterministic reset state
- `experiments/windows/Start-ElkAdventure.ps1`: current end-to-end launch-to-Elk adventure runner
- `experiments/windows/Probe-FourSlotCarousel.ps1`: probe left/middle/right states on 4-tile carousel screens
- `experiments/windows/Demo-FourSlotHover.ps1`: hover all 4 visible slots in a chosen 4-tile carousel state
- `experiments/windows/Select-FourSlotChoice.ps1`: click a chosen slot from a left/middle/right 4-tile carousel state
- `experiments/windows/Enter-PlayerName.ps1`: type a short leaderboard name using the on-screen keyboard
- `experiments/windows/Select-SiteChoice.ps1`: click one of the 5 visible hunting sites
- `experiments/windows/Start-ObsSiteCapture.ps1`: start an OBS-backed one-site capture run with metadata
- `experiments/windows/Stop-ObsSiteCapture.ps1`: stop OBS recording and file the newest video into the active run folder
- `experiments/windows/Start-ObsVisionBridge.ps1`: switch OBS to the BBH scene and optionally start stream outputs
- `experiments/windows/Capture-BBHFrame.ps1`: save a labeled screenshot from the BBH OBS source
- `experiments/windows/Recognize-BBHScreen.ps1`: compare a current frame against labeled references and return the closest screen
- `experiments/windows/screen-recognition-catalog.example.json`: map reference labels to stable screen families
- `experiments/windows/Resolve-BBHScreenContext.ps1`: combine family recognition with OCR and simple hints to infer adventure and trek when possible
- `experiments/windows/screen-context-catalog.example.json`: map recognized locations to known adventure and trek metadata
- `experiments/windows/Get-BBHState.ps1`: capture and resolve the current BBH screen family plus any available context
- `experiments/windows/Invoke-BBHMenuRouter.ps1`: state-aware polling controller that routes through known menu families to a target site
- `experiments/windows/menu-router.example.json`: generic menu click targets and router timing defaults
- `experiments/windows/Invoke-BBHSiteCaptureRun.ps1`: route to site selection, start OBS recording, click one site, and record for a fixed duration
- `experiments/windows/Invoke-BBHTrekCaptureRun.ps1`: record sites `1-5` for a trek, with timing-based site handoff and post-trek cleanup
- `experiments/windows/Invoke-BBHAdventureCaptureRun.ps1`: chain three trek recordings for a full adventure pass
- `experiments/windows/Start-BBHAutomationGui.ps1`: local operator GUI for launch, route, and capture workflows
- `experiments/windows/Stop-BBHAutomationEmergency.ps1`: external emergency stop for stuck GUI or runaway workflows
