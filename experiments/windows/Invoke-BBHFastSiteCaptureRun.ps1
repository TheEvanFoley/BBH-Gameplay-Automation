[CmdletBinding()]
param(
    [string]$Adventure = "Elk",
    [ValidateSet("Trek 1", "Trek 2", "Trek 3")]
    [string]$Trek = "Trek 3",
    [ValidateRange(1, 5)]
    [int]$Site = 1,
    [string]$GameMode = "classic",
    [string]$Weapon = "gun",
    [string]$Notes = "",
    [int]$MaxRecordingSeconds = 35,
    [string]$RouterConfigPath = ".\experiments\windows\menu-router.local.json",
    [string]$CaptureConfigPath = ".\experiments\windows\obs-capture.local.json",
    [string]$AnimalConfigPath = ".\experiments\windows\calibration\animal-carousel.local.json",
    [string]$TrekConfigPath = ".\experiments\windows\calibration\trek-selection.local.json",
    [string]$NameConfigPath = ".\experiments\windows\calibration\name-entry.local.json",
    [string]$SiteConfigPath = ".\experiments\windows\calibration\site-selection.local.json",
    [switch]$InitialFocusClick,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "InputToolkit.ps1")

function Wait-IntervalMilliseconds {
    param(
        [int]$Milliseconds
    )

    if ($DryRun -or $Milliseconds -le 0) {
        return
    }

    Start-Sleep -Milliseconds $Milliseconds
}

function Resolve-JsonConfigPath {
    param(
        [string]$RequestedPath,
        [string]$LocalFileName,
        [string]$ExampleFileName,
        [switch]$Calibration
    )

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $baseFolder = if ($Calibration) { "experiments\windows\calibration" } else { "experiments\windows" }
    $candidatePaths = @(
        $RequestedPath,
        (Join-Path $repoRoot (Join-Path $baseFolder $LocalFileName)),
        (Join-Path $repoRoot (Join-Path $baseFolder $ExampleFileName))
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

    throw "Unable to resolve config path for $ExampleFileName."
}

function Get-ConfigValue {
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

function Convert-TrekToSlot {
    param(
        [string]$TrekName
    )

    switch ($TrekName) {
        "Trek 1" { return "slot1Safe" }
        "Trek 2" { return "slot2" }
        "Trek 3" { return "slot3" }
        default { throw "Unsupported trek '$TrekName'." }
    }
}

function Get-AnimalStateSelection {
    param(
        $States,
        [string]$RequestedAnimalName
    )

    foreach ($stateName in @("left", "middle", "right")) {
        $stateDefinition = Get-ConfigValue -Object $States -PropertyName $stateName
        if (-not $stateDefinition) {
            continue
        }

        $slots = Get-ConfigValue -Object $stateDefinition -PropertyName "slots"
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

    throw "Unsupported animal '$RequestedAnimalName'."
}

function Invoke-TimedClick {
    param(
        [string]$Description,
        [double]$XPercent,
        [double]$YPercent
    )

    Write-Host $Description
    Invoke-BBHRelativeClick `
        -XPercent $XPercent `
        -YPercent $YPercent `
        -Button Left `
        -DryRun:$DryRun `
        -ProcessNamePattern $processNamePattern `
        -WindowTitlePattern $windowTitlePattern
}

$startCaptureScriptPath = Join-Path $PSScriptRoot "Start-ObsSiteCapture.ps1"
$stopCaptureScriptPath = Join-Path $PSScriptRoot "Stop-ObsSiteCapture.ps1"

$resolvedRouterConfigPath = Resolve-JsonConfigPath -RequestedPath $RouterConfigPath -LocalFileName "menu-router.local.json" -ExampleFileName "menu-router.example.json"
$routerConfig = Get-Content -LiteralPath $resolvedRouterConfigPath -Raw | ConvertFrom-Json
$resolvedCaptureConfigPath = Resolve-JsonConfigPath -RequestedPath $CaptureConfigPath -LocalFileName "obs-capture.local.json" -ExampleFileName "obs-capture.example.json"
$captureConfig = Get-Content -LiteralPath $resolvedCaptureConfigPath -Raw | ConvertFrom-Json
$resolvedAnimalConfigPath = Resolve-JsonConfigPath -RequestedPath $AnimalConfigPath -LocalFileName "animal-carousel.local.json" -ExampleFileName "animal-carousel.example.json" -Calibration
$animalConfig = Get-Content -LiteralPath $resolvedAnimalConfigPath -Raw | ConvertFrom-Json
$resolvedTrekConfigPath = Resolve-JsonConfigPath -RequestedPath $TrekConfigPath -LocalFileName "trek-selection.local.json" -ExampleFileName "trek-selection.example.json" -Calibration
$trekConfig = Get-Content -LiteralPath $resolvedTrekConfigPath -Raw | ConvertFrom-Json
$resolvedNameConfigPath = Resolve-JsonConfigPath -RequestedPath $NameConfigPath -LocalFileName "name-entry.local.json" -ExampleFileName "name-entry.example.json" -Calibration
$nameConfig = Get-Content -LiteralPath $resolvedNameConfigPath -Raw | ConvertFrom-Json
$resolvedSiteConfigPath = Resolve-JsonConfigPath -RequestedPath $SiteConfigPath -LocalFileName "site-selection.local.json" -ExampleFileName "site-selection.example.json" -Calibration
$siteConfig = Get-Content -LiteralPath $resolvedSiteConfigPath -Raw | ConvertFrom-Json

$processNamePattern = [string](Get-ConfigValue -Object $routerConfig -PropertyName "processNamePattern" -DefaultValue "^BBH$")
$windowTitlePattern = [string](Get-ConfigValue -Object $routerConfig -PropertyName "windowTitlePattern" -DefaultValue "BigBuckHunter_UltimateTrophy")
$targets = Get-ConfigValue -Object $routerConfig -PropertyName "targets" -DefaultValue ([pscustomobject]@{})
$timing = Get-ConfigValue -Object $routerConfig -PropertyName "timing" -DefaultValue ([pscustomobject]@{})
$focusTarget = Get-ConfigValue -Object $targets -PropertyName "focusSafeZone" -DefaultValue ([pscustomobject]@{
    xPercent = 0.50
    yPercent = 0.10
})
$mainMenuStartGame = Get-ConfigValue -Object $targets -PropertyName "mainMenuStartGame"
$genericLeftChoice = Get-ConfigValue -Object $targets -PropertyName "genericLeftChoice"
$genericRightChoice = Get-ConfigValue -Object $targets -PropertyName "genericRightChoice"
$centerContinue = Get-ConfigValue -Object $targets -PropertyName "centerContinue"
$fastTipSkipHoldMs = 5000

$restReticleTarget = Get-ConfigValue -Object $captureConfig -PropertyName "restReticleTarget"
$restReticleSettleMilliseconds = [int](Get-ConfigValue -Object $captureConfig -PropertyName "restReticleSettleMilliseconds" -DefaultValue 250)

$animalSelection = Get-AnimalStateSelection -States (Get-ConfigValue -Object $animalConfig -PropertyName "states") -RequestedAnimalName $Adventure
$animalSlotTarget = Get-ConfigValue -Object (Get-ConfigValue -Object $animalConfig -PropertyName "slots") -PropertyName ([string]$animalSelection.SlotName)
$animalDrivePosition = Get-ConfigValue -Object $animalConfig -PropertyName "drivePosition"
$animalNeutralPosition = Get-ConfigValue -Object $animalConfig -PropertyName "neutralPosition"

$trekTargetSlot = Convert-TrekToSlot -TrekName $Trek
$trekSlotTarget = Get-ConfigValue -Object (Get-ConfigValue -Object $trekConfig -PropertyName "slots") -PropertyName $trekTargetSlot
$confirmTarget = Get-ConfigValue -Object (Get-ConfigValue -Object $nameConfig -PropertyName "keys") -PropertyName "CONFIRM"
$targetSiteName = "site$Site"
$siteTarget = Get-ConfigValue -Object (Get-ConfigValue -Object $siteConfig -PropertyName "sites") -PropertyName $targetSiteName

$weaponTarget = switch ($Weapon.ToLowerInvariant()) {
    "gun" { $genericLeftChoice }
    "bow" { $genericRightChoice }
    default { throw "Unsupported weapon '$Weapon'." }
}

Write-Host "Adventure: $Adventure"
Write-Host "Trek: $Trek"
Write-Host "Site: $targetSiteName"
Write-Host "Weapon: $Weapon"
Write-Host "Recording length target: $MaxRecordingSeconds seconds"
Write-Host "Fast mode: True"
Write-Host "Initial focus click: $InitialFocusClick"
Write-Host "Dry run: $DryRun"

Focus-BBHWindow -ProcessNamePattern $processNamePattern -WindowTitlePattern $windowTitlePattern | Out-Null

if ($InitialFocusClick) {
    Invoke-TimedClick -Description "Fast path: click into the game window" -XPercent ([double]$focusTarget.xPercent) -YPercent ([double]$focusTarget.yPercent)
}

Wait-IntervalMilliseconds -Milliseconds 500
Invoke-TimedClick -Description "Fast path: click Start Game" -XPercent ([double]$mainMenuStartGame.xPercent) -YPercent ([double]$mainMenuStartGame.yPercent)

Wait-IntervalMilliseconds -Milliseconds 2500
Invoke-TimedClick -Description "Fast path: click Big Buck Hunter" -XPercent ([double]$genericLeftChoice.xPercent) -YPercent ([double]$genericLeftChoice.yPercent)

Wait-IntervalMilliseconds -Milliseconds 1500
Invoke-TimedClick -Description "Fast path: click Classic" -XPercent ([double]$genericLeftChoice.xPercent) -YPercent ([double]$genericLeftChoice.yPercent)

Wait-IntervalMilliseconds -Milliseconds 1500
Invoke-TimedClick -Description "Fast path: click 1 Player" -XPercent ([double]$genericLeftChoice.xPercent) -YPercent ([double]$genericLeftChoice.yPercent)

Wait-IntervalMilliseconds -Milliseconds 1500
Invoke-TimedClick -Description ("Fast path: click selected weapon '{0}'" -f $Weapon) -XPercent ([double]$weaponTarget.xPercent) -YPercent ([double]$weaponTarget.yPercent)

Wait-IntervalMilliseconds -Milliseconds 1500
Write-Host ("Fast path: select adventure '{0}'" -f $Adventure)
if ($animalSelection.MoveMs -gt 0) {
    Write-Host ("Driving adventure carousel to state '{0}' for {1} ms" -f $animalSelection.StateName, $animalSelection.MoveMs)
    Move-BBHCursorRelativeAndHold `
        -XPercent ([double]$animalDrivePosition.xPercent) `
        -YPercent ([double]$animalDrivePosition.yPercent) `
        -HoldMilliseconds ([int]$animalSelection.MoveMs) `
        -SkipFocus `
        -DryRun:$DryRun `
        -ProcessNamePattern $processNamePattern `
        -WindowTitlePattern $windowTitlePattern
}
Move-BBHCursorRelative `
    -XPercent ([double]$animalNeutralPosition.xPercent) `
    -YPercent ([double]$animalNeutralPosition.yPercent) `
    -SkipFocus `
    -DryRun:$DryRun `
    -ProcessNamePattern $processNamePattern `
    -WindowTitlePattern $windowTitlePattern
Invoke-BBHRelativeClick `
    -XPercent ([double]$animalSlotTarget.xPercent) `
    -YPercent ([double]$animalSlotTarget.yPercent) `
    -Button Left `
    -SkipFocus `
    -DryRun:$DryRun `
    -ProcessNamePattern $processNamePattern `
    -WindowTitlePattern $windowTitlePattern

Wait-IntervalMilliseconds -Milliseconds 1500
Invoke-TimedClick -Description ("Fast path: click selected trek '{0}'" -f $Trek) -XPercent ([double]$trekSlotTarget.xPercent) -YPercent ([double]$trekSlotTarget.yPercent)

Wait-IntervalMilliseconds -Milliseconds 4500
Write-Host "Fast path: hold left click on the tip screen"
Move-BBHCursorRelative `
    -XPercent ([double]$centerContinue.xPercent) `
    -YPercent ([double]$centerContinue.yPercent) `
    -SkipFocus `
    -DryRun:$DryRun `
    -ProcessNamePattern $processNamePattern `
    -WindowTitlePattern $windowTitlePattern
Invoke-BBHMouseButtonHold `
    -Button Left `
    -HoldMilliseconds $fastTipSkipHoldMs `
    -SkipFocus `
    -DryRun:$DryRun `
    -ProcessNamePattern $processNamePattern `
    -WindowTitlePattern $windowTitlePattern
Write-Host "Fast path: confirm the existing player name"
Invoke-BBHRelativeClick `
    -XPercent ([double]$confirmTarget.xPercent) `
    -YPercent ([double]$confirmTarget.yPercent) `
    -Button Left `
    -SkipFocus `
    -DryRun:$DryRun `
    -ProcessNamePattern $processNamePattern `
    -WindowTitlePattern $windowTitlePattern

Wait-IntervalMilliseconds -Milliseconds 6500
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

Write-Host ("Fast path: click site '{0}'" -f $targetSiteName)
Move-BBHCursorRelative `
    -XPercent ([double]$siteTarget.xPercent) `
    -YPercent ([double]$siteTarget.yPercent) `
    -SkipFocus `
    -DryRun:$DryRun `
    -ProcessNamePattern $processNamePattern `
    -WindowTitlePattern $windowTitlePattern
Invoke-BBHRelativeClick `
    -XPercent ([double]$siteTarget.xPercent) `
    -YPercent ([double]$siteTarget.yPercent) `
    -Button Left `
    -SkipFocus `
    -DryRun:$DryRun `
    -ProcessNamePattern $processNamePattern `
    -WindowTitlePattern $windowTitlePattern

if ($restReticleTarget) {
    Write-Host "Moving reticle to the configured rest position for gameplay capture"
    Move-BBHCursorRelative `
        -XPercent ([double]$restReticleTarget.xPercent) `
        -YPercent ([double]$restReticleTarget.yPercent) `
        -SkipFocus `
        -DryRun:$DryRun `
        -ProcessNamePattern $processNamePattern `
        -WindowTitlePattern $windowTitlePattern
    Wait-IntervalMilliseconds -Milliseconds $restReticleSettleMilliseconds
}

if ($DryRun) {
    [pscustomobject]@{
        completed = $false
        dryRun = $true
        fastMode = $true
        targetAdventure = $Adventure
        targetTrek = $Trek
        targetSite = $targetSiteName
        nextPhase = "fixed-duration-recording"
    } | ConvertTo-Json -Depth 4
    return
}

$remainingMilliseconds = [Math]::Max(0, [int](($MaxRecordingSeconds * 1000) - $recordingStopwatch.ElapsedMilliseconds))
if ($remainingMilliseconds -gt 0) {
    Write-Host ("Recording for the remaining {0:N1} seconds before finalizing capture" -f ($remainingMilliseconds / 1000))
    Start-Sleep -Milliseconds $remainingMilliseconds
}

$actualRecordedSeconds = [Math]::Round($recordingStopwatch.Elapsed.TotalSeconds, 2)

Write-Host "Stopping OBS site capture"
& $stopCaptureScriptPath -ConfigPath $CaptureConfigPath -DryRun:$DryRun

[pscustomobject]@{
    completed = $true
    fastMode = $true
    adventure = $Adventure
    trek = $Trek
    site = $targetSiteName
    recordingStartedAt = if ($recordingStartedAt) { $recordingStartedAt.ToString("o") } else { $null }
    recordingStoppedAt = (Get-Date).ToString("o")
    fixedDurationMode = $true
    actualRecordedSeconds = $actualRecordedSeconds
    maxRecordingSeconds = $MaxRecordingSeconds
} | ConvertTo-Json -Depth 4
