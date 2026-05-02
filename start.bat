@echo off
title Stability Test Manager
set NODE="C:\Program Files\nodejs\node.exe"
set NPM="C:\Program Files\nodejs\npm.cmd"

if not exist %NODE% (
  echo Node.js not found at C:\Program Files\nodejs\
  echo Please install from https://nodejs.org
  pause & exit /b 1
)

cd /d "%~dp0"

if not exist "node_modules" (
  echo Installing backend packages...
  %NPM% install
)
if not exist "client\node_modules" (
  echo Installing frontend packages...
  %NPM% install --prefix client
)
if not exist "client\dist\index.html" (
  echo Building frontend...
  %NPM% run build --prefix client
)

set NODE_ENV=production
echo.
echo  Stability Test Manager is starting...
echo  Open your browser at:  http://localhost:3001
echo  Press Ctrl+C to stop.
echo.
%NODE% server.js
pause
