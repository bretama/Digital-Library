@echo off
setlocal enabledelayedexpansion

:: Environment Variables passed in: _VERSION, GLILANG and possibly also
:: GSDLHOME and/or GSDL3SRCHOME.
:: As a result of executing this script, the JAVA_EXECUTABLE and GS_JAVA_HOME
:: environment variables will be set, but only if Perl was found.

:findJava

:: We will already be in the correct folder (GLI folder), which would
:: contain a compiled up search4j.exe if this GLI is part of an installation.
:: If search4j.exe is not there, then it means this is an SVN checkout. 
:: In such a case, it's up to the user checking things out to ensure JAVA_HOME
:: is set and moreover points to the correct version of the Java.

set DISPLAY_MIN_VERSION=1.4
set MIN_VERSION=1.4.0_00
set SEARCH4J_EXECUTABLE=search4j.exe
if exist %SEARCH4J_EXECUTABLE% goto setJexec
if "%_VERSION%" == "" goto tryJava
	:: else we look for a compiled version of search4j in a GS installation
	if "%_VERSION%" == "2" (
		set SEARCH4J_EXECUTABLE=!GSDLHOME!\bin\windows\search4j.exe
		set HINT=!GSDLHOME!\packages\jre
	)
	if "%_VERSION%" == "3" (
		set SEARCH4J_EXECUTABLE=!GSDL3SRCHOME!\bin\search4j.exe
		set HINT=!GSDL3SRCHOME!\packages\jre
	)
	if not exist "%SEARCH4J_EXECUTABLE%" goto tryJava

:setJexec
    "%SEARCH4J_EXECUTABLE%" -e -m "%MIN_VERSION%" -p "%HINT%" | winutil\setvar.exe JAVA_EXECUTABLE > %TMP%\set_java_executable.bat
    call "%TMP%\set_java_executable.bat"
    del "%TMP%\set_java_executable.bat"
    
    if "%JAVA_EXECUTABLE%" == "" goto noJava
    echo Java:
    echo %JAVA_EXECUTABLE%
    echo.

    :: we know that works, so we can set the local javahome (for Greenstone) as well
    "%SEARCH4J_EXECUTABLE%" -m "%MIN_VERSION%" -p "%HINT%" | winutil\setvar.exe GS_JAVA_HOME > %TMP%\set_java_home.bat
    call "%TMP%\set_java_home.bat"
    del "%TMP%\set_java_home.bat"

	::set JAVA_HOME=%GS_JAVA_HOME%
	::set PATH=%GS_JAVA_HOME%\bin;%PATH%
	
:: found java, JAVA_EXECUTABLE and GS_JAVA_HOME env vars set, can exit this script
    goto exit

:tryJava
if "%JAVA_HOME%" == "" goto noJava
if not exist "%JAVA_HOME%\bin\java.exe" goto noJava
	if "%GLILANG%" == "en" (
		echo.
		echo ***************************************************************************
    		echo WARNING: 
		echo Java Runtime not bundled with this Greenstone installation.
		echo Using JAVA_HOME: !JAVA_HOME!
		echo ^(NOTE: this needs to be %DISPLAY_MIN_VERSION% or higher.^)
		echo ***************************************************************************
		echo.
	)
	:: Try to use this version
	set JAVA_EXECUTABLE=%JAVA_HOME%\bin\java
	set GS_JAVA_HOME=%JAVA_HOME%
	::set JAVA_HOME=%GS_JAVA_HOME%
	::set PATH=%GS_JAVA_HOME%\bin;%PATH%
	goto exit

:noJava
    echo.
    if "%GLILANG%" == "en" (
		echo Failed to locate an appropriate version of Java. You must install a
    		echo Java Runtime Environment ^(version %DISPLAY_MIN_VERSION% or greater^) before running the
    		echo Greenstone Librarian Interface.
	)

    if "%GLILANG%" == "es" (
		echo No se pudo localizar una versiвn apropiada de Java. Usted deber 
    		echo instalar un Ambiente de Ejecuciвn Java ^(versiвn %DISPLAY_MIN_VERSION% o superior^)
    		echo antes de correr la Interfaz de la Biblioteca Digital Greenstone.
	)

    if "%GLILANG%" == "fr" (
		echo Une version ad?quate de Java n'a pas pu ?tre localis?e. Vous devez
    		echo installer un Java Runtime Environment ^(version %DISPLAY_MIN_VERSION% ou sup?rieur^)
    		echo avant de d?marrer Greenstone Librarian Interface.
	)

    if "%GLILANG%" == "ru" (
		echo Не уА лось опреАелЪть местон хоКАенЪе соответствующей версЪЪ Java.
    		echo ?ы АолКны уст новЪть Java Runtime Environment ^(версЪю %DISPLAY_MIN_VERSION% ЪлЪ выше^) переА ввоАом
    		echo бЪблЪотечного Ънтерфейс  Greenstone.
	)
    goto exit

:exit
set SEARCH4J_EXECUTABLE=
set MIN_VERSION=
set DISPLAY_MIN_VERSION=

endlocal & set JAVA_EXECUTABLE=%JAVA_EXECUTABLE%& set GS_JAVA_HOME=%GS_JAVA_HOME%
::& set JAVA_HOME=%JAVA_HOME%& set PATH=%PATH%

::echo ** JAVA_HOME: %JAVA_HOME%
::echo ** PATH: %PATH%