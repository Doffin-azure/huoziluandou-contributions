@echo off
chcp 65001 >nul
where py >nul 2>nul
if %errorlevel% equ 0 (
  py -3 "%~dp0..\tools\balance\import_excel.py" 
) else (
  python "%~dp0..\tools\balance\import_excel.py" 
)
set import_exit=%errorlevel%
pause
exit /b %import_exit%
