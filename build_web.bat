@echo off
chcp 65001 >nul
title Build Flutter Web Release

echo ====================================================
echo      DANG DONG GOI FLUTTER WEB (RELEASE PRODUCTION)
echo ====================================================
echo.

set FLUTTER_CMD=flutter
where flutter >nul 2>&1
if %errorlevel% neq 0 (
  if exist "D:\flutter\bin\flutter.bat" (
    set FLUTTER_CMD="D:\flutter\bin\flutter.bat"
  ) else (
    echo [LOI] Khong tim thay Flutter SDK!
    pause
    exit /b 1
  )
)

cd /d "%~dp0clinic-app"

echo Dang chay flutter clean va flutter pub get...
call %FLUTTER_CMD% pub get

echo Dang dong goi ban web release...
call %FLUTTER_CMD% build web --release

echo.
if %errorlevel% equ 0 (
  echo ====================================================
  echo [THANH CONG] Da build web thanh cong vao clinic-app\build\web!
  echo Ban co the chay file "2_chay_web_that.bat" de thuong thuc.
  echo ====================================================
) else (
  echo [THAT BAI] Co loi trong qua trinh build web.
)
echo.
pause
