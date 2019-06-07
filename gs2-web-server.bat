@echo off
SETLOCAL enabledelayedexpansion

if "%serverlang%" == "" set serverlang=en
set java_min_version=1.5.0_00
set PROGNAME=gs2-server
if "%PROGABBR%" == "" set PROGABBR=GSI
pushd "%CD%"
CD /D "%~dp0"

echo Greenstone 2 Server
echo Copyright (C) 2009, New Zealand Digital Library Project, University Of Waikato
echo This software comes with ABSOLUTELY NO WARRANTY; for details see LICENSE.txt
echo This is free software, and you are welcome to redistribute it

::  -------- Run the Greenstone 2 Server --------

::  ---- Determine GSDLHOME ----
set gsdl2path=

:: Some users may set the above line manually
if "%gsdl2path%" == "" (
   set GSDLHOME=!CD!
   set gsdl2path=!CD!
)

:checkUserPermissions
	echo.
	echo Checking if the Greenstone log directory is writable ...
	if not exist "%GSDLHOME%\etc\logs-gsi" goto missingLogDir
	(echo This is a temporary file. It is safe to delete it. > "!GSDLHOME!\etc\logs-gsi\testing.tmp" ) 2>nul
	if exist "%GSDLHOME%\etc\logs-gsi\testing.tmp" goto deleteTempFile  
	if "%1" == "Elevated" goto printWarning
	echo ... FAILED
	echo The Greenstone server cannot write to the log directory (!GSDLHOME!\etc\logs-gsi)
	echo Requesting elevated status to become admin user to continue.
	"%GSDLHOME%\bin\windows\gstart.exe" %0 Elevated %1 %2 %3 %4 %5 %6 %7 %8 %9
    goto exit
	
:missingLogDir
	echo ... FAILED
	echo The Greenstone log directory does not exist (!GSDLHOME!\etc\logs-gsi). Please reinstall Greenstone.
	pause
	goto exit
	
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

echo GS2 Home: %GSDLHOME%

:: Setup Greenstone2, unless it has already been done
:: If either GSDLHOME or GSDLOS is not set, need to run setup.bat first
:: OR operations in an IF stmt: http://fixunix.com/ms-dos/21057-how-implement-if-condition-batch-file.html
for %%i in ("!GSDLOS!" "!GSDLHOME!") do if %%i == "" set OR=True
if "%OR%" == "True" (
   pushd "!gsdl2path!"
   call setup.bat
rem   echo **** GSDLOS: %GSDLOS% and GSDLHOME: %GSDLHOME%
   popd
)


:: First test that there is actually something that can be run...
:: Exit if the apache-httpd folder doesn't exist for some reason
:: (The errors reported when the apache webserver does not exist 
:: in the correct location are not at all helpful).

:: "You cannot use the if command to test directly for a directory, but
:: the null (NUL) device does exist in every directory. As a result, you
:: can test for the null device to determine whether a directory exists."
rem echo "%GSDLHOME%\apache-httpd\nul"
if not exist "%GSDLHOME%\apache-httpd\*" (
    echo.
    echo UNABLE TO CONTINUE: There is no apache-httpd directory.
    echo It does not look like the local apache webserver has been installed.
    echo Exiting...
    echo.
    goto exit
)
:: exit 1

set PATH=%GSDLHOME%\apache-httpd\windows\lib;%PATH%

:: If there's no llssite.cfg file, copy from the template
if exist "%GSDLHOME%\llssite.cfg" goto cfgfile
if exist "%GSDLHOME%\llssite.cfg.in" (
   copy "!GSDLHOME!\llssite.cfg.in" "!GSDLHOME!\llssite.cfg"
) else (
   echo Warning: could not find llssite.cfg.in to create llssite.cfg from.
)

:cfgfile
::  ---- Determine GSDLHOME ----
:: JRE_HOME or JAVA_HOME must be set correctly to run this program
bin\windows\search4j -m %java_min_version% > nul
echo.
:: In Java code, '...getResourceAsStream("build.properties")'
:: needs up to be in the right directory when run
if %ERRORLEVEL% equ 0 pushd %GSDL2PATH%

:: http://ss64.com/nt/call.html (and leave in trailing slash)
call :isinpath "%GSDLHOME%\lib\java"

:: After the call, we come back here
goto chkjava

:isinpath
:: http://ss64.com/nt/syntax-replace.html and http://ss64.com/nt/syntax-args.html
:: (Does not work: section "Finding items within the PATH environment variable")
:: Instead, we expand the filepath of parameter 1 to its full path and
:: try to subtract it from the classpath. 
::call set test_cpath=%%CLASSPATH:%~f1=%%
call set test_cpath=%%CLASSPATH:%~1=%%

:: If the classpath was not empty to begin with and if there IS a difference in
:: the classpath before and after, then the filepath was already on the classpath
if not "%CLASSPATH%" == "" if not "%CLASSPATH%" == "%test_cpath%" (
   echo   - CLASSPATH already correct:
   echo !CLASSPATH!
   goto :eof
)

:: If there was NO difference in the classpath before and after,
:: then the filepath needs to be added to the classpath
set CLASSPATH=%GSDLHOME%\lib\java;%CLASSPATH%

:: http://ss64.com/nt/for_r.html and (for call) http://ss64.com/nt/for.html
:: http://ss64.com/nt/syntax-args.html
FOR /R "%GSDLHOME%\lib\java" %%G IN (*.jar) DO call :putinpath "%%G"
echo   - Adjusted CLASSPATH
echo.
::echo CLASSPATH:& echo %CLASSPATH%
goto :eof


:putinpath
set jarfile=%1
::strip quotes around jarfile path, since we can't update classpath with quotes
set jarfile=%jarfile:"=%
echo jarfile: %jarfile%
set CLASSPATH=%CLASSPATH%;%jarfile%
goto :eof

:: ---- Check Java ----
:chkjava
:: call the script with source, so that we have the variables JAVA_EXECUTABLE and GS_JAVA_HOME it sets
set exit_status=0
:: Need to find Java. If found, JAVA_EXECUTABLE will be set
:: call findjava.bat %serverlang% %PROGNAME%
if "%GSDL3SRCHOME%" == "" (set _VERSION=2) else (set _VERSION=3)
call "%GSDLHOME%\findjava.bat"
if "%JAVA_EXECUTABLE%" == "" echo **** No Java executable found& goto exit
set PATH=%GS_JAVA_HOME%\bin;%PATH%


:: ---- Run the Greenstone Server Interface ----
:: Some informative messages to direct the users to the logs
if "%serverlang%" == "en" (
   echo ***************************************************************
   echo Starting the Greenstone Server Interface ^(GSI^)...
   echo.
   echo Server log messages go to:
   echo    "!GSDLHOME!\etc\logs-gsi\server.log"
   echo.
   echo Using Apache web server located at:
   echo    "!GSDLHOME!\apache-httpd\!GSDLOS!\bin\httpd"
   echo The Apache error log is at:
   echo    "!GSDLHOME!\apache-httpd\!GSDLOS!\logs\error_log"
   echo The Apache configuration file template is at:
   echo    "!GSDLHOME!\apache-httpd\!GSDLOS!\conf\httpd.conf.in"
   echo This is used to generate:
   echo    "!GSDLHOME!\apache-httpd\!GSDLOS!\conf\httpd.conf"
   echo    each time Enter Library is pressed or otherwise activated.
   echo ***************************************************************
   echo.
)
echo.

:: GLI launches gs2-server.bat with:
:: cmd /c start "window" "c:\path to\gs2-web-server.bat" --config=c:\path to\llssite.cfg --quit=portnum --mode=gli
:: where the --options are generally optional, but always used for GLI.
:: The configfile param could contain spaces, in which case its space-separated parts spread over 
:: multiple parameters. In the past, we used to handle this problem here. 
:: At present we pass all the arguments as-is to the Server.jar program and let it handle the parameters.
:: E.g. gs2-web-server.bat --config=C:\pinky was\here at greenstone2\llssite.cfg --mode=gli --quitport=50100
:: or gs2-web-server.bat --quitport=50100 --config=C:\pinky was\here at greenstone2\llssite.cfg --mode=gli
:: Note the (lack of) use of quotes!


:runit 
:: whenever the server is started up, make sure gsdlhome is correct (in case the gs install was moved).
:: In parallel with the linux equivalent script, redirect stdout into the void
:: (If redirecting both stderr and stdout into the void, would need to use >nul 2>&1. See
:: http://stackoverflow.com/questions/1420965/redirect-stdout-and-stderr-to-a-single-file-in-dos)
call gsicontrol.bat reset-gsdlhome >nul

::echo port: %port%& echo conf: %conf%& echo.& echo.
:: Do not remove the quotes around %* !!! It's what helps Server2.jar deal with spaces in configfile path
if not defined GSDLARCH "%JAVA_EXECUTABLE%" org.greenstone.server.Server2 "%GSDLHOME%" "%GSDLOS%" "%serverlang%" "%*"
if defined GSDLARCH "%JAVA_EXECUTABLE%" org.greenstone.server.Server2 "%GSDLHOME%" "%GSDLOS%%GSDLARCH%" "%serverlang%" "%*"

:: All params are stored in %* now. This batch script can be called from the commandline or from GLI
:: If the --mode(=gli) flag was passed in as parameter, then this script was launched through GLI
:: and would have opened a DOS console. Need to then exit from this script to close the console.
set allparams=%*
:: And if there were absolutely no params to gs2-web-server.bat, it's not called from GLI either
if "%allparams%" == "" goto exit
set glimode=%allparams:--mode=%
:: if one of the parameters was --mode(=gli), we close the console
if /i "%allparams%" == "%glimode%" ( 
	goto exit 
) else ( 
	goto quitcmd 
)

:: Exit the batch script (close the console)
:quitcmd
popd
ENDLOCAL
exit 0

:: Just end the script without closing the console
:exit
popd
ENDLOCAL
