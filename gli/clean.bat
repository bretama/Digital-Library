@echo off
set GLILANG=en


::  -------- Clean up the Greenstone Librarian Interface directory --------

:: This script must be run from within the directory in which it lives
if exist clean.bat goto cleanGLI
    if "%GLILANG%" == "en" echo This script must be run from the directory in which it resides.
    if "%GLILANG%" == "es" echo Este guiвn deberа ejecutarse desde el directorio en el que reside.
    if "%GLILANG%" == "fr" echo Ce script doit Иtre exВcutВ Е partir du rВpertoire dans lequel il se trouve.
    if "%GLILANG%" == "ru" echo Этот скрипт должен быть взят из директории, в которой он расположен
    goto exit


:cleanGLI
:: ---- Remove class files ----
echo.
if "%GLILANG%" == "en" echo Removing the Greenstone Librarian Interface class files...
if "%GLILANG%" == "es" echo Eliminando los archivos de clase de la Interfaz de la Biblioteca Digital Greenstone...
if "%GLILANG%" == "fr" echo Suppression des fichiers de classe de Greenstone Librarian Interface
if "%GLILANG%" == "ru" echo Удаление файлов класса библиотечного интерфейса Greenstone

if not exist classes\org\greenstone\gatherer goto done

cd classes\org\greenstone\gatherer
if exist "*.class" del "*.class"
if exist "cdm\*.class" del "cdm\*.class"
if exist "collection\*.class" del "collection\*.class"
if exist "download\*.class" del "download\*.class"
if exist "feedback\*.class" del "feedback\*.class"
if exist "file\*.class" del "file\*.class"
if exist "gems\*.class" del "gems\*.class"
if exist "greenstone\*.class" del "greenstone\*.class"
if exist "greenstone3\*.class" del "greenstone3\*.class"
if exist "gui\*.class" del "gui\*.class"
if exist "gui\metaaudit\*.class" del "gui\metaaudit\*.class"
if exist "gui\tree\*.class" del "gui\tree\*.class"
if exist "metadata\*.class" del "metadata\*.class"
if exist "remote\*.class" del "remote\*.class"
if exist "shell\*.class" del "shell\*.class"
if exist "util\*.class" del "util\*.class"
cd ..\..\..\..

:done
if "%GLILANG%" == "en" echo Done!
if "%GLILANG%" == "es" echo нHecho!
if "%GLILANG%" == "fr" echo TerminВ!
if "%GLILANG%" == "ru" echo Выполнено!

:exit
echo.
