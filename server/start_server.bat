@echo off
REM Request admin privileges for hotspot access
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo ⚠️  This script requires Administrator privileges to enable the hotspot.
    echo Requesting admin privileges...
    echo.
    powershell -Command "Start-Process cmd -ArgumentList '/c cd /d \"%cd%\" ^& \"%0\"' -Verb RunAs"
    exit /b
)

echo.
echo ========================================
echo   CampusNet Server Starting...
echo ========================================
echo.
echo 🚀 Server will:
echo   - Enable Mobile Hotspot (CampusNet)
echo   - Listen on ws://0.0.0.0:8083/ws
echo   - Broadcast on UDP port 8082
echo.
echo Press Ctrl+C to stop the server
echo ========================================
echo.

cd /d "%~dp0"
dart run bin/server.dart
pause
