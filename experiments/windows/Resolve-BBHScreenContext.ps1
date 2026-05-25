[CmdletBinding()]
param(
    [string]$ImagePath,
    [switch]$CaptureCurrent,
    [string]$CaptureLabel = "context-current",
    [string]$RecognitionCatalogPath = ".\experiments\windows\screen-recognition-catalog.example.json",
    [string]$ContextCatalogPath = ".\experiments\windows\screen-context-catalog.example.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.SoftwareBitmap, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrResult, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
[Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime] | Out-Null

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

function ConvertTo-Slug {
    param(
        [string]$Value
    )

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace '[^a-z0-9]+', '-'
    $slug = $slug.Trim('-')
    if (-not $slug) {
        return "frame"
    }

    return $slug
}

function Await-WinRtOperation {
    param(
        $Operation,
        [type]$ResultType
    )

    $method = [System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
            $_.Name -eq "AsTask" -and
            $_.IsGenericMethod -and
            $_.GetParameters().Count -eq 1
        } |
        Select-Object -First 1

    if (-not $method) {
        throw "Unable to find System.WindowsRuntimeSystemExtensions.AsTask for WinRT operations."
    }

    $task = $method.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    $task.Wait()
    return $task.Result
}

function Invoke-ImageOcr {
    param(
        [string]$FilePath
    )

    $language = [Windows.Globalization.Language]::new("en-US")
    $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($language)
    $storageFile = Await-WinRtOperation -Operation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($FilePath)) -ResultType ([Windows.Storage.StorageFile])
    $stream = Await-WinRtOperation -Operation ($storageFile.OpenAsync([Windows.Storage.FileAccessMode]::Read)) -ResultType ([Windows.Storage.Streams.IRandomAccessStream])
    try {
        $decoder = Await-WinRtOperation -Operation ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) -ResultType ([Windows.Graphics.Imaging.BitmapDecoder])
        $softwareBitmap = Await-WinRtOperation -Operation ($decoder.GetSoftwareBitmapAsync()) -ResultType ([Windows.Graphics.Imaging.SoftwareBitmap])
        $ocrResult = Await-WinRtOperation -Operation ($ocrEngine.RecognizeAsync($softwareBitmap)) -ResultType ([Windows.Media.Ocr.OcrResult])
        return [string]$ocrResult.Text
    }
    finally {
        $stream.Dispose()
    }
}

function Save-ImageRegion {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [double]$XPercent,
        [double]$YPercent,
        [double]$WidthPercent,
        [double]$HeightPercent
    )

    $bitmap = [System.Drawing.Bitmap]::new($SourcePath)
    try {
        $x = [int][Math]::Round($bitmap.Width * $XPercent)
        $y = [int][Math]::Round($bitmap.Height * $YPercent)
        $width = [int][Math]::Round($bitmap.Width * $WidthPercent)
        $height = [int][Math]::Round($bitmap.Height * $HeightPercent)

        $width = [Math]::Max(1, [Math]::Min($width, $bitmap.Width - $x))
        $height = [Math]::Max(1, [Math]::Min($height, $bitmap.Height - $y))

        $rectangle = [System.Drawing.Rectangle]::new($x, $y, $width, $height)
        $cropped = $bitmap.Clone($rectangle, $bitmap.PixelFormat)
        try {
            $cropped.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $cropped.Dispose()
        }
    }
    finally {
        $bitmap.Dispose()
    }
}

function Save-ProcessedImageRegion {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [double]$XPercent,
        [double]$YPercent,
        [double]$WidthPercent,
        [double]$HeightPercent,
        [int]$Scale = 1,
        [int]$Threshold = -1,
        [switch]$Invert
    )

    $bitmap = [System.Drawing.Bitmap]::new($SourcePath)
    try {
        $x = [int][Math]::Round($bitmap.Width * $XPercent)
        $y = [int][Math]::Round($bitmap.Height * $YPercent)
        $width = [int][Math]::Round($bitmap.Width * $WidthPercent)
        $height = [int][Math]::Round($bitmap.Height * $HeightPercent)

        $width = [Math]::Max(1, [Math]::Min($width, $bitmap.Width - $x))
        $height = [Math]::Max(1, [Math]::Min($height, $bitmap.Height - $y))

        $rectangle = [System.Drawing.Rectangle]::new($x, $y, $width, $height)
        $cropped = $bitmap.Clone($rectangle, $bitmap.PixelFormat)
        try {
            $scaledWidth = [Math]::Max(1, $cropped.Width * $Scale)
            $scaledHeight = [Math]::Max(1, $cropped.Height * $Scale)
            $processed = [System.Drawing.Bitmap]::new($scaledWidth, $scaledHeight)
            try {
                $graphics = [System.Drawing.Graphics]::FromImage($processed)
                try {
                    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $graphics.DrawImage($cropped, 0, 0, $scaledWidth, $scaledHeight)
                }
                finally {
                    $graphics.Dispose()
                }

                for ($yy = 0; $yy -lt $processed.Height; $yy++) {
                    for ($xx = 0; $xx -lt $processed.Width; $xx++) {
                        $pixel = $processed.GetPixel($xx, $yy)
                        $gray = [int][Math]::Round(($pixel.R * 0.299) + ($pixel.G * 0.587) + ($pixel.B * 0.114))
                        if ($Threshold -ge 0) {
                            if ($gray -gt $Threshold) {
                                $gray = 255
                            }
                            else {
                                $gray = 0
                            }
                        }

                        if ($Invert) {
                            $gray = 255 - $gray
                        }

                        $processed.SetPixel($xx, $yy, [System.Drawing.Color]::FromArgb($gray, $gray, $gray))
                    }
                }

                $processed.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
            }
            finally {
                $processed.Dispose()
            }
        }
        finally {
            $cropped.Dispose()
        }
    }
    finally {
        $bitmap.Dispose()
    }
}

function Normalize-OcrText {
    param(
        [string]$Text
    )

    if (-not $Text) {
        return ""
    }

    $normalized = $Text.ToUpperInvariant()
    $normalized = $normalized -replace '\s+', ' '
    $normalized = $normalized -replace 'SELECT A HUNTING SITE', ''
    $normalized = $normalized -replace 'SELECT A TREK OR PLAY ALL THREE', ''
    $normalized = $normalized.Trim()
    return $normalized
}

function Normalize-MatchText {
    param(
        [string]$Text
    )

    $normalized = Normalize-OcrText -Text $Text
    if (-not $normalized) {
        return ""
    }

    return ($normalized -replace '[^A-Z0-9]+', '')
}

function Get-TextTokens {
    param(
        [string]$Text
    )

    $normalized = Normalize-OcrText -Text $Text
    if (-not $normalized) {
        return @()
    }

    return @($normalized -split '[^A-Z0-9]+' | Where-Object { $_ })
}

function Convert-LabelTokenToTitle {
    param(
        [string]$Token
    )

    $parts = $Token -split '-'
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $textInfo = $culture.TextInfo
    return (($parts | ForEach-Object { $textInfo.ToTitleCase($_) }) -join ' ')
}

function Get-ReferenceAdventureHint {
    param(
        [string]$ReferenceLabel
    )

    if ($ReferenceLabel -match '^classic-(.+)-trek-selection$') {
        return Convert-LabelTokenToTitle -Token $matches[1]
    }

    return $null
}

function Resolve-AdventureFromTextCandidates {
    param(
        [string[]]$CandidateTexts,
        [string[]]$AdventureNames
    )

    $joinedTokens = New-Object System.Collections.Generic.HashSet[string]
    foreach ($candidateText in $CandidateTexts) {
        foreach ($token in (Get-TextTokens -Text $candidateText)) {
            [void]$joinedTokens.Add($token)
        }
    }

    if ($joinedTokens.Count -eq 0) {
        return $null
    }

    $bestMatch = $null
    $bestScore = -1
    foreach ($adventureName in $AdventureNames) {
        $tokens = @(Get-TextTokens -Text $adventureName)
        if (-not $tokens) {
            continue
        }

        $score = 0
        foreach ($token in $tokens) {
            if ($joinedTokens.Contains($token)) {
                $score++
            }
        }

        if ($score -gt $bestScore -or ($score -eq $bestScore -and $tokens.Count -gt 0 -and $bestMatch -and $tokens.Count -gt (Get-TextTokens -Text $bestMatch).Count)) {
            $bestScore = $score
            $bestMatch = $adventureName
        }
    }

    if ($bestScore -le 0) {
        return $null
    }

    $bestTokens = @(Get-TextTokens -Text $bestMatch)
    if ($bestScore -lt $bestTokens.Count) {
        return $null
    }

    return $bestMatch
}

function Get-MatchedLocationMappings {
    param(
        [string]$OcrText,
        [object[]]$LocationMappings
    )

    $normalizedOcrText = Normalize-MatchText -Text $OcrText
    if (-not $normalizedOcrText) {
        return @()
    }

    $matches = foreach ($mapping in $LocationMappings) {
        $pattern = Normalize-MatchText -Text ([string]$mapping.pattern)
        if (-not $pattern) {
            continue
        }

        if ($normalizedOcrText.Contains($pattern)) {
            [pscustomobject]@{
                pattern = [string]$mapping.pattern
                adventure = [string]$mapping.adventure
                trek = [string]$mapping.trek
            }
        }
    }

    return @($matches)
}

function Get-BestLocationMappingForCandidateText {
    param(
        [string]$CandidateText,
        [object[]]$LocationMappings
    )

    $candidateTokens = @(Get-TextTokens -Text $CandidateText)
    if ($candidateTokens.Count -eq 0) {
        return $null
    }

    function Get-LevenshteinDistance {
        param(
            [string]$Left,
            [string]$Right
        )

        $n = $Left.Length
        $m = $Right.Length
        $matrix = New-Object 'int[,]' ($n + 1), ($m + 1)

        for ($i = 0; $i -le $n; $i++) {
            $matrix[$i, 0] = $i
        }

        for ($j = 0; $j -le $m; $j++) {
            $matrix[0, $j] = $j
        }

        for ($i = 1; $i -le $n; $i++) {
            for ($j = 1; $j -le $m; $j++) {
                $cost = if ($Left[($i - 1)] -eq $Right[($j - 1)]) { 0 } else { 1 }
                $deletion = $matrix[($i - 1), $j] + 1
                $insertion = $matrix[$i, ($j - 1)] + 1
                $substitution = $matrix[($i - 1), ($j - 1)] + $cost
                $matrix[$i, $j] = [Math]::Min([Math]::Min($deletion, $insertion), $substitution)
            }
        }

        return $matrix[$n, $m]
    }

    $best = $null
    foreach ($mapping in $LocationMappings) {
        $patternTokens = @(Get-TextTokens -Text ([string]$mapping.pattern))
        if ($patternTokens.Count -eq 0) {
            continue
        }

        $matchedTokens = @($candidateTokens | Where-Object { $patternTokens -contains $_ } | Select-Object -Unique)
        $score = $matchedTokens.Count
        $fuzzyMatchedTokens = New-Object System.Collections.Generic.List[string]
        $bestFuzzySimilarity = 0.0

        if ($score -eq 0) {
            foreach ($candidateToken in $candidateTokens) {
                if ($candidateToken.Length -lt 5) {
                    continue
                }

                foreach ($patternToken in $patternTokens) {
                    if ($patternToken.Length -lt 5) {
                        continue
                    }

                    $distance = Get-LevenshteinDistance -Left $candidateToken -Right $patternToken
                    $similarity = 1.0 - ($distance / [Math]::Max($candidateToken.Length, $patternToken.Length))
                    if ($similarity -ge 0.6) {
                        $score = 1
                        [void]$fuzzyMatchedTokens.Add($patternToken)
                        if ($similarity -gt $bestFuzzySimilarity) {
                            $bestFuzzySimilarity = $similarity
                        }
                    }
                }
            }
        }

        if ($score -eq 0) {
            continue
        }

        $allMatchedTokens = @($matchedTokens + $fuzzyMatchedTokens.ToArray() | Select-Object -Unique)
        $longestTokenLength = (@($allMatchedTokens | ForEach-Object { $_.Length }) | Measure-Object -Maximum).Maximum
        $confidence = if ($bestFuzzySimilarity -gt 0) {
            [Math]::Round($bestFuzzySimilarity, 4)
        }
        else {
            [Math]::Round(($score / $patternTokens.Count), 4)
        }
        $candidate = [pscustomobject]@{
            pattern = [string]$mapping.pattern
            adventure = [string]$mapping.adventure
            trek = [string]$mapping.trek
            matchedTokens = @($allMatchedTokens)
            tokenScore = $score
            longestTokenLength = [int]$longestTokenLength
            confidence = $confidence
        }

        if (
            -not $best -or
            $candidate.tokenScore -gt $best.tokenScore -or
            ($candidate.tokenScore -eq $best.tokenScore -and $candidate.longestTokenLength -gt $best.longestTokenLength) -or
            ($candidate.tokenScore -eq $best.tokenScore -and $candidate.longestTokenLength -eq $best.longestTokenLength -and $candidate.confidence -gt $best.confidence)
        ) {
            $best = $candidate
        }
    }

    if (-not $best) {
        return $null
    }

    if ($best.tokenScore -ge 2) {
        return $best
    }

    if ($best.tokenScore -eq 1 -and $best.longestTokenLength -ge 5) {
        return $best
    }

    return $null
}

function Get-AdventureTrekList {
    param(
        [string]$Adventure,
        [object[]]$LocationMappings
    )

    if (-not $Adventure) {
        return @()
    }

    return @(
        $LocationMappings |
            Where-Object { [string]$_.adventure -eq $Adventure } |
            Sort-Object trek |
            Select-Object -ExpandProperty trek -Unique
    )
}

function Get-AdventureLocationList {
    param(
        [string]$Adventure,
        [object[]]$LocationMappings
    )

    if (-not $Adventure) {
        return @()
    }

    return @(
        $LocationMappings |
            Where-Object { [string]$_.adventure -eq $Adventure } |
            Sort-Object trek |
            ForEach-Object {
                [pscustomobject]@{
                    trek = [string]$_.trek
                    location = [string]$_.pattern
                }
            }
    )
}

function Test-FamilyTextHint {
    param(
        [string]$SourcePath,
        $Hint,
        $ContextCatalog,
        [string]$TempRoot
    )

    $regionProperty = [string]$Hint.regionProperty
    if (-not $regionProperty) {
        return $null
    }

    $region = Get-ConfigValue -Object $ContextCatalog -PropertyName $regionProperty
    if (-not $region) {
        return $null
    }

    $hintImagePath = Join-Path $TempRoot ("family-hint-" + [System.Guid]::NewGuid().ToString("N") + ".png")
    Save-ProcessedImageRegion `
        -SourcePath $SourcePath `
        -DestinationPath $hintImagePath `
        -XPercent ([double]$region.xPercent) `
        -YPercent ([double]$region.yPercent) `
        -WidthPercent ([double]$region.widthPercent) `
        -HeightPercent ([double]$region.heightPercent) `
        -Scale 4 `
        -Threshold 170

    $ocrText = Normalize-OcrText -Text (Invoke-ImageOcr -FilePath $hintImagePath)
    Remove-Item -LiteralPath $hintImagePath -ErrorAction SilentlyContinue

    $requiredPhrases = @($Hint.requiredPhrases)
    foreach ($phrase in $requiredPhrases) {
        $normalizedPhrase = Normalize-OcrText -Text ([string]$phrase)
        if (-not $normalizedPhrase) {
            continue
        }

        if (-not $ocrText.Contains($normalizedPhrase)) {
            return [pscustomobject]@{
                matched = $false
                ocrText = $ocrText
            }
        }
    }

    return [pscustomobject]@{
        matched = $true
        ocrText = $ocrText
    }
}

function Resolve-AdventureFromLogoRegion {
    param(
        [string]$SourcePath,
        $LogoRegion,
        [string[]]$AdventureNames,
        [string]$TempRoot
    )

    if (-not $LogoRegion -or $AdventureNames.Count -eq 0) {
        return $null
    }

    $logoVariants = @(
        @{ Scale = 3; Threshold = -1; Invert = $false },
        @{ Scale = 4; Threshold = 160; Invert = $false },
        @{ Scale = 5; Threshold = 180; Invert = $false },
        @{ Scale = 4; Threshold = 120; Invert = $true }
    )

    $logoTexts = New-Object System.Collections.Generic.List[string]
    foreach ($variant in $logoVariants) {
        $logoImagePath = Join-Path $TempRoot ("site-logo-" + [System.Guid]::NewGuid().ToString("N") + ".png")
        Save-ProcessedImageRegion `
            -SourcePath $SourcePath `
            -DestinationPath $logoImagePath `
            -XPercent ([double]$LogoRegion.xPercent) `
            -YPercent ([double]$LogoRegion.yPercent) `
            -WidthPercent ([double]$LogoRegion.widthPercent) `
            -HeightPercent ([double]$LogoRegion.heightPercent) `
            -Scale ([int]$variant.Scale) `
            -Threshold ([int]$variant.Threshold) `
            -Invert:([bool]$variant.Invert)

        $logoText = Normalize-OcrText -Text (Invoke-ImageOcr -FilePath $logoImagePath)
        Remove-Item -LiteralPath $logoImagePath -ErrorAction SilentlyContinue
        if ($logoText) {
            $logoTexts.Add($logoText)
        }
    }

    return [pscustomobject]@{
        adventure = Resolve-AdventureFromTextCandidates -CandidateTexts $logoTexts.ToArray() -AdventureNames $AdventureNames
        rawTexts = $logoTexts.ToArray()
    }
}

$resolvedRecognitionCatalogPath = Get-ScriptResolvedPath -PathValue $RecognitionCatalogPath
$resolvedContextCatalogPath = Get-ScriptResolvedPath -PathValue $ContextCatalogPath
if (-not (Test-Path -LiteralPath $resolvedContextCatalogPath)) {
    throw "Context catalog not found: $resolvedContextCatalogPath"
}

$contextCatalog = Get-Content -LiteralPath $resolvedContextCatalogPath -Raw | ConvertFrom-Json
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")

if ($CaptureCurrent) {
    $captureScriptPath = Join-Path $PSScriptRoot "Capture-BBHFrame.ps1"
    & $captureScriptPath -Label $CaptureLabel

    $frameRoot = Join-Path $repoRoot "output\frames"
    $slug = ConvertTo-Slug -Value $CaptureLabel
    $capturedImage = Get-ChildItem -LiteralPath $frameRoot -Recurse -File -Filter "*.png" |
        Where-Object { $_.Name -like "*-$slug.png" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $capturedImage) {
        throw "Could not locate a captured frame for label '$CaptureLabel'."
    }

    $ImagePath = $capturedImage.FullName
}

if (-not $ImagePath) {
    throw "Provide -ImagePath or use -CaptureCurrent."
}

$resolvedImagePath = Get-ScriptResolvedPath -PathValue $ImagePath
if (-not (Test-Path -LiteralPath $resolvedImagePath)) {
    throw "Image path not found: $resolvedImagePath"
}

$recognizerScriptPath = Join-Path $PSScriptRoot "Recognize-BBHScreen.ps1"
$recognitionJson = & $recognizerScriptPath -ImagePath $resolvedImagePath -CatalogPath $resolvedRecognitionCatalogPath
$recognition = $recognitionJson | ConvertFrom-Json
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "bbh-screen-context"
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

$familyTextHints = @(Get-ConfigValue -Object $contextCatalog -PropertyName "familyTextHints" -DefaultValue @())
$baseScreenFamily = [string]$recognition.screenFamily
$baseConfidence = [double]$recognition.confidence
foreach ($hint in $familyTextHints) {
    $hintFamily = [string]$hint.screenFamily
    $canOverrideBaseMatch = (
        $baseScreenFamily -eq "unknown" -or
        $baseScreenFamily -eq $hintFamily
    )

    if (-not $canOverrideBaseMatch) {
        continue
    }

    $hintResult = Test-FamilyTextHint -SourcePath $resolvedImagePath -Hint $hint -ContextCatalog $contextCatalog -TempRoot $tempRoot
    if ($hintResult -and $hintResult.matched) {
        $recognition.screenFamily = $hintFamily
        $recognition.isKnown = $true
        if ([double]$recognition.confidence -lt 0.99) {
            $recognition.confidence = 0.99
        }
        break
    }
}

$result = [ordered]@{
    imagePath = $resolvedImagePath
    screenFamily = [string]$recognition.screenFamily
    confidence = [double]$recognition.confidence
    matchedReference = [string]$recognition.matchedReference
    referenceLabel = [string]$recognition.referenceLabel
    isKnown = [bool]$recognition.isKnown
    adventure = $null
    trek = $null
    locationText = $null
    availableTreks = @()
    availableLocations = @()
    matchedLocations = @()
    contextMethod = $null
}

if ($result.screenFamily -eq "classic-site-selection-screen") {
    $region = Get-ConfigValue -Object $contextCatalog -PropertyName "siteSelectionLocationRegion"
    if ($region) {
        $locationImagePath = Join-Path $tempRoot ("site-location-" + [System.Guid]::NewGuid().ToString("N") + ".png")
        Save-ImageRegion `
            -SourcePath $resolvedImagePath `
            -DestinationPath $locationImagePath `
            -XPercent ([double]$region.xPercent) `
            -YPercent ([double]$region.yPercent) `
            -WidthPercent ([double]$region.widthPercent) `
            -HeightPercent ([double]$region.heightPercent)

        $locationText = Normalize-OcrText -Text (Invoke-ImageOcr -FilePath $locationImagePath)
        Remove-Item -LiteralPath $locationImagePath -ErrorAction SilentlyContinue

        $result.locationText = $locationText
        $mappings = @(Get-ConfigValue -Object $contextCatalog -PropertyName "locationMappings" -DefaultValue @())
        $locationMatches = @(Get-MatchedLocationMappings -OcrText $locationText -LocationMappings $mappings)
        if ($locationMatches.Count -gt 0) {
            $firstMatch = $locationMatches[0]
            $result.adventure = [string]$firstMatch.adventure
            $result.trek = [string]$firstMatch.trek
            $result.matchedLocations = @($locationMatches)
            $result.availableTreks = @(Get-AdventureTrekList -Adventure $result.adventure -LocationMappings $mappings)
            $result.availableLocations = @(Get-AdventureLocationList -Adventure $result.adventure -LocationMappings $mappings)
            $result.contextMethod = "site-selection-location-ocr"
        }
    }

    $logoRegion = Get-ConfigValue -Object $contextCatalog -PropertyName "siteSelectionLogoRegion"
    $adventureNames = @(Get-ConfigValue -Object $contextCatalog -PropertyName "adventureNames" -DefaultValue @())
    if ($logoRegion -and $adventureNames.Count -gt 0) {
        $logoResolution = Resolve-AdventureFromLogoRegion -SourcePath $resolvedImagePath -LogoRegion $logoRegion -AdventureNames $adventureNames -TempRoot $tempRoot
        $resolvedAdventureFromLogo = $logoResolution.adventure
        if ($resolvedAdventureFromLogo -and -not $result.adventure) {
            $result.adventure = $resolvedAdventureFromLogo
            $result.contextMethod = "site-selection-logo-ocr"
        }
        elseif ($resolvedAdventureFromLogo -and $result.adventure -eq $resolvedAdventureFromLogo -and -not $result.contextMethod) {
            $result.contextMethod = "site-selection-location-and-logo-ocr"
        }
    }
}
elseif ($result.screenFamily -eq "classic-trek-selection") {
    $mappings = @(Get-ConfigValue -Object $contextCatalog -PropertyName "locationMappings" -DefaultValue @())
    $trekRegion = Get-ConfigValue -Object $contextCatalog -PropertyName "trekSelectionLocationsRegion"
    if ($trekRegion) {
        $trekLocationsImagePath = Join-Path $tempRoot ("trek-locations-" + [System.Guid]::NewGuid().ToString("N") + ".png")
        Save-ProcessedImageRegion `
            -SourcePath $resolvedImagePath `
            -DestinationPath $trekLocationsImagePath `
            -XPercent ([double]$trekRegion.xPercent) `
            -YPercent ([double]$trekRegion.yPercent) `
            -WidthPercent ([double]$trekRegion.widthPercent) `
            -HeightPercent ([double]$trekRegion.heightPercent) `
            -Scale 3 `
            -Threshold 170

        $trekLocationsText = Normalize-OcrText -Text (Invoke-ImageOcr -FilePath $trekLocationsImagePath)
        Remove-Item -LiteralPath $trekLocationsImagePath -ErrorAction SilentlyContinue

        $result.locationText = $trekLocationsText
        $trekLocationMatches = New-Object System.Collections.Generic.List[object]
        foreach ($match in @(Get-MatchedLocationMappings -OcrText $trekLocationsText -LocationMappings $mappings)) {
            [void]$trekLocationMatches.Add($match)
        }

        $slotRegions = @(Get-ConfigValue -Object $contextCatalog -PropertyName "trekSelectionLocationSlots" -DefaultValue @())
        foreach ($slotRegion in $slotRegions) {
            $slotImagePath = Join-Path $tempRoot ("trek-slot-" + [System.Guid]::NewGuid().ToString("N") + ".png")
            Save-ProcessedImageRegion `
                -SourcePath $resolvedImagePath `
                -DestinationPath $slotImagePath `
                -XPercent ([double]$slotRegion.xPercent) `
                -YPercent ([double]$slotRegion.yPercent) `
                -WidthPercent ([double]$slotRegion.widthPercent) `
                -HeightPercent ([double]$slotRegion.heightPercent) `
                -Scale 6

            $slotText = Normalize-OcrText -Text (Invoke-ImageOcr -FilePath $slotImagePath)
            Remove-Item -LiteralPath $slotImagePath -ErrorAction SilentlyContinue
            $slotMatch = Get-BestLocationMappingForCandidateText -CandidateText $slotText -LocationMappings $mappings
            if ($slotMatch) {
                [void]$trekLocationMatches.Add($slotMatch)
            }
        }

        $trekLocationMatches = @(
            $trekLocationMatches |
                Group-Object pattern |
                ForEach-Object { $_.Group | Select-Object -First 1 }
        )

        if ($trekLocationMatches.Count -gt 0) {
            $result.matchedLocations = @($trekLocationMatches)
            $adventureGroups = @($trekLocationMatches | Group-Object adventure | Sort-Object Count -Descending)
            if ($adventureGroups.Count -gt 0) {
                $result.adventure = [string]$adventureGroups[0].Name
                $result.availableTreks = @(Get-AdventureTrekList -Adventure $result.adventure -LocationMappings $mappings)
                $result.availableLocations = @(Get-AdventureLocationList -Adventure $result.adventure -LocationMappings $mappings)
                $result.contextMethod = "trek-selection-locations-ocr"
            }
        }
    }

    $logoRegion = Get-ConfigValue -Object $contextCatalog -PropertyName "siteSelectionLogoRegion"
    $adventureNames = @(Get-ConfigValue -Object $contextCatalog -PropertyName "adventureNames" -DefaultValue @())
    $logoResolution = Resolve-AdventureFromLogoRegion -SourcePath $resolvedImagePath -LogoRegion $logoRegion -AdventureNames $adventureNames -TempRoot $tempRoot
    if ($logoResolution.adventure -and -not $result.adventure) {
        $result.adventure = $logoResolution.adventure
        $result.contextMethod = "trek-selection-logo-ocr"
    }
    elseif (-not $result.adventure -and $result.confidence -ge 0.9999 -and [System.String]::Equals($resolvedImagePath, [string]$result.matchedReference, [System.StringComparison]::OrdinalIgnoreCase)) {
        $adventureHint = Get-ReferenceAdventureHint -ReferenceLabel $result.referenceLabel
        if ($adventureHint) {
            $result.adventure = $adventureHint
            $result.contextMethod = "reference-label-hint"
        }
    }
}

[pscustomobject]$result | ConvertTo-Json -Depth 5
