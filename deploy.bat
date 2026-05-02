@echo off
title Deploy to Railway
set PATH=C:\Program Files\nodejs;C:\Users\User\AppData\Roaming\npm;%PATH%
cd /d "%~dp0"

echo.
echo  ============================================
echo   Stability Test Manager - Deploy to Railway
echo  ============================================
echo.
echo  Before running this script you need a Railway API token.
echo  1. Go to: https://railway.app  (sign up free)
echo  2. Click your profile - Account Settings - Tokens
echo  3. Click "Create Token", copy it
echo  4. Paste it below when prompted
echo.

set /p RAILWAY_TOKEN=Paste your Railway token here and press Enter:
if "%RAILWAY_TOKEN%"=="" ( echo No token entered. Exiting. & pause & exit /b 1 )

set RAILWAY_TOKEN=%RAILWAY_TOKEN%

echo.
echo  Deploying...
railway init --name "stability-test-manager"
railway up --detach
echo.
echo  Adding persistent volume for your data...
railway volume add --mount-path /data
echo.
echo  Opening your live app...
railway open
echo.
echo  Done! Your app is now live on the internet.
pause
