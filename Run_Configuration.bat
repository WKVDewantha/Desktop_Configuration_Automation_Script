@echo off
REM Desktop Configuration Automation Launcher
REM This batch file launches the PowerShell script with proper privileges

echo ========================================
echo Desktop Configuration Automation Script
echo    https://github.com/WKVDewantha
echo ========================================
echo.

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ERROR: This script must be run as Administrator!
    echo.
    echo Please right-click this file and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)

echo Running as Administrator... OK
echo.

REM Set PowerShell execution policy for this session
powershell.exe -NoProfile -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force"

REM Run the PowerShell script
echo Starting configuration...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Desktop_Configuration.ps1"

echo.
echo Configuration script completed.
echo Check C:\Logs for detailed logs.
echo.
pause
