# Control Findings

## Source

Observed from the in-game Controls screen on the PC version of Big Buck Hunter: Ultimate Trophy on May 23, 2026.

## Control Schemes

### Standard

Gameplay controls:

- `Shoot`: left click
- `Reload`: space
- `Focus`: right click
- `Move Reticle`: mouse wheel

UI controls:

- `Select`: right click
- `Back`: escape
- `Pause`: escape
- `Navigation`: scroll wheel

### Legacy

Same as Standard except:

- `Reload`: right click
- `Focus`: space

## Additional Observed Menu Inputs

These were not taken from the controls screen itself, but were confirmed during automation experiments:

- `Tab`: navigates through menu options
- `Enter`: selects the current menu option
- `Down`: moves downward through vertically ordered menu items
- Tile-style selection screens have so far behaved like standard mouse UIs in practice, where left click activates the hovered choice

## Immediate Automation Implications

- Standard controls are likely the better default for automation because gameplay `Shoot` and `UI Select` both map to mouse buttons instead of swapping a core gameplay action onto `space`.
- Keyboard-only menu automation is already viable for some screens.
- Some in-game controls text may describe arcade-oriented mappings or incomplete UI behavior, so live interaction should override menu-text assumptions when they conflict.
- We should treat gameplay reticle movement carefully because it appears to be mapped to scroll wheel rather than plain mouse movement in the controls summary, which may or may not fully describe real aiming behavior.

## Follow-Up Questions

- Does live gameplay actually aim with mouse movement despite the controls text mentioning scroll wheel?
- Does `Tab` always move forward through menu elements, or only on certain menus?
- Are there any controller-specific prompts or hidden bindings not shown on the controls screen?
