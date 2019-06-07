@echo off
if "%GSDLHOME%" == "" goto NotSet

start "" /B "%GSDLHOME%\bin\windows\cron.exe" "%GSDLHOME%\collect\crontab"
goto End

:NotSet
echo GSDLHOME not set - run setup.bat first

:End
@echo on