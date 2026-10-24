@echo off
title Start App and Backend
echo Checking if Backend (Port 8080) is already running...

netstat -ano | findstr LISTENING | findstr :8080 >nul
if %errorlevel% equ 0 (
    echo Backend is already running! Skipping backend startup.
) else (
    echo Starting Backend...
    start "Spring Boot Backend" cmd /k "cd /d %~dp0backend && mvnw.cmd spring-boot:run"
    echo Waiting 10 seconds for Backend to initialize...
    timeout /t 10
)

echo Starting Flutter App...
start "Flutter App" cmd /k "cd /d %~dp0app && flutter run -d windows"
