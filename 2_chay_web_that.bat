@echo off
chcp 65001 >nul
title ClinicCare Web Server (SPA Production Mode)

echo ====================================================
echo      DANG KHOI CHAY CLINICCARE WEB (NHU WEB THAT)
echo ====================================================
echo.

where node >nul 2>&1
if %errorlevel% neq 0 (
  echo [LOI] Khong tim thay Node.js tren may!
  echo Vui long cai dat Node.js de chay web server.
  pause
  exit /b 1
)

cd /d "%~dp0"

REM Mo trinh duyet sau 1 giay
start "" cmd /c "timeout /t 1 /nobreak >nul & start http://localhost:3000"

node serve_web.js
pause
