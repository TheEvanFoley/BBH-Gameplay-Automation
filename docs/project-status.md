# Project Status

## Current Position

This repo now has a working foundation for interacting with the PC game in a repeatable way.

## Proven Capabilities

### Launch and focus

- the game can be launched from script
- the live BBH window can be found and focused
- startup stabilization matters because the game can briefly relaunch or disappear during startup

### Menu automation

- title and early menus can be driven with keyboard input
- later menus are more reliable with calibrated mouse coordinates
- animal, trek, site, and name-entry flows are scriptable

### Calibration work completed

- left and right two-choice tile screens
- timed animal carousel states
- four-slot carousel middle-state timing
- trek-specific slot geometry
- site-selection coordinates
- on-screen QWERTY name keyboard

## Strong Parity Signal So Far

Multiple `Elk` trek 3 sites were recognized from prior arcade experience during PC testing.

This does not prove full parity yet, but it is a meaningful signal that the PC version may be good enough for capture and later site analysis.

## Known Unknowns

- randomized trophy behavior
- site version recognition at scale
- mirror-state detection
- critter variation labeling
- bonus-game capture and labeling

## Best Next Phase

Shift the main effort toward OBS-based site capture and metadata organization.

The repo is now in a good state to resume later from:

1. launch and automate into a desired site
2. record one site at a time
3. store video plus metadata in run folders
4. enrich labels after review

## Best Resume Point Later

When returning to the project, the most valuable next implementation step is:

- build the site-level OBS capture organizer and metadata stub workflow
