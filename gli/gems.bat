@echo off
setlocal enabledelayedexpansion

color 0A
pushd "%CD%"
CD /D "%~dp0"
set GLILANG=en


::  -------- Run the Greenstone Librarian Interface --------

:: This script must be run from within the directory in which it lives
if exist gems.bat goto start
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
if "%GLILANG%" == "es" set PROGNAME=Editar conjuntos de metadatos
if "%GLILANG%" == "fr" set PROGNAME=Editer les jeux de méta-données
if "%GLILANG%" == "ru" set PROGNAME=Ðåäàêòèðîâàòü íàáîðû ìåòàäàííûõ
:: if the PROGNAME is still not set, then set the language to English
if "%PROGNAME%" == "" set PROGNAME=Greenstone Editor for Metadata Sets

if "%PROGABBR%" == "" set PROGABBR=GEMS
if "%PROGNAME_EN%" == "" set PROGNAME_EN=Greenstone Editor for Metadata Sets

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

:: Need to find Java. If found, JAVA_EXECUTABLE will be set
call findjava.bat
if "%JAVA_EXECUTABLE%" == "" goto exit


:chkGEMS
:: ---- Check that the GEMS has been compiled ----
if exist "classes/org/greenstone/gatherer/Gatherer.class" goto runGEMS
if exist "GLI.jar" goto runGEMS
    echo.
    if "%GLILANG%" == "en" echo You need to compile the %PROGNAME% (using makegli.bat)
    if "%GLILANG%" == "en" echo before running this script.

    if "%GLILANG%" == "es" echo Usted necesita compilar la %PROGNAME%
    if "%GLILANG%" == "es" echo (por medio de makegli.bat) antes de ejecutar este gui¢n.

    if "%GLILANG%" == "fr" echo Vous devez compiler le %PROGNAME% (en utilisant makegli.bat)
    if "%GLILANG%" == "fr" echo avant d'ex‚cuter ce script.

    if "%GLILANG%" == "ru" echo ‚ë ¤®«¦­ë ª®¬¯¨«¨à®¢ âì %PROGNAME% (¨á¯®«ì§ãï makegli.bat)
    if "%GLILANG%" == "ru" echo ¯¥à¥¤ ¢¢®¤®¬ íâ®£® áªà¨¯â 
    goto exit


:runGEMS
if not "%_VERSION%" == "" (
    echo Greenstone Major Version:
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

:: ---- Finally, run the GEMS ----
if "%GLILANG%" == "en" echo Running the %PROGNAME%...
if "%GLILANG%" == "es" echo Ejecutando la %PROGNAME%...
if "%GLILANG%" == "fr" echo Ex‚cution de %PROGNAME%
if "%GLILANG%" == "ru" echo ’¥ªãé¨© %PROGNAME%...

:: -Xms32M          To set minimum memory
:: -Xmx32M          To set maximum memory
:: -verbose:gc      To set garbage collection messages
:: -Xincgc          For incremental garbage collection
:: -Xprof           Function call profiling
:: -Xloggc:<file>   Write garbage collection log


:: Run GS3 if version = 3
if "%_VERSION%" == "3" "%JAVA_EXECUTABLE%" -cp classes/;GLI.jar;lib/apache.jar org.greenstone.gatherer.gems.GEMS -gsdl3 %GSDL3HOME% %1 %2 %3 %4 %5 %6 %7 %8 %9
if "%_VERSION%" == "3" goto finRun

	:: Else run GS2 since version is 2:
	"%JAVA_EXECUTABLE%" -cp classes/;GLI.jar;lib/apache.jar org.greenstone.gatherer.gems.GEMS -gsdl %GSDLHOME% %1 %2 %3 %4 %5 %6 %7 %8 %9

:finRun
    if "%GLILANG%" == "en" echo Done!
    if "%GLILANG%" == "es" echo ­Hecho!
    if "%GLILANG%" == "fr" echo Termin‚!
    if "%GLILANG%" == "ru" echo ‚ë¯®«­¥­®!
    goto done


:exit
echo.
pause
color 07
popd
:done
:: ---- Clean up ----
set JAVAPATH=
set JAVA_EXECUTABLE=
color 07
popd

endlocal
