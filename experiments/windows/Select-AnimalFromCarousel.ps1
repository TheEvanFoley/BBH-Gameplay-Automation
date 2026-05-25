[CmdletBinding()]
param(
    [string]$AnimalName = "Elk",
    [string]$ConfigPath = ".\experiments\windows\calibration\animal-carousel.local.json",
    [int]$MoveMsOverride = -1,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "InputToolkit.ps1")

function Resolve-CarouselConfig {
    param(
        [string]$RequestedPath
    )

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $candidatePaths = @(
        $RequestedPath,
        (Join-Path $repoRoot "experiments\windows\calibration\animal-carousel.local.json"),
        (Join-Path $repoRoot "experiments\windows\calibration\animal-carousel.example.json")
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

    throw "No carousel config found. Create experiments\windows\calibration\animal-carousel.local.json from the example file."
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

function Get-AnimalStateSelection {
    param(
        $States,
        [string]$RequestedAnimalName
    )

    $stateNames = @("left", "middle", "right")
    foreach ($stateName in $stateNames) {
        $stateDefinition = Get-ConfigValue -Object $States -PropertyName $stateName
        if (-not $stateDefinition) {
            continue
        }

        $slots = Get-ConfigValue -Object $stateDefinition -PropertyName "slots"
        if (-not $slots) {
            continue
        }

        foreach ($slotName in @("slot1Safe", "slot2", "slot3", "slot4Safe")) {
            $label = Get-ConfigValue -Object $slots -PropertyName $slotName
            if ($label -eq $RequestedAnimalName) {
                return [pscustomobject]@{
                    StateName = $stateName
                    SlotName = $slotName
                    MoveMs = [int](Get-ConfigValue -Object $stateDefinition -PropertyName "moveMs" -DefaultValue 0)
                }
            }
        }
    }

    $supported = @()
    foreach ($stateName in $stateNames) {
        $stateDefinition = Get-ConfigValue -Object $States -PropertyName $stateName
        if (-not $stateDefinition) {
            continue
        }

        $slots = Get-ConfigValue -Object $stateDefinition -PropertyName "slots"
        if (-not $slots) {
            continue
        }

        foreach ($slotName in @("slot1Safe", "slot2", "slot3", "slot4Safe")) {
            $label = Get-ConfigValue -Object $slots -PropertyName $slotName
            if ($label) {
                $supported += [string]$label
            }
        }
    }

    $supportedList = ($supported | Select-Object -Unique) -join ", "
    throw "Unsupported animal '$RequestedAnimalName'. Supported animals: $supportedList"
}

$resolvedConfigPath = Resolve-CarouselConfig -RequestedPath $ConfigPath
$config = Get-Content -LiteralPath $resolvedConfigPath -Raw | ConvertFrom-Json

$processNamePattern = Get-ConfigValue -Object $config -PropertyName "processNamePattern" -DefaultValue "^BBH$"
$windowTitlePattern = Get-ConfigValue -Object $config -PropertyName "windowTitlePattern" -DefaultValue "BigBuckHunter_UltimateTrophy"
$resetDirection = Get-ConfigValue -Object $config -PropertyName "resetDirection" -DefaultValue "far-left"
$resetPosition = Get-ConfigValue -Object $config -PropertyName "resetPosition"
$drivePosition = Get-ConfigValue -Object $config -PropertyName "drivePosition"
$neutralPosition = Get-ConfigValue -Object $config -PropertyName "neutralPosition"
$states = Get-ConfigValue -Object $config -PropertyName "states"
$slots = Get-ConfigValue -Object $config -PropertyName "slots"
$timing = Get-ConfigValue -Object $config -PropertyName "timing"

if (-not $states -or -not $slots) {
    throw "Carousel config is missing state or slot definitions."
}

if (-not $resetPosition -or -not $drivePosition -or -not $neutralPosition -or -not $timing) {
    throw "Carousel config is missing one of: resetPosition, drivePosition, neutralPosition, timing."
}

$selection = Get-AnimalStateSelection -States $states -RequestedAnimalName $AnimalName
$slotName = [string]$selection.SlotName
$slotTarget = Get-ConfigValue -Object $slots -PropertyName $slotName
if (-not $slotTarget) {
    throw "Slot target '$slotName' is not defined in the carousel config."
}

$moveMs = [int]$selection.MoveMs
if ($MoveMsOverride -ge 0) {
    $moveMs = $MoveMsOverride
}

$resetHoldMs = [int](Get-ConfigValue -Object $timing -PropertyName "resetHoldMs" -DefaultValue 6000)
$postDriveSettleMs = [int](Get-ConfigValue -Object $timing -PropertyName "postDriveSettleMs" -DefaultValue 300)
$preSelectSettleMs = [int](Get-ConfigValue -Object $timing -PropertyName "preSelectSettleMs" -DefaultValue 300)
$postSelectWaitMs = [int](Get-ConfigValue -Object $timing -PropertyName "postSelectWaitMs" -DefaultValue 2000)

Write-Host "Using carousel config: $resolvedConfigPath"
Write-Host "Animal target: $AnimalName"
Write-Host "Reset direction: $resetDirection"
Write-Host "State: $($selection.StateName)"
Write-Host "Slot: $slotName"
Write-Host "Move duration: $moveMs ms"
Write-Host "Dry run: $DryRun"

Focus-BBHWindow -ProcessNamePattern $processNamePattern -WindowTitlePattern $windowTitlePattern | Out-Null

Write-Host "Resetting carousel from far-left anchor"
Move-BBHCursorRelativeAndHold `
    -XPercent ([double]$resetPosition.xPercent) `
    -YPercent ([double]$resetPosition.yPercent) `
    -HoldMilliseconds $resetHoldMs `
    -SkipFocus `
    -DryRun:$DryRun `
    -ProcessNamePattern $processNamePattern `
    -WindowTitlePattern $windowTitlePattern

if ($moveMs -gt 0) {
    Write-Host "Driving carousel toward '$AnimalName'"
    Move-BBHCursorRelativeAndHold `
        -XPercent ([double]$drivePosition.xPercent) `
        -YPercent ([double]$drivePosition.yPercent) `
        -HoldMilliseconds $moveMs `
        -SkipFocus `
        -DryRun:$DryRun `
        -ProcessNamePattern $processNamePattern `
        -WindowTitlePattern $windowTitlePattern
}
else {
    Write-Host "No drive phase needed for '$AnimalName'"
}

Write-Host "Returning cursor to neutral carousel position"
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

Write-Host "Moving to slot '$slotName' for '$AnimalName'"
Move-BBHCursorRelative `
    -XPercent ([double]$slotTarget.xPercent) `
    -YPercent ([double]$slotTarget.yPercent) `
    -SkipFocus `
    -DryRun:$DryRun `
    -ProcessNamePattern $processNamePattern `
    -WindowTitlePattern $windowTitlePattern

Write-Host "Settling before selection for $preSelectSettleMs ms"
if (-not $DryRun) {
    Start-Sleep -Milliseconds $preSelectSettleMs
}

Invoke-BBHRelativeClick `
    -XPercent ([double]$slotTarget.xPercent) `
    -YPercent ([double]$slotTarget.yPercent) `
    -Button Left `
    -SkipFocus `
    -DryRun:$DryRun `
    -ProcessNamePattern $processNamePattern `
    -WindowTitlePattern $windowTitlePattern

Write-Host "Waiting $postSelectWaitMs ms for the next screen"
if (-not $DryRun) {
    Start-Sleep -Milliseconds $postSelectWaitMs
}
