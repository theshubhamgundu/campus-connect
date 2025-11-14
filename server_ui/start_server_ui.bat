@echo off
echo Starting CampusNet Server with Web UI...
echo.
echo Server will be available at:
echo - Web UI: http://localhost:3000
echo - WebSocket: ws://localhost:3000/ws
echo.
echo Press Ctrl+C to stop the server
echo.

REM Check if Node.js is installed
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

REM Install dependencies if node_modules doesn't exist
if not exist "node_modules" (
    echo Installing dependencies...
    npm install
    if %errorlevel% neq 0 (
        echo ERROR: Failed to install dependencies
        pause
        exit /b 1
    )
)

REM Start the server
node server.js

pause
