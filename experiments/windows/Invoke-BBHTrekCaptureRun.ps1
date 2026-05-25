[CmdletBinding()]
param(
    [string]$Adventure = "Elk",
    [ValidateSet("Trek 1", "Trek 2", "Trek 3")]
    [string]$Trek = "Trek 3",
    [string]$PlayerName = "CODEX",
    [string]$GameMode = "classic",
    [string]$Weapon = "gun",
    [string]$Notes = "",
    [ValidateRange(1, 5)]
    [int]$StartSite = 1,
    [ValidateRange(1, 5)]
    [int]$EndSite = 5,
    [int]$RepeatCount = 1,
    [int]$SiteCycleSeconds = 45,
    [int]$MaxRecordingSeconds = 35,
    [int]$InterSiteReadyPollSeconds = 2,
    [int]$PostTrekTransitionTimeoutSeconds = 60,
    [int]$RouteMaxSteps = 24,
    [string]$RouterConfigPath = ".\experiments\windows\menu-router.local.json",
    [string]$CaptureConfigPath = ".\experiments\windows\obs-capture.local.json",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "InputToolkit.ps1")

if ($EndSite -lt $StartSite) {
    throw "EndSite must be greater than or equal to StartSite."
}

$siteCaptureScriptPath = Join-Path $PSScriptRoot "Invoke-BBHSiteCaptureRun.ps1"
$startCaptureScriptPath = Join-Path $PSScriptRoot "Start-ObsSiteCapture.ps1"
$stopCaptureScriptPath = Join-Path $PSScriptRoot "Stop-ObsSiteCapture.ps1"
$siteSelectorScriptPath = Join-Path $PSScriptRoot "Select-SiteChoice.ps1"
$nameScriptPath = Join-Path $PSScriptRoot "Enter-PlayerName.ps1"
$stateScriptPath = Join-Path $PSScriptRoot "Get-BBHState.ps1"
$results = @()
$initialStartSite = $StartSite

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

    $property = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $DefaultValue
    }

    return $property.Value
}

function Invoke-PostTrekMenuAction {
    param(
        [ValidateSet("Replay", "Next", "NewHunt")]
        [string]$Action,
        [int]$TimeoutSeconds,
        [int]$PollSeconds,
        [switch]$WhatIfMode
    )

    if ($WhatIfMode) {
        Write-Host ("Dry run: skipping post-trek action '{0}'" -f $Action)
        return $true
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $stateJson = & $stateScriptPath -CaptureCurrent -CaptureLabel "post-trek-transition" -FamilyOnly
        $state = $stateJson | ConvertFrom-Json
        Write-Host ("Post-trek transition: family={0}" -f $state.screenFamily)

        switch ([string]$state.screenFamily) {
            "bonus-report" {
                Write-Host "Advancing bonus report before post-trek action"
                Invoke-BBHRelativeClick `
                    -XPercent ([double]$centerContinueTarget.xPercent) `
                    -YPercent ([double]$centerContinueTarget.yPercent) `
                    -Button Left `
                    -ProcessNamePattern $processNamePattern `
                    -WindowTitlePattern $windowTitlePattern
                Start-Sleep -Seconds 2
                continue
            }

            "post-trek-menu" {
                $target = switch ($Action) {
                    "Replay" { $postTrekReplayTarget }
                    "Next" { $postTrekNextTarget }
                    "NewHunt" { $postTrekNewHuntTarget }
                }

                Write-Host ("Executing post-trek action '{0}'" -f $Action)
                Invoke-BBHRelativeClick `
                    -XPercent ([double]$target.xPercent) `
                    -YPercent ([double]$target.yPercent) `
                    -Button Left `
                    -ProcessNamePattern $processNamePattern `
                    -WindowTitlePattern $windowTitlePattern
                Start-Sleep -Seconds 2
                return $true
            }
        }

        Start-Sleep -Seconds $PollSeconds
    } while ((Get-Date) -lt $deadline)

    Write-Warning ("Timed out waiting to perform post-trek action '{0}'." -f $Action)
    return $false
}

function Wait-ForPostTrekMenu {
    param(
        [int]$TimeoutSeconds,
        [int]$PollSeconds,
        [switch]$WhatIfMode
    )

    if ($WhatIfMode) {
        Write-Host "Dry run: skipping post-trek menu wait"
        return $true
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $stateJson = & $stateScriptPath -CaptureCurrent -CaptureLabel "post-trek-ready" -FamilyOnly
        $state = $stateJson | ConvertFrom-Json
        Write-Host ("Post-trek ready check: family={0}" -f $state.screenFamily)

        switch ([string]$state.screenFamily) {
            "bonus-report" {
                Write-Host "Advancing bonus report to reach post-trek menu"
                Invoke-BBHRelativeClick `
                    -XPercent ([double]$centerContinueTarget.xPercent) `
                    -YPercent ([double]$centerContinueTarget.yPercent) `
                    -Button Left `
                    -ProcessNamePattern $processNamePattern `
                    -WindowTitlePattern $windowTitlePattern
                Start-Sleep -Seconds 2
                continue
            }

            "post-trek-menu" {
                Write-Host "Post-trek menu is ready."
                return $true
            }
        }

        Start-Sleep -Seconds $PollSeconds
    } while ((Get-Date) -lt $deadline)

    Write-Warning "Timed out waiting to reach the post-trek menu."
    return $false
}

function Wait-ForReplaySiteSelection {
    param(
        [int]$TimeoutSeconds,
        [int]$PollSeconds,
        [switch]$WhatIfMode
    )

    if ($WhatIfMode) {
        Write-Host "Dry run: skipping replay transition wait"
        return $true
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $stateJson = & $stateScriptPath -CaptureCurrent -CaptureLabel "replay-transition" -FamilyOnly
        $state = $stateJson | ConvertFrom-Json
        Write-Host ("Replay transition: family={0}" -f $state.screenFamily)

        switch ([string]$state.screenFamily) {
            "tip-screen" {
                Write-Host "Skipping tip screen during replay transition"
                Move-BBHCursorRelative `
                    -XPercent ([double]$centerContinueTarget.xPercent) `
                    -YPercent ([double]$centerContinueTarget.yPercent) `
                    -SkipFocus `
                    -ProcessNamePattern $processNamePattern `
                    -WindowTitlePattern $windowTitlePattern | Out-Null
                Invoke-BBHMouseButtonHold `
                    -Button Left `
                    -HoldMilliseconds $tipSkipHoldMs `
                    -SkipFocus `
                    -ProcessNamePattern $processNamePattern `
                    -WindowTitlePattern $windowTitlePattern
                Start-Sleep -Seconds 2
                continue
            }

            "name-selection-screen" {
                Write-Host "Confirming existing player name during replay transition"
                & $nameScriptPath -ConfirmOnly
                Start-Sleep -Seconds 2
                continue
            }

            "classic-site-selection-screen" {
                Write-Host "Replay transition complete: site selection is back."
                return $true
            }

            "unknown" {
                Write-Host "Replay transition is in a short loading state; waiting"
                Start-Sleep -Seconds ([Math]::Max(1, $PollSeconds))
                continue
            }
        }

        Start-Sleep -Seconds $PollSeconds
    } while ((Get-Date) -lt $deadline)

    Write-Warning "Timed out waiting for replay to return to site selection."
    return $false
}

function Invoke-DirectSiteCapture {
    param(
        [ValidateRange(1, 5)]
        [int]$SiteNumber,
        [switch]$WhatIfMode
    )

    $targetSiteName = "site$SiteNumber"
    Write-Host ("Direct site capture: {0}" -f $targetSiteName)

    & $startCaptureScriptPath `
        -GameMode $GameMode `
        -Weapon $Weapon `
        -Adventure $Adventure `
        -Trek $Trek `
        -Site ("Site " + $SiteNumber) `
        -Notes $Notes `
        -ConfigPath $CaptureConfigPath `
        -DryRun:$WhatIfMode

    Write-Host ("Selecting site '{0}' without rerouting" -f $targetSiteName)
    & $siteSelectorScriptPath -SiteName $targetSiteName -DryRun:$WhatIfMode

    if ($restReticleTarget) {
        Write-Host "Moving reticle to the configured rest position for gameplay capture"
        Move-BBHCursorRelative `
            -XPercent ([double]$restReticleTarget.xPercent) `
            -YPercent ([double]$restReticleTarget.yPercent) `
            -SkipFocus `
            -DryRun:$WhatIfMode `
            -ProcessNamePattern $processNamePattern `
            -WindowTitlePattern $windowTitlePattern

        if (-not $WhatIfMode) {
            Start-Sleep -Milliseconds $restReticleSettleMilliseconds
        }
    }

    if ($WhatIfMode) {
        return [pscustomobject]@{
            completed = $false
            dryRun = $true
            site = $targetSiteName
            fixedDurationMode = $true
            directSiteMode = $true
        }
    }

    Start-Sleep -Seconds $MaxRecordingSeconds
    & $stopCaptureScriptPath -ConfigPath $CaptureConfigPath -DryRun:$WhatIfMode

    return [pscustomobject]@{
        completed = $true
        adventure = $Adventure
        trek = $Trek
        site = $targetSiteName
        fixedDurationMode = $true
        directSiteMode = $true
        maxRecordingSeconds = $MaxRecordingSeconds
    }
}

$resolvedRouterConfigPath = Resolve-JsonConfigPath `
    -RequestedPath $RouterConfigPath `
    -LocalFileName "menu-router.local.json" `
    -ExampleFileName "menu-router.example.json"
$routerConfig = Get-Content -LiteralPath $resolvedRouterConfigPath -Raw | ConvertFrom-Json
$processNamePattern = [string](Get-ConfigValue -Object $routerConfig -PropertyName "processNamePattern" -DefaultValue "^BBH$")
$windowTitlePattern = [string](Get-ConfigValue -Object $routerConfig -PropertyName "windowTitlePattern" -DefaultValue "BigBuckHunter_UltimateTrophy")
$targets = Get-ConfigValue -Object $routerConfig -PropertyName "targets" -DefaultValue ([pscustomobject]@{})
$centerContinueTarget = Get-ConfigValue -Object $targets -PropertyName "centerContinue"
$postTrekReplayTarget = Get-ConfigValue -Object $targets -PropertyName "postTrekReplay"
$postTrekNextTarget = Get-ConfigValue -Object $targets -PropertyName "postTrekNext"
$postTrekNewHuntTarget = Get-ConfigValue -Object $targets -PropertyName "postTrekNewHunt"
$resolvedCaptureConfigPath = Resolve-JsonConfigPath `
    -RequestedPath $CaptureConfigPath `
    -LocalFileName "obs-capture.local.json" `
    -ExampleFileName "obs-capture.example.json"
$captureConfig = Get-Content -LiteralPath $resolvedCaptureConfigPath -Raw | ConvertFrom-Json
$restReticleTarget = Get-ConfigValue -Object $captureConfig -PropertyName "restReticleTarget"
$restReticleSettleMilliseconds = [int](Get-ConfigValue -Object $captureConfig -PropertyName "restReticleSettleMilliseconds" -DefaultValue 250)
$timing = Get-ConfigValue -Object $routerConfig -PropertyName "timing" -DefaultValue ([pscustomobject]@{})
$tipSkipHoldMs = [int](Get-ConfigValue -Object $timing -PropertyName "tipSkipHoldMs" -DefaultValue 12000)

if (-not $centerContinueTarget -or -not $postTrekReplayTarget -or -not $postTrekNextTarget -or -not $postTrekNewHuntTarget) {
    throw "Menu-router config must define centerContinue, postTrekReplay, postTrekNext, and postTrekNewHunt targets."
}

$interSiteDelaySeconds = [Math]::Max(0, ($SiteCycleSeconds - $MaxRecordingSeconds))

Write-Host "Adventure: $Adventure"
Write-Host "Trek: $Trek"
Write-Host "Sites: $StartSite to $EndSite"
Write-Host "Repeat count: $RepeatCount"
Write-Host "Site cycle target: $SiteCycleSeconds seconds"
Write-Host "Per-site recording length: $MaxRecordingSeconds seconds"
Write-Host "Inter-site delay: $interSiteDelaySeconds seconds"
Write-Host "Dry run: $DryRun"

for ($repeatIndex = 1; $repeatIndex -le $RepeatCount; $repeatIndex++) {
    Write-Host ("Starting trek pass {0} of {1}" -f $repeatIndex, $RepeatCount)

    for ($site = $StartSite; $site -le $EndSite; $site++) {
        Write-Host ("Starting site {0} of {1}" -f $site, $EndSite)

        $useRoutedCapture = ($repeatIndex -eq 1 -and $site -eq $StartSite)
        if ($useRoutedCapture) {
            $siteResultJson = & $siteCaptureScriptPath `
                -Adventure $Adventure `
                -Trek $Trek `
                -Site $site `
                -PlayerName $PlayerName `
                -GameMode $GameMode `
                -Weapon $Weapon `
                -Notes $Notes `
                -RouteMaxSteps $RouteMaxSteps `
                -MaxRecordingSeconds $MaxRecordingSeconds `
                -RouterConfigPath $RouterConfigPath `
                -CaptureConfigPath $CaptureConfigPath `
                -DryRun:$DryRun

            if ($siteResultJson) {
                $results += ,($siteResultJson | ConvertFrom-Json)
            }
        }
        else {
            $directResult = Invoke-DirectSiteCapture -SiteNumber $site -WhatIfMode:$DryRun
            if ($directResult) {
                $results += ,$directResult
            }
        }

        if ($site -ge $EndSite) {
            continue
        }

        if ($interSiteDelaySeconds -gt 0) {
            Write-Host ("Waiting {0} seconds before starting site {1}" -f $interSiteDelaySeconds, ($site + 1))
            if (-not $DryRun) {
                Start-Sleep -Seconds $interSiteDelaySeconds
            }
        }
    }

    if ($repeatIndex -lt $RepeatCount) {
        Write-Host "Preparing to replay the trek"
        Invoke-PostTrekMenuAction `
            -Action Replay `
            -TimeoutSeconds $PostTrekTransitionTimeoutSeconds `
            -PollSeconds $InterSiteReadyPollSeconds `
            -WhatIfMode:$DryRun | Out-Null
        Wait-ForReplaySiteSelection `
            -TimeoutSeconds $PostTrekTransitionTimeoutSeconds `
            -PollSeconds $InterSiteReadyPollSeconds `
            -WhatIfMode:$DryRun | Out-Null
        $StartSite = 1
    }
    else {
        Write-Host "Advancing final bonus report and leaving the game on the post-trek menu"
        Wait-ForPostTrekMenu `
            -TimeoutSeconds $PostTrekTransitionTimeoutSeconds `
            -PollSeconds $InterSiteReadyPollSeconds `
            -WhatIfMode:$DryRun | Out-Null
    }
}

[pscustomobject]@{
    completed = $true
    adventure = $Adventure
    trek = $Trek
    startSite = $initialStartSite
    endSite = $EndSite
    repeatCount = $RepeatCount
    siteCycleSeconds = $SiteCycleSeconds
    maxRecordingSeconds = $MaxRecordingSeconds
    results = @($results)
} | ConvertTo-Json -Depth 6
