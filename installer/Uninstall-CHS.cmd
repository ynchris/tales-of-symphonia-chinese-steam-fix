@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patch.ps1" -Action Uninstall
exit /b %errorlevel%
