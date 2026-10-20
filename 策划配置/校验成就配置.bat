@echo off
chcp 65001 >nul
where py >nul 2>nul
if %errorlevel% equ 0 (
  py -3 "%~dp0..\tools\achievements\import_achievements.py" --check
) else (
  python "%~dp0..\tools\achievements\import_achievements.py" --check
)
set "import_exit=%errorlevel%"
if not "%ACHIEVEMENT_NO_PAUSE%"=="1" pause
exit /b %import_exit%
