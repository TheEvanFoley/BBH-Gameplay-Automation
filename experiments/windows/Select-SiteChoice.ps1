[CmdletBinding()]
param(
    [ValidateSet("site1", "site2", "site3", "site4", "site5")]
    [string]$SiteName = "site3",
    [string]$ConfigPath = ".\experiments\windows\calibration\site-selection.local.json",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "InputToolkit.ps1")

function Resolve-SiteConfig {
    param(
        [string]$RequestedPath
    )

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $candidatePaths = @(
        $RequestedPath,
        (Join-Path $repoRoot "experiments\windows\calibration\site-selection.local.json"),
        (Join-Path $repoRoot "experiments\windows\calibration\site-selection.example.json")
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

    throw "No site-selection config found. Create experiments\windows\calibration\site-selection.local.json from the example file."
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

$resolvedConfigPath = Resolve-SiteConfig -RequestedPath $ConfigPath
$config = Get-Content -LiteralPath $resolvedConfigPath -Raw | ConvertFrom-Json

$processNamePattern = Get-ConfigValue -Object $config -PropertyName "processNamePattern" -DefaultValue "^BBH$"
$windowTitlePattern = Get-ConfigValue -Object $config -PropertyName "windowTitlePattern" -DefaultValue "BigBuckHunter_UltimateTrophy"
$timing = Get-ConfigValue -Object $config -PropertyName "timing"
$sites = Get-ConfigValue -Object $config -PropertyName "sites"

$preSelectSettleMs = [int](Get-ConfigValue -Object $timing -PropertyName "preSelectSettleMs" -DefaultValue 300)
$postSelectWaitMs = [int](Get-ConfigValue -Object $timing -PropertyName "postSelectWaitMs" -DefaultValue 2000)

$siteTarget = Get-ConfigValue -Object $sites -PropertyName $SiteName
if (-not $siteTarget) {
    throw "Site target '$SiteName' is not defined."
}

Write-Host "Using site-selection config: $resolvedConfigPath"
Write-Host "Site target: $SiteName"
Write-Host "Dry run: $DryRun"

Focus-BBHWindow -ProcessNamePattern $processNamePattern -WindowTitlePattern $windowTitlePattern | Out-Null

Write-Host "Moving to '$SiteName'"
Move-BBHCursorRelative `
    -XPercent ([double]$siteTarget.xPercent) `
    -YPercent ([double]$siteTarget.yPercent) `
    -SkipFocus `
    -DryRun:$DryRun `
    -ProcessNamePattern $processNamePattern `
    -WindowTitlePattern $windowTitlePattern

Write-Host "Settling before selection for $preSelectSettleMs ms"
if (-not $DryRun) {
    Start-Sleep -Milliseconds $preSelectSettleMs
}

Invoke-BBHRelativeClick `
    -XPercent ([double]$siteTarget.xPercent) `
    -YPercent ([double]$siteTarget.yPercent) `
    -Button Left `
    -SkipFocus `
    -DryRun:$DryRun `
    -ProcessNamePattern $processNamePattern `
    -WindowTitlePattern $windowTitlePattern

Write-Host "Waiting $postSelectWaitMs ms for the next screen"
if (-not $DryRun) {
    Start-Sleep -Milliseconds $postSelectWaitMs
}
