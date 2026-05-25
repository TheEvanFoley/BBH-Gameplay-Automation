[CmdletBinding()]
param(
    [string]$Adventure = "Elk",
    [ValidateSet("Trek 1", "Trek 2", "Trek 3")]
    [string]$Trek = "Trek 3",
    [ValidateRange(1, 5)]
    [int]$Site = 1,
    [string]$PlayerName = "CODEX",
    [string]$GameMode = "classic",
    [string]$Weapon = "gun",
    [string]$Notes = "",
    [int]$RouteMaxSteps = 24,
    [int]$MaxRecordingSeconds = 35,
    [string]$RouterConfigPath = ".\experiments\windows\menu-router.local.json",
    [string]$CaptureConfigPath = ".\experiments\windows\obs-capture.local.json",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "InputToolkit.ps1")

function Wait-Interval {
    param(
        [int]$Seconds
    )

    if ($DryRun) {
        return
    }

    Start-Sleep -Seconds $Seconds
}

function Get-RemainingRecordingMilliseconds {
    param(
        [System.Diagnostics.Stopwatch]$Stopwatch,
        [int]$MaxSeconds
    )

    return [Math]::Max(0, [int](($MaxSeconds * 1000) - $Stopwatch.ElapsedMilliseconds))
}

function Get-OptionalPropertyValue {
    param(
        $Object,
        [string]$PropertyName,
        $DefaultValue = $null
    )

    if (-not $Object) {
        return $DefaultValue
    }

    $property = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $DefaultValue
    }

    return $property.Value
}

$routerScriptPath = Join-Path $PSScriptRoot "Invoke-BBHMenuRouter.ps1"
$stateScriptPath = Join-Path $PSScriptRoot "Get-BBHState.ps1"
$startCaptureScriptPath = Join-Path $PSScriptRoot "Start-ObsSiteCapture.ps1"
$stopCaptureScriptPath = Join-Path $PSScriptRoot "Stop-ObsSiteCapture.ps1"
$siteSelectorScriptPath = Join-Path $PSScriptRoot "Select-SiteChoice.ps1"
$targetSiteName = "site$Site"
$resolvedCaptureConfigPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CaptureConfigPath)
$captureConfig = $null
if (Test-Path -LiteralPath $resolvedCaptureConfigPath) {
    $captureConfig = Get-Content -LiteralPath $resolvedCaptureConfigPath -Raw | ConvertFrom-Json
}

$restReticleTarget = Get-OptionalPropertyValue -Object $captureConfig -PropertyName "restReticleTarget"
$restReticleSettleMilliseconds = [int](Get-OptionalPropertyValue -Object $captureConfig -PropertyName "restReticleSettleMilliseconds" -DefaultValue 250)

Write-Host "Adventure: $Adventure"
Write-Host "Trek: $Trek"
Write-Host "Site: $targetSiteName"
Write-Host "Game mode: $GameMode"
Write-Host "Weapon: $Weapon"
Write-Host "Recording length target: $MaxRecordingSeconds seconds"
Write-Host "Dry run: $DryRun"

Write-Host "Routing to the target site-selection screen"
$routerJson = & $routerScriptPath `
    -Adventure $Adventure `
    -Trek $Trek `
    -Site $Site `
    -PlayerName $PlayerName `
    -MaxSteps $RouteMaxSteps `
    -ConfigPath $RouterConfigPath `
    -StopAtSiteSelection `
    -DryRun:$DryRun

if ($routerJson) {
    Write-Host "Router result:"
    Write-Host $routerJson
}

Write-Host "Verifying that the live screen is the target site-selection state"
$preflightStateJson = & $stateScriptPath -CaptureCurrent -CaptureLabel "capture-preflight"
$preflightState = $preflightStateJson | ConvertFrom-Json

Write-Host ("Preflight: family={0} adventure={1} trek={2}" -f $preflightState.screenFamily, $preflightState.adventure, $preflightState.trek)

$familyMatches = ([string]$preflightState.screenFamily -eq "classic-site-selection-screen")
$adventureText = [string]$preflightState.adventure
$trekText = [string]$preflightState.trek
$adventureMatches = (-not $adventureText) -or ($adventureText -eq $Adventure)
$trekMatches = (-not $trekText) -or ($trekText -eq $Trek)
$isConfirmedSiteSelection = $familyMatches -and $adventureMatches -and $trekMatches

if (-not $isConfirmedSiteSelection) {
    throw ("Capture preflight failed. Expected classic-site-selection-screen for adventure '{0}' and trek '{1}', but got family='{2}', adventure='{3}', trek='{4}'." -f `
        $Adventure, `
        $Trek, `
        [string]$preflightState.screenFamily, `
        [string]$preflightState.adventure, `
        [string]$preflightState.trek)
}

if ($familyMatches -and (-not $adventureText -or -not $trekText)) {
    Write-Warning "Preflight reached the site-selection family, but adventure/trek OCR was incomplete. Continuing in fixed-duration mode."
}

Write-Host "Starting OBS site capture"
& $startCaptureScriptPath `
    -GameMode $GameMode `
    -Weapon $Weapon `
    -Adventure $Adventure `
    -Trek $Trek `
    -Site ("Site " + $Site) `
    -Notes $Notes `
    -ConfigPath $CaptureConfigPath `
    -DryRun:$DryRun

$recordingStopwatch = if ($DryRun) { $null } else { [System.Diagnostics.Stopwatch]::StartNew() }
$recordingStartedAt = if ($DryRun) { $null } else { Get-Date }

Write-Host "Selecting site '$targetSiteName' to begin the recorded run"
& $siteSelectorScriptPath -SiteName $targetSiteName -DryRun:$DryRun

if ($restReticleTarget) {
    Write-Host "Moving reticle to the configured rest position for gameplay capture"
    Move-BBHCursorRelative `
        -XPercent ([double]$restReticleTarget.xPercent) `
        -YPercent ([double]$restReticleTarget.yPercent) `
        -SkipFocus `
        -DryRun:$DryRun

    if (-not $DryRun) {
        Start-Sleep -Milliseconds $restReticleSettleMilliseconds
    }
}

if ($DryRun) {
    [pscustomobject]@{
        completed = $false
        dryRun = $true
        targetAdventure = $Adventure
        targetTrek = $Trek
        targetSite = $targetSiteName
        nextPhase = "fixed-duration-recording"
    } | ConvertTo-Json -Depth 4
    return
}

$remainingMilliseconds = Get-RemainingRecordingMilliseconds -Stopwatch $recordingStopwatch -MaxSeconds $MaxRecordingSeconds
if ($remainingMilliseconds -gt 0) {
    Write-Host ("Recording for the remaining {0:N1} seconds before finalizing capture" -f ($remainingMilliseconds / 1000))
    Start-Sleep -Milliseconds $remainingMilliseconds
}

$actualRecordedSeconds = [Math]::Round($recordingStopwatch.Elapsed.TotalSeconds, 2)

Write-Host "Stopping OBS site capture"
& $stopCaptureScriptPath -ConfigPath $CaptureConfigPath -DryRun:$DryRun

[pscustomobject]@{
    completed = $true
    adventure = $Adventure
    trek = $Trek
    site = $targetSiteName
    recordingStartedAt = if ($recordingStartedAt) { $recordingStartedAt.ToString("o") } else { $null }
    recordingStoppedAt = (Get-Date).ToString("o")
    fixedDurationMode = $true
    actualRecordedSeconds = $actualRecordedSeconds
    maxRecordingSeconds = $MaxRecordingSeconds
    detectedEndAt = $null
    detectedEndFamily = $null
    detectedEndAdventure = $null
    detectedEndTrek = $null
    warning = "Fixed-duration mode: no end-of-run detection was attempted."
} | ConvertTo-Json -Depth 4
