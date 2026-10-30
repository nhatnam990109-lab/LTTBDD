@echo off
chcp 65001 >nul
title Khoi Chay Toan Bo He Thong ClinicCare

echo ====================================================
echo      KHOI DONG CLINICCARE: BACKEND + WEB THAT
echo ====================================================
echo.
echo Dang khoi dong Backend API...
start "ClinicCare Backend API" cmd /k "call \"%~dp01_chay_backend.bat\""

timeout /t 2 /nobreak >nul

echo Dang khoi dong Web Server va mo trinh duyet...
start "ClinicCare Web Frontend" cmd /k "call \"%~dp02_chay_web_that.bat\""

echo.
echo ====================================================
echo He thong dang duoc khoi chay tren 2 cua so cmd:
echo   - Backend API: http://127.0.0.1:8080
echo   - Web Frontend: http://localhost:3000
echo.
echo Giu nguyen 2 cua so do trong suot qua trinh su dung.
echo ====================================================
