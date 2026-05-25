# Project Status

## Current Position

This repo now has a working, usable foundation for interacting with the PC game in a repeatable way.

## Proven Capabilities

### Launch and focus

- the game can be launched from script
- the live BBH window can be found and focused
- startup stabilization matters because the game can briefly relaunch or disappear during startup

### Menu automation

- title and early menus can be driven with keyboard input
- later menus are more reliable with calibrated mouse coordinates
- animal, trek, site, and name-entry flows are scriptable
- a menu router can navigate between major known menu families using OBS-captured frames

### Recording and operator tooling

- OBS-backed site recording is working reliably in fixed-duration mode
- the current reliable default is `35` seconds per site recording
- recordings are saved under `E:\BigBuckHunterRecordings`
- a local GUI can trigger launch, route, site, trek, and adventure workflows
- an external emergency-stop script exists because GUI-stop behavior is not yet fully trusted

### Calibration work completed

- left and right two-choice tile screens
- timed animal carousel states
- four-slot carousel middle-state timing
- trek-specific slot geometry
- site-selection coordinates
- on-screen QWERTY name keyboard
- key menu-family recognition references

## Strong Parity Signal So Far

Multiple `Elk` trek 3 sites were recognized from prior arcade experience during PC testing.

This does not prove full parity yet, but it is a meaningful signal that the PC version may be good enough for capture and later site analysis.

We also successfully used the toolchain to capture complete Elk trek 3 site footage on PC, which is the most important near-term proof of usefulness.

## Known Unknowns

- randomized trophy behavior
- site version recognition at scale
- mirror-state detection
- critter variation labeling
- bonus-game capture and labeling
- fully unattended long chained automation
- elegant in-GUI workflow interruption

## Best Next Phase

The repo is already in a state where it can collect useful footage now, so future work can bias toward reliability and supervision reduction instead of proving core feasibility.

That means likely next work is:

1. improve unattended workflow behavior
2. tighten repeated trek / adventure flows
3. strengthen screen recovery and post-run handling
4. improve context extraction where it meaningfully reduces operator effort

## Best Resume Point Later

When returning to the project, the most valuable next implementation step is:

- use `docs/current-handoff.md` as the first read
