@echo off
setlocal enabledelayedexpansion

color 0A
set startdir=%CD%
rem pushd "%CD%"
CD /D "%~dp0"
set GLILANG=en

if "%GLIMODE%" == "" set GLIMODE=local

::  -------- Run the Greenstone Librarian Interface --------

:: This script must be run from within the directory in which it lives
if exist gli.bat goto start
    if "%GLILANG%" == "en" echo This script must be run from the directory in which it resides.
    if "%GLILANG%" == "es" echo Este gui¢n deber  ejecutarse desde el directorio en el que reside.
    if "%GLILANG%" == "fr" echo Ce script doit ˆtre ex‚cut‚ … partir du r‚pertoire dans lequel il se trouve.
    if "%GLILANG%" == "ru" echo â®â áªà¨¯â ¤®«¦¥­ ¡ëâì ¢§ïâ ¨§ ¤¨à¥ªâ®à¨¨, ¢ ª®â®à®© ®­ à á¯®«®¦¥­
    goto exit
	
:start
if "%OS%" == "Windows_NT" goto progName
    :: Invoke a new command processor to ensure there's enough environment space
    if "%1" == "Second" goto progName
		command /E:2048 /C %0 Second %1 %2 %3 %4 %5 %6 %7 %8 %9
		shift
		goto done

:progName
if not "%PROGNAME%" == "" goto findGSDL
	:: otherwise PROGNAME was not set, so default to the Greenstone Librarian Interface (GLI) program
	if "%GLILANG%" == "es" set PROGNAME=Biblioteca Digital Greenstone
	if "%GLILANG%" == "fr" set PROGNAME=Bibliothécaire Greenstone
	if "%GLILANG%" == "ru" set PROGNAME=ÉÎÔÅÒÆÅÊÓ Greenstone
	:: if the PROGNAME is still not set, then set the language to English
	if "%PROGNAME%" == "" set PROGNAME=Greenstone Librarian Interface


if "%PROGABBR%" == "" set PROGABBR=GLI
if "%PROGNAME_EN%" == "" set PROGNAME_EN=Greenstone Librarian Interface

:: Now need to work out the _VERSION, GSDLHOME (and if GS3, then GSDL3SRCHOME and GSDL3HOME)
:findGSDL
call findgsdl.bat
if "%GSDLHOME%" == "" goto exit

:checkUserPermissions

rem In a web-dispersed GS3 setup like in the labs, we don't require the Greenstone directory to be writable.
rem If GS3, get the using.user.web property from build.properties and if set to true, we can skip to shiftElevated
:: http://ss64.com/nt/syntax-substring.html	
	if "%_VERSION%" == "3" if exist "%GSDL3SRCHOME%\build.properties" for /F "usebackq tokens=1,2 delims==" %%G in ("%GSDL3SRCHOME%\build.properties") do ( 
		if "%%G" == "using.user.web" if "%%H" == "true" goto :shiftElevated
	)
	echo.
	echo Checking if the Greenstone collection directory is writable ...
	(echo This is a temporary file. It is safe to delete it. > "!GSDLHOME!\collect\testing.tmp" ) 2>nul
	if exist "%GSDLHOME%\collect\testing.tmp" goto deleteTempFile 
	if "%1" == "Elevated" goto printWarning
	echo ... FAILED
	echo The %PROGNAME% cannot write to the collection directory (!GSDLHOME!\collect)
	echo Requesting elevated status to become admin user to continue.
	"%GSDLHOME%\bin\windows\gstart.exe" %0 Elevated %1 %2 %3 %4 %5 %6 %7 %8 %9
    goto done
	
:printWarning
	echo ... FAILED
	echo The %PROGNAME% cannot write to the log directory (!GSDLHOME!\collect). 
	echo Attempting to continue without permissions.
	goto shiftElevated

:deleteTempFile
	echo ... OK
	del "%GSDLHOME%\collect\testing.tmp"

:shiftElevated
:: Shift "Elevated" (one of our own internal command words) out of the way if present
:: so the command-line is as it was when the user initiated the command
	if "%1" == "Elevated" shift

:: Make sure we're in the GLI folder, even if located outside a GS installation
CD /D "%~dp0"

:findPerl
:: Now need to find Perl. If found, PERLPATH will be set 
call findperl.bat
if "%PERLPATH%" == "" goto exit

:: Need to find Java. If found, JAVA_EXECUTABLE will be set
call findjava.bat
if "%JAVA_EXECUTABLE%" == "" goto exit


:checkGLI
:: ---- Check that the GLI has been compiled ----
if exist "classes/org/greenstone/gatherer/Gatherer.class" goto runGLI
if exist "GLI.jar" goto runGLI
    echo.
    if "%GLILANG%" == "en" echo You need to compile the Greenstone Librarian Interface (using makegli.bat)
    if "%GLILANG%" == "en" echo before running this script.

    if "%GLILANG%" == "es" echo Usted necesita compilar la Interfaz de la Biblioteca Digital Greenstone
    if "%GLILANG%" == "es" echo (por medio de makegli.bat) antes de ejecutar este gui¢n.

    if "%GLILANG%" == "fr" echo Vous devez compiler le Greenstone Interface (en utilisant makegli.bat)
    if "%GLILANG%" == "fr" echo avant d'ex‚cuter ce script.

    if "%GLILANG%" == "ru" echo ‚ë ¤®«¦­ë ª®¬¯¨«¨à®¢ âì ¡¨¡«¨®â¥ç­ë© ¨­â¥àä¥©á Greenstone (¨á¯®«ì§ãï makegli.bat)
    if "%GLILANG%" == "ru" echo ¯¥à¥¤ ¢¢®¤®¬ íâ®£® áªà¨¯â 
    goto exit


:runGLI

if not "%_VERSION%" == "" (
  echo Greenstone Major Version : 
  echo %_VERSION%
	echo.
)

if not "%GSDL3SRCHOME%" == "" (
    echo GSDL3SRCHOME:
    echo !GSDL3SRCHOME!
	echo.
)

if not "%GSDL3HOME%" == "" (
    echo GSDL3HOME:
    echo !GSDL3HOME!
	echo.
)

if not "%GSDLHOME%" == "" (
    echo GSDLHOME:
    echo !GSDLHOME!
	echo.
)

:: ---- Explain how to bypass Imagemagick and Ghostscript bundled with Greenstone if needed ----
echo.
if exist "%GSDLHOME%\bin\windows\ghostscript\bin\*.*" echo GhostScript bundled with Greenstone will be used, if you wish to use the version installed on your system (if any) please go to %GSDLHOME%\bin\windows and rename the folder called ghostscript to something else.
echo.
echo.
if exist "%GSDLHOME%\bin\windows\imagemagick\*.*" echo ImageMagick bundled with Greenstone will be used, if you wish to use the version installed on your system (if any) please go to %GSDLHOME%\bin\windows and rename the folder called imagemagick to something else.
echo.
echo.


:: ---- Finally, run the GLI ----
if "%GLILANG%" == "en" echo Running the %PROGNAME%...
if "%GLILANG%" == "es" echo Ejecutando la %PROGNAME%...
if "%GLILANG%" == "fr" echo Ex‚cution de %PROGNAME%
if "%GLILANG%" == "ru" echo ’¥ªãé¨© ¡¨¡«¨ %PROGNAME%...

:: -Xms32M          To set minimum memory
:: -Xmx32M          To set maximum memory
:: -verbose:gc      To set garbage collection messages
:: -Xincgc          For incremental garbage collection
:: -Xprof           Function call profiling
:: -Xloggc:<file>   Write garbage collection log


:: Run GS3 if version = 3
:rungs3

	rem In a web-dispersed GS3 set up like in the labs, gsdl3home.isreadonly would be true and
	rem we need to run the web server in read-only mode. This section of code borrowed from gs3-server.bat.	
	if "%_VERSION%" == "3" for /F "usebackq tokens=1,2 delims==" %%G in ("%GSDL3SRCHOME%\build.properties") do ( 
		if "%%G"=="gsdl3home.isreadonly" if "%%H" == "true" (
			set gsdl3_writablehome=%TMP%\greenstone\web
			:: not used
			set opt_properties="-Dgsdl3home.isreadonly=true" -Dgsdl3.writablehome="%gsdl3_writablehome%"
			echo Setting Greenstone3 web home writable area to be: %gsdl3_writablehome%
			pushd "%GSDL3SRCHOME%"
			:: passing opt_properties is no longer necessary because ant.bat is unmodified (doesn't make use of it) 
			:: and because build.xml already contains the properties with the correct values
			cmd /c ant.bat %opt_properties% configure-web
			popd
		)
	)
	
	if "%_VERSION%" == "3" "%JAVA_EXECUTABLE%" -cp classes/;GLI.jar;lib/apache.jar;lib/jna.jar;lib/jna-platform.jar;lib/qfslib.jar;lib/rsyntaxtextarea.jar org.greenstone.gatherer.GathererProg -gsdl "%GSDLHOME%" -gsdlos %GSDLOS% -gsdl3 "%GSDL3HOME%" -gsdl3src "%GSDL3SRCHOME%" -perl "%PERLPATH%" %1 %2 %3 %4 %5 %6 %7 %8 %9
    if ERRORLEVEL 2 (
        goto rungs3
    )
	if "%_VERSION%" == "3" goto finRun

:: Run GS2 since version is 2:
:: if FLI is running, we don't want the local Greenstone library server running
if "%PROGABBR%" == "FLI" goto webLib
	:: Else we're running GLI, so we want the local Greenstone library server (if server.exe/gs2-web-server.bat exists, otherwise it will be webLib)
	if not exist "%GSDLHOME%\server.exe" if not exist "%GSDLHOME%\gs2-web-server.bat" goto webLib 

:localLib
    if exist "%GSDLHOME%\server.exe" (
	set locallib=!GSDLHOME!\server.exe
    ) else (
	set locallib=!GSDLHOME!\gs2-web-server.bat
    )

    "%JAVA_EXECUTABLE%" -Xmx128M -cp classes/;GLI.jar;lib/apache.jar;lib/jna.jar;lib/jna-platform.jar;lib/qfslib.jar;lib/rsyntaxtextarea.jar org.greenstone.gatherer.GathererProg -gsdl "%GSDLHOME%" -gsdlos %GSDLOS% -perl "%PERLPATH%" -local_library "%locallib%" %1 %2 %3 %4 %5 %6 %7 %8 %9
    if ERRORLEVEL 2 (
        goto localLib
    )
    goto finRun

:webLib
    "%JAVA_EXECUTABLE%" -Xmx128M -cp classes/;GLI.jar;lib/apache.jar;lib/jna.jar;lib/jna-platform.jar;lib/qfslib.jar;lib/rsyntaxtextarea.jar org.greenstone.gatherer.GathererProg -gsdl "%GSDLHOME%" -gsdlos %GSDLOS% -perl "%PERLPATH%" %1 %2 %3 %4 %5 %6 %7 %8 %9
    if ERRORLEVEL 2 (
        goto webLib
    )
    goto finRun

:finRun
    if "%GLILANG%" == "en" echo Done.
    if "%GLILANG%" == "es" echo Hecho.
    if "%GLILANG%" == "fr" echo Termin‚.
    if "%GLILANG%" == "ru" echo ‚ë¯®«­¥­®.
    goto done


:exit
echo.
pause
color 07
rem popd

:done
:: ---- Clean up ----
set PERLPATH=
set JAVA_EXECUTABLE=
set GLIMODE=
set PROGNAME=
set PROGNAME_EN=
set PROGFULLNAME=
set PROGABBR=
color 07
rem popd
cd "%startdir%"
set startdir=

endlocal
