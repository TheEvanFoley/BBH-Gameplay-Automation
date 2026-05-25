[CmdletBinding()]
param(
    [string]$GameMode = "classic",
    [string]$Weapon = "gun",
    [string]$Adventure = "Elk",
    [ValidateSet("Trek 1", "Trek 2", "Trek 3")]
    [string]$Trek = "Trek 3",
    [string]$Site = "Manual",
    [string]$Notes = "",
    [int]$MaxRecordingSeconds = 35,
    [string]$CaptureConfigPath = ".\experiments\windows\obs-capture.local.json",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$startCaptureScriptPath = Join-Path $PSScriptRoot "Start-ObsSiteCapture.ps1"
$stopCaptureScriptPath = Join-Path $PSScriptRoot "Stop-ObsSiteCapture.ps1"

Write-Host "Starting manual timed capture"
Write-Host "Game mode: $GameMode"
Write-Host "Weapon: $Weapon"
Write-Host "Adventure: $Adventure"
Write-Host "Trek: $Trek"
Write-Host "Site label: $Site"
Write-Host "Recording length target: $MaxRecordingSeconds seconds"
Write-Host "Dry run: $DryRun"

& $startCaptureScriptPath `
    -GameMode $GameMode `
    -Weapon $Weapon `
    -Adventure $Adventure `
    -Trek $Trek `
    -Site $Site `
    -Notes $Notes `
    -ConfigPath $CaptureConfigPath `
    -DryRun:$DryRun

if ($DryRun) {
    [pscustomobject]@{
        completed = $false
        dryRun = $true
        fixedDurationMode = $true
        manualSetupMode = $true
        maxRecordingSeconds = $MaxRecordingSeconds
        site = $Site
        nextPhase = "manual-fixed-duration-recording"
    } | ConvertTo-Json -Depth 4
    return
}

if (-not $DryRun) {
    Start-Sleep -Seconds $MaxRecordingSeconds
}

& $stopCaptureScriptPath -ConfigPath $CaptureConfigPath -DryRun:$DryRun

[pscustomobject]@{
    completed = $true
    fixedDurationMode = $true
    manualSetupMode = $true
    maxRecordingSeconds = $MaxRecordingSeconds
    site = $Site
} | ConvertTo-Json -Depth 4
