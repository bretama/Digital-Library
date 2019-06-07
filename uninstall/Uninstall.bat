@echo off
CD /D "%~dp0"

setlocal enabledelayedexpansion

:checkUserPermissions
	echo Checking if the Greenstone directory is writable ...
	(echo This is a temporary file. It is safe to delete it. > "testing.tmp" ) 2>nul
	if exist "testing.tmp" goto deleteTempFile 
	if "%1" == "Elevated" goto printWarning
	echo ... FAILED
	echo The uninstaller cannot write to the Greenstone directory (%CD%)
	echo Requesting elevated status to become admin user to continue.
	..\bin\windows\gstart.exe %0 Elevated %1 %2 %3 %4 %5 %6 %7 %8 %9
    goto done
	
:printWarning
	echo ... FAILED
	echo The uninstaller cannot write to the Greenstone directory (%CD%). 
	echo Attempting to continue without permissions.
	goto shiftElevated

:deleteTempFile
	echo ... OK
	del "testing.tmp"

:shiftElevated
:: Shift "Elevated" (one of our own internal command words) out of the way if present
:: so the command-line is as it was when the user initiated the command
	if "%1" == "Elevated" shift

cd ..
if exist .\bin\windows\search4j.exe .\bin\windows\search4j.exe -p .\packages\jre -l .\uninstall\uninst.jar

if exist .\gs2build\bin\windows\search4j.exe .\gs2build\bin\windows\search4j.exe -p .\packages\jre -l .\uninstall\uninst.jar

if exist uninst.flag (

	rd /s /q packages\jre
	rmdir packages
	
	if exist bin\windows\search4j.exe (
		del bin\windows\search4j.exe
		rmdir bin\windows
	)
	if exist gs2build\bin\windows\search4j.exe (
		del gs2build\bin\windows\search4j.exe
		rd /s /q gs2build
	)
	
	if exist llssite.cfg del llssite.cfg
	if exist glisite.cfg del glisite.cfg
	del uninst.flag
		
	del uninstall\uninst.jar
	del uninstall\Uninstall.*
	del uninstall\*.uninstall
	rmdir /S /Q bin
	rmdir /S /Q tmp
	rmdir /S /Q ext
	
	set GSDEL=!CD!
	cd ..
	
	echo @echo off > %TEMP%\gsuninstall.bat
	echo rmdir /S /Q !GSDEL!\uninstall >> %TEMP%\gsuninstall.bat
	echo ping 127.0.0.1 ^> nul >> %TEMP%\gsuninstall.bat
	echo rmdir !GSDEL! >> %TEMP%\gsuninstall.bat
	start cmd /C %TEMP%\gsuninstall.bat
	
)

:done
