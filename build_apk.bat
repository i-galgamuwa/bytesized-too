@echo off
title Build APK
echo Building APK...
cd /d "%~dp0app"
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
call "D:\gpssalestraker3\flutter\bin\flutter.bat" build apk --release
if %errorlevel% neq 0 (
    echo Build failed!
    pause
    exit /b %errorlevel%
)
echo Copying APK...
copy "build\app\outputs\flutter-apk\app-release.apk" "..\app-release.apk"
echo Done!
