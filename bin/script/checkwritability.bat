@echo off

if "%GSDLHOME%" == "" goto EnvNotSet

REM test if we have write permission on the greenstone install directory
echo.
echo Checking if GSDLHOME is writable...
echo This is a temporary file. It is safe to delete it. > "%GSDLHOME%\etc\testing.tmp"
if not exist "%GSDLHOME%\etc\testing.tmp" goto CantWrite
del "%GSDLHOME%\etc\testing.tmp"
echo GSDLHOME has write permission for the current user.
echo.
goto TheEnd

:CantWrite
echo.
echo.
echo.
echo -----------------------------------

if "%GSDLLANG%" == "en" echo  WARNING: CANNOT WRITE TO GSDLHOME
if "%GSDLLANG%" == "es" echo  ATENCIÓN: NO PUEDE ESCRIBIR EN EL DIRECTORIO RAÍZ DE GREENSTONE.
if "%GSDLLANG%" == "fr" echo  AVERTISSEMENT: ECRIRE IMPOSSIBLE DANS LE DOSSIER D'ACCUEIL DE GREENSTONE
if "%GSDLLANG%" == "ru" echo  ВНИМАНИЕ: НЕВОЗМОЖНО ОСУЩЕСТВИТЬ ЗАПИСЬ В ДОМАШНЮЮ ПАПКУ GREENSTONE

echo -----------------------------------
If "%GSDLLANG%" == "en" echo Greenstone needs write permission for the Greenstone home folder,
if "%GSDLLANG%" == "en" echo which is %GSDLHOME%,
if "%GSDLLANG%" == "en" echo but right now it does not.
if "%GSDLLANG%" == "en" echo Please grant "Full Control" for this folder (and all subfolders)  
if "%GSDLLANG%" == "en" echo to the current user (%username%) and try again.

if "%GSDLLANG%" == "es" echo Greenstone necesita permiso de escritura en el directorio:
if "%GSDLLANG%" == "es" echo %GSDLHOME%,
if "%GSDLLANG%" == "es" echo pero no lo tiene.
if "%GSDLLANG%" == "es" echo Por favor, concédale “Control completo” al usuario actual (%username%), 
if "%GSDLLANG%" == "es" echo y vuelva a intentarlo.

if "%GSDLLANG%" == "fr" echo Greenstone nécessite une autorisation d'écriture dans le dossier 
if "%GSDLLANG%" == "fr" echo principal de Greenstone: %GSDLHOME%,
if "%GSDLLANG%" == "fr" echo mais pour l'instant cette autorisation n'existe pas.
if "%GSDLLANG%" == "fr" echo Autorisez le « Contrôle Total » sur ce dossier (et sur tous les sous-dossiers)
if "%GSDLLANG%" == "fr" echo pour l'utilisateur courant (%username%) puis re-essayez.

if "%GSDLLANG%" == "ru" echo Greenstone требуется разрешение на запись в домашнюю папку %GSDLHOME%,
if "%GSDLLANG%" == "ru" echo в данный момент запись в домашнюю папку запрещена.
if "%GSDLLANG%" == "ru" echo Пожалуйста установите Полный доступ для папки (и всех вложенных папок)
if "%GSDLLANG%" == "ru" echo для текущего пользователя (%username%) и попробуйте заново.

echo.

if "%GSDLLANG%" == "en" echo (Alternatively, re-install Greenstone to a location where you have Full
if "%GSDLLANG%" == "en" echo Control already, such as a your home folder or 'My Documents'.)

if "%GSDLLANG%" == "es" echo (Alternativamente, reinstale Greenstone en una localización en la que tenga “Control completo”, 
if "%GSDLLANG%" == "es" echo como su directorio raíz o “Mis documentos”).

if "%GSDLLANG%" == "fr" echo (Alternativement, re-installez Greenstone à l'emplacement où vous avez déjà le « Contrôle Total », 
if "%GSDLLANG%" == "fr" echo comme votre dossier d'accueil ou  "Mes Documents".)

if "%GSDLLANG%" == "ru" echo (Либо, переустановите Greenstone в ту папку, к которой Вы уже имеете полный доступ, 
if "%GSDLLANG%" == "ru" echo например в свою домашнюю папку или в папку "Мои документы".)

echo.
echo.
echo.
echo.
goto TheEnd

:EnvNotSet
echo GSDLHOME not set

:TheEnd
