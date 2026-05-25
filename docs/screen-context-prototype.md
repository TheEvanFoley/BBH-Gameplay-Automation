# Screen Context Prototype

## Goal

Go beyond `screenFamily` and extract useful gameplay context from a live BBH frame when the screen layout makes that practical.

## Scripts

- `experiments/windows/Resolve-BBHScreenContext.ps1`
- `experiments/windows/screen-context-catalog.example.json`

## Current Behavior

The prototype currently does two things:

1. run the family-based menu recognizer
2. add extra context when the current family supports it

Today, the strongest case is `classic-site-selection-screen`:

- crop the top-right location region
- run Windows OCR on that region
- normalize the text
- map the recognized location to a known `adventure` and `trek`
- optionally OCR the top-middle adventure logo with multiple preprocessing variants to recover the adventure name when the logo text is readable

For `classic-trek-selection`, the current fallback is lighter:

- OCR the lower location-name strip and match any recognized trek places against the location catalog
- use those matched places to infer the current adventure and expose the visible trek options
- attempt the same top-middle logo OCR to recover the adventure name when the place-name OCR is weak
- only use the matched reference label as an adventure hint when the image is itself a labeled reference screenshot

## Example

```powershell
powershell -ExecutionPolicy Bypass -File experiments\windows\Resolve-BBHScreenContext.ps1 -CaptureCurrent
```

Example output:

```json
{
  "screenFamily": "classic-site-selection-screen",
  "confidence": 0.9329,
  "referenceLabel": "classic-site-selection-screen",
  "adventure": "Elk",
  "trek": "Trek 3",
  "locationText": "BROWNING, MT",
  "contextMethod": "site-selection-location-ocr"
}
```

For trek-selection screens, the output may look more like:

```json
{
  "screenFamily": "classic-trek-selection",
  "adventure": "Irish Elk",
  "trek": null,
  "availableTreks": ["Trek 1", "Trek 2", "Trek 3"],
  "matchedLocations": [
    { "pattern": "AGHNAMONA BOG", "adventure": "Irish Elk", "trek": "Trek 1" },
    { "pattern": "KAMA RIVER BASIN", "adventure": "Irish Elk", "trek": "Trek 2" },
    { "pattern": "RIF MOUNTAINS", "adventure": "Irish Elk", "trek": "Trek 3" }
  ],
  "contextMethod": "trek-selection-locations-ocr"
}
```

## Current Limits

- adventure logo OCR is promising but still inconsistent across all adventures and screen states
- the location mapping is only as good as the OCR text quality and the catalog entries we maintain
- trek selection can infer the adventure and visible trek options, but there is still no single selected trek until a user or script clicks one

This is still useful because it proves a path toward state-aware automation:

- recognize the family first
- extract text or structured hints from known screen regions
- expand the metadata catalog over time as more adventures and treks are captured
