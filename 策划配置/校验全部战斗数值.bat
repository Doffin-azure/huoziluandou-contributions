@echo off
chcp 65001 >nul
where py >nul 2>nul
if %errorlevel% equ 0 (
  py -3 "%~dp0..\tools\balance\import_battle_excel.py" --check
) else (
  python "%~dp0..\tools\balance\import_battle_excel.py" --check
)
set "import_exit=%errorlevel%"
pause
exit /b %import_exit%
