@echo off
setlocal enabledelayedexpansion

pushd "%CD%"
CD /D "%~dp0"

set GSDLHOME=%CD%

:checkUserPermissions
	echo Checking if the Greenstone log directory is writable ...
	if not exist "%GSDLHOME%\etc\logs-gsi" goto missingLogDir
	(echo This is a temporary file. It is safe to delete it. > "!GSDLHOME!\etc\logs-gsi\testing.tmp" ) 2>nul
	if exist "%GSDLHOME%\etc\logs-gsi\testing.tmp" goto deleteTempFile 
	if "%1" == "Elevated" goto printWarning
	echo ... FAILED
	echo The Greenstone server cannot write to the log directory (!GSDLHOME!\etc\logs-gsi)
	echo Requesting elevated status to become admin user to continue.
	"%GSDLHOME%\bin\windows\gstart.exe" %0 Elevated %1 %2 %3 %4 %5 %6 %7 %8 %9
	goto done
	
:missingLogDir
	echo ... FAILED
	echo The Greenstone log directory does not exist (!GSDLHOME!\etc\logs-gsi). Please either create this directory or reinstall Greenstone.
	pause
	goto done
	
:printWarning
	echo ... FAILED
	echo The Greenstone server cannot write to the log directory (!GSDLHOME!\etc\logs-gsi). 
	echo Attempting to continue without permissions.
	goto shiftElevated

:deleteTempFile
	echo ... OK
	del "%GSDLHOME%\etc\logs-gsi\testing.tmp"

:shiftElevated
	:: Shift "Elevated" (one of our own internal command words) out of the way if present
	:: so the command-line is as it was when the user initiated the command
	if "%1" == "Elevated" shift

:checkserver
    if exist "%GSDLHOME%\server.exe" goto localserver
	goto webserver

:localserver
	start /MIN cmd /C "%GSDLHOME%\server.exe"
	goto done
	
:webserver
	call "%GSDLHOME%\gs2-web-server.bat"
	goto done
	
:done
popd
endlocal
