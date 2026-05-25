[CmdletBinding()]
param(
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

function Invoke-ObsCmd {
    param(
        [string]$ObsCmdPath,
        [string]$WebsocketUrl,
        [string[]]$Arguments
    )

    & $ObsCmdPath --websocket $WebsocketUrl @Arguments
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

$resolvedConfigPath = Resolve-CaptureConfig -RequestedPath $ConfigPath
$config = Get-Content -LiteralPath $resolvedConfigPath -Raw | ConvertFrom-Json

$obsCmdPath = Get-ConfigValue -Object $config -PropertyName "obsCmdPath"
$websocketUrl = Get-ConfigValue -Object $config -PropertyName "websocketUrl"
$captureRoot = Get-ConfigValue -Object $config -PropertyName "captureRoot" -DefaultValue "captures"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
if ([System.IO.Path]::IsPathRooted($captureRoot)) {
    $captureRootPath = $captureRoot
}
else {
    $captureRootPath = Join-Path $repoRoot $captureRoot
}

$statePath = Join-Path $captureRootPath ".current-run.json"

if (-not (Test-Path -LiteralPath $statePath)) {
    throw "No active capture state found at $statePath"
}

$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$runFolderPath = [string]$state.runFolderPath
$metadataPath = [string]$state.metadataPath
$preferredVideoName = [string]$state.preferredVideoName
$recordDirectory = [string]$state.recordDirectory
$startedAt = [datetimeoffset]$state.startedAt
$stopRequestedAt = Get-Date

Write-Host "OBS command: $obsCmdPath"
Write-Host "Run folder: $runFolderPath"
Write-Host "OBS record directory: $recordDirectory"
Write-Host "Dry run: $DryRun"

if ($DryRun) {
    return
}

Invoke-ObsCmd -ObsCmdPath $obsCmdPath -WebsocketUrl $websocketUrl -Arguments @("recording", "stop") | Out-Host
Start-Sleep -Seconds 2
$stopCompletedAt = Get-Date

$videoFile = Get-ChildItem -LiteralPath $recordDirectory -File |
    Where-Object { $_.LastWriteTime -ge $startedAt.LocalDateTime } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $videoFile) {
    throw "Could not find a newly recorded OBS file in $recordDirectory"
}

$extension = $videoFile.Extension
$destinationPath = Join-Path $runFolderPath ($preferredVideoName + $extension)
Move-Item -LiteralPath $videoFile.FullName -Destination $destinationPath -Force

$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$metadata | Add-Member -NotePropertyName "videoPath" -NotePropertyValue ($destinationPath -replace '\\', '/') -Force
$metadata | Add-Member -NotePropertyName "stopRequestedAt" -NotePropertyValue ($stopRequestedAt.ToString("o")) -Force
$metadata | Add-Member -NotePropertyName "stopCompletedAt" -NotePropertyValue ($stopCompletedAt.ToString("o")) -Force
$metadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $metadataPath

Remove-Item -LiteralPath $statePath -Force

Write-Host "Capture run finalized."
Write-Host "Video: $destinationPath"
