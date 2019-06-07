@echo off

pushd "%CD%"
CD /D "%~dp0"

:: by default, assume English
set PROGNAME=Fedora Librarian Interface
if "%GLILANG%" == "es" set PROGNAME=Biblioteca Digital Fedora.
if "%GLILANG%" == "fr" set PROGNAME=BibliothÈcaire Fedora.
if "%GLILANG%" == "ru" set PROGNAME=…Œ‘≈“∆≈ ” Fedora.
:: How to export PROGNAME?

set PROGNAME_EN=Fedora Librarian Interface
set PROGABBR=FLI


echo.
:: Test to see if FEDORA_HOME environment variable has been set up
if "%FEDORA_HOME%" == "" goto noFed
	:: Check if the directory FEDORA_HOME exists
	:: MAN: Can't use the if command to test directly for a directory, but the null (NUL) device does exist in
	:: every directory. As a result, you can test for the null device to determine whether a directory exists. 
	if not exist %FEDORA_HOME%\nul echo Error: Cannot find Fedora home. No such directory: %FEDORA_HOME%
	if not exist %FEDORA_HOME%\nul goto exit
		
:: If FEDORA_VERSION not set, default fedora-version to 3 after warning user.
if not "%FEDORA_VERSION%" == "" goto runFed
	echo FEDORA_VERSION (major version of Fedora) was not set. Defaulting to: 3.
	echo If you are running a different version of Fedora, set the FEDORA_VERSION
	echo environment variable.
	set FEDORA_VERSION="3"
	echo.


:runFed
:: MAN: The %* batch parameter is a wildcard reference to all the arguments, not including %0, 
:: that are passed to the batch file.
echo FEDORA_HOME: %FEDORA_HOME%. 
echo FEDORA_VERSION: %FEDORA_VERSION%
call gli.bat -fedora -fedora_home %FEDORA_HOME% -fedora_version %FEDORA_VERSION% %*
goto exit

:: Either (or both) of FEDORA_HOME and FEDORA_VERSION were not set, both are crucial
:noFed
echo Error: Cannot run %PROGNAME_EN% (%PROGABBR%) if FEDORA_HOME is not set.
goto exit


:exit
echo.
pause

:done
:: ---- Clean up ----
set PROGNAME_EN=
set PROGABBR=
set PROGNAME=

popd
