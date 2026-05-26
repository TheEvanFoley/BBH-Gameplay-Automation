# GUI Runner

## Goal

Provide a local Windows GUI so capture and routing workflows can be run without using the chat interface.

## Script

- `experiments/windows/Start-BBHAutomationGui.ps1`

## What It Does

The GUI is a thin wrapper around the scripts already used during development:

- `Launch-Game.ps1`
- `Invoke-BBHMenuRouter.ps1`
- `Invoke-BBHSiteCaptureRun.ps1`
- `Invoke-BBHTrekCaptureRun.ps1`
- `Invoke-BBHWorkflow.ps1`

That means the GUI is not a second implementation of the automation logic. It simply exposes the existing workflow through dropdowns and buttons.

## Available Actions

- `Launch Game`
- `Route To Site`
- `Record Site`
- `Record Current Setup`
- `Record Full Trek`
- `Record Adventure`
- `Open Recordings`

## Current Controls

- starting screen
- run mode
- weapon
- adventure
- trek
- site or starting site
- player name
- recording seconds
- trek cycle seconds
- repeat count
- notes
- dry run toggle

## Starting Screen Notes

`Game Closed` changes behavior directly by launching the game first.

`Site Selection` also changes behavior for `Record Site`.

When `Starting Screen` is `Site Selection` and the action is `Record Site`, the workflow now skips the router and screen-recognition preflight checks. It immediately starts OBS recording and clicks the selected site based on the calibrated site coordinates. This is the fastest path when the operator already has the game on the correct site-selection screen.

`Record Site` repeat is only supported from `Main Menu`.

If `Repeat Count` is greater than `1` and `Starting Screen` is not `Main Menu`, the GUI disables `Record Site`. The workflow also enforces that rule directly if it is called outside the GUI.

The other starting-screen values still mainly document the current state and keep the GUI aligned with how the project is operated.

## Run Mode

The GUI now exposes a `Run Mode` toggle:

- `Safe`: existing routed behavior with screen recognition and preflight checks
- `Fast`: timing-based blind clicks for a limited, high-throughput path

`Fast` is currently only supported for `Record Site` when `Starting Screen` is `Main Menu`. In other combinations, the GUI forces the mode back to `Safe`.

## Record Site Repeat Behavior

When `Starting Screen` is `Main Menu` and `Repeat Count` is greater than `1`, the workflow repeats the same site capture by:

1. routing from the main menu to the selected site
2. recording that site normally
3. waiting the remaining cycle time computed as `Trek Cycle Seconds - Recording Seconds`
4. clicking the upper-left `MAIN MENU` return target
5. starting the next routed site capture from the main menu

The upper-left return target is configured as `gameplayMainMenu` in the menu-router config and is currently estimated from the site-selection screen at roughly `xPercent 0.332`, `yPercent 0.104`.

## Record Site Fast Behavior

`Fast` mode currently applies only to `Record Site` from `Main Menu`.

That path uses fixed timing instead of screen recognition:

1. optional high-screen focus click on the first pass only
2. click `Start Game`
3. click `Big Buck Hunter`
4. click `Classic`
5. click `1 Player`
6. click the selected weapon
7. drive the adventure carousel only as far as needed for the selected animal, then click the adventure
8. click the selected trek directly by slot coordinate
9. hold left click on the tip screen
10. click `Confirm` on the name-selection screen
11. start OBS capture and click the selected site
12. record for `Recording Seconds`

Between repeated runs, it waits `Trek Cycle Seconds - Recording Seconds`, clicks the `MAIN MENU` return target, waits 3 seconds, and then starts the next fast pass without the initial focus click.

## Record Full Trek Behavior

The current full-trek runner records sites in order from the selected `Site / Start Site` value through `5`.

It does this by:

1. using the full route + preflight flow for the first site
2. using direct site clicks plus fixed-duration recording for the remaining sites in the trek
3. waiting for the remaining cycle time computed as `Trek Cycle Seconds - Recording Seconds` between sites

This is intentionally simple and predictable. It does not currently use live end-of-run detection.

After the fifth site, the runner advances through `bonus-report` and leaves the game on `post-trek-menu`.

If `Repeat Count` is greater than `1`, the trek runner uses the `Replay` button on the post-trek menu between passes, then steps back through the replay transition flow:

1. `tip-screen`
2. `name-selection-screen`
3. short loading delay
4. `classic-site-selection-screen`

## Record Adventure Behavior

`Record Adventure` records three treks for the selected adventure in cyclic order starting from the selected trek.

Examples:

- start on `Trek 1` -> records `Trek 1`, `Trek 2`, `Trek 3`
- start on `Trek 2` -> records `Trek 2`, `Trek 3`, `Trek 1`

The selected `Site / Start Site` applies only to the first trek. Later treks start at `Site 1`.

Between treks, the runner uses:

1. `bonus-report` -> single click to continue
2. `post-trek-menu` -> `Next`

If `Repeat Count` is greater than `1`, the runner uses `New Hunt` after the third trek before starting the next full-adventure pass.

## Record Current Setup

`Record Current Setup` is the flexible manual option.

Use it when you already handled the game setup yourself and only want the GUI to:

1. start OBS recording
2. wait for the configured fixed duration
3. stop OBS and file the run

It does not launch the game, route menus, or click a site.

## Launch Command

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Start-BBHAutomationGui.ps1
```

## Emergency Stop

If the GUI becomes unresponsive or a workflow keeps running when it should not, use the external emergency stop:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Stop-BBHAutomationEmergency.ps1
```

or run:

```text
experiments\windows\Stop-BBHAutomationEmergency.cmd
```

That emergency stop:

1. stops an active OBS capture if one is in progress
2. kills the repo's active BBH automation PowerShell processes
