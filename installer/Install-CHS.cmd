@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patch.ps1" -Action Install
exit /b %errorlevel%
