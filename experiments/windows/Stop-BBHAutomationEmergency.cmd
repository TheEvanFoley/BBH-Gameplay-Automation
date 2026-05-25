@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop-BBHAutomationEmergency.ps1"
endlocal
