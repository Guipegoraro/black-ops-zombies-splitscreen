@echo off
rem Black Ops 1 Zombies splitscreen on one monitor: player 1 keyboard and mouse, players 2-4 one controller each.
rem   Splitscreen.bat            2 players (top / bottom)
rem   Splitscreen.bat 3          3 players (2x2 grid)
rem   Splitscreen.bat 3 zombie_pentagon
rem More options (layout, all on controllers): tools\splitscreen.ps1
set "PLAYERS=%~1"
if "%PLAYERS%"=="" set "PLAYERS=2"
set "MAP=%~2"
if "%MAP%"=="" set "MAP=zombie_theater"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\splitscreen.ps1" -Players %PLAYERS% -Map %MAP%
if errorlevel 1 pause
