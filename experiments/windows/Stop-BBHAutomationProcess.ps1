[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$WorkflowProcessId,
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
    $stopScriptPath = Join-Path $PSScriptRoot "Stop-ObsSiteCapture.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $stopScriptPath -ConfigPath $resolvedCaptureConfigPath
}

Start-Process -FilePath "taskkill.exe" -ArgumentList @("/PID", [string]$WorkflowProcessId, "/T", "/F") -Wait -NoNewWindow | Out-Null
