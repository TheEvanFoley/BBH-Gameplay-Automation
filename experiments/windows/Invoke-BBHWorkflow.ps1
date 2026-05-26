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
    [ValidateSet("Safe", "Fast")]
    [string]$RunMode = "Safe",
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

. (Join-Path $PSScriptRoot "InputToolkit.ps1")

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

function Resolve-JsonConfigPath {
    param(
        [string]$RequestedPath,
        [string]$LocalFileName,
        [string]$ExampleFileName
    )

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $candidatePaths = @(
        $RequestedPath,
        (Join-Path $repoRoot ("experiments\windows\" + $LocalFileName)),
        (Join-Path $repoRoot ("experiments\windows\" + $ExampleFileName))
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

function Invoke-RecordSiteReturnToMainMenu {
    param(
        [string]$ResolvedRouterConfigPath,
        [switch]$WhatIfMode
    )

    $routerConfig = Get-Content -LiteralPath $ResolvedRouterConfigPath -Raw | ConvertFrom-Json
    $targets = Get-ConfigValue -Object $routerConfig -PropertyName "targets" -DefaultValue ([pscustomobject]@{})
    $timing = Get-ConfigValue -Object $routerConfig -PropertyName "timing" -DefaultValue ([pscustomobject]@{})
    $processNamePattern = [string](Get-ConfigValue -Object $routerConfig -PropertyName "processNamePattern" -DefaultValue "^BBH$")
    $windowTitlePattern = [string](Get-ConfigValue -Object $routerConfig -PropertyName "windowTitlePattern" -DefaultValue "BigBuckHunter_UltimateTrophy")
    $mainMenuReturnTarget = Get-ConfigValue -Object $targets -PropertyName "gameplayMainMenu" -DefaultValue ([pscustomobject]@{
        xPercent = 0.332
        yPercent = 0.104
    })
    $settleMilliseconds = [int](Get-ConfigValue -Object $timing -PropertyName "afterCenterClickMs" -DefaultValue 2000)

    Write-Host "Returning to the main menu for the next repeated site run"
    Invoke-BBHRelativeClick `
        -XPercent ([double]$mainMenuReturnTarget.xPercent) `
        -YPercent ([double]$mainMenuReturnTarget.yPercent) `
        -Button Left `
        -DryRun:$WhatIfMode `
        -ProcessNamePattern $processNamePattern `
        -WindowTitlePattern $windowTitlePattern

    if (-not $WhatIfMode) {
        Start-Sleep -Milliseconds $settleMilliseconds
    }
}

$launchScriptPath = Join-Path $PSScriptRoot "Launch-Game.ps1"
$routerScriptPath = Join-Path $PSScriptRoot "Invoke-BBHMenuRouter.ps1"
$siteCaptureScriptPath = Join-Path $PSScriptRoot "Invoke-BBHSiteCaptureRun.ps1"
$fastSiteCaptureScriptPath = Join-Path $PSScriptRoot "Invoke-BBHFastSiteCaptureRun.ps1"
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
Write-Host "Run mode: $RunMode"
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
        if ($RunMode -eq "Fast" -and $StartingScreen -ne "Main Menu") {
            throw "Fast RecordSite mode is only supported when StartingScreen is 'Main Menu'."
        }

        if ($RepeatCount -gt 1 -and $StartingScreen -ne "Main Menu") {
            throw "RecordSite repeat is only supported when StartingScreen is 'Main Menu'."
        }

        $resolvedRouterConfigPath = $null
        $interRunDelaySeconds = [Math]::Max(0, ($SiteCycleSeconds - $MaxRecordingSeconds))
        if ($RepeatCount -gt 1) {
            $resolvedRouterConfigPath = Resolve-JsonConfigPath `
                -RequestedPath $RouterConfigPath `
                -LocalFileName "menu-router.local.json" `
                -ExampleFileName "menu-router.example.json"
            Write-Host "RecordSite repeat mode is enabled from the main menu."
            Write-Host ("Delay before returning to main menu: {0} seconds" -f $interRunDelaySeconds)
        }

        for ($iteration = 1; $iteration -le $RepeatCount; $iteration++) {
            if ($RepeatCount -gt 1) {
                Write-Host ("RecordSite: iteration {0} of {1}" -f $iteration, $RepeatCount)
            }

            if ($RunMode -eq "Fast") {
                & $fastSiteCaptureScriptPath `
                    -Adventure $Adventure `
                    -Trek $Trek `
                    -Site $Site `
                    -GameMode "classic" `
                    -Weapon $normalizedWeapon `
                    -Notes $Notes `
                    -MaxRecordingSeconds $MaxRecordingSeconds `
                    -RouterConfigPath $RouterConfigPath `
                    -CaptureConfigPath $CaptureConfigPath `
                    -InitialFocusClick:($iteration -eq 1) `
                    -DryRun:$DryRun
            }
            else {
                $skipRoutingAndPreflight = ($StartingScreen -eq "Site Selection" -and $iteration -eq 1)

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
                    -SkipRoutingAndPreflight:$skipRoutingAndPreflight `
                    -DryRun:$DryRun
            }

            if ($iteration -ge $RepeatCount) {
                continue
            }

            if ($interRunDelaySeconds -gt 0) {
                Write-Host ("Waiting {0} seconds before returning to the main menu" -f $interRunDelaySeconds)
                if (-not $DryRun) {
                    Start-Sleep -Seconds $interRunDelaySeconds
                }
            }

            Invoke-RecordSiteReturnToMainMenu `
                -ResolvedRouterConfigPath $resolvedRouterConfigPath `
                -WhatIfMode:$DryRun

            if ($RunMode -eq "Fast") {
                Write-Host "Waiting 3 seconds after returning to the main menu"
                if (-not $DryRun) {
                    Start-Sleep -Seconds 3
                }
            }
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
