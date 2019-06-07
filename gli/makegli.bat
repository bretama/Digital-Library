@echo off
pushd "%CD%"
CD /D "%~dp0"
set GLILANG=en


::  -------- Compile the Greenstone Librarian Interface --------

echo.
if "%GLILANG%" == "en" echo Greenstone Librarian Interface (GLI)
if "%GLILANG%" == "en" echo Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato
if "%GLILANG%" == "en" echo GLI comes with ABSOLUTELY NO WARRANTY; for details see LICENSE.txt
if "%GLILANG%" == "en" echo This is free software, and you are welcome to redistribute it

if "%GLILANG%" == "es" echo Interfaz de la Biblioteca Digital Greenstone (Greenstone Librarian Interface - GLI)
if "%GLILANG%" == "es" echo Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato
if "%GLILANG%" == "es" echo La Interfaz de la Biblioteca Digital Greenstone NO INCLUYE ABSOLUTAMENTE NINGUNA GARANT╓A.
if "%GLILANG%" == "es" echo Para mayor informaciвn vea los tВrminos de la licencia en LICENSE.txt
if "%GLILANG%" == "es" echo Este es un software abierto, por lo que lo invitamos a que lo distribuya de forma gratuita

if "%GLILANG%" == "fr" echo Interface du BibliothВcaire Greenstone (Greenstone Librarian Interface - GLI)
if "%GLILANG%" == "fr" echo Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato
if "%GLILANG%" == "fr" echo GLI est fourni sans AUCUNE GARANTIE; pour des dВtails, voir LICENSE.txt
if "%GLILANG%" == "fr" echo Ceci est un logiciel libre, et vous Иtes invitВ Е le redistribuer

if "%GLILANG%" == "ru" echo Библиотечный интерфейс Greenstone (Greenstone Librarian Interface - GLI)
if "%GLILANG%" == "ru" echo Copyright (C) 2008, New Zealand Digital Library Project, University Of Waikato
if "%GLILANG%" == "ru" echo БИГ не дает АБСОЛЮТНО НИКАКИХ ГАРАНТИЙ; детали см. в тексте LICENSE.TXT
if "%GLILANG%" == "ru" echo Это - свободно распространяемое программное обеспечение и Вы можете распространять его

echo.

:: This script must be run from within the directory in which it lives
if exist makegli.bat goto findJavac
    if "%GLILANG%" == "en" echo This script must be run from the directory in which it resides.
    if "%GLILANG%" == "es" echo Este guiвn deberа ejecutarse desde el directorio en el que reside.
    if "%GLILANG%" == "fr" echo Ce script doit Иtre exВcutВ Е partir du rВpertoire dans lequel il se trouve.
    if "%GLILANG%" == "ru" echo Этот скрипт должен быть взят из директории, в которой он расположен
    goto exit


:findJavac
:: ---- Check Javac exists ----
set JAVACPATH=

:: Some users may set the above line manually
if not "%JAVACPATH%" == "" goto testJavac

    :: If it is set, use the JAVA_HOME environment variable
    if not "%JAVA_HOME%" == "" goto javahome

    :: Check if Javac is on the search path
    echo %PATH%| winutil\which.exe javac.exe | winutil\setvar.exe JAVACPATH > setjavac.bat
    call setjavac.bat
    del setjavac.bat
    if not "%JAVACPATH%" == "" goto testJavac

    :: Still haven't found anything, so try looking in the registry (gulp!)
    type nul > jdk.reg
    regedit /E jdk.reg "HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Development Kit"
    type jdk.reg > jdk.txt
    del jdk.reg

    winutil\findjava.exe jdk.txt | winutil\setvar.exe JAVACPATH > setjavac.bat
    del jdk.txt
    call setjavac.bat
    del setjavac.bat

    :: If nothing was found in the registry, we're stuck
    if "%JAVACPATH%" == "" goto noJavac

    set JAVACPATH=%JAVACPATH%\bin
    goto testJavac

:javahome
    set JAVACPATH=%JAVA_HOME%\bin

:testJavac
:: Check that a Javac executable has been found
if "%GLILANG%" == "en" echo Checking Javac: %JAVACPATH%
if "%GLILANG%" == "es" echo Revisando Javac: %JAVACPATH%
if "%GLILANG%" == "fr" echo VВrification de Javac: %JAVACPATH%
if "%GLILANG%" == "ru" echo Проверка Javac: %JAVACPATH%
if exist "%JAVACPATH%\javac.exe" goto makeGLI

:noJavac
    echo.
    if "%GLILANG%" == "en" echo Failed to locate an appropriate version of Javac. You must install a
    if "%GLILANG%" == "en" echo Java Development Kit (version 1.4 or greater) before compiling the
    if "%GLILANG%" == "en" echo Greenstone Librarian Interface.

    if "%GLILANG%" == "es" echo No se pudo localizar una versiвn apropiada de Javac. Usted deberа
    if "%GLILANG%" == "es" echo instalar un Kit de Desarrollo de Software Java (versiвn 1.4 o superior)
    if "%GLILANG%" == "es" echo antes de generar la documentaciвn para la Interfaz de la Biblioteca
    if "%GLILANG%" == "es" echo Digital Greenstone.

    if "%GLILANG%" == "fr" echo Une version appropriВe de Javac n'a pas pu Иtre localisВe. Vous devez
    if "%GLILANG%" == "fr" echo installer un Kit de DВveloppement Java (version 1.4 ou supВrieure) 
    if "%GLILANG%" == "fr" echo avant de produire la documentation de Greenstone Librarian Interface.

    if "%GLILANG%" == "ru" echo Не удалось определить местонахождение соответствующей версии Javac.
    if "%GLILANG%" == "ru" echo Вы должны инсталлировать Java Development Kit (версия 1.4 или выше)
    if "%GLILANG%" == "ru" echo прежде, чем генерировать документацию для библиотечного
    if "%GLILANG%" == "ru" echo интерфейса Greenstone.
    goto exit


:makeGLI
:: ---- Compile the GLI ----

if "%1" == "" goto makeAll
    :: If a file has been specified as a command-line argument, just compile that file
    echo.
    if "%GLILANG%" == "en" echo Compiling %1 and dependent classes...
    if "%GLILANG%" == "es" echo Compilando %1 y clases dependientes...
    if "%GLILANG%" == "fr" echo Compilation de %1 et des classes dВpendantes,,,
    if "%GLILANG%" == "ru" echo Компилирование %1 и зависимые классы...

    "%JAVACPATH%\javac.exe" -d classes/ -sourcepath src/ -classpath classes/;lib/apache.jar;lib/jna.jar;lib/jna-platform.jar;lib/qfslib.jar;lib/rsyntaxtextarea.jar %1

    if "%GLILANG%" == "en" echo Done!
    if "%GLILANG%" == "es" echo нHecho!
    if "%GLILANG%" == "fr" echo TerminВ!
    if "%GLILANG%" == "ru" echo Выполнено!
    goto done

:makeAll
:: Otherwise compile the lot...

:: Remove any existing class files first
call clean.bat

if "%GLILANG%" == "en" echo Compiling the Greenstone Librarian Interface...
if "%GLILANG%" == "es" echo Compilando la Interfaz de la Biblioteca Digital Greenstone...
if "%GLILANG%" == "fr" echo Compilation de Greenstone Librarian Interface,,,
if "%GLILANG%" == "ru" echo Компилирование библиотечного интерфейса Greenstone...

:: Compile the GLI
:: Sun compiler (tested with 1.5 and 1.6) didn't compile DragTreeSelectionModel.java or MetadataAuditTableModel.java automatically, so we need to put them in explicitly
"%JAVACPATH%\javac.exe" -d classes/ -sourcepath src/ -classpath classes/;lib/apache.jar;lib/jna.jar;lib/jna-platform.jar;lib/qfslib.jar;lib/rsyntaxtextarea.jar src/org/greenstone/gatherer/GathererProg.java src/org/greenstone/gatherer/util/DragTreeSelectionModel.java src/org/greenstone/gatherer/metadata/MetadataAuditTableModel.java 
"%JAVACPATH%\javac.exe" -d classes/ -sourcepath src/ -classpath classes/;lib/apache.jar;lib/jna.jar;lib/jna-platform.jar;lib/qfslib.jar;lib/rsyntaxtextarea.jar src/org/greenstone/gatherer/GathererApplet.java
:: "%JAVACPATH%\javac.exe" -d classes/ -sourcepath src/ -classpath classes/;lib/apache.jar;lib/jna.jar;lib/jna-platform.jar;lib/qfslib.jar;lib/rsyntaxtextarea.jar src/org/greenstone/gatherer/GathererApplet4gs3.java

:: Compile the GEMS
"%JAVACPATH%\javac.exe" -d classes/ -sourcepath src/ -classpath classes/;lib/apache.jar;lib/jna.jar;lib/jna-platform.jar;lib/qfslib.jar;lib/rsyntaxtextarea.jar src/org/greenstone/gatherer/gems/GEMS.java

:: Compile the standalone programs needed on the server for remote building
"%JAVACPATH%\javac.exe" -d classes/ -sourcepath src/ -classpath classes/ src/org/greenstone/gatherer/remote/Zip*.java
"%JAVACPATH%\javac.exe" -d classes/ -sourcepath src/ -classpath classes/ src/org/greenstone/gatherer/remote/Unzip.java

if "%GLILANG%" == "en" echo Done!
if "%GLILANG%" == "es" echo нHecho!
if "%GLILANG%" == "fr" echo TerminВ!
if "%GLILANG%" == "ru" echo Выполнено!
goto done

:exit
echo.
popd
pause

:done
:: ---- Clean up ----
popd
set JAVACPATH=
