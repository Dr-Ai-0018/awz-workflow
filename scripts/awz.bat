@echo off
setlocal
chcp 65001 >nul

where pwsh.exe >nul 2>nul
if %errorlevel% equ 0 (
    pwsh.exe -NoLogo -NoProfile -File "%~dp0awz.ps1" %*
) else (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0awz.ps1" %*
)

exit /b %errorlevel%
