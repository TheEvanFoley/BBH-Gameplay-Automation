[CmdletBinding()]
param(
    [string]$CaptureConfigPath = ".\experiments\windows\obs-capture.local.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-ConfigPath {
    param(
        [string]$RequestedPath
    )

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $candidatePaths = @(
        $RequestedPath,
        (Join-Path $repoRoot "experiments\windows\obs-capture.local.json"),
        (Join-Path $repoRoot "experiments\windows\obs-capture.example.json")
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

    throw "Unable to resolve OBS capture config path."
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

$resolvedCaptureConfigPath = Resolve-ConfigPath -RequestedPath $CaptureConfigPath
$captureConfig = Get-Content -LiteralPath $resolvedCaptureConfigPath -Raw | ConvertFrom-Json
$captureRoot = [string](Get-ConfigValue -Object $captureConfig -PropertyName "captureRoot" -DefaultValue "captures")
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
if (-not [System.IO.Path]::IsPathRooted($captureRoot)) {
    $captureRoot = Join-Path $repoRoot $captureRoot
}

$statePath = Join-Path $captureRoot ".current-run.json"
if (Test-Path -LiteralPath $statePath) {
    Write-Host "Active capture state found. Stopping OBS capture..."
    $stopScriptPath = Join-Path $PSScriptRoot "Stop-ObsSiteCapture.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $stopScriptPath -ConfigPath $resolvedCaptureConfigPath
}
else {
    Write-Host "No active capture state file found."
}

$targetScriptNames = @(
    "Invoke-BBHWorkflow.ps1",
    "Invoke-BBHTrekCaptureRun.ps1",
    "Invoke-BBHAdventureCaptureRun.ps1",
    "Invoke-BBHSiteCaptureRun.ps1",
    "Invoke-BBHMenuRouter.ps1",
    "Invoke-BBHManualTimedCapture.ps1"
)

$automationProcesses = Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -match '^powershell(\.exe)?$|^pwsh(\.exe)?$' -and
        $_.CommandLine -and
        $_.CommandLine.Contains("BBH-Gameplay-Automation") -and
        ($targetScriptNames | Where-Object { $_ -and $_.CommandLine.Contains($_) })
    }

foreach ($process in $automationProcesses) {
    try {
        Write-Host ("Stopping automation PID {0}" -f $process.ProcessId)
        Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}

Write-Host "Emergency stop completed."
