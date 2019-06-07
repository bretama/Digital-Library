@echo off
setlocal enabledelayedexpansion

pushd "%CD%"
CD /D "%~dp0"
set GLILANG=en
set GLIMODE=client

if "%PROGNAME%" == "" set PROGNAME=Greenstone

if not "%PROGFULLNAME%" == "" goto setvars
if "%GLILANG%" == "es" set PROGFULLNAME="Biblioteca Digital Greenstone"  
if "%GLILANG%" == "fr" set PROGFULLNAME="Bibliothщcaire Greenstone"
if "%GLILANG%" == "ru" set PROGFULLNAME="╔╬╘┼╥╞┼╩╙ Greenstone"
:: if the PROGFULLNAME is still not set, then set the language to English
if "%PROGFULLNAME%" == "" set PROGNAME=Greenstone Digital Library
  

:setvars
if "%PROGABBR%" == "" set PROGABBR=GLI
if "%PROGNAME_EN%" == "" set PROGNAME_EN=Greenstone Librarian Interface

::  -------- Run the Greenstone Librarian Interface --------

:: This script must be run from within the directory in which it lives
if exist client-gli.bat goto start
    if "%GLILANG%" == "en" echo This script must be run from the directory in which it resides.
    if "%GLILANG%" == "es" echo Este guiвn deberа ejecutarse desde el directorio en el que reside.
    if "%GLILANG%" == "fr" echo Ce script doit Иtre exВcutВ Е partir du rВpertoire dans lequel il se trouve.
    if "%GLILANG%" == "ru" echo Этот скрипт должен быть взят из директории, в которой он расположен
    goto exit

:start
if "%OS%" == "Windows_NT" goto findGSDL
    :: Invoke a new command processor to ensure there's enough environment space
    if "%1" == "Second" goto findGSDL
        command /E:2048 /C %0 Second %1 %2 %3 %4 %5 %6 %7 %8 %9
        goto done

:findGSDL
:: Try to detect a local GSDLHOME installation (gs2build). If none can be
:: found, then client-gli won't have a download panel. We're calling 
:: findgsdl.bat purely for knowing if there's a GSDLHOME around and to set and
:: use that for downloading. If there IS a local GSDLHOME, then we can download
:: (and build) locally, but ONLY if we have perl. Else downloading and building
:: will have to be done remotely anyway. If Perl is found, PERLPATH will be set.
call findgsdl.bat
if "%GSDLHOME%" == "" goto findJava
	call findperl.bat

:findJava
:: Need to find Java. If found, JAVA_EXECUTABLE will be set
call findjava.bat
if "%JAVA_EXECUTABLE%" == "" goto exit

:checkGLI
:: ---- Check that the GLI has been compiled ----
if exist "classes/org/greenstone/gatherer/Gatherer.class" goto runGLI
if exist "GLI.jar" goto runGLI
    echo.
    if "%GLILANG%" == "en" echo You need to compile the %PROGNAME_EN% (using makegli.bat)
    if "%GLILANG%" == "en" echo before running this script.

    if "%GLILANG%" == "es" echo Usted necesita compilar la Interfaz de la %PROGFULLNAME%
    if "%GLILANG%" == "es" echo (por medio de makegli.bat) antes de ejecutar este guiвn.

    if "%GLILANG%" == "fr" echo Vous devez compiler le %PROGNAME% Interface (en utilisant makegil.bat)
    if "%GLILANG%" == "fr" echo avant d'exВcuter ce script.

    if "%GLILANG%" == "ru" echo Вы должны компилировать библиотечный интерфейс %PROGNAME% (используя makegli.bat)
    if "%GLILANG%" == "ru" echo перед вводом этого скрипта
    goto exit


:runGLI
:: ---- Finally, run the GLI ----
echo.


if "%GLILANG%" == "en" echo Running the %PROGNAME_EN%...
if "%GLILANG%" == "es" echo Ejecutando la Interfaz de la %PROGFULLNAME%...
if "%GLILANG%" == "fr" echo ExВcution de %PROGNAME_EN%
if "%GLILANG%" == "ru" echo Текущий библиотечный интерфейс %PROGNAME%...

:: -Xms32M          To set minimum memory
:: -Xmx32M          To set maximum memory
:: -verbose:gc      To set garbage collection messages
:: -Xincgc          For incremental garbage collection
:: -Xprof           Function call profiling
:: -Xloggc:<file>   Write garbage collection log


:: If there's a local GS2 installation (GSDLHOME set), we'd have looked for Perl. If we had
:: found Perl, PERLPATH would have been set. If no perl, can't download or build locally on
:: the client side. If we have Perl, pass in GSDLHOME for the -gsdl option and the PERLPATH.
if "%PERLPATH%" == "" goto nogsdl
	echo Perl and GSDLHOME (!GSDLHOME!) detected. Downloading is enabled.
	echo.
	"%JAVA_EXECUTABLE%" -Xmx128M -cp classes/;GLI.jar;lib/apache.jar;lib/jna.jar;lib/jna-platform.jar;lib/qfslib.jar;lib/rsyntaxtextarea.jar org.greenstone.gatherer.GathererProg -use_remote_greenstone -gsdl "%GSDLHOME%" -perl "%PERLPATH%" %1 %2 %3 %4 %5 %6 %7 %8 %9
	goto finish

:nogsdl
echo Since there's no GSDLHOME, client-GLI's download panel will be deactivated.
"%JAVA_EXECUTABLE%" -Xmx128M -cp classes/;GLI.jar;lib/apache.jar;lib/jna.jar;lib/jna-platform.jar;lib/qfslib.jar;lib/rsyntaxtextarea.jar org.greenstone.gatherer.GathererProg -use_remote_greenstone %1 %2 %3 %4 %5 %6 %7 %8 %9

:finish
if "%GLILANG%" == "en" echo Done!
if "%GLILANG%" == "es" echo нHecho!
if "%GLILANG%" == "fr" echo TerminВ!
if "%GLILANG%" == "ru" echo Выполнено!
goto done

:exit
echo.
pause

:done
:: ---- Clean up ----
set PERLPATH=
set JAVA_EXECUTABLE=
set GLIMODE=
set PROGNAME=
set PROGNAME_EN=
set PROGFULLNAME=
set PROGABBR=
popd
endlocal
