[CmdletBinding()]
param(
    [string]$ConfigPath = ".\experiments\windows\obs-vision.local.json",
    [switch]$StartStreaming,
    [switch]$StartVirtualCamera,
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

$resolvedConfigPath = Resolve-VisionConfig -RequestedPath $ConfigPath
$config = Get-Content -LiteralPath $resolvedConfigPath -Raw | ConvertFrom-Json

$obsCmdPath = Get-ConfigValue -Object $config -PropertyName "obsCmdPath"
$websocketUrl = Get-ConfigValue -Object $config -PropertyName "websocketUrl"
$sceneName = Get-ConfigValue -Object $config -PropertyName "sceneName"
$sourceName = Get-ConfigValue -Object $config -PropertyName "sourceName"

if (-not $obsCmdPath -or -not $websocketUrl -or -not $sceneName -or -not $sourceName) {
    throw "OBS vision config must define obsCmdPath, websocketUrl, sceneName, and sourceName."
}

Write-Host "OBS command: $obsCmdPath"
Write-Host "Scene: $sceneName"
Write-Host "Source: $sourceName"
Write-Host "Start streaming: $StartStreaming"
Write-Host "Start virtual camera: $StartVirtualCamera"
Write-Host "Dry run: $DryRun"

if ($DryRun) {
    return
}

Invoke-ObsCmd -ObsCmdPath $obsCmdPath -WebsocketUrl $websocketUrl -Arguments @("scene", "switch", $sceneName) | Out-Host

if ($StartVirtualCamera) {
    Invoke-ObsCmd -ObsCmdPath $obsCmdPath -WebsocketUrl $websocketUrl -Arguments @("virtual-camera", "start") | Out-Host
}

if ($StartStreaming) {
    Invoke-ObsCmd -ObsCmdPath $obsCmdPath -WebsocketUrl $websocketUrl -Arguments @("streaming", "start") | Out-Host
}

Write-Host "OBS vision bridge prepared."
