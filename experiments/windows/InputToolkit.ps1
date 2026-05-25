Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

if (-not ([System.Management.Automation.PSTypeName]'NativeInput').Type) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class NativeInput
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT
    {
        public int X;
        public int Y;
    }

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
}
"@
}

$script:MouseLeftDown = 0x0002
$script:MouseLeftUp = 0x0004
$script:MouseRightDown = 0x0008
$script:MouseRightUp = 0x0010
$script:MouseWheel = 0x0800
$script:ShowWindowRestore = 9

function ConvertTo-UnsignedWheelDelta {
    param(
        [int]$WheelDelta
    )

    return [BitConverter]::ToUInt32([BitConverter]::GetBytes($WheelDelta), 0)
}

function Get-BBHWindow {
    [CmdletBinding()]
    param(
        [string]$ProcessNamePattern = "^BBH$",
        [string]$WindowTitlePattern = "BigBuckHunter_UltimateTrophy"
    )

    $candidates = Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.MainWindowHandle -ne 0 -and (
                $_.ProcessName -match $ProcessNamePattern -or
                $_.MainWindowTitle -match $WindowTitlePattern
            )
        } |
        Sort-Object Id

    if (-not $candidates) {
        return $null
    }

    $process = $candidates | Select-Object -First 1
    [pscustomobject]@{
        ProcessId        = $process.Id
        ProcessName      = $process.ProcessName
        WindowTitle      = $process.MainWindowTitle
        MainWindowHandle = $process.MainWindowHandle
        Path             = $process.Path
    }
}

function Wait-BBHWindow {
    [CmdletBinding()]
    param(
        [int]$TimeoutSeconds = 30,
        [int]$PollMilliseconds = 500,
        [string]$ProcessNamePattern = "^BBH$",
        [string]$WindowTitlePattern = "BigBuckHunter_UltimateTrophy"
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $window = Get-BBHWindow -ProcessNamePattern $ProcessNamePattern -WindowTitlePattern $WindowTitlePattern
        if ($window) {
            return $window
        }

        Start-Sleep -Milliseconds $PollMilliseconds
    } while ((Get-Date) -lt $deadline)

    throw "Timed out waiting for a BBH game window."
}

function Focus-BBHWindow {
    [CmdletBinding()]
    param(
        [string]$ProcessNamePattern = "^BBH$",
        [string]$WindowTitlePattern = "BigBuckHunter_UltimateTrophy"
    )

    $window = Wait-BBHWindow -ProcessNamePattern $ProcessNamePattern -WindowTitlePattern $WindowTitlePattern
    $handle = [IntPtr]$window.MainWindowHandle

    [NativeInput]::ShowWindowAsync($handle, $script:ShowWindowRestore) | Out-Null
    Start-Sleep -Milliseconds 200
    $activated = [NativeInput]::SetForegroundWindow($handle)
    Start-Sleep -Milliseconds 200

    if (-not $activated) {
        [Microsoft.VisualBasic.Interaction]::AppActivate($window.ProcessId) | Out-Null
        Start-Sleep -Milliseconds 250
        $activated = [NativeInput]::SetForegroundWindow($handle)
        Start-Sleep -Milliseconds 200
    }

    if (-not $activated) {
        Write-Warning "Foreground activation was not confirmed by SetForegroundWindow. Continuing after AppActivate fallback."
    }

    return $window
}

function Get-BBHClientGeometry {
    [CmdletBinding()]
    param(
        [string]$ProcessNamePattern = "^BBH$",
        [string]$WindowTitlePattern = "BigBuckHunter_UltimateTrophy"
    )

    $window = Wait-BBHWindow -ProcessNamePattern $ProcessNamePattern -WindowTitlePattern $WindowTitlePattern
    $handle = [IntPtr]$window.MainWindowHandle

    $rect = New-Object 'NativeInput+RECT'
    if (-not [NativeInput]::GetClientRect($handle, [ref]$rect)) {
        throw "Unable to read BBH client rect."
    }

    $origin = New-Object 'NativeInput+POINT'
    $origin.X = 0
    $origin.Y = 0
    if (-not [NativeInput]::ClientToScreen($handle, [ref]$origin)) {
        throw "Unable to convert BBH client coordinates to screen coordinates."
    }

    [pscustomobject]@{
        ProcessId     = $window.ProcessId
        WindowTitle   = $window.WindowTitle
        ScreenLeft    = $origin.X
        ScreenTop     = $origin.Y
        ClientWidth   = $rect.Right - $rect.Left
        ClientHeight  = $rect.Bottom - $rect.Top
    }
}

function Invoke-BBHRelativeClick {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [double]$XPercent,
        [Parameter(Mandatory = $true)]
        [double]$YPercent,
        [int]$ClickCount = 1,
        [int]$DelayMilliseconds = 150,
    [switch]$SkipFocus,
    [switch]$DryRun,
    [ValidateSet("Left", "Right")]
    [string]$Button = "Left",
    [string]$ProcessNamePattern = "^BBH$",
    [string]$WindowTitlePattern = "BigBuckHunter_UltimateTrophy"
    )

    if ($XPercent -lt 0 -or $XPercent -gt 1 -or $YPercent -lt 0 -or $YPercent -gt 1) {
        throw "Relative click coordinates must be between 0 and 1."
    }

    if (-not $SkipFocus) {
        Focus-BBHWindow -ProcessNamePattern $ProcessNamePattern -WindowTitlePattern $WindowTitlePattern | Out-Null
    }

    $target = Get-BBHRelativePoint `
        -XPercent $XPercent `
        -YPercent $YPercent `
        -ProcessNamePattern $ProcessNamePattern `
        -WindowTitlePattern $WindowTitlePattern

    Write-Host "Click target: ($($target.X), $($target.Y)) from relative ($XPercent, $YPercent)"

    if ($DryRun) {
        return
    }

    [NativeInput]::SetCursorPos($target.X, $target.Y) | Out-Null
    Start-Sleep -Milliseconds 75

    if ($Button -eq "Right") {
        $buttonDown = $script:MouseRightDown
        $buttonUp = $script:MouseRightUp
    }
    else {
        $buttonDown = $script:MouseLeftDown
        $buttonUp = $script:MouseLeftUp
    }

    for ($i = 0; $i -lt $ClickCount; $i++) {
        [NativeInput]::mouse_event($buttonDown, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 40
        [NativeInput]::mouse_event($buttonUp, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds $DelayMilliseconds
    }
}

function Send-BBHKeys {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Keys,
        [switch]$SkipFocus,
        [switch]$DryRun,
        [string]$ProcessNamePattern = "^BBH$",
        [string]$WindowTitlePattern = "BigBuckHunter_UltimateTrophy"
    )

    if (-not $SkipFocus) {
        Focus-BBHWindow -ProcessNamePattern $ProcessNamePattern -WindowTitlePattern $WindowTitlePattern | Out-Null
    }

    Write-Host "Sending keys: $Keys"

    if ($DryRun) {
        return
    }

    [System.Windows.Forms.SendKeys]::SendWait($Keys)
}

function Get-BBHRelativePoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [double]$XPercent,
        [Parameter(Mandatory = $true)]
        [double]$YPercent,
        [string]$ProcessNamePattern = "^BBH$",
        [string]$WindowTitlePattern = "BigBuckHunter_UltimateTrophy"
    )

    if ($XPercent -lt 0 -or $XPercent -gt 1 -or $YPercent -lt 0 -or $YPercent -gt 1) {
        throw "Relative coordinates must be between 0 and 1."
    }

    $geometry = Get-BBHClientGeometry -ProcessNamePattern $ProcessNamePattern -WindowTitlePattern $WindowTitlePattern
    $targetX = [int]([Math]::Round($geometry.ScreenLeft + ($geometry.ClientWidth * $XPercent)))
    $targetY = [int]([Math]::Round($geometry.ScreenTop + ($geometry.ClientHeight * $YPercent)))

    [pscustomobject]@{
        X = $targetX
        Y = $targetY
        ClientWidth = $geometry.ClientWidth
        ClientHeight = $geometry.ClientHeight
    }
}

function Move-BBHCursorRelative {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [double]$XPercent,
        [Parameter(Mandatory = $true)]
        [double]$YPercent,
        [switch]$SkipFocus,
        [switch]$DryRun,
        [string]$ProcessNamePattern = "^BBH$",
        [string]$WindowTitlePattern = "BigBuckHunter_UltimateTrophy"
    )

    if (-not $SkipFocus) {
        Focus-BBHWindow -ProcessNamePattern $ProcessNamePattern -WindowTitlePattern $WindowTitlePattern | Out-Null
    }

    $target = Get-BBHRelativePoint `
        -XPercent $XPercent `
        -YPercent $YPercent `
        -ProcessNamePattern $ProcessNamePattern `
        -WindowTitlePattern $WindowTitlePattern

    Write-Host "Move target: ($($target.X), $($target.Y)) from relative ($XPercent, $YPercent)"

    if ($DryRun) {
        return
    }

    [NativeInput]::SetCursorPos($target.X, $target.Y) | Out-Null
}

function Send-BBHMouseWheel {
    [CmdletBinding()]
    param(
        [int]$WheelDelta = 120,
        [int]$RepeatCount = 1,
        [switch]$SkipFocus,
        [switch]$DryRun,
        [string]$ProcessNamePattern = "^BBH$",
        [string]$WindowTitlePattern = "BigBuckHunter_UltimateTrophy"
    )

    if (-not $SkipFocus) {
        Focus-BBHWindow -ProcessNamePattern $ProcessNamePattern -WindowTitlePattern $WindowTitlePattern | Out-Null
    }

    Write-Host "Sending mouse wheel: delta=$WheelDelta repeat=$RepeatCount"

    if ($DryRun) {
        return
    }

    for ($i = 0; $i -lt $RepeatCount; $i++) {
        $nativeDelta = ConvertTo-UnsignedWheelDelta -WheelDelta $WheelDelta
        [NativeInput]::mouse_event($script:MouseWheel, 0, 0, $nativeDelta, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 120
    }
}

function Move-BBHCursorRelativeAndHold {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [double]$XPercent,
        [Parameter(Mandatory = $true)]
        [double]$YPercent,
        [Parameter(Mandatory = $true)]
        [int]$HoldMilliseconds,
        [switch]$SkipFocus,
        [switch]$DryRun,
        [string]$ProcessNamePattern = "^BBH$",
        [string]$WindowTitlePattern = "BigBuckHunter_UltimateTrophy"
    )

    Move-BBHCursorRelative `
        -XPercent $XPercent `
        -YPercent $YPercent `
        -SkipFocus:$SkipFocus `
        -DryRun:$DryRun `
        -ProcessNamePattern $ProcessNamePattern `
        -WindowTitlePattern $WindowTitlePattern

    Write-Host "Holding cursor for $HoldMilliseconds ms"

    if ($DryRun) {
        return
    }

    Start-Sleep -Milliseconds $HoldMilliseconds
}

function Invoke-BBHMouseButtonHold {
    [CmdletBinding()]
    param(
        [ValidateSet("Left", "Right")]
        [string]$Button = "Left",
        [int]$HoldMilliseconds = 3000,
        [switch]$SkipFocus,
        [switch]$DryRun,
        [string]$ProcessNamePattern = "^BBH$",
        [string]$WindowTitlePattern = "BigBuckHunter_UltimateTrophy"
    )

    if (-not $SkipFocus) {
        Focus-BBHWindow -ProcessNamePattern $ProcessNamePattern -WindowTitlePattern $WindowTitlePattern | Out-Null
    }

    Write-Host "Holding $Button mouse button for $HoldMilliseconds ms"

    if ($DryRun) {
        return
    }

    if ($Button -eq "Right") {
        $buttonDown = $script:MouseRightDown
        $buttonUp = $script:MouseRightUp
    }
    else {
        $buttonDown = $script:MouseLeftDown
        $buttonUp = $script:MouseLeftUp
    }

    [NativeInput]::mouse_event($buttonDown, 0, 0, 0, [UIntPtr]::Zero)
    try {
        Start-Sleep -Milliseconds $HoldMilliseconds
    }
    finally {
        [NativeInput]::mouse_event($buttonUp, 0, 0, 0, [UIntPtr]::Zero)
    }
}
