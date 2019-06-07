@echo off

setlocal enabledelayedexpansion

::set testdone=0
set startdir=%CD%
cd /d "%~dp0"
::we're now in the "%GSDLHOME%" folder
call setup.bat 

::set _sed="%GSDLHOME%\bin\windows\sed.exe"
:: NOTE: no quotes allowed around the following, since it's used inside 
:: a FOR statement executing a command already embedded in quotes
set _sed=bin\windows\sed.exe

set target=%1
set configfile=%2
:: remove any quotes around configfile, if we were given parameter configfile
:: To test for the existence of a cmdline parameter: http://ss64.com/nt/if.html
if not [%2] == [] set configfile=%configfile:"=%

:: Construct the signal using the unique GS2 installation
:: directory (after replacing spaces, colons and backslashes)
set signal=%GSDLHOME: =_%
for /F "delims=*" %%T in ('"echo !signal!| !_sed! s@[\\:]@_@g"') do set signal=%%T
set GS2_APACHE_HTTPD_SIGNAL=GS2_APACHE_HTTPD_%signal%
set signal=
rem echo Signal is: %GS2_APACHE_HTTPD_SIGNAL%

:: Need to get greenstone installation directory
:: set cwd=%CD%

set MONITOR_SUCCESS=MAKE SUCCESSFUL
set MONITOR_FAILED=MAKE FAILED
set MONITOR_FINISHED=MAKE DONE

:: check that we have >=1 and <=2 arguments
:chkargs
if "%target%" == "" goto usage
if not "%3" == "" goto usage
	goto begincmd


:usage
echo.
echo    Usage: %0 command
echo           where command is any of the following: 
echo    web-start
echo    web-stop
echo    web-restart
::echo    web-status
::echo    web-graceful
echo    configure-admin
echo    configure-web    [config-filename]
echo    configure-apache [config-filename]
echo    configure-cgi
echo    reset-gsdlhome [config-filename]
echo    set-port
echo    test-gsdlhome
echo    web-stop-tested
echo.
goto exit


:begincmd
:: web-stop-tested command assumes GSDLHOME/greenstone environment is already set
if "%target%" == "web-stop-tested" goto stoptest

:: For all other commands, the greenstone environment needs to be set first before they can be run
:testgsdl
if NOT "%GSDLHOME%" == "" if NOT "%GSDLOS%" == "" goto commands
echo.
echo Environment variable GSDLHOME (or GSDLOS) not set.
echo   This needs to be set to run the gsicontrol command %target%.
echo   Have you run setup.bat?
echo.
goto exit


::MAIN MENU
:commands
echo. 
echo Using:
echo   GSDLHOME = %GSDLHOME%
echo   GSDLOS = %GSDLOS%
echo.

:: If %PROCESSOR_ARCHITECTURE% is x86, default the architecture to 32 bits, else 64.
:: (Can't test for x64, since the 64 bit Win 7 here returns "AMD64" instead of "x64".)
:: Then, if the svn version already uses just %GSDLOS% not %GSDLOS%%GSDLARCH%, 
:: set GSDLARCH to the empty string. Same if %PROCESSOR_ARCHITECTURE% is empty.
if "%PROCESSOR_ARCHITECTURE%" == "x86" (set GSDLARCH=32) else (set GSDLARCH=64)
if "%PROCESSOR_ARCHITECTURE%" == "" set GSDLARCH=
if exist "bin\windows" set GSDLARCH=
set cgibin=cgi-bin\%GSDLOS%%GSDLARCH%
::set cgibin=cgi-bin ::set cgibin=cgi-bin\windows

if "%target%" == "web-start" goto start
if "%target%" == "web-stop" goto stop
if "%target%" == "web-restart" goto restart
if "%target%" == "configure-admin" goto cfgadmin
if "%target%" == "configure-web" goto cfgweb
if "%target%" == "configure-apache" goto cfgapach
if "%target%" == "configure-cgi" goto cfgcgi
if "%target%" == "reset-gsdlhome" goto resethome
:: already tested gsdlhome (and web-stop-tested) above, don't want to keep looping on it
if "%target%" == "test-gsdlhome" goto exit
rem if "%target%" == "web-stop-tested" goto exit
rem if "%target%" == "web-status" goto status
rem if "%target%" == "web-graceful" goto graceful
if "%target%" == "set-port" goto setport
:: unknown command
echo Command unrecognised: %target%
goto usage


:start
:: START starts the app in a new console named by the string following immediately thereafter
:: then we start up apache-httpd and pass the signal that the stop command will respond to
START "%GSDLHOME%\apachectl" "%GSDLHOME%\bin\windows\starthttpd.exe" %GS2_APACHE_HTTPD_SIGNAL% "%GSDLHOME%\apache-httpd\windows\bin\httpd.exe"
:: if the return value is >= 0, it's succeeded:
if ERRORLEVEL 0 (echo %MONITOR_SUCCESS%) else (echo %MONITOR_FAILED%)
echo %MONITOR_FINISHED%
goto exit

:stop
:stoptest
if exist "%GSDLHOME%\apache-httpd\%GSDLOS%\conf\httpd.conf" "%GSDLHOME%\bin\windows\stophttpd.exe" %GS2_APACHE_HTTPD_SIGNAL% SILENT
if "%target%" == "web-stop-tested" goto exit
:: if the return value is >= 0, it's succeeded:
if ERRORLEVEL 0 (echo %MONITOR_SUCCESS%) else (echo %MONITOR_FAILED%)
echo %MONITOR_FINISHED%
goto exit


:restart
:: Need to stop server, wait and start it again.
:: We're using Ping to implement batch file Wait
if exist "%GSDLHOME%\apache-httpd\%GSDLOS%\conf\httpd.conf" "%GSDLHOME%\bin\windows\stophttpd.exe" %GS2_APACHE_HTTPD_SIGNAL%

:: Wait 5 seconds and then start. See http://ss64.com/nt/sleep.html (and http://malektips.com/dos0017.html)
:: if loopback IP address (127.0.0.1) does not exist, we ask them to manually start it up again
ping -n 1 -w 1000 127.0.0.1 |find "TTL=">nul || goto failmsg
echo Waiting for re-start....
ping -n 5 -w 1000 127.0.0.1> nul
goto start

:failmsg
echo Unable to wait for restart. Manually run %0 web-start
goto exit


::status
::graceful
::echo Command %target% is not operational on this operating system
::goto exit


::configure-admin
:cfgadmin
echo.
echo Configuring admin user password:
for /F %%T in ('getpw') do set encrypted_password=%%T

:: Have to create an intermediate file in the following, because echoing
:: lines straight into a pipe adds spaces before the end of each line.
:: When piping, need to double-escape the angle brackets with three hat signs,
:: but when redirecting to a file, need to escape only once (one hat sign). 
if ERRORLEVEL 0 (
	(
	echo [admin]
	echo ^<enabled^>true
	echo ^<groups^>administrator,colbuilder,all-collections-editor
	echo ^<password^>!encrypted_password!
	echo ^<username^>admin
	) > "!GSDLHOME!\etc\users.txt"
	type "!GSDLHOME!\etc\users.txt" | txt2db -append "!GSDLHOME!\etc\users.gdb"
	del "!GSDLHOME!\etc\users.txt"	
) else (
	echo Did not set password 
)
echo.
goto exit


:: reset-gsdlhome forces configure-cgi by renaming any 
:: existing gsdlsite.cfg and by deleting Mac .app files
:: However, we only relocate if there is a gsdlsite.cfg file with its gsdlhome 
:: property the same as the current (greenstone installation) directory
:resethome
echo.
if not exist "%GSDLHOME%\%cgibin%\gsdlsite.cfg" goto relocate

set gshome=
FOR /F "tokens=*" %%G IN ('findstr /R ^gsdlhome "!GSDLHOME!\!cgibin!\gsdlsite.cfg"') do call :concat %%G

:: The following doesn't work if there are spaces in the gsdlhome filepath
::FOR /F "tokens=2" %%G IN ('findstr /R ^gsdlhome "!GSDLHOME!\!cgibin!\gsdlsite.cfg"') do set gshome=%%G
:: before string comparison, remove any quotes around gsdlhome value defined in config file
:: if not [%gshome%] == [] set gshome=%gshome:"=%

if "%gshome%" == "%GSDLHOME%" set gshome=& goto exit
  
move "%GSDLHOME%\%cgibin%\gsdlsite.cfg" "%GSDLHOME%\%cgibin%\gsdlsite.cfg.bak"
echo **** Regenerating %GSDLHOME%\%cgibin%\gsdlsite.cfg
echo **** Previous version of file now %GSDLHOME%\%cgibin%\gsdlsite.cfg.bak

:relocate
:: The path to the included perl at the top of gliserver.pl and other cgi-bin perl files needs to use the new gsdlhome
:: On windows, the path in gliserver.pl and the others uses backslashes
for /F "delims=*" %%T in ('"echo !gshome!| !_sed! s@\\@\\\\@g"') do set safeoldhome=%%T
for /F "delims=*" %%T in ('"echo !gsdlhome!| !_sed! s@\\@\\\\@g"') do set safenewhome=%%T
if exist "%GSDLHOME%\bin\%GSDLOS%\perl" (
  copy "!cgibin!\gliserver.pl" "!cgibin!\gliserver.pl.bak"
  type "!cgibin!\gliserver.pl.bak" | !_sed! "s@!safeoldhome!@!safenewhome!@g" > "!cgibin!\gliserver.pl"
  del "!cgibin!\gliserver.pl.bak"

  copy "!cgibin!\metadata-server.pl" "!cgibin!\metadata-server.pl.bak"
  type "!cgibin!\metadata-server.pl.bak" | !_sed! "s@!safeoldhome!@!safenewhome!@g" > "!cgibin!\metadata-server.pl"
  del "!cgibin!\metadata-server.pl.bak"

  copy "!cgibin!\checksum.pl" "!cgibin!\checksum.pl.bak"
  type "!cgibin!\checksum.pl.bak" | !_sed! "s@!safeoldhome!@!safenewhome!@g" > "!cgibin!\checksum.pl"
  del "!cgibin!\checksum.pl.bak"
)
set safenewhome=
set safeoldhome=
set gshome=

for /F "delims=*" %%T in ('"echo !GSDLHOME!| !_sed! s@\\@\/@g"') do set safepath=%%T

:: Also re-initialise the log4j.properties and force regeneration of 
:: Mac .app files since cfgweb will generate these if they don't exist
type "lib\java\log4j.properties.in" | %_sed% "s\@gsdl2home@\%safepath%\g" > "lib\java\log4j.properties" 
:: No use for Mac .app files on Windows, so they're not there in Windows binaries including caveat
::for %%G in (gs2-server.app gli.app client-gli.app gems.app) do if exist "%%G\Contents\document.wflow" del "%%G\Contents\document.wflow"
goto cfgweb

:: Subroutine used to glue parts of a filepath that contains spaces back together again
:: http://www.computing.net/answers/programming/batch-for-loop-tokens/16727.html
:concat
:: first remove any quotes around this part of the filepath
set suffix=%~1
if not "%suffix%" == "gsdlhome" if not "%suffix%" == "collecthome" set gshome=%gshome%%suffix%
shift
if not "%~1"=="" goto concat
goto :eof


::configure-web
::configure-cgi
:cfgweb
:: first set up Mac's .app files if that's not already been done (if this is the first time we're running GS3)
:: No use for Mac .app files on Windows, so they're not there in Windows binaries including caveat
:: for %%G in (gs2-server.app gli.app client-gli.app gems.app) do if not exist "%%G\Contents\document.wflow" type "%%G\Contents\document.wflow.in" | %_sed% "s@\*\*GSDLHOME\*\*@%safepath%@g" > "%%G\Contents\document.wflow"

:cfgcgi
:: Need to preserve the user-assigned collecthome property, if any
if exist "%GSDLHOME%\%cgibin%\gsdlsite.cfg" goto cgimsg
echo Configuring %cgibin%\gsdlsite.cfg
echo # **** This file is automatically generated, do not edit **** > "%cgibin%\gsdlsite.cfg"
echo # For local customization of Greenstone, edit gsdlsite.cfg.in >> "%cgibin%\gsdlsite.cfg"
echo. >> "%cgibin%\gsdlsite.cfg"

for /F "delims=*" %%T in ('"echo !GSDLHOME!| !_sed! s@\\@\\\\@g"') do set safepath=%%T
%_sed% "s@\*\*GSDLHOME\*\*@\"%safepath%\"@g" "%cgibin%\gsdlsite.cfg.in" >> "%cgibin%\gsdlsite.cfg"
set safepath=

goto cgifin

:cgimsg
echo WARNING: Nothing done for configure-cgi.
echo    If you wish to regenerate the file
echo    %GSDLHOME%\%cgibin%\gsdlsite.cfg
echo    from scratch, delete the existing file first.
echo.

:cgifin
if "%target%" == "configure-cgi" goto exit
if "%target%" == "configure-web" goto cfgapach

::configure-apache
:cfgapach
if not "%configfile%" == "" if exist "%configfile%" (goto cfgport) else (echo Config file !configfile! does not exist. Using default llssite.cfg)

if exist "%GSDLHOME%\llssite.cfg" (
  set configfile=!GSDLHOME!\llssite.cfg
  goto cfgport 
)
if not exist "%GSDLHOME%\llssite.cfg.in" (
  echo Unable to proceed as neither !GSDLHOME!\llssite.cfg nor !GSDLHOME!\llssite.cfg.in could be found
  goto exit
)
copy "%GSDLHOME%\llssite.cfg.in" "%GSDLHOME%\llssite.cfg"
set configfile=%GSDLHOME%\llssite.cfg

:cfgport
echo Configuring the apache webserver...
:: See http://ss64.com/nt/for_cmd.html, http://ss64.com/nt/findstr.html (and http://ss64.com/nt/find.html)
FOR /F "tokens=2 delims==" %%G IN ('findstr /R ^portnumber "!configfile!"') do set port=%%G
FOR /F "tokens=2 delims==" %%G IN ('findstr /R ^hostIP "!configfile!"') do set hostIP=%%G
FOR /F "tokens=2 delims==" %%G IN ('findstr /R ^hosts "!configfile!"') do set hosts=%%G
FOR /F "tokens=2 delims==" %%G IN ('findstr /R ^externalaccess "!configfile!"') do set allowfromall=%%G

if "%allowfromall%" == "1" set allowfromall="Allow"& goto portcon
set allowfromall="Deny"

:: Using CALL to jump to labels means we can return from them. BUT need to ensure
:: that command extensions are enabled to call labels. So just use GOTO instead.
::http://ss64.com/nt/call.html
goto portcon


::configure-port-and-connection
:setport
set /p port=Enter port number to use:
set /p hostIP=Enter host IP to allow (127.0.0.1 is included by default):
set /p hosts=Enter hostname or list of hosts to allow (localhost included by default):
set /p allowfromall=Allow external connections [yes/no]:

if "%allowfromall%" == "yes" set allowfromall="Allow"& goto portcon
if "%allowfromall%" == "y" set allowfromall="Allow"& goto portcon
set allowfromall="Deny"
goto portcon

:portcon
if "%port%" == "" (
   echo Done
   goto exit
)
if "%safepath%" == "" for /F "delims=*" %%T in ('"echo !GSDLHOME!| !_sed! s@\\@\/@g"') do set safepath=%%T

:: Doesn't work if there are spaces in the collecthome path in gsdlsite.cfg
::if exist "%GSDLHOME%\%cgibin%\gsdlsite.cfg" FOR /F "tokens=2" %%G IN ('findstr /R ^collecthome "!GSDLHOME!\!cgibin!\gsdlsite.cfg"') do set COLLECTHOME=%%G

:: variable in subroutine concat is called gshome, 
:: so forced to use it here for collecthome
set gshome=
if exist "%GSDLHOME%\%cgibin%\gsdlsite.cfg" FOR /F "tokens=*" %%G IN ('findstr /R ^collecthome "!GSDLHOME!\!cgibin!\gsdlsite.cfg"') do call :concat %%G
set COLLECTHOME=%gshome%
set gshome=

if "%COLLECTHOME%" == "" set COLLECTHOME=%GSDLHOME%\collect
for /F "delims=*" %%T in ('"echo !COLLECTHOME!| !_sed! s@\\@\/@g"') do set safecollectpath=%%T

echo Port: %port%
echo Stopping web server (if running)
if not exist "%GSDLHOME%\apache-httpd\%GSDLOS%\conf\httpd.conf"	echo Missing conf file
if exist "%GSDLHOME%\apache-httpd\%GSDLOS%\conf\httpd.conf" "%GSDLHOME%\bin\windows\stophttpd.exe" %GS2_APACHE_HTTPD_SIGNAL% SILENT
echo Setting config file to use port %port%
type "%GSDLHOME%\apache-httpd\%GSDLOS%\conf\httpd.conf.in" | %_sed% "s@\*\*GSDL_OS_ARCH\*\*@%GSDLOS%%GSDLARCH%@g" | %_sed% "s@\*\*PORT\*\*@%port%@g" | %_sed% "s@\*\*CONNECTPERMISSION\*\*@%allowfromall%@g" | %_sed% "s@\*\*HOST_IP\*\*@%hostIP%@g" | %_sed% "s@\*\*HOSTS\*\*@%hosts%@g" | %_sed% "s@\*\*COLLECTHOME\*\*@%safecollectpath%@g" | %_sed% "s@\*\*GSDLHOME\*\*@%safepath%@g" | %_sed% "s@\*\*APACHE_HOME_OS\*\*@%safepath%\/apache-httpd\/%GSDLOS%@g" > "%GSDLHOME%\apache-httpd\%GSDLOS%\conf\httpd.conf"
echo Type '%0 web-start' to start the web server running on port %port%
echo Done

set allowfromall=
set _sed=
set safepath=
set port=

:: Extra processing for configure-web and configure-cgi command targets
if not "%target%" == "configure-web" if not "%target%" == "configure-cgi" goto exit
if exist "%GSDLHOME%\apache-httpd\%GSDLOS%\conf\httpd.conf" (echo %MONITOR_SUCCESS%) else (echo %MONITOR_FAILED%)
echo %MONITOR_FINISHED%
goto exit

:exit
cd "%startdir%"
set startdir= 
endlocal
