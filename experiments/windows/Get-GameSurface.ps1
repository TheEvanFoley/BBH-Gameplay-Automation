param(
    [string]$NamePattern = "Buck|Hunter|Reloaded",
    [switch]$IncludeWindowTitleSearch,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class WindowInventory
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    public static List<Tuple<int, string, long>> GetVisibleWindows()
    {
        var windows = new List<Tuple<int, string, long>>();

        EnumWindows(delegate (IntPtr hWnd, IntPtr lParam)
        {
            if (!IsWindowVisible(hWnd))
            {
                return true;
            }

            var title = new StringBuilder(1024);
            GetWindowText(hWnd, title, title.Capacity);

            if (title.Length == 0)
            {
                return true;
            }

            uint processId;
            GetWindowThreadProcessId(hWnd, out processId);
            windows.Add(Tuple.Create((int)processId, title.ToString(), hWnd.ToInt64()));
            return true;
        }, IntPtr.Zero);

        return windows;
    }
}
"@

$pattern = $NamePattern
$windows = [WindowInventory]::GetVisibleWindows()
$processes = Get-Process | Select-Object Id, ProcessName, MainWindowTitle, Path

$matches = foreach ($process in $processes) {
    $windowMatches = @($windows | Where-Object { $_.Item1 -eq $process.Id })
    $hasVisibleWindow = $windowMatches.Count -gt 0
    $searchParts = @(
        $process.ProcessName
        $process.Path
    )

    if ($IncludeWindowTitleSearch) {
        $searchParts += $process.MainWindowTitle
        $searchParts += ($windowMatches | ForEach-Object { $_.Item2 })
    }

    $searchBlob = $searchParts -join " "

    if ($searchBlob -match $pattern) {
        [pscustomobject]@{
            ProcessId       = $process.Id
            ProcessName     = $process.ProcessName
            MainWindowTitle = $process.MainWindowTitle
            Path            = $process.Path
            HasVisibleWindow = $hasVisibleWindow
            VisibleWindows  = @($windowMatches | ForEach-Object {
                [pscustomobject]@{
                    Title    = $_.Item2
                    Handle   = ('0x{0:X}' -f $_.Item3)
                }
            })
        }
    }
}

if ($AsJson) {
    $matches | ConvertTo-Json -Depth 5
    return
}

if (-not $matches) {
    Write-Host "No matching processes or windows found."
    Write-Host "Pattern: $pattern"
    Write-Host "Tip: launch the game first, then rerun with -AsJson if you want structured output."
    Write-Host "Tip: add -IncludeWindowTitleSearch if the game title appears in the window but not the executable path."
    return
}

$matches |
    Sort-Object @{ Expression = "HasVisibleWindow"; Descending = $true }, ProcessName, ProcessId |
    Format-List ProcessId, ProcessName, MainWindowTitle, Path, HasVisibleWindow, VisibleWindows
