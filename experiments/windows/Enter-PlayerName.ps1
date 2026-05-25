[CmdletBinding()]
param(
    [string]$Name = "CODEX",
    [string]$ConfigPath = ".\experiments\windows\calibration\name-entry.local.json",
    [switch]$ConfirmOnly,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "InputToolkit.ps1")

function Resolve-NameConfig {
    param(
        [string]$RequestedPath
    )

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $candidatePaths = @(
        $RequestedPath,
        (Join-Path $repoRoot "experiments\windows\calibration\name-entry.local.json"),
        (Join-Path $repoRoot "experiments\windows\calibration\name-entry.example.json")
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

    throw "No name-entry config found. Create experiments\windows\calibration\name-entry.local.json from the example file."
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

$resolvedConfigPath = Resolve-NameConfig -RequestedPath $ConfigPath
$config = Get-Content -LiteralPath $resolvedConfigPath -Raw | ConvertFrom-Json

$processNamePattern = Get-ConfigValue -Object $config -PropertyName "processNamePattern" -DefaultValue "^BBH$"
$windowTitlePattern = Get-ConfigValue -Object $config -PropertyName "windowTitlePattern" -DefaultValue "BigBuckHunter_UltimateTrophy"
$timing = Get-ConfigValue -Object $config -PropertyName "timing"
$keys = Get-ConfigValue -Object $config -PropertyName "keys"

$preKeySettleMs = [int](Get-ConfigValue -Object $timing -PropertyName "preKeySettleMs" -DefaultValue 250)
$betweenKeyMs = [int](Get-ConfigValue -Object $timing -PropertyName "betweenKeyMs" -DefaultValue 250)
$preConfirmSettleMs = [int](Get-ConfigValue -Object $timing -PropertyName "preConfirmSettleMs" -DefaultValue 350)
$postConfirmWaitMs = [int](Get-ConfigValue -Object $timing -PropertyName "postConfirmWaitMs" -DefaultValue 1500)

$normalizedName = $null
if (-not $ConfirmOnly) {
    $normalizedName = $Name.ToUpperInvariant()
    if ($normalizedName -notmatch '^[A-Z]{1,10}$') {
        throw "Name must be 1-10 letters A-Z for the current V1 keyboard mapping."
    }
}

Write-Host "Using name-entry config: $resolvedConfigPath"
if ($ConfirmOnly) {
    Write-Host "Name entry mode: confirm existing name"
}
else {
    Write-Host "Leaderboard name: $normalizedName"
}
Write-Host "Dry run: $DryRun"

Focus-BBHWindow -ProcessNamePattern $processNamePattern -WindowTitlePattern $windowTitlePattern | Out-Null

if (-not $ConfirmOnly) {
    Write-Host "Settling before key entry for $preKeySettleMs ms"
    if (-not $DryRun) {
        Start-Sleep -Milliseconds $preKeySettleMs
    }

    foreach ($character in $normalizedName.ToCharArray()) {
        $keyName = [string]$character
        $keyTarget = Get-ConfigValue -Object $keys -PropertyName $keyName
        if (-not $keyTarget) {
            throw "No coordinate mapping found for '$keyName'."
        }

        Write-Host "Typing '$keyName'"
        Invoke-BBHRelativeClick `
            -XPercent ([double]$keyTarget.xPercent) `
            -YPercent ([double]$keyTarget.yPercent) `
            -Button Left `
            -SkipFocus `
            -DryRun:$DryRun `
            -ProcessNamePattern $processNamePattern `
            -WindowTitlePattern $windowTitlePattern

        if (-not $DryRun) {
            Start-Sleep -Milliseconds $betweenKeyMs
        }
    }
}

$confirmTarget = Get-ConfigValue -Object $keys -PropertyName "CONFIRM"
if (-not $confirmTarget) {
    throw "No CONFIRM coordinate mapping found."
}

Write-Host "Settling before confirm for $preConfirmSettleMs ms"
if (-not $DryRun) {
    Start-Sleep -Milliseconds $preConfirmSettleMs
}

Write-Host "Confirming name entry"
Invoke-BBHRelativeClick `
    -XPercent ([double]$confirmTarget.xPercent) `
    -YPercent ([double]$confirmTarget.yPercent) `
    -Button Left `
    -SkipFocus `
    -DryRun:$DryRun `
    -ProcessNamePattern $processNamePattern `
    -WindowTitlePattern $windowTitlePattern

Write-Host "Waiting $postConfirmWaitMs ms for the next screen"
if (-not $DryRun) {
    Start-Sleep -Milliseconds $postConfirmWaitMs
}
