@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Medieval Launcher.ps1"
if errorlevel 1 (
  echo.
  echo Launcher stopped with an error. Read the message above.
  pause
)
endlocal
