[CmdletBinding()]
param(
    [string]$Label = "frame",
    [string]$ConfigPath = ".\experiments\windows\obs-vision.local.json",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-VisionConfig {
    param(
        [string]$RequestedPath
    )

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $candidatePaths = @(
        $RequestedPath,
        (Join-Path $repoRoot "experiments\windows\obs-vision.local.json"),
        (Join-Path $repoRoot "experiments\windows\obs-vision.example.json")
    )

    foreach ($candidate in $candidatePaths) {
        if (-not $candidate) {
            continue
        }

        $resolvedCandidate = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($candidate)
        if (Test-Path -LiteralPath $resolvedCandidate) {
            return $resolvedCandidate
        }
    }

    throw "No OBS vision config found. Create experiments\windows\obs-vision.local.json from the example file."
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

function Invoke-ObsCmd {
    param(
        [string]$ObsCmdPath,
        [string]$WebsocketUrl,
        [string[]]$Arguments
    )

    & $ObsCmdPath --websocket $WebsocketUrl @Arguments
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

$resolvedConfigPath = Resolve-VisionConfig -RequestedPath $ConfigPath
$config = Get-Content -LiteralPath $resolvedConfigPath -Raw | ConvertFrom-Json

$obsCmdPath = Get-ConfigValue -Object $config -PropertyName "obsCmdPath"
$websocketUrl = Get-ConfigValue -Object $config -PropertyName "websocketUrl"
$sceneName = Get-ConfigValue -Object $config -PropertyName "sceneName"
$sourceName = Get-ConfigValue -Object $config -PropertyName "sourceName"
$frameRoot = Get-ConfigValue -Object $config -PropertyName "frameRoot" -DefaultValue "output\frames"
$defaultImageFormat = Get-ConfigValue -Object $config -PropertyName "defaultImageFormat" -DefaultValue "png"
$defaultImageWidth = [int](Get-ConfigValue -Object $config -PropertyName "defaultImageWidth" -DefaultValue 1920)
$defaultImageHeight = [int](Get-ConfigValue -Object $config -PropertyName "defaultImageHeight" -DefaultValue 1080)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$frameRootPath = Join-Path $repoRoot $frameRoot
$dateFolder = Get-Date -Format "yyyy-MM-dd"
$timestamp = Get-Date
$timestampText = $timestamp.ToString("yyyy-MM-ddTHH-mm-ss-fff")
$labelSlug = ConvertTo-Slug -Value $Label
$frameFolderPath = Join-Path $frameRootPath $dateFolder
$fileName = "$timestampText-$labelSlug.$defaultImageFormat"
$filePath = Join-Path $frameFolderPath $fileName

Write-Host "OBS command: $obsCmdPath"
Write-Host "Scene: $sceneName"
Write-Host "Source: $sourceName"
Write-Host "Frame path: $filePath"
Write-Host "Dry run: $DryRun"

if ($DryRun) {
    return
}

New-Item -ItemType Directory -Force -Path $frameFolderPath | Out-Null
Invoke-ObsCmd `
    -ObsCmdPath $obsCmdPath `
    -WebsocketUrl $websocketUrl `
    -Arguments @(
        "save-screenshot",
        $sourceName,
        $defaultImageFormat,
        $filePath,
        "--width", $defaultImageWidth,
        "--height", $defaultImageHeight
    ) | Out-Host

Write-Host "Captured frame: $filePath"
