[CmdletBinding()]
param(
    [ValidateSet("left", "middle", "right")]
    [string]$State = "middle",
    [string]$ConfigPath = ".\experiments\windows\calibration\four-slot-carousel.local.json",
    [int]$DriveMsOverride = -1,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "InputToolkit.ps1")

function Resolve-FourSlotConfig {
    param(
        [string]$RequestedPath
    )

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $candidatePaths = @(
        $RequestedPath,
        (Join-Path $repoRoot "experiments\windows\calibration\four-slot-carousel.local.json"),
        (Join-Path $repoRoot "experiments\windows\calibration\four-slot-carousel.example.json")
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

    throw "No four-slot carousel config found. Create experiments\windows\calibration\four-slot-carousel.local.json from the example file."
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

$resolvedConfigPath = Resolve-FourSlotConfig -RequestedPath $ConfigPath
$config = Get-Content -LiteralPath $resolvedConfigPath -Raw | ConvertFrom-Json

$processNamePattern = Get-ConfigValue -Object $config -PropertyName "processNamePattern" -DefaultValue "^BBH$"
$windowTitlePattern = Get-ConfigValue -Object $config -PropertyName "windowTitlePattern" -DefaultValue "BigBuckHunter_UltimateTrophy"
$resetPosition = Get-ConfigValue -Object $config -PropertyName "resetPosition"
$drivePosition = Get-ConfigValue -Object $config -PropertyName "drivePosition"
$neutralPosition = Get-ConfigValue -Object $config -PropertyName "neutralPosition"
$timing = Get-ConfigValue -Object $config -PropertyName "timing"

$resetHoldMs = [int](Get-ConfigValue -Object $timing -PropertyName "resetHoldMs" -DefaultValue 6000)
$fullSweepMs = [int](Get-ConfigValue -Object $timing -PropertyName "fullSweepMs" -DefaultValue 5000)
$middleProbeMs = [int](Get-ConfigValue -Object $timing -PropertyName "middleProbeMs" -DefaultValue 2500)
$postDriveSettleMs = [int](Get-ConfigValue -Object $timing -PropertyName "postDriveSettleMs" -DefaultValue 300)

$driveMs = switch ($State) {
    "left" { 0 }
    "middle" { $middleProbeMs }
    "right" { $fullSweepMs }
}

if ($DriveMsOverride -ge 0) {
    $driveMs = $DriveMsOverride
}

Write-Host "Using four-slot carousel config: $resolvedConfigPath"
Write-Host "Target state: $State"
Write-Host "Drive duration: $driveMs ms"
Write-Host "Dry run: $DryRun"

Focus-BBHWindow -ProcessNamePattern $processNamePattern -WindowTitlePattern $windowTitlePattern | Out-Null

Write-Host "Resetting four-slot carousel from far-left anchor"
Move-BBHCursorRelativeAndHold `
    -XPercent ([double]$resetPosition.xPercent) `
    -YPercent ([double]$resetPosition.yPercent) `
    -HoldMilliseconds $resetHoldMs `
    -SkipFocus `
    -DryRun:$DryRun `
    -ProcessNamePattern $processNamePattern `
    -WindowTitlePattern $windowTitlePattern

if ($driveMs -gt 0) {
    Write-Host "Driving carousel toward state '$State'"
    Move-BBHCursorRelativeAndHold `
        -XPercent ([double]$drivePosition.xPercent) `
        -YPercent ([double]$drivePosition.yPercent) `
        -HoldMilliseconds $driveMs `
        -SkipFocus `
        -DryRun:$DryRun `
        -ProcessNamePattern $processNamePattern `
        -WindowTitlePattern $windowTitlePattern
}
else {
    Write-Host "No drive phase needed for '$State'"
}

if ($neutralPosition) {
    Write-Host "Returning cursor to neutral inspection position"
    Move-BBHCursorRelative `
        -XPercent ([double]$neutralPosition.xPercent) `
        -YPercent ([double]$neutralPosition.yPercent) `
        -SkipFocus `
        -DryRun:$DryRun `
        -ProcessNamePattern $processNamePattern `
        -WindowTitlePattern $windowTitlePattern

    Write-Host "Settling after drive for $postDriveSettleMs ms"
    if (-not $DryRun) {
        Start-Sleep -Milliseconds $postDriveSettleMs
    }
}
