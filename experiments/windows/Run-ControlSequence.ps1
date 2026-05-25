[CmdletBinding()]
param(
    [string]$ConfigPath = ".\experiments\windows\game-controls.local.json",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "InputToolkit.ps1")

function Resolve-ControlConfig {
    param(
        [string]$RequestedPath
    )

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $candidatePaths = @(
        $RequestedPath,
        (Join-Path $repoRoot "experiments\windows\game-controls.local.json"),
        (Join-Path $repoRoot "experiments\windows\game-controls.example.json")
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

    throw "No control config found. Create experiments\windows\game-controls.local.json from the example file."
}

function Get-ControlConfigValue {
    param(
        $Config,
        [string]$PropertyName,
        $DefaultValue = $null
    )

    $property = $Config.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $DefaultValue
    }

    return $property.Value
}

$resolvedConfigPath = Resolve-ControlConfig -RequestedPath $ConfigPath
$config = Get-Content -LiteralPath $resolvedConfigPath -Raw | ConvertFrom-Json

$processNamePattern = Get-ControlConfigValue -Config $config -PropertyName "processNamePattern" -DefaultValue "^BBH$"
$windowTitlePattern = Get-ControlConfigValue -Config $config -PropertyName "windowTitlePattern" -DefaultValue "BigBuckHunter_UltimateTrophy"
$postFocusDelayMilliseconds = [int](Get-ControlConfigValue -Config $config -PropertyName "postFocusDelayMilliseconds" -DefaultValue 500)
$steps = @(Get-ControlConfigValue -Config $config -PropertyName "steps" -DefaultValue @())

Write-Host "Using control config: $resolvedConfigPath"
Write-Host "Dry run: $DryRun"

if (-not $steps.Count) {
    throw "No control steps were defined."
}

for ($index = 0; $index -lt $steps.Count; $index++) {
    $step = $steps[$index]
    $stepNumber = $index + 1
    $stepType = [string]$step.type
    $description = ""
    if ($step.PSObject.Properties["description"]) {
        $description = [string]$step.description
    }

    if ($description) {
        Write-Host "Step $stepNumber [$stepType]: $description"
    }
    else {
        Write-Host "Step $stepNumber [$stepType]"
    }

    switch ($stepType) {
        "focus" {
            Focus-BBHWindow -ProcessNamePattern $processNamePattern -WindowTitlePattern $windowTitlePattern | Out-Null
            if ($postFocusDelayMilliseconds -gt 0) {
                Start-Sleep -Milliseconds $postFocusDelayMilliseconds
            }
        }
        "wait" {
            $milliseconds = 500
            if ($step.PSObject.Properties["milliseconds"]) {
                $milliseconds = [int]$step.milliseconds
            }
            Write-Host "Waiting $milliseconds ms"
            if (-not $DryRun) {
                Start-Sleep -Milliseconds $milliseconds
            }
        }
        "click" {
            $clickCount = 1
            if ($step.PSObject.Properties["clickCount"]) {
                $clickCount = [int]$step.clickCount
            }

            $delayMilliseconds = 150
            if ($step.PSObject.Properties["delayMilliseconds"]) {
                $delayMilliseconds = [int]$step.delayMilliseconds
            }

            $button = "Left"
            if ($step.PSObject.Properties["button"]) {
                $button = [string]$step.button
            }

            Invoke-BBHRelativeClick `
                -XPercent ([double]$step.xPercent) `
                -YPercent ([double]$step.yPercent) `
                -ClickCount $clickCount `
                -DelayMilliseconds $delayMilliseconds `
                -Button $button `
                -DryRun:$DryRun `
                -ProcessNamePattern $processNamePattern `
                -WindowTitlePattern $windowTitlePattern
        }
        "moveMouse" {
            Move-BBHCursorRelative `
                -XPercent ([double]$step.xPercent) `
                -YPercent ([double]$step.yPercent) `
                -DryRun:$DryRun `
                -ProcessNamePattern $processNamePattern `
                -WindowTitlePattern $windowTitlePattern
        }
        "scroll" {
            $wheelDelta = 120
            if ($step.PSObject.Properties["wheelDelta"]) {
                $wheelDelta = [int]$step.wheelDelta
            }

            $repeatCount = 1
            if ($step.PSObject.Properties["repeatCount"]) {
                $repeatCount = [int]$step.repeatCount
            }

            Send-BBHMouseWheel `
                -WheelDelta $wheelDelta `
                -RepeatCount $repeatCount `
                -DryRun:$DryRun `
                -ProcessNamePattern $processNamePattern `
                -WindowTitlePattern $windowTitlePattern
        }
        "sendKeys" {
            Send-BBHKeys `
                -Keys ([string]$step.keys) `
                -DryRun:$DryRun `
                -ProcessNamePattern $processNamePattern `
                -WindowTitlePattern $windowTitlePattern
        }
        default {
            throw "Unsupported control step type '$stepType'."
        }
    }
}
