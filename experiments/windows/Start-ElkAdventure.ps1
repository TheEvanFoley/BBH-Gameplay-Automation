[CmdletBinding()]
param(
    [string]$AnimalName = "Elk",
    [int]$PostLaunchStabilitySeconds = 5,
    [int]$PostLaunchExtraSettleSeconds = 10,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
. (Join-Path $PSScriptRoot "InputToolkit.ps1")
$launchScriptPath = Join-Path $PSScriptRoot "Launch-Game.ps1"
$sequenceScriptPath = Join-Path $PSScriptRoot "Run-ControlSequence.ps1"
$carouselScriptPath = Join-Path $PSScriptRoot "Select-AnimalFromCarousel.ps1"

$pressAnyButtonConfig = Join-Path $repoRoot "experiments\windows\sequences\press-any-button.json"
$startGameConfig = Join-Path $repoRoot "experiments\windows\sequences\start-game-from-main-menu.json"
$selectBigBuckHunterConfig = Join-Path $repoRoot "experiments\windows\sequences\select-big-buck-hunter-tile.json"
$selectLeftTileConfig = Join-Path $repoRoot "experiments\windows\sequences\select-classic-tile.json"

function Wait-ForStableGameWindow {
    param(
        [int]$StableSeconds,
        [int]$TimeoutSeconds = 60
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $stableStart = $null
    $lastProcessId = $null

    do {
        $window = Get-BBHWindow
        if (-not $window) {
            $stableStart = $null
            $lastProcessId = $null
            Start-Sleep -Milliseconds 500
            continue
        }

        if ($window.ProcessId -ne $lastProcessId) {
            $stableStart = Get-Date
            $lastProcessId = $window.ProcessId
        }

        $stableDuration = ((Get-Date) - $stableStart).TotalSeconds
        if ($stableDuration -ge $StableSeconds) {
            Write-Host "Game window stabilized on process $($window.ProcessId) for $StableSeconds seconds."
            return
        }

        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    throw "Timed out waiting for a stable BBH game window."
}

Write-Host "=== Launch game ==="
if ($DryRun) {
    & $launchScriptPath -DryRun
}
else {
    & $launchScriptPath
    Write-Host "=== Stabilize launched game ==="
    Wait-ForStableGameWindow -StableSeconds $PostLaunchStabilitySeconds
    if ($PostLaunchExtraSettleSeconds -gt 0) {
        Write-Host "Waiting an extra $PostLaunchExtraSettleSeconds seconds for menus and loading to settle."
        Start-Sleep -Seconds $PostLaunchExtraSettleSeconds
    }
}

Write-Host "=== Advance past title screen ==="
if ($DryRun) {
    & $sequenceScriptPath -ConfigPath $pressAnyButtonConfig -DryRun
}
else {
    & $sequenceScriptPath -ConfigPath $pressAnyButtonConfig
}

Write-Host "=== Open Start Game ==="
if ($DryRun) {
    & $sequenceScriptPath -ConfigPath $startGameConfig -DryRun
}
else {
    & $sequenceScriptPath -ConfigPath $startGameConfig
}

Write-Host "=== Choose Big Buck Hunter ==="
if ($DryRun) {
    & $sequenceScriptPath -ConfigPath $selectBigBuckHunterConfig -DryRun
}
else {
    & $sequenceScriptPath -ConfigPath $selectBigBuckHunterConfig
}

Write-Host "=== Choose Classic ==="
if ($DryRun) {
    & $sequenceScriptPath -ConfigPath $selectLeftTileConfig -DryRun
}
else {
    & $sequenceScriptPath -ConfigPath $selectLeftTileConfig
}

Write-Host "=== Choose 1 Player ==="
if ($DryRun) {
    & $sequenceScriptPath -ConfigPath $selectLeftTileConfig -DryRun
}
else {
    & $sequenceScriptPath -ConfigPath $selectLeftTileConfig
}

Write-Host "=== Choose Gun ==="
if ($DryRun) {
    & $sequenceScriptPath -ConfigPath $selectLeftTileConfig -DryRun
}
else {
    & $sequenceScriptPath -ConfigPath $selectLeftTileConfig
}

Write-Host "=== Choose $AnimalName ==="
if ($DryRun) {
    & $carouselScriptPath -AnimalName $AnimalName -DryRun
}
else {
    & $carouselScriptPath -AnimalName $AnimalName
}
