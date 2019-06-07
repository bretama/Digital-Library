@echo off

setlocal enabledelayedexpansion

pushd "%CD%"
CD /D "%~dp0"
set GSDLLANG=en

echo.
echo.
echo  ####                        #
echo ##                           #
echo #     ###  ##   ##  ### ### ###  ##  ###  ##
echo #   # #   #### #### # # ##   #  #  # # # ####
echo ##  # #   #    #    # #   #  #  #  # # # #
echo  #### #    ###  ### # # ###  ##  ##  # #  ###
echo (C) 2008, New Zealand Digital Library Project
echo.
echo.
echo.

if "!GSDLHOME!" == "" goto start
if "!GSDLHOME!" == "!CD!" if not "!GSDLOS!" == "" (
	echo Your environment is already set up for Greenstone
	goto done
)

:start
if "!OS!" == "Windows_NT" goto WinNT
if "!OS!" == "" goto Win95
if "!GSDLLANG!" == "en" echo Setup failed - your PATH has not been set
if "!GSDLLANG!" == "es" echo No se pudo realizar la configuraci¢n - no se ha establecido la RUTA.
if "!GSDLLANG!" == "fr" echo Ech‚c de l'installation - votre variable PATH n'a pas ‚t‚ ajust‚e
if "!GSDLLANG!" == "ru" echo “áâ ­®¢ª  ­¥ ã¤ « áì - “’œ ­¥ ¡ë« ãáâ ­®¢«¥­
goto End

:WinNT
set GSDLHOME=%CD%
set GSDLOS=windows

REM Override Imagemagick and Ghostscript paths to the bundled applications shipped with greenstone if they exists otherwise use default environment variables.
if exist "!GSDLHOME!\bin\windows\ghostscript\bin\gsdll32.dll" set GS_DLL=!GSDLHOME!\bin\windows\ghostscript\bin\gsdll32.dll
if exist "!GSDLHOME!\bin\windows\ghostscript\lib\*.*" set GS_LIB=!GSDLHOME!\bin\windows\ghostscript\lib
if exist "!GSDLHOME!\bin\windows\ghostscript\bin\*.*" set PATH=!GSDLHOME!\bin\windows\ghostscript\bin;!PATH!
:: ImageMagick environment vars are now set in bin\script\gs-magick.pl
::if exist "!GSDLHOME!\bin\windows\imagemagick\*.*" set PATH=!GSDLHOME!\bin\windows\imagemagick;!PATH!

if "!GS_CP_SET!" == "yes" goto Success
set PATH=!GSDLHOME!\bin\windows;!GSDLHOME!\bin\script;!PATH!
if exist "!GSDLHOME!\bin\windows\perl\bin" (
	set PERLPATH=!GSDLHOME!\bin\windows\perl\bin
	set PATH=!PERLPATH!;!PATH!	
)

set GS_CP_SET=yes
goto Success

:Win95
if "%1" == "SetEnv" goto Win95Env
REM We'll invoke a second copy of the command processor to make
REM sure there's enough environment space
COMMAND /E:2048 /K %0 SetEnv
goto End

:Win95Env
set GSDLHOME=%CD%
set GSDLOS=windows

REM Override Imagemagick and Ghostscript paths to the bundled applications shipped with greenstone if they exists otherwise use default environment variables.
if exist "!GSDLHOME!\bin\windows\ghostscript\bin\gsdll32.dll" set GS_DLL="!GSDLHOME!\bin\windows\ghostscript\bin\gsdll32.dll"
if exist "!GSDLHOME!\bin\windows\ghostscript\lib\*.*" set GS_LIB="!GSDLHOME!\bin\windows\ghostscript\lib"
if exist "!GSDLHOME!\bin\windows\ghostscript\bin\*.*" set PATH="!GSDLHOME!\bin\windows\ghostscript\bin";"!PATH!"
:: ImageMagick environment vars are now set in bin\script\gs-magick.pl
::if exist "!GSDLHOME!\bin\windows\imagemagick\*.*" set PATH="!GSDLHOME!\bin\windows\imagemagick";"!PATH!"

if "!GS_CP_SET!" == "yes" goto Success
set PATH=!GSDLHOME!\bin\windows;!GSDLHOME!\bin\script;!PATH!
if exist "!GSDLHOME!\bin\windows\perl\bin" (
	set PERLPATH=!GSDLHOME!\bin\windows\perl\bin
	set PATH=!PERLPATH!;!PATH!
)
set GS_CP_SET=yes
goto Success


:Success
if "!GSDLLANG!" == "en" echo.
if "!GSDLLANG!" == "en" echo Your environment has successfully been set up to run Greenstone.
if "!GSDLLANG!" == "en" echo Note that these settings will only have effect within this MS-DOS
if "!GSDLLANG!" == "en" echo session. You will therefore need to rerun setup.bat if you want
if "!GSDLLANG!" == "en" echo to run Greenstone programs from a different MS-DOS session.
if "!GSDLLANG!" == "en" echo.

if "!GSDLLANG!" == "es" echo.
if "!GSDLLANG!" == "es" echo Su ambiente ha sido configurado para correr los programas Greenstone.
if "!GSDLLANG!" == "es" echo Recuerde que estos ajustes £nicamente tendr n efecto dentro de esta sesi¢n
if "!GSDLLANG!" == "es" echo MS-DOS. Por lo tanto deber  ejecutar nuevamente setup.bat si desea
if "!GSDLLANG!" == "es" echo correr los programas de Greenstone desde una sesi¢n MS-DOS diferente.
if "!GSDLLANG!" == "es" echo.

if "!GSDLLANG!" == "fr" echo.
if "!GSDLLANG!" == "fr" echo Votre environnement a ‚t‚ configu‚re avec succŠs pour ex‚cuter Greenstone
if "!GSDLLANG!" == "fr" echo Notez que ces paramŠtrages n'auront d'effet que dans cette session MS-DOS.
if "!GSDLLANG!" == "fr" echo Vous devrez par cons‚quent r‚ex‚cuter setup.bat si vous voulez faire
if "!GSDLLANG!" == "fr" echo lancer des programmes Greenstone dans une autre session MS-DOS.
if "!GSDLLANG!" == "fr" echo.

if "!GSDLLANG!" == "ru" echo.
if "!GSDLLANG!" == "ru" echo ‚ è¥ ®ªàã¦¥­¨¥ ¡ë«® ãá¯¥è­® ­ áâà®¥­®, çâ®¡ë ãáâ ­®¢¨âì Greenstone Ž¡à â¨â¥
if "!GSDLLANG!" == "ru" echo ¢­¨¬ ­¨¥, çâ® íâ¨ ­ §­ ç¥­¨ï ¡ã¤ãâ â®«ìª® ¨¬¥âì íää¥ªâ ¢ ¯à¥¤¥« å íâ®£® MS DOS
if "!GSDLLANG!" == "ru" echo á¥áá¨ï. ‚ë ¡ã¤¥â¥ ¯®íâ®¬ã ¤®«¦­ë ¯®¢â®à­® ã¯à ¢«ïâì setup.bat, ¥á«¨ ‚ë å®â¨â¥
if "!GSDLLANG!" == "ru" echo ã¯à ¢«ïâì ¯à®£à ¬¬ ¬¨ ‡¥«ñ­ëå ¨§¢¥à¦¥­­ëå ¯®à®¤ ®â à §«¨ç­®© á¥áá¨¨ MS DOS.
if "!GSDLLANG!" == "ru" echo.

:End
endlocal & set PATH=%PATH%& set GSDLHOME=%GSDLHOME%& set GSDLOS=%GSDLOS%

set savedir=%CD%
cd "%GSDLHOME%"
if exist ext (	
    for /D %%e IN ("ext/*") do call :addexts %%e
)
cd "%savedir%"
set savedir=
goto :doneexts

:addexts
set folder=%1
cd "ext\%folder%"		
if EXIST setup.bat call setup.bat
cd ..\..
goto :eof

:doneexts


if exist "%GSDLHOME%\local\setup.bat" (
    echo.
    echo Running %GSDLHOME%\local\setup.bat
    cd "%GSDLHOME%\local"
    call setup.bat 
    cd "%GSDLHOME%"
)

setlocal enabledelayedexpansion

if exist "%GSDLHOME%\local" (
  set PATH=!GSDLHOME!\local\bin;!PATH!
)

if exist "%GSDLHOME%\apache-httpd" (
  echo +Adding in executable path for apache-httpd
  set PATH=!GSDLHOME!\apache-httpd\!GSDLOS!\bin;!PATH!
  set PATH=!GSDLHOME!\apache-httpd\!GSDLOS!\lib;!PATH!
)

:: test writability of GSDLHOME
@call "!GSDLHOME!\bin\script\checkwritability.bat"

::::::::::::::::::::::::::::::
if "!GSDL3SRCHOME!" == "" (goto javacheck) else (goto done)

:javacheck
:: Only for GS2: work out java, and if the bundled jre is found, then set Java env vars with it
:: Then the same java will be consistently available for all aspects of GS2 (server or GLI, and any subshells these launch)
echo.
set MINIMUM_JAVA_VERSION=1.5.0_00
echo GS2 installation: Checking for Java of version !MINIMUM_JAVA_VERSION! or above

set BUNDLED_JRE=!GSDLHOME!\packages\jre
if exist "!BUNDLED_JRE!" (
	set HINT=!BUNDLED_JRE!
) else (
	echo No bundled JRE
	set HINT=
)

set SEARCH4J_EXECUTABLE=!GSDLHOME!\bin\!GSDLOS!\search4j.exe
if not exist "!SEARCH4J_EXECUTABLE!" (
	echo Can't check for java, no Search4j	
	if not exist "!BUNDLED_JRE!" echo Ensure Java environment variables are set ^(either JAVA_HOME or JRE_HOME and on PATH^) & goto done
	:: else use Bundled JRE
	echo Will use the bundled JRE and unset any JAVA_HOME to prevent conflicts
	set JAVA_HOME=
	set JRE_HOME=!BUNDLED_JRE!
	set PATH=!BUNDLED_JRE!\bin;!PATH!
	goto done
)

:: Need the call stmt, the usebackq with backticks around the full command, AND the double quotes around filepaths to properly handle spaces in the filepaths
for /f "usebackq tokens=*" %%r in (`call "!GSDLHOME!\bin\!GSDLOS!\search4j.exe" -p "!HINT!" -m !MINIMUM_JAVA_VERSION!`) do set GS_JAVA_HOME=%%r


if "!GS_JAVA_HOME!" == "" (
	if not exist "!BUNDLED_JRE!" echo There's no bundled JRE.
	echo setup.bat: Could not find Java in the environment or installation.	
	echo Set JAVA_HOME or JRE_HOME, and put it on the PATH, if working with Java tools like Lucene.
	goto done
)

:: found java, now GS_JAVA_HOME env vars set, set JAVA_HOME else JRE_HOME

if "!GS_JAVA_HOME!" == "!BUNDLED_JRE!" (	
	:: since our bundled JRE was selected by search4j and we'll be using that, clearing any existing JAVA_HOME to prevent version conflicts	
	echo Found a bundled JRE. Setting up GS2's Java environment to use this ^(and unsetting any JAVA_HOME to prevent version conflicts^)
	set JAVA_HOME=
	set JRE_HOME=!BUNDLED_JRE!
	set PATH=!BUNDLED_JRE!\bin;!PATH!
	goto done
)

:: Otherwise, the java that search4j found is not the bundled jre. In that case
:: if JAVA_HOME or JRE_HOME is already set to the Java found, then PATH presumably would already be set too.
if "!JAVA_HOME!" == "!GS_JAVA_HOME!" (
	echo Looks like the Java environment is already set up with a JAVA_HOME
	::echo Looks like the Java environment is already set up with a JAVA_HOME, unsetting any JRE_HOME	
	goto done
)
if "!JRE_HOME!" == "!GS_JAVA_HOME!" (
	echo Looks like the Java environment is already set up with a JRE_HOME, unsetting any JAVA_HOME to prevent java version conflicts
	set JAVA_HOME=
	goto done
)

:: if Java env vars not already set, then set them to the GS_JAVA_HOME found
echo Found a Java on the system. Setting up GS2's Java environment to use this
::echo Found a Java on the system. Setting up GS2's Java environment to use this: !GS_JAVA_HOME!
set PATH=!GS_JAVA_HOME!\bin;!PATH!
:: extract the last 4 chars from folder name. Could be \jre or jre\ or otherwise
set javafoldername=!GS_JAVA_HOME:~-4!
:: now can test if the foldername contains jre or otherwise, and based on that set either JAVA_HOME or JRE_HOME
:: https://stackoverflow.com/questions/7005951/batch-file-find-if-substring-is-in-string-not-in-a-file
:: https://ss64.com/nt/syntax-substring.html
if /i "x!javafoldername:jre=!" == "x!javafoldername!" (
	echo Setting JAVA_HOME, and unsetting any JRE_HOME to prevent version conflicts
	set JAVA_HOME=!GS_JAVA_HOME!
	set JRE_HOME=
) else (
	echo Setting JRE_HOME, and unsetting any JAVA_HOME to prevent version conflicts
	set JRE_HOME=!GS_JAVA_HOME!
	set JAVA_HOME=
)

::::::::::::::::::::::::::::::

:done
popd
endlocal & set PATH=%PATH%& set GSDLHOME=%GSDLHOME%& set GSDLOS=%GSDLOS%& set JRE_HOME=%JRE_HOME%& set JAVA_HOME=%JAVA_HOME%

if not "%JAVA_HOME%" == "" echo JAVA_HOME: %JAVA_HOME%
if not "%JRE_HOME%" == "" echo JRE_HOME: %JRE_HOME%
if "%JAVA_HOME%" == "" if "%JRE_HOME%" == "" echo Warning: Neither JAVA_HOME nor JRE_HOME set. Ensure one is set and on PATH.

:: Perl >= v5.18.* randomises map iteration order within a process
set PERL_PERTURB_KEYS=0

:: The user can customise wget flags like number of retries and setting timeouts in the Wgetrc file.
:: The WGETRC environment variable is used by wget to find a user wgetrc file overriding any system level one
:: https://www.gnu.org/software/wget/manual/html_node/Wgetrc-Location.html
set WGETRC=%GSDLHOME%/bin/%GSDLOS%/wgetrc
