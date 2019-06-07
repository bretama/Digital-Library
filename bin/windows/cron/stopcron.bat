@echo off
if "%GSDLHOME%" == "" goto NotSet
set /p pd= <cron.pid
taskkill /PID %pd% /F 1>nul 
del cron.pid
goto End

:NotSet
echo GSDLHOME not set - run setup.bat first. 

:End
@echo on 