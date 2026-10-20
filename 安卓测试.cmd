@echo off
python -X utf8 "%~dp0tools\android\dev.py" %*
if errorlevel 1 pause
