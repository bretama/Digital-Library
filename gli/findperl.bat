@echo off

:: Environment Variables passed in: GSLDHOME, OS, GLILANG
:: As a result of executing this script, the PERLPATH variable 
:: will be set, but only if Perl was found.

:findPerl
::  ---- Check Perl exists ----
set PERLPATH=

:: Some users may set the above line manually - If you do this, you need to 
:: make sure that perl is in your path otherwise lucene collections may not 
:: work
if not "%PERLPATH%" == "" goto testPerl
    :: Check if Perl is on the search path
    echo %PATH%| winutil\which.exe perl.exe | winutil\setvar.exe PERLPATH > %TMP%\setperl.bat
    call %TMP%\setperl.bat
    del %TMP%\setperl.bat
    if not "%PERLPATH%" == "" goto testPerl

    :: If not, try GSDLHOME\bin\windows\perl\bin
    if exist "%GSDLHOME%\bin\windows\perl\bin\perl.exe" goto gsdlPerl

    :: Still haven't found anything, so try looking in the registry (gulp!)
    type nul > %TMP%\perl.reg
    regedit /E %TMP%\perl.reg "HKEY_LOCAL_MACHINE\SOFTWARE\Perl"
    type %TMP%\perl.reg > %TMP%\perl.txt
    del %TMP%\perl.reg

    winutil\findperl.exe %TMP%\perl.txt | winutil\setvar.exe PERLPATH > %TMP%\setperl.bat
    del %TMP%\perl.txt
    call %TMP%\setperl.bat
    del %TMP%\setperl.bat

    :: If nothing was found in the registry, we're stuck
    if "%PERLPATH%" == "" goto noPerl

    :: if have found perl in registry, but not in path, then we need to 
    :: add it to path for lucene stuff.
    if "%OS%" == "Windows_NT" set PATH=%PATH%;%PERLPATH%
    if "%OS%" == "" set PATH="%PATH%";"%PERLPATH%"
    goto testPerl

:gsdlPerl
    set PERLPATH=%GSDLHOME%\bin\windows\perl\bin
    	
:testPerl
:: Check that a Perl executable has been found
if not exist "%PERLPATH%\perl.exe" goto noPerl
echo Perl:
echo %PERLPATH%
echo.

:: found perl, perlpath set, can exit this script
goto exit


:noPerl
    echo.
    if "%GLILANG%" == "en" echo The Greenstone Librarian Interface requires Perl in order to operate,
    if "%GLILANG%" == "en" echo but Perl could not be detected on your system. Please ensure that Perl
    if "%GLILANG%" == "en" echo is installed and is on your search path, then try again.

    if "%GLILANG%" == "es" echo La Interfaz de la Biblioteca Digital Greenstone requiere Perl para poder
    if "%GLILANG%" == "es" echo operar, pero Вste no aparece en su sistema. Por favor asegгrese de
    if "%GLILANG%" == "es" echo que Perl estа instalado y se encuentra en su ruta de bгsqueda.
    if "%GLILANG%" == "es" echo A continuaciвn ejecute nuevamente este guiвn.

    if "%GLILANG%" == "fr" echo Greenstone Librarian Interface nВcessite perl pour son fonctionnement,
    if "%GLILANG%" == "fr" echo mais perl n'a pas pu Иtre dВtectВ dans votre systКme. Veuillez vous 
    if "%GLILANG%" == "fr" echo assurer que perl est installВ et est spВcifiВ dans votre chemin de 
    if "%GLILANG%" == "fr" echo recherche, puis redВmarrez ce script.

    if "%GLILANG%" == "ru" echo Библиотечный интерфейс Greenstone требует Perl, чтобы иметь возможность
    if "%GLILANG%" == "ru" echo работать, но Perl не был в вашей системе. Пожалуйста, подтвердите,
    if "%GLILANG%" == "ru" echo что Perl установлен и находится на вашем пути поиска, затем
    if "%GLILANG%" == "ru" echo повторновведите этот скрипт.
    goto exit

:exit





