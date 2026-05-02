@echo off
title Stability Test Manager (Dev Mode)

echo.
echo  ============================================
echo   Stability Test Manager - Development Mode
echo  ============================================
echo.

:: Try common Node.js locations
set NODE_PATHS=C:\Program Files\nodejs;C:\Program Files (x86)\nodejs;%APPDATA%\nvm\current;%LOCALAPPDATA%\Programs\nodejs
for %%p in (%NODE_PATHS%) do (
  if exist "%%p\node.exe" (
    set PATH=%%p;%PATH%
    goto :found
  )
)
echo  [!] Node.js not found. Install from https://nodejs.org
pause
exit /b 1

:found
node --version

if not exist "node_modules" ( npm install )
if not exist "client\node_modules" ( cd client && npm install && cd .. )

echo.
echo  Backend API  -> http://localhost:3001
echo  Frontend App -> http://localhost:5173
echo.
echo  Press Ctrl+C in this window to stop.
echo.

:: Start backend in background, frontend in foreground
start "Stability Backend" cmd /c "node server.js"
cd client && npm run dev
