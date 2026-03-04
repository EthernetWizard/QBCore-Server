@echo off
title StabCity AI - QBCore Server
echo ============================================
echo   StabCity AI Society - QBCore Edition
echo ============================================
echo.

:: Start the AI Bridge in a separate window
echo [1/2] Starting AI Bridge (localhost:5000)...
start "StabCity Bridge" cmd /k "cd /d X:\QBCore\AgentBrain\Bridge\StabCityBridge && dotnet run"
timeout /t 3 /nobreak >nul

:: Start the FiveM server
echo [2/2] Starting FiveM Server (port 30120)...
echo.
cd /d X:\QBCore\Server
FXServer.exe +exec server.cfg

pause
