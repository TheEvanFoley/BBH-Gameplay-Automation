[CmdletBinding()]
param(
    [ValidateSet("LaunchGame", "RouteToSiteSelection", "RecordSite", "RecordTrek", "RecordAdventure", "RecordCurrentSetup")]
    [string]$Action,
    [ValidateSet("Game Closed", "Main Menu", "Adventure Selection", "Trek Selection", "Site Selection")]
    [string]$StartingScreen = "Main Menu",
    [ValidateSet("Gun", "Bow")]
    [string]$Weapon = "Gun",
    [string]$Adventure = "Elk",
    [ValidateSet("Trek 1", "Trek 2", "Trek 3")]
    [string]$Trek = "Trek 3",
    [ValidateRange(1, 5)]
    [int]$Site = 1,
    [string]$PlayerName = "CODEX",
    [string]$Notes = "",
    [int]$MaxRecordingSeconds = 35,
    [int]$SiteCycleSeconds = 45,
    [int]$RepeatCount = 1,
    [int]$RouteMaxSteps = 24,
    [string]$LaunchConfigPath = ".\experiments\windows\game-launch.local.json",
    [string]$RouterConfigPath = ".\experiments\windows\menu-router.local.json",
    [string]$CaptureConfigPath = ".\experiments\windows\obs-capture.local.json",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Convert-WeaponValue {
    param(
        [string]$Value
    )

    switch ($Value.ToLowerInvariant()) {
        "gun" { return "gun" }
        "bow" { return "bow" }
        default { throw "Unsupported weapon '$Value'." }
    }
}

$launchScriptPath = Join-Path $PSScriptRoot "Launch-Game.ps1"
$routerScriptPath = Join-Path $PSScriptRoot "Invoke-BBHMenuRouter.ps1"
$siteCaptureScriptPath = Join-Path $PSScriptRoot "Invoke-BBHSiteCaptureRun.ps1"
$trekCaptureScriptPath = Join-Path $PSScriptRoot "Invoke-BBHTrekCaptureRun.ps1"
$adventureCaptureScriptPath = Join-Path $PSScriptRoot "Invoke-BBHAdventureCaptureRun.ps1"
$manualTimedCaptureScriptPath = Join-Path $PSScriptRoot "Invoke-BBHManualTimedCapture.ps1"
$normalizedWeapon = Convert-WeaponValue -Value $Weapon

function Invoke-RepeatedAction {
    param(
        [int]$Count,
        [scriptblock]$ActionBlock,
        [string]$Label
    )

    for ($iteration = 1; $iteration -le $Count; $iteration++) {
        if ($Count -gt 1) {
            Write-Host ("{0}: iteration {1} of {2}" -f $Label, $iteration, $Count)
        }

        & $ActionBlock
    }
}

Write-Host "Action: $Action"
Write-Host "Starting screen: $StartingScreen"
Write-Host "Adventure: $Adventure"
Write-Host "Trek: $Trek"
Write-Host "Site: $Site"
Write-Host "Weapon: $normalizedWeapon"
Write-Host "Player name: $PlayerName"
Write-Host "Repeat count: $RepeatCount"
Write-Host "Dry run: $DryRun"

if ($Action -eq "LaunchGame") {
    & $launchScriptPath -ConfigPath $LaunchConfigPath -DryRun:$DryRun
    return
}

if ($StartingScreen -eq "Game Closed") {
    Write-Host "Starting screen indicates the game is closed. Launching first."
    & $launchScriptPath -ConfigPath $LaunchConfigPath -DryRun:$DryRun
}

switch ($Action) {
    "RouteToSiteSelection" {
        Invoke-RepeatedAction -Count $RepeatCount -Label "RouteToSiteSelection" -ActionBlock {
            & $routerScriptPath `
                -Adventure $Adventure `
                -Trek $Trek `
                -Site $Site `
                -PlayerName $PlayerName `
                -MaxSteps $RouteMaxSteps `
                -ConfigPath $RouterConfigPath `
                -StopAtSiteSelection `
                -DryRun:$DryRun
        }
    }

    "RecordSite" {
        Invoke-RepeatedAction -Count $RepeatCount -Label "RecordSite" -ActionBlock {
            & $siteCaptureScriptPath `
                -Adventure $Adventure `
                -Trek $Trek `
                -Site $Site `
                -PlayerName $PlayerName `
                -GameMode "classic" `
                -Weapon $normalizedWeapon `
                -Notes $Notes `
                -RouteMaxSteps $RouteMaxSteps `
                -MaxRecordingSeconds $MaxRecordingSeconds `
                -RouterConfigPath $RouterConfigPath `
                -CaptureConfigPath $CaptureConfigPath `
                -DryRun:$DryRun
        }
    }

    "RecordTrek" {
        & $trekCaptureScriptPath `
            -Adventure $Adventure `
            -Trek $Trek `
            -PlayerName $PlayerName `
            -GameMode "classic" `
            -Weapon $normalizedWeapon `
            -Notes $Notes `
            -StartSite $Site `
            -EndSite 5 `
            -RepeatCount $RepeatCount `
            -SiteCycleSeconds $SiteCycleSeconds `
            -MaxRecordingSeconds $MaxRecordingSeconds `
            -RouteMaxSteps $RouteMaxSteps `
            -RouterConfigPath $RouterConfigPath `
            -CaptureConfigPath $CaptureConfigPath `
            -DryRun:$DryRun
    }

    "RecordAdventure" {
        & $adventureCaptureScriptPath `
            -Adventure $Adventure `
            -StartTrek $Trek `
            -PlayerName $PlayerName `
            -GameMode "classic" `
            -Weapon $normalizedWeapon `
            -Notes $Notes `
            -StartSite $Site `
            -RepeatCount $RepeatCount `
            -SiteCycleSeconds $SiteCycleSeconds `
            -MaxRecordingSeconds $MaxRecordingSeconds `
            -RouteMaxSteps $RouteMaxSteps `
            -RouterConfigPath $RouterConfigPath `
            -CaptureConfigPath $CaptureConfigPath `
            -DryRun:$DryRun
    }

    "RecordCurrentSetup" {
        Invoke-RepeatedAction -Count $RepeatCount -Label "RecordCurrentSetup" -ActionBlock {
            & $manualTimedCaptureScriptPath `
                -GameMode "classic" `
                -Weapon $normalizedWeapon `
                -Adventure $Adventure `
                -Trek $Trek `
                -Site ("Site " + $Site) `
                -Notes $Notes `
                -MaxRecordingSeconds $MaxRecordingSeconds `
                -CaptureConfigPath $CaptureConfigPath `
                -DryRun:$DryRun
        }
    }
}
