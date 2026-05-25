[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GameMode,
    [Parameter(Mandatory = $true)]
    [string]$Weapon,
    [Parameter(Mandatory = $true)]
    [string]$Adventure,
    [Parameter(Mandatory = $true)]
    [string]$Trek,
    [Parameter(Mandatory = $true)]
    [string]$Site,
    [string]$Notes = "",
    [string]$ConfigPath = ".\experiments\windows\obs-capture.local.json",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-CaptureConfig {
    param(
        [string]$RequestedPath
    )

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $candidatePaths = @(
        $RequestedPath,
        (Join-Path $repoRoot "experiments\windows\obs-capture.local.json"),
        (Join-Path $repoRoot "experiments\windows\obs-capture.example.json")
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

    throw "No OBS capture config found. Create experiments\windows\obs-capture.local.json from the example file."
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
        return "value"
    }

    return $slug
}

$resolvedConfigPath = Resolve-CaptureConfig -RequestedPath $ConfigPath
$config = Get-Content -LiteralPath $resolvedConfigPath -Raw | ConvertFrom-Json

$obsCmdPath = Get-ConfigValue -Object $config -PropertyName "obsCmdPath"
$websocketUrl = Get-ConfigValue -Object $config -PropertyName "websocketUrl"
$sceneName = Get-ConfigValue -Object $config -PropertyName "sceneName"
$obsRecordDirectoryConfig = Get-ConfigValue -Object $config -PropertyName "obsRecordDirectory"
$captureRoot = Get-ConfigValue -Object $config -PropertyName "captureRoot" -DefaultValue "captures"
$preferredVideoName = Get-ConfigValue -Object $config -PropertyName "preferredVideoName" -DefaultValue "video"

if (-not $obsCmdPath -or -not $websocketUrl) {
    throw "OBS capture config must define obsCmdPath and websocketUrl."
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
if ([System.IO.Path]::IsPathRooted($captureRoot)) {
    $captureRootPath = $captureRoot
}
else {
    $captureRootPath = Join-Path $repoRoot $captureRoot
}

$dateFolder = Get-Date -Format "yyyy-MM-dd"
$timestamp = Get-Date
$timestampText = $timestamp.ToString("yyyy-MM-ddTHH-mm-ss")
$runSlug = @(
    (ConvertTo-Slug -Value $Adventure),
    (ConvertTo-Slug -Value $Trek),
    (ConvertTo-Slug -Value $Site)
) -join "-"
$runFolderName = "$runSlug-$timestampText"
$runFolderPath = Join-Path (Join-Path $captureRootPath $dateFolder) $runFolderName
$metadataPath = Join-Path $runFolderPath "metadata.json"
$notesPath = Join-Path $runFolderPath "notes.md"
$statePath = Join-Path $captureRootPath ".current-run.json"

$recordDirectoryOutput = Invoke-ObsCmd -ObsCmdPath $obsCmdPath -WebsocketUrl $websocketUrl -Arguments @("record-directory", "get")
$recordDirectoryLine = $recordDirectoryOutput | Where-Object { $_ -match '^Current record directory:' } | Select-Object -First 1
if (-not $recordDirectoryLine) {
    throw "Unable to determine OBS record directory."
}

$recordDirectory = ($recordDirectoryLine -replace '^Current record directory:\s*', '').Trim()
$recordDirectory = $recordDirectory -replace '/', '\'

if ($obsRecordDirectoryConfig) {
    $normalizedConfiguredDirectory = $obsRecordDirectoryConfig -replace '/', '\'
    if ($recordDirectory -ne $normalizedConfiguredDirectory) {
        Write-Warning "OBS is currently recording to '$recordDirectory', but config expects '$normalizedConfiguredDirectory'."
    }
}

$metadata = [ordered]@{
    runId = $runFolderName
    recordedAt = $timestamp.ToString("o")
    recordingStartedAt = $timestamp.ToString("o")
    gameMode = $GameMode
    weapon = $Weapon
    adventure = $Adventure
    trek = $Trek
    site = $Site
    notes = $Notes
    videoPath = $null
    metadataVersion = 1
    siteVersion = $null
    isMirror = $null
    isPlayed = $null
    hasTrophy = $null
    critterVersion = $null
    bonusGameName = $null
}

$state = [ordered]@{
    runId = $runFolderName
    captureRootPath = $captureRootPath
    runFolderPath = $runFolderPath
    metadataPath = $metadataPath
    notesPath = $notesPath
    preferredVideoName = $preferredVideoName
    recordDirectory = $recordDirectory
    startedAt = $timestamp.ToString("o")
    recordingStartedAt = $timestamp.ToString("o")
}

Write-Host "OBS command: $obsCmdPath"
Write-Host "OBS record directory: $recordDirectory"
Write-Host "Run folder: $runFolderPath"
if ($sceneName) {
    Write-Host "OBS scene: $sceneName"
}
Write-Host "Dry run: $DryRun"

if ($DryRun) {
    $metadata | ConvertTo-Json -Depth 5
    return
}

New-Item -ItemType Directory -Force -Path $runFolderPath | Out-Null
$metadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $metadataPath
$notes | Set-Content -LiteralPath $notesPath
$state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $statePath

if ($sceneName) {
    Invoke-ObsCmd -ObsCmdPath $obsCmdPath -WebsocketUrl $websocketUrl -Arguments @("scene", "switch", $sceneName) | Out-Host
}

Invoke-ObsCmd -ObsCmdPath $obsCmdPath -WebsocketUrl $websocketUrl -Arguments @("recording", "start") | Out-Host

Write-Host "Capture run started."
Write-Host "State file: $statePath"
