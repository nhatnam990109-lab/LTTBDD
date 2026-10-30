@echo off
chcp 65001 >nul
title ClinicCare Backend API Server

echo ====================================================
echo        DANG KHOI CHAY CLINICCARE BACKEND API
echo ====================================================
echo.

REM Tim kiem Dart
set DART_CMD=dart
where dart >nul 2>&1
if %errorlevel% neq 0 (
  if exist "D:\flutter\bin\dart.bat" (
    set DART_CMD="D:\flutter\bin\dart.bat"
  ) else if exist "D:\flutter\bin\cache\dart-sdk\bin\dart.exe" (
    set DART_CMD="D:\flutter\bin\cache\dart-sdk\bin\dart.exe"
  ) else (
    echo [LOI] Khong tim thay Dart SDK tren may!
    echo Vui long kiem tra lai duong dan Flutter hoac them vao bien PATH.
    pause
    exit /b 1
  )
)

cd /d "%~dp0clinic-api"

echo [1/2] Dang kiem tra thu vien (pub get)...
call %DART_CMD% pub get >nul 2>&1

echo [2/2] Dang chay API Server tai http://127.0.0.1:8080 ...
echo (Luu y: MySQL phai dang chay va mat khau phai dung trong clinic-api\config.json)
echo.
call %DART_CMD% run bin/server.dart

if %errorlevel% neq 0 (
  echo.
  echo [LỖI] Khong the khoi dong API Server!
  echo Kiem tra:
  echo   1. MySQL da duoc bat chua? (MySQL80 trong Services hoac XAMPP)
  echo   2. Mat khau root trong clinic-api\config.json da dung chua?
  echo.
  pause
)
