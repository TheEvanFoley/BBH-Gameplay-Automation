# Site Selection Calibration

## Goal

Select one of the five visible sites from the site-selection screen.

## Files

- `experiments/windows/calibration/site-selection.example.json`
- `experiments/windows/Select-SiteChoice.ps1`

## Current Screenshot-Based Site Targets

- `site1`: `xPercent 0.115`, `yPercent 0.602`
- `site2`: `xPercent 0.313`, `yPercent 0.602`
- `site3`: `xPercent 0.513`, `yPercent 0.602`
- `site4`: `xPercent 0.710`, `yPercent 0.602`
- `site5`: `xPercent 0.905`, `yPercent 0.602`

## Command

Select `Site 3`:

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Select-SiteChoice.ps1 -SiteName site3
```
