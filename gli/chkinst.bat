::@echo off

set CHECK=1

:: Check that the Greenstone installation looks OK
if "%GLILANG%" == "en" echo Checking GSDL: %1
if "%GLILANG%" == "es" echo Revisando GSDL: %1
if "%GLILANG%" == "fr" echo VВrification de GSDL: %1
if "%GLILANG%" == "ru" echo Проверка GSDL: %1

:: if either of the files exist, we know we can install greenstone
if exist %1\gs3-setup.bat set CHECK=0
if exist %1\setup.bat set CHECK=0

if "%CHECK%" == "0" goto endchk

	:: Otherwise, if there was no setup file, then installation fails
	echo.
	if "%GLILANG%" == "en" echo The Greenstone %2 installation could not be found, or is incomplete.
	if "%GLILANG%" == "en" echo Try reinstalling Greenstone %2 then running this script again.

	if "%GLILANG%" == "es" echo No se pudo encontrar la instalaciвn de Greenstone %2 o estа incompleta.
	if "%GLILANG%" == "es" echo Trate de reinstalar Greenstone %2 y a continuaciвn ejecute nuevamente este guiвn.

	if "%GLILANG%" == "fr" echo L'installation de Greenstone %2 est introuvable ou incomplКte. Essayez
	if "%GLILANG%" == "fr" echo de rВinstaller Greenstone %2 et exВcutez ce script Е nouveau.

	if "%GLILANG%" == "ru" echo Инсталляция Greenstone %2 не была найдена или она неполна. Попробуйте повторно
	if "%GLILANG%" == "ru" echo установить Greenstone %2, а затем ввести этот скрипт снова.

:endchk