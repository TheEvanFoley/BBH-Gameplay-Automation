[CmdletBinding()]
param(
    [string]$Adventure = "Elk",
    [ValidateSet("Trek 1", "Trek 2", "Trek 3")]
    [string]$Trek = "Trek 3",
    [ValidateRange(1, 5)]
    [int]$Site = 3,
    [string]$PlayerName = "CODEX",
    [int]$MaxSteps = 20,
    [string]$ConfigPath = ".\experiments\windows\menu-router.local.json",
    [switch]$StopAtSiteSelection,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "InputToolkit.ps1")

function Resolve-RouterConfig {
    param(
        [string]$RequestedPath
    )

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $candidatePaths = @(
        $RequestedPath,
        (Join-Path $repoRoot "experiments\windows\menu-router.local.json"),
        (Join-Path $repoRoot "experiments\windows\menu-router.example.json")
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

    throw "No menu-router config found. Create experiments\windows\menu-router.local.json from the example file."
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

function Get-CurrentState {
    $stateScriptPath = Join-Path $PSScriptRoot "Get-BBHState.ps1"
    $stateJson = & $stateScriptPath -CaptureCurrent -CaptureLabel "router-current" -FamilyOnly
    return ($stateJson | ConvertFrom-Json)
}

function Wait-AfterAction {
    param(
        [int]$Milliseconds
    )

    if ($DryRun) {
        return
    }

    Start-Sleep -Milliseconds $Milliseconds
}

function Get-LastKnownFamily {
    param(
        [System.Collections.Generic.List[object]]$History
    )

    for ($index = $History.Count - 1; $index -ge 0; $index--) {
        $family = [string]$History[$index].screenFamily
        if ($family -and $family -ne "unknown") {
            return $family
        }
    }

    return $null
}

function Invoke-GenericRelativeClick {
    param(
        $Target,
        [int]$PostWaitMs
    )

    Focus-BBHWindow -ProcessNamePattern $processNamePattern -WindowTitlePattern $windowTitlePattern | Out-Null
    Invoke-BBHRelativeClick `
        -XPercent ([double]$Target.xPercent) `
        -YPercent ([double]$Target.yPercent) `
        -Button Left `
        -SkipFocus `
        -DryRun:$DryRun `
        -ProcessNamePattern $processNamePattern `
        -WindowTitlePattern $windowTitlePattern
    Wait-AfterAction -Milliseconds $PostWaitMs
}

function Invoke-EnterAction {
    param(
        [int]$PostWaitMs
    )

    Focus-BBHWindow -ProcessNamePattern $processNamePattern -WindowTitlePattern $windowTitlePattern | Out-Null
    Send-BBHKeys `
        -Keys "{ENTER}" `
        -SkipFocus `
        -DryRun:$DryRun `
        -ProcessNamePattern $processNamePattern `
        -WindowTitlePattern $windowTitlePattern
    Wait-AfterAction -Milliseconds $PostWaitMs
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

$resolvedConfigPath = Resolve-RouterConfig -RequestedPath $ConfigPath
$config = Get-Content -LiteralPath $resolvedConfigPath -Raw | ConvertFrom-Json

$processNamePattern = Get-ConfigValue -Object $config -PropertyName "processNamePattern" -DefaultValue "^BBH$"
$windowTitlePattern = Get-ConfigValue -Object $config -PropertyName "windowTitlePattern" -DefaultValue "BigBuckHunter_UltimateTrophy"
$timing = Get-ConfigValue -Object $config -PropertyName "timing" -DefaultValue ([pscustomobject]@{})
$targets = Get-ConfigValue -Object $config -PropertyName "targets" -DefaultValue ([pscustomobject]@{})

$betweenStepsMs = [int](Get-ConfigValue -Object $timing -PropertyName "betweenStepsMs" -DefaultValue 500)
$afterEnterMs = [int](Get-ConfigValue -Object $timing -PropertyName "afterEnterMs" -DefaultValue 2000)
$afterCenterClickMs = [int](Get-ConfigValue -Object $timing -PropertyName "afterCenterClickMs" -DefaultValue 2000)
$tipSkipHoldMs = [int](Get-ConfigValue -Object $timing -PropertyName "tipSkipHoldMs" -DefaultValue 12000)
$unknownVideoWaitMs = [int](Get-ConfigValue -Object $timing -PropertyName "unknownVideoWaitMs" -DefaultValue 8000)

$genericLeftChoice = Get-ConfigValue -Object $targets -PropertyName "genericLeftChoice"
$genericRightChoice = Get-ConfigValue -Object $targets -PropertyName "genericRightChoice"
$centerContinue = Get-ConfigValue -Object $targets -PropertyName "centerContinue"
$mainMenuStartGame = Get-ConfigValue -Object $targets -PropertyName "mainMenuStartGame"
$postTrekNext = Get-ConfigValue -Object $targets -PropertyName "postTrekNext" -DefaultValue $centerContinue

if (-not $genericLeftChoice -or -not $genericRightChoice -or -not $centerContinue -or -not $mainMenuStartGame -or -not $postTrekNext) {
    throw "Router config must define mainMenuStartGame, genericLeftChoice, genericRightChoice, centerContinue, and postTrekNext targets."
}

$animalScriptPath = Join-Path $PSScriptRoot "Select-AnimalFromCarousel.ps1"
$fourSlotScriptPath = Join-Path $PSScriptRoot "Select-FourSlotChoice.ps1"
$siteScriptPath = Join-Path $PSScriptRoot "Select-SiteChoice.ps1"
$nameScriptPath = Join-Path $PSScriptRoot "Enter-PlayerName.ps1"
$trekConfigPath = Join-Path $PSScriptRoot "calibration\trek-selection.example.json"

$targetSiteName = "site$Site"
$targetTrekSlot = Convert-TrekToSlot -TrekName $Trek

Write-Host "Using menu-router config: $resolvedConfigPath"
Write-Host "Target adventure: $Adventure"
Write-Host "Target trek: $Trek"
Write-Host "Target site: $targetSiteName"
Write-Host "Player name: $PlayerName"
Write-Host "Dry run: $DryRun"

$history = New-Object System.Collections.Generic.List[object]

for ($step = 1; $step -le $MaxSteps; $step++) {
    $state = Get-CurrentState
    $history.Add($state)

    Write-Host ("Step {0}: family={1} adventure={2} trek={3}" -f $step, $state.screenFamily, $state.adventure, $state.trek)

    switch ([string]$state.screenFamily) {
        "landing-page" {
            Write-Host "Action: press Enter on landing page"
            Invoke-EnterAction -PostWaitMs $afterEnterMs
        }

        "main-menu" {
            Write-Host "Action: click Start Game on main menu"
            Invoke-GenericRelativeClick -Target $mainMenuStartGame -PostWaitMs $afterCenterClickMs
        }

        "game-mode-selection" {
            Write-Host "Action: choose Big Buck Hunter"
            Invoke-GenericRelativeClick -Target $genericLeftChoice -PostWaitMs $afterCenterClickMs
        }

        "big-buck-hunter-mode-selection" {
            Write-Host "Action: choose Classic mode"
            Invoke-GenericRelativeClick -Target $genericLeftChoice -PostWaitMs $afterCenterClickMs
        }

        "classic-player-count" {
            Write-Host "Action: choose 1 Player"
            Invoke-GenericRelativeClick -Target $genericLeftChoice -PostWaitMs $afterCenterClickMs
        }

        "classic-weapon-selection" {
            Write-Host "Action: choose Gun"
            Invoke-GenericRelativeClick -Target $genericLeftChoice -PostWaitMs $afterCenterClickMs
        }

        "classic-adventure-carousel" {
            Write-Host "Action: select adventure '$Adventure'"
            & $animalScriptPath -AnimalName $Adventure -DryRun:$DryRun
        }

        "classic-trek-selection" {
            Write-Host "Action: select trek '$Trek'"
            & $fourSlotScriptPath -State left -SlotName $targetTrekSlot -ConfigPath $trekConfigPath -DryRun:$DryRun
        }

        "tip-screen" {
            Write-Host "Action: hold left click from tip screen to skip intro/tutorial flow"
            Move-BBHCursorRelative `
                -XPercent ([double]$centerContinue.xPercent) `
                -YPercent ([double]$centerContinue.yPercent) `
                -DryRun:$DryRun `
                -ProcessNamePattern $processNamePattern `
                -WindowTitlePattern $windowTitlePattern | Out-Null
            Invoke-BBHMouseButtonHold `
                -Button Left `
                -HoldMilliseconds $tipSkipHoldMs `
                -SkipFocus `
                -DryRun:$DryRun `
                -ProcessNamePattern $processNamePattern `
                -WindowTitlePattern $windowTitlePattern
        }

        "bonus-report" {
            Write-Host "Action: advance bonus report"
            Invoke-GenericRelativeClick -Target $centerContinue -PostWaitMs $afterCenterClickMs
        }

        "post-trek-menu" {
            Write-Host "Action: choose Next on post-trek menu"
            Invoke-GenericRelativeClick -Target $postTrekNext -PostWaitMs $afterCenterClickMs
        }

        "name-selection-screen" {
            if ($PlayerName) {
                Write-Host "Action: confirm existing player name"
                & $nameScriptPath -ConfirmOnly -DryRun:$DryRun
            }
            else {
                throw "Reached name-selection-screen but no -PlayerName was provided."
            }
        }

        "classic-site-selection-screen" {
            if ($state.adventure -and $state.adventure -ne $Adventure) {
                Write-Warning "Site selection screen adventure '$($state.adventure)' does not match target '$Adventure'. Continuing with target site selection."
            }

            $historySummary = @(
                $history | ForEach-Object {
                    [pscustomobject]@{
                        screenFamily = [string]$_.screenFamily
                        adventure = [string]$_.adventure
                        trek = [string]$_.trek
                        locationText = [string]$_.locationText
                    }
                }
            )

            if ($StopAtSiteSelection) {
                [pscustomobject]@{
                    completed = $true
                    finalAction = "site-selection-reached"
                    targetAdventure = $Adventure
                    targetTrek = $Trek
                    targetSite = $targetSiteName
                    history = $historySummary
                } | ConvertTo-Json -Depth 6
                return
            }

            Write-Host "Action: select site '$targetSiteName'"
            & $siteScriptPath -SiteName $targetSiteName -DryRun:$DryRun

            [pscustomobject]@{
                completed = $true
                finalAction = "site-selected"
                targetAdventure = $Adventure
                targetTrek = $Trek
                targetSite = $targetSiteName
                history = $historySummary
            } | ConvertTo-Json -Depth 6
            return
        }

        "unknown" {
            $lastKnownFamily = Get-LastKnownFamily -History $history
            if ($lastKnownFamily -in @("tip-screen", "name-selection-screen")) {
                Write-Host "Action: wait for unrecognized intro/tutorial video to finish"
                Wait-AfterAction -Milliseconds $unknownVideoWaitMs
                break
            }

            throw "Menu router hit an unknown screen family. Stop and inspect the live frame before continuing."
        }

        default {
            throw "Menu router does not yet handle screen family '$($state.screenFamily)'."
        }
    }

    Wait-AfterAction -Milliseconds $betweenStepsMs
}

throw "Menu router reached MaxSteps ($MaxSteps) without selecting the target site."
