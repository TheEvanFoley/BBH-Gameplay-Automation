[CmdletBinding()]
param(
    [string]$ImagePath,
    [switch]$CaptureCurrent,
    [string]$CaptureLabel = "state-current",
    [switch]$FamilyOnly,
    [string]$RecognitionCatalogPath = ".\experiments\windows\screen-recognition-catalog.example.json",
    [string]$ContextCatalogPath = ".\experiments\windows\screen-context-catalog.example.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($FamilyOnly) {
    $recognizerScriptPath = Join-Path $PSScriptRoot "Recognize-BBHScreen.ps1"
    $recognitionJson = & $recognizerScriptPath `
        -ImagePath $ImagePath `
        -CaptureCurrent:$CaptureCurrent `
        -CaptureLabel $CaptureLabel `
        -CatalogPath $RecognitionCatalogPath

    $recognition = $recognitionJson | ConvertFrom-Json
    if ([string]$recognition.screenFamily -eq "unknown") {
        $resolverScriptPath = Join-Path $PSScriptRoot "Resolve-BBHScreenContext.ps1"
        & $resolverScriptPath `
            -ImagePath $ImagePath `
            -CaptureCurrent:$CaptureCurrent `
            -CaptureLabel $CaptureLabel `
            -RecognitionCatalogPath $RecognitionCatalogPath `
            -ContextCatalogPath $ContextCatalogPath
        return
    }

    [pscustomobject]@{
        imagePath = if ($recognition.PSObject.Properties["imagePath"]) { [string]$recognition.imagePath } else { $ImagePath }
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
        contextMethod = "family-only"
    } | ConvertTo-Json -Depth 6
    return
}

$resolverScriptPath = Join-Path $PSScriptRoot "Resolve-BBHScreenContext.ps1"
& $resolverScriptPath `
    -ImagePath $ImagePath `
    -CaptureCurrent:$CaptureCurrent `
    -CaptureLabel $CaptureLabel `
    -RecognitionCatalogPath $RecognitionCatalogPath `
    -ContextCatalogPath $ContextCatalogPath
