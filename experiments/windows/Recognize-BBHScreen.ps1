[CmdletBinding()]
param(
    [string]$ImagePath,
    [string]$ReferenceRoot = ".\output\frames",
    [string]$CatalogPath = ".\experiments\windows\screen-recognition-catalog.example.json",
    [switch]$CaptureCurrent,
    [string]$CaptureLabel = "recognizer-current",
    [int]$HashSize = 16
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function Get-ScriptResolvedPath {
    param(
        [string]$PathValue
    )

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $candidate = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PathValue)
    if (Test-Path -LiteralPath $candidate) {
        return (Resolve-Path $candidate).Path
    }

    $joined = Join-Path $repoRoot $PathValue
    if (Test-Path -LiteralPath $joined) {
        return (Resolve-Path $joined).Path
    }

    return $candidate
}

function Get-ConfigValue {
    param(
        $Object,
        [string]$PropertyName,
        $DefaultValue = $null
    )

    $property = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $DefaultValue
    }

    return $property.Value
}

function Get-ImageAverageHash {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Size
    )

    $resized = [System.Drawing.Bitmap]::new($Size, $Size)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($resized)
        try {
            $graphics.DrawImage($Bitmap, 0, 0, $Size, $Size)
        }
        finally {
            $graphics.Dispose()
        }

        $values = New-Object System.Collections.Generic.List[int]
        $sum = 0.0
        for ($y = 0; $y -lt $Size; $y++) {
            for ($x = 0; $x -lt $Size; $x++) {
                $pixel = $resized.GetPixel($x, $y)
                $gray = [int][Math]::Round(($pixel.R * 0.299) + ($pixel.G * 0.587) + ($pixel.B * 0.114))
                $values.Add($gray)
                $sum += $gray
            }
        }

        $average = $sum / $values.Count
        $chars = New-Object System.Collections.Generic.List[string]
        foreach ($value in $values) {
            if ($value -ge $average) {
                $chars.Add("1")
            }
            else {
                $chars.Add("0")
            }
        }

        return ($chars -join "")
    }
    finally {
        $resized.Dispose()
    }
}

function Get-MeanAbsoluteDistance {
    param(
        [double[]]$Left,
        [double[]]$Right
    )

    if ($Left.Count -ne $Right.Count) {
        throw "Cannot compare feature vectors with different lengths."
    }

    $sum = 0.0
    for ($i = 0; $i -lt $Left.Count; $i++) {
        $sum += [Math]::Abs($Left[$i] - $Right[$i])
    }

    return ($sum / $Left.Count)
}

function Get-ReferenceLabel {
    param(
        [string]$FileName
    )

    if ($FileName -match '^\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}-\d{3}-(.+)\.png$') {
        return $matches[1]
    }

    return [System.IO.Path]::GetFileNameWithoutExtension($FileName)
}

function Resolve-CatalogEntry {
    param(
        [object[]]$CatalogEntries,
        [string]$ReferenceLabel
    )

    return $CatalogEntries | Where-Object {
        $_.enabled -ne $false -and $_.referenceLabel -eq $ReferenceLabel
    } | Select-Object -First 1
}

function Get-ImageFeatureVector {
    param(
        [string]$FilePath,
        [int]$Size
    )

    $bitmap = [System.Drawing.Bitmap]::new($FilePath)
    try {
        $regions = @(
            [pscustomobject]@{ X = 0; Y = 0; Width = $bitmap.Width; Height = $bitmap.Height }
            [pscustomobject]@{ X = 0; Y = 0; Width = $bitmap.Width; Height = [int]($bitmap.Height / 2) }
            [pscustomobject]@{ X = 0; Y = [int]($bitmap.Height / 2); Width = $bitmap.Width; Height = $bitmap.Height - [int]($bitmap.Height / 2) }
            [pscustomobject]@{ X = 0; Y = 0; Width = [int]($bitmap.Width / 2); Height = $bitmap.Height }
            [pscustomobject]@{ X = [int]($bitmap.Width / 2); Y = 0; Width = $bitmap.Width - [int]($bitmap.Width / 2); Height = $bitmap.Height }
            [pscustomobject]@{ X = [int]($bitmap.Width * 0.25); Y = [int]($bitmap.Height * 0.25); Width = [int]($bitmap.Width * 0.5); Height = [int]($bitmap.Height * 0.5) }
        )

        $features = New-Object System.Collections.Generic.List[double]
        foreach ($region in $regions) {
            $cropRect = [System.Drawing.Rectangle]::new($region.X, $region.Y, $region.Width, $region.Height)
            $cropped = $bitmap.Clone($cropRect, $bitmap.PixelFormat)
            try {
                $resized = [System.Drawing.Bitmap]::new($Size, $Size)
                try {
                    $graphics = [System.Drawing.Graphics]::FromImage($resized)
                    try {
                        $graphics.DrawImage($cropped, 0, 0, $Size, $Size)
                    }
                    finally {
                        $graphics.Dispose()
                    }

                    for ($y = 0; $y -lt $Size; $y++) {
                        for ($x = 0; $x -lt $Size; $x++) {
                            $pixel = $resized.GetPixel($x, $y)
                            $gray = ($pixel.R * 0.299) + ($pixel.G * 0.587) + ($pixel.B * 0.114)
                            $features.Add([Math]::Round($gray, 2))
                        }
                    }
                }
                finally {
                    $resized.Dispose()
                }
            }
            finally {
                $cropped.Dispose()
            }
        }

        return ,$features.ToArray()
    }
    finally {
        $bitmap.Dispose()
    }
}

if ($CaptureCurrent) {
    $captureScriptPath = Join-Path $PSScriptRoot "Capture-BBHFrame.ps1"
    & $captureScriptPath -Label $CaptureLabel
}

$resolvedCatalogPath = Get-ScriptResolvedPath -PathValue $CatalogPath
if (-not (Test-Path -LiteralPath $resolvedCatalogPath)) {
    throw "Catalog path not found: $resolvedCatalogPath"
}

$catalog = Get-Content -LiteralPath $resolvedCatalogPath -Raw | ConvertFrom-Json
$catalogReferenceRoot = Get-ConfigValue -Object $catalog -PropertyName "referenceRoot"
$confidenceThreshold = [double](Get-ConfigValue -Object $catalog -PropertyName "confidenceThreshold" -DefaultValue 0.93)
$ignoredLabelPatterns = @(Get-ConfigValue -Object $catalog -PropertyName "ignoredLabelPatterns" -DefaultValue @())
$catalogEntries = @(Get-ConfigValue -Object $catalog -PropertyName "references" -DefaultValue @())

if ($catalogReferenceRoot) {
    $ReferenceRoot = $catalogReferenceRoot
}

$resolvedReferenceRoot = Get-ScriptResolvedPath -PathValue $ReferenceRoot
if (-not (Test-Path -LiteralPath $resolvedReferenceRoot)) {
    throw "Reference root not found: $resolvedReferenceRoot"
}

if (-not $ImagePath) {
    $imageFile = Get-ChildItem -LiteralPath $resolvedReferenceRoot -Recurse -File -Filter "*.png" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $imageFile) {
        throw "No PNG files found under $resolvedReferenceRoot"
    }

    $resolvedImagePath = $imageFile.FullName
}
else {
    $resolvedImagePath = Get-ScriptResolvedPath -PathValue $ImagePath
}

if (-not (Test-Path -LiteralPath $resolvedImagePath)) {
    throw "Image path not found: $resolvedImagePath"
}

$targetLabel = Get-ReferenceLabel -FileName ([System.IO.Path]::GetFileName($resolvedImagePath))
$targetCatalogEntry = Resolve-CatalogEntry -CatalogEntries $catalogEntries -ReferenceLabel $targetLabel
if ($targetCatalogEntry) {
    $targetIgnored = $false
    foreach ($pattern in $ignoredLabelPatterns) {
        if ($targetLabel -match $pattern) {
            $targetIgnored = $true
            break
        }
    }

    if (-not $targetIgnored) {
        [pscustomobject]@{
            screenFamily = [string]$targetCatalogEntry.screenFamily
            confidence = 1.0
            matchedReference = $resolvedImagePath
            referenceLabel = $targetLabel
            isKnown = $true
            threshold = $confidenceThreshold
        } | ConvertTo-Json -Depth 4
        return
    }
}

$targetVector = Get-ImageFeatureVector -FilePath $resolvedImagePath -Size $HashSize
$references = Get-ChildItem -LiteralPath $resolvedReferenceRoot -Recurse -File -Filter "*.png" |
    Where-Object {
        if ($_.FullName -eq $resolvedImagePath) {
            return $false
        }

        $label = Get-ReferenceLabel -FileName $_.Name
        foreach ($pattern in $ignoredLabelPatterns) {
            if ($label -match $pattern) {
                return $false
            }
        }

        $entry = Resolve-CatalogEntry -CatalogEntries $catalogEntries -ReferenceLabel $label
        return $null -ne $entry
    }

if (-not $references) {
    throw "Need at least one reference PNG besides the target image."
}

$results = foreach ($reference in $references) {
    $referenceLabel = Get-ReferenceLabel -FileName $reference.Name
    $catalogEntry = Resolve-CatalogEntry -CatalogEntries $catalogEntries -ReferenceLabel $referenceLabel
    if (-not $catalogEntry) {
        continue
    }

    $referenceVector = Get-ImageFeatureVector -FilePath $reference.FullName -Size $HashSize
    $distance = Get-MeanAbsoluteDistance -Left $targetVector -Right $referenceVector
    $confidence = [Math]::Max(0.0, 1.0 - ($distance / 255.0))

    [pscustomobject]@{
        screenFamily = [string]$catalogEntry.screenFamily
        referenceLabel = $referenceLabel
        confidence = [Math]::Round($confidence, 4)
        distance = [Math]::Round($distance, 4)
        matchedReference = $reference.FullName
    }
}

if (-not $results) {
    throw "No enabled catalog references matched the available screenshots."
}

$best = $results | Sort-Object distance, screenFamily, referenceLabel | Select-Object -First 1
$isKnown = $best.confidence -ge $confidenceThreshold

[pscustomobject]@{
    screenFamily = if ($isKnown) { $best.screenFamily } else { "unknown" }
    confidence = $best.confidence
    matchedReference = $best.matchedReference
    referenceLabel = $best.referenceLabel
    isKnown = $isKnown
    threshold = $confidenceThreshold
} | ConvertTo-Json -Depth 4
