# Current Handoff

## Why This File Exists

This is the best single-file resume point for a fresh thread or future work session.

If someone needs to quickly understand what the repo does today, what is proven, and what still needs care, start here and then branch into the linked docs.

## Current Reality

This repo is no longer just exploratory.

It already works as a practical capture tool for BBH gameplay footage on PC, with the biggest current strength being:

- route to a desired site
- start OBS
- record a fixed-duration site clip
- file the clip plus metadata into a separate recordings directory

It still needs supervision in some flows, especially longer chained automation, but it is already usable for data collection.

## Most Important Proven Capabilities

- launch the PC game from script
- focus and control the BBH window
- navigate menus through keyboard plus calibrated mouse automation
- select animals, treks, sites, and on-screen name-entry keys
- recognize major menu families from OBS-captured screenshots
- run fixed-duration one-site capture reliably
- use the GUI for common operator workflows

## Proven Capture Workflow

The current reliable site-capture flow is:

1. route to the desired site-selection screen
2. start OBS recording
3. click the target site
4. move the reticle to a bottom-right rest position
5. record for `35` seconds
6. stop OBS
7. save the video plus metadata into `E:\BigBuckHunterRecordings`

This works better right now than trying to detect the end of gameplay in real time.

## Important Current Assumptions

- OBS is the recorder
- the active scene is `BigBuckHunter`
- the capture source is `BigBuckHunterGame`
- recordings should be filed under `E:\BigBuckHunterRecordings`
- audio handling is managed in OBS, not in the repo scripts

## Current Operator Entry Points

- GUI:
  - `experiments/windows/Start-BBHAutomationGui.ps1`
- one-site capture:
  - `experiments/windows/Invoke-BBHSiteCaptureRun.ps1`
- full-trek capture:
  - `experiments/windows/Invoke-BBHTrekCaptureRun.ps1`
- full-adventure capture:
  - `experiments/windows/Invoke-BBHAdventureCaptureRun.ps1`
- menu router:
  - `experiments/windows/Invoke-BBHMenuRouter.ps1`
- emergency stop:
  - `experiments/windows/Stop-BBHAutomationEmergency.ps1`
  - `experiments/windows/Stop-BBHAutomationEmergency.cmd`

## Current GUI Feature Set

The GUI can currently trigger:

- `Launch Game`
- `Route To Site`
- `Record Site`
- `Record Current Setup`
- `Record Full Trek`
- `Record Adventure`
- `Open Recordings`

Important note:

- the GUI stop button is not yet trusted as the sole stop mechanism
- the external emergency stop script/cmd is the safe fallback

## Screen Families That Matter Today

Recognition is currently most valuable for menu routing and post-run cleanup, not for live gameplay control.

Key families already in use:

- `landing-page`
- `main-menu`
- `game-mode-selection`
- `big-buck-hunter-mode-selection`
- `classic-player-count`
- `classic-weapon-selection`
- `classic-adventure-carousel`
- `classic-trek-selection`
- `tip-screen`
- `name-selection-screen`
- `classic-site-selection-screen`
- `bonus-report`
- `post-trek-menu`

## Current Full Trek Model

For a trek recording:

- the first selected site uses the full route + preflight flow
- later sites in the same trek trust timing and direct clicks instead of repeated re-routing
- after Site 5, the runner should advance through `bonus-report`
- it should then stop on `post-trek-menu`
- if repeating the trek, it uses `Replay`

Replay caveat already learned:

- `Replay` does not go directly to site selection
- it goes through:
  1. `tip-screen`
  2. `name-selection-screen`
  3. short loading
  4. `classic-site-selection-screen`

## Known Rough Edges

- GUI stop behavior is not yet elegant
- some longer automation chains still need monitoring
- trek/adventure repeated-run flows may still hide timing bugs
- screen recognition is good for menu families but not yet a full unattended gameplay-state solution
- gameplay-end detection is intentionally de-emphasized right now in favor of fixed-duration capture

## Why The Current State Is Still Valuable

Even with those rough edges, the project already delivers the thing it most needed to deliver:

- reproducible gameplay footage collection from the PC version

That means the repo is already useful for:

- parity checking
- site archive building
- future video-analysis input generation
- later site-version / mirror / trophy / critter review

## Best Docs To Read Next

- `README.md`
- `docs/project-status.md`
- `docs/gui-runner.md`
- `docs/site-capture-runner.md`
- `docs/menu-router.md`
- `docs/screen-context-prototype.md`
- `docs/capture-workflow.md`

## Best Practical Resume Point

If resuming work later, the most likely next areas are:

1. harden unattended GUI / workflow behavior
2. tighten repeated trek / adventure automation
3. improve menu-state recovery logic
4. improve screen/context recognition where it reduces operator supervision
