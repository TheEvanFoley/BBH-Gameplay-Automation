# Game Controls And Sequences

## Goal

Create a small control layer we can trust before trying to automate full gameplay.

## Why This Layer Exists

The first useful automation is not "play perfectly." It is:

1. focus the game reliably
2. click predictable menu positions
3. send simple key presses
4. run those actions from a readable sequence file

That gives us a safe base for launch-to-menu automation and later capture workflows.

## Files

- `experiments/windows/InputToolkit.ps1`
- `experiments/windows/Run-ControlSequence.ps1`
- `experiments/windows/game-controls.example.json`
- `experiments/windows/game-controls.local.json`

## What The Toolkit Supports

- waiting for the BBH window
- focusing the game window
- reading client-area geometry
- clicking by relative client coordinates
- sending key presses to the focused game window

## Relative Coordinates

Clicks use normalized values from `0` to `1`:

- `xPercent: 0.0` means the far left edge of the client area
- `xPercent: 0.5` means horizontal center
- `xPercent: 1.0` means the far right edge
- `yPercent: 0.0` means the top edge
- `yPercent: 1.0` means the bottom edge

This is better than hardcoded screen pixels because it gives us a chance to survive different resolutions or borderless-window sizes.

## Example Sequence

```json
{
  "processNamePattern": "^BBH$",
  "windowTitlePattern": "BigBuckHunter_UltimateTrophy",
  "postFocusDelayMilliseconds": 500,
  "steps": [
    { "type": "focus", "description": "Bring the game forward." },
    { "type": "wait", "milliseconds": 1000, "description": "Let the menu settle." },
    { "type": "click", "xPercent": 0.5, "yPercent": 0.82, "description": "Press a lower-center button." }
  ]
}
```

## Commands

Dry run the control sequence:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Run-ControlSequence.ps1 -DryRun
```

Run the real sequence:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Run-ControlSequence.ps1
```

## Recommended Calibration Workflow

1. Keep the game at a stable resolution or borderless size.
2. Start with `-DryRun` and confirm the intended step order.
3. Change one click at a time in `game-controls.local.json`.
4. Test only one menu transition at a time.
5. Write down which menu screen each coordinate was calibrated against.

## Tradeoffs

### Relative clicks

Pros:

- simple to reason about
- easy to calibrate
- good enough for menu automation

Cons:

- assumes a stable UI layout
- not robust against unexpected popups or resolution changes

### SendKeys

Pros:

- very easy to test
- useful when menus accept keyboard input

Cons:

- depends on window focus
- less deterministic than future lower-level input approaches
