@echo off
:: By the time this script is called by gli.bat, PROGNAME, 
:: PROGABBR and GLILANG would be set.

:: At the end of this script, GSDLHOME (and possibly GSDL3SRCHOME, GSDL3HOME)
:: will have been set if a local GS installation was found. If not found, then 
:: GSDLHOME would not have been set.

:findGSDL
echo.
if "%GLILANG%" == "en" (
		echo %PROGNAME% ^(%PROGABBR%^)
		echo Copyright ^(C^) 2008, New Zealand Digital Library Project, University Of Waikato
		echo %PROGABBR% comes with ABSOLUTELY NO WARRANTY; for details see LICENSE.txt
		echo This is free software, and you are welcome to redistribute it
	)

if "%GLILANG%" == "es" (
		echo Interfaz de la %PROGNAME% ^(%PROGNAME_EN% - %PROGABBR%^)
		echo Copyright ^(C^) 2008, New Zealand Digital Library Project, University Of Waikato
		echo La Interfaz de la %PROGNAME% NO INCLUYE ABSOLUTAMENTE NINGUNA GARANTÖA.
		echo Para mayor informaci¢n vea los t‚rminos de la licencia en LICENSE.txt
		echo Este es un software abierto, por lo que lo invitamos a que lo distribuya de forma gratuita
	)

if "%GLILANG%" == "fr" (
		echo Interface du %PROGNAME% ^(%PROGNAME_EN% - %PROGABBR%^)
		echo Copyright ^(C^) 2008, New Zealand Digital Library Project, University Of Waikato
		echo %PROGABBR% est fourni sans AUCUNE GARANTIE; pour des d‚tails, voir LICENSE.txt
		echo Ceci est un logiciel libre, et vous ˆtes invit‚ … le redistribuer
	)

if "%GLILANG%" == "ru" (
		echo ¨¡«¨®â¥ç­ë© ¨­â¥àä¥©á %PROGNAME% ^(%PROGNAME_EN% - %PROGABBR%^)
		echo Copyright ^(C^) 2008, New Zealand Digital Library Project, University Of Waikato
		echo ˆƒ ­¥ ¤ ¥â €‘Ž‹ž’Ž ˆŠ€Šˆ• ƒ€€’ˆ‰; ¤¥â «¨ á¬. ¢ â¥ªáâ¥ LICENSE.TXT
		echo â® - á¢®¡®¤­® à á¯à®áâà ­ï¥¬®¥ ¯à®£à ¬¬­®¥ ®¡¥á¯¥ç¥­¨¥ ¨ ‚ë ¬®¦¥â¥ à á¯à®áâà ­ïâì ¥£®
	)

echo.
::  ---- Determine path to Greenstone home for GS2 and GS3 ----
set GSDLPATH=
:: Some users may set the above line manually, or it may be set as an argument

set _VERSION=
if not "%GSDLPATH%" == "" goto getVer
	:: Otherwise gsdlpath is not yet set
	:: Check the env vars first 
	if not "%GSDL3SRCHOME%" == "" goto ver3
		if not "%GSDLHOME%" == "" goto ver2
			:: If not set, the default location for the GLI is a subdirectory of Greenstone
			set GSDLPATH=..
			goto getVer				

:getVer
call gsdlver.bat %GSDLPATH% %_VERSION%
:: Stand-alone GLI with no Greenstone installation to be detected
:: otherwise
if "%_VERSION%" == "1" goto noVer
	::if we are running GS2, free up any pre-set GS3 environment variables since we won't need them
	if "%_VERSION%" == "2" set GSDL3SRCHOME=
	if "%_VERSION%" == "2" set GSDL3HOME=
	goto testGSDL
	:: else _VERSION is 3, we continue:

:ver3
set _VERSION=3
set GSDLPATH=%GSDL3SRCHOME%
:: if GS2 is now also set, then both GS3 and GS2 are set: 
:: warn the user that we have defaulted to GS3
if not "%GSDLHOME%" == "" (
		echo Both Greenstone 2 and Greenstone 3 environments are set.
		echo It is assumed you want to run Greenstone 3.
		echo If you want to run Greenstone 2, please unset the
		echo environment variable GSDL3SRCHOME before running GLI.
		echo.
	)
goto testGSDL

:ver2
set _VERSION=2
set GSDLPATH=%GSDLHOME%
::free up the GS3 environment variables since we are running GS2 and don't need them
set GSDL3SRCHOME=
set GSDL3HOME=
goto testGSDL

:noVer
if "%GLIMODE%" == "local" if "%GLILANG%" == "en" echo Error: can't determine which Greenstone version is being run.
if "%GLIMODE%" == "client" if "%GLILANG%" == "en" echo Could not detect a Greenstone installation (no GSDLHOME).
goto exit

:testGSDL
set CHECK=1
call chkinst.bat "%GSDLPATH%" %_VERSION% %GLILANG% %CHECK% > nul
if "%CHECK%" == "1" goto exit
	:: otherwise installation worked well
	goto prepGSDL


:prepGSDL
:: Greenstone 3 case
if "%_VERSION%" == "3" goto prepGS3

if not "%_VERSION%" == "2" echo "Greenstone version unknown"
if not "%_VERSION%" == "2" goto exit

:: Otherwise, we are dealing with Greenstone 2
:: Setup Greenstone 2, unless it has already been done
if not "%GSDLHOME%" == "" goto doneGSDL
    call "%GSDLPATH%\setup.bat" SetEnv
    goto doneGSDL


:prepGS3
set GSDL2PATH=
:: Some users may set the above line manually

if "%GSDL3SRCHOME%" == "" goto setup3
	if "%GSDL3HOME%" == "" goto setup3
		::otherwise
		goto gs2build


:setup3
:: Setup Greenstone 3, unless it has already been done
    cd | winutil\setvar.exe GLIDIR > %TMP%\setgli.bat
    call %TMP%\setgli.bat
    del %TMP%\setgli.bat
    cd "%GSDLPATH%"
    call gs3-setup.bat SetEnv
    cd %GLIDIR%
    goto gs2build


:gs2build
	:: If Greenstone version 3 is running, we want to set gsdl2path
	:: Determine GSDLHOME for GS3 
	if not "%GSDL2PATH%" == "" goto setupGS2
		:: GSDL2PATH is not yet set. 
		:: And if GSDLHOME is not set either, then assume 
		:: that the gs2build subdir of GS3 exists
		if "%GSDLHOME%" == "" set GSDL2PATH=%GSDL3SRCHOME%\gs2build
		if "%GSDLHOME%" == "" goto setupGS2	
			:: Otherwise GSDLHOME is set, so set GSDL2PATH to GSDLHOME
			echo GSDLHOME environment variable is set to %GSDLHOME%.	
			echo Will use this to find build scripts.
			set GSDL2PATH=%GSDLHOME%

:setupGS2
set CHECK=1
call chkinst.bat "%GSDL2PATH%" 2 %GLILANG% %CHECK% > nul
if "%CHECK%" == "1" goto exit
	:: otherwise installation worked well
	:: Setup Greenstone, unless it has already been done
	if "%GSDLHOME%" == "" call "%GSDL2PATH%\setup.bat" SetEnv
	:: Either way, we can now dispose of GSDL2PATH
	set GSDL2PATH=	
	goto doneGSDL


:exit
:: if exit, then something went wrong. GSDLHOME would be empty already

:doneGSDL
:: GSDLPATH is no longer needed, since GSDLHOME should now be set
set GSDLPATH=
set CHECK=
set GLIDIR=