[CmdletBinding()]
param(
    [string]$Adventure = "Elk",
    [ValidateSet("Trek 1", "Trek 2", "Trek 3")]
    [string]$StartTrek = "Trek 1",
    [string]$PlayerName = "CODEX",
    [string]$GameMode = "classic",
    [string]$Weapon = "gun",
    [string]$Notes = "",
    [ValidateRange(1, 5)]
    [int]$StartSite = 1,
    [int]$RepeatCount = 1,
    [int]$SiteCycleSeconds = 45,
    [int]$MaxRecordingSeconds = 35,
    [int]$InterTrekTransitionTimeoutSeconds = 75,
    [int]$InterTrekPollSeconds = 2,
    [int]$RouteMaxSteps = 24,
    [string]$RouterConfigPath = ".\experiments\windows\menu-router.local.json",
    [string]$CaptureConfigPath = ".\experiments\windows\obs-capture.local.json",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "InputToolkit.ps1")

$trekCaptureScriptPath = Join-Path $PSScriptRoot "Invoke-BBHTrekCaptureRun.ps1"
$stateScriptPath = Join-Path $PSScriptRoot "Get-BBHState.ps1"
$results = New-Object System.Collections.Generic.List[object]

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

function Get-TrekSequence {
    param(
        [string]$StartingTrek
    )

    $allTreks = @("Trek 1", "Trek 2", "Trek 3")
    $startIndex = [Array]::IndexOf($allTreks, $StartingTrek)
    if ($startIndex -lt 0) {
        throw "Unsupported trek '$StartingTrek'."
    }

    $sequence = New-Object System.Collections.Generic.List[string]
    for ($offset = 0; $offset -lt $allTreks.Count; $offset++) {
        $index = ($startIndex + $offset) % $allTreks.Count
        $sequence.Add($allTreks[$index])
    }

    return @($sequence)
}

function Invoke-PostTrekAction {
    param(
        [ValidateSet("Next", "NewHunt")]
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
        $stateJson = & $stateScriptPath -CaptureCurrent -CaptureLabel "adventure-transition" -FamilyOnly
        $state = $stateJson | ConvertFrom-Json
        Write-Host ("Adventure transition: family={0}" -f $state.screenFamily)

        switch ([string]$state.screenFamily) {
            "bonus-report" {
                Write-Host "Advancing bonus report before adventure transition"
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
                $target = if ($Action -eq "Next") { $postTrekNextTarget } else { $postTrekNewHuntTarget }
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

    Write-Warning ("Timed out waiting to perform adventure action '{0}'." -f $Action)
    return $false
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
$postTrekNextTarget = Get-ConfigValue -Object $targets -PropertyName "postTrekNext"
$postTrekNewHuntTarget = Get-ConfigValue -Object $targets -PropertyName "postTrekNewHunt"

if (-not $centerContinueTarget -or -not $postTrekNextTarget -or -not $postTrekNewHuntTarget) {
    throw "Menu-router config must define centerContinue, postTrekNext, and postTrekNewHunt targets."
}

$trekSequence = Get-TrekSequence -StartingTrek $StartTrek

Write-Host "Adventure: $Adventure"
Write-Host "Starting trek: $StartTrek"
Write-Host "Trek order: $($trekSequence -join ', ')"
Write-Host "Start site: $StartSite"
Write-Host "Repeat count: $RepeatCount"
Write-Host "Dry run: $DryRun"

for ($repeatIndex = 1; $repeatIndex -le $RepeatCount; $repeatIndex++) {
    Write-Host ("Starting adventure pass {0} of {1}" -f $repeatIndex, $RepeatCount)

    for ($trekIndex = 0; $trekIndex -lt $trekSequence.Count; $trekIndex++) {
        $trekName = $trekSequence[$trekIndex]
        $trekStartSite = if ($trekIndex -eq 0) { $StartSite } else { 1 }

        Write-Host ("Recording {0} starting at Site {1}" -f $trekName, $trekStartSite)

        $trekResultJson = & $trekCaptureScriptPath `
            -Adventure $Adventure `
            -Trek $trekName `
            -PlayerName $PlayerName `
            -GameMode $GameMode `
            -Weapon $Weapon `
            -Notes $Notes `
            -StartSite $trekStartSite `
            -EndSite 5 `
            -RepeatCount 1 `
            -SiteCycleSeconds $SiteCycleSeconds `
            -MaxRecordingSeconds $MaxRecordingSeconds `
            -RouteMaxSteps $RouteMaxSteps `
            -RouterConfigPath $RouterConfigPath `
            -CaptureConfigPath $CaptureConfigPath `
            -DryRun:$DryRun

        if ($trekResultJson) {
            $results.Add(($trekResultJson | ConvertFrom-Json))
        }

        $isLastTrekInAdventure = ($trekIndex -eq ($trekSequence.Count - 1))
        if (-not $isLastTrekInAdventure) {
            Invoke-PostTrekAction `
                -Action Next `
                -TimeoutSeconds $InterTrekTransitionTimeoutSeconds `
                -PollSeconds $InterTrekPollSeconds `
                -WhatIfMode:$DryRun | Out-Null
        }
    }

    if ($repeatIndex -lt $RepeatCount) {
        Invoke-PostTrekAction `
            -Action NewHunt `
            -TimeoutSeconds $InterTrekTransitionTimeoutSeconds `
            -PollSeconds $InterTrekPollSeconds `
            -WhatIfMode:$DryRun | Out-Null
    }
}

[pscustomobject]@{
    completed = $true
    adventure = $Adventure
    startTrek = $StartTrek
    startSite = $StartSite
    repeatCount = $RepeatCount
    siteCycleSeconds = $SiteCycleSeconds
    maxRecordingSeconds = $MaxRecordingSeconds
    results = @($results)
} | ConvertTo-Json -Depth 6
