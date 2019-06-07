echo off
setlocal enabledelayedexpansion

pushd "%CD%"
CD /D "%~dp0"
set GLILANG=en

:: This script must be run from within the directory in which it lives
if exist makejar.bat goto findJar
    if "%GLILANG%" == "en" echo This script must be run from the directory in which it resides.
    if "%GLILANG%" == "es" echo Este gui¢n deber  ejecutarse desde el directorio en el que reside.
    if "%GLILANG%" == "fr" echo Ce script doit ˆtre ex‚cut‚ … partir du r‚pertoire dans lequel il se trouve.
    if "%GLILANG%" == "ru" echo â®â áªà¨¯â ¤®«¦¥­ ¡ëâì ¢§ïâ ¨§ ¤¨à¥ªâ®à¨¨, ¢ ª®â®à®© ®­ à á¯®«®¦¥­
    goto exit




:findJar
:: ---- Check jar exists ----
set JARPATH=

:: Some users may set the above line manually
if not "%JARPATH%" == "" goto testJar

    :: If it is set, use the JAVA_HOME environment variable
    if not "%JAVA_HOME%" == "" goto javahome

    :: Check if jar is on the search path
    echo %PATH%| winutil\which.exe jar.exe | winutil\setvar.exe JARPATH > setjar.bat
    call setjar.bat
    del setjar.bat
    if not "%JARPATH%" == "" goto testJar

    :: Still haven't found anything, so try looking in the registry (gulp!)
    type nul > jdk.reg
    regedit /E jdk.reg "HKEY_LOCAL_MACHINE\SOFTWARE\JavaSoft\Java Development Kit"
    type jdk.reg > jdk.txt
    del jdk.reg

    winutil\findjava.exe jdk.txt | winutil\setvar.exe JARPATH > setjar.bat
    del jdk.txt
    call setjar.bat
    del setjar.bat

    :: If nothing was found in the registry, we're stuck
    if "%JARPATH%" == "" goto noJar

    set JARPATH=%JARPATH%\bin
    goto testJar

:javahome
    set JARPATH=%JAVA_HOME%\bin

:testJar
:: Check that a jar executable has been found
if "%GLILANG%" == "en" echo Checking jar: %JARPATH%
if "%GLILANG%" == "es" echo Revisando jar: %JARPATH%
if "%GLILANG%" == "fr" echo V‚rification de jar: %JARPATH%
if "%GLILANG%" == "ru" echo à®¢¥àª  jar: %JARPATH%
if exist "%JARPATH%\jar.exe" goto checkCompile

:noJar
    echo.
    if "%GLILANG%" == "en" echo Failed to locate an appropriate version of jar. You must install a
    if "%GLILANG%" == "en" echo Java Development Kit (version 1.4 or greater) before compiling the
    if "%GLILANG%" == "en" echo Greenstone Librarian Interface.

    if "%GLILANG%" == "es" echo No se pudo localizar una versi¢n apropiada de jar. Usted deber 
    if "%GLILANG%" == "es" echo instalar un Kit de Desarrollo de Software Java (versi¢n 1.4 o superior)
    if "%GLILANG%" == "es" echo antes de generar la documentaci¢n para la Interfaz de la Biblioteca
    if "%GLILANG%" == "es" echo Digital Greenstone.

    if "%GLILANG%" == "fr" echo Une version appropri‚e de jar n'a pas pu ˆtre localis‚e. Vous devez
    if "%GLILANG%" == "fr" echo installer un Kit de D‚veloppement Java (version 1.4 ou sup‚rieure) 
    if "%GLILANG%" == "fr" echo avant de produire la documentation de Greenstone Librarian Interface.

    if "%GLILANG%" == "ru" echo ¥ ã¤ «®áì ®¯à¥¤¥«¨âì ¬¥áâ®­ å®¦¤¥­¨¥ á®®â¢¥âáâ¢ãîé¥© ¢¥àá¨¨ jar.
    if "%GLILANG%" == "ru" echo ‚ë ¤®«¦­ë ¨­áâ ««¨à®¢ âì Java Development Kit (¢¥àá¨ï 1.4 ¨«¨ ¢ëè¥)
    if "%GLILANG%" == "ru" echo ¯à¥¦¤¥, ç¥¬ £¥­¥à¨à®¢ âì ¤®ªã¬¥­â æ¨î ¤«ï ¡¨¡«¨®â¥ç­®£®
    if "%GLILANG%" == "ru" echo ¨­â¥àä¥©á  Greenstone.
    goto exit



:checkCompile
:: Check that the GLI has been compiled 
if exist classes\org\greenstone\gatherer\GathererProg.class goto makeJar
    if "%GLILANG%" == "es"  (
	echo Usted necesita compilar la Interfaz de la Biblioteca Digital Greenstone
	echo ^(por medio de makegli.sh^) antes de ejecutar este guión.
    )
    if "%GLILANG%" == "fr" (
	echo Vous devez compiler le Greenstone Interface ^(en utilisant makegli.sh^)
	echo avant d'exécuter ce script.
    )
    if "%GLILANG%" == "ru" (
	echo ÷Ù ÄÏÌÖÎÙ ËÏÍÐÉÌÉÒÏ×ÁÔØ ÂÉÂÌÉÏÔÅÞÎÙÊ ÉÎÔÅÒÆÅÊÓ Greenstone
	echo ^(ÉÓÐÏÌØÚÕÑ makegli.sh^) ÐÅÒÅÄ ××ÏÄÏÍ ÜÔÏÇÏ ÓËÒÉÐÔÁ
    )
    if "%GLILANG%" == "en" (
	echo You need to compile the Greenstone Librarian Interface ^(using makegli.sh^)
	echo before running this script.
    )
    goto exit
fi


:makeJar
:: All the GLI class files and supporting libraries are put into the "jar" directory

echo Assuming that Java code is freshly compiled...

if NOT exist jar (
  mkdir jar

  cd jar
  "!JARPATH!\jar" xf ..\lib\apache.jar com org javax
  "!JARPATH!\jar" xf ..\lib\jna.jar com
  "!JARPATH!\jar" xf ..\lib\jna-platform.jar com
  "!JARPATH!\jar" xf ..\lib\qfslib.jar de
  "!JARPATH!\jar" xf ..\lib\rsyntaxtextarea.jar org
  cd ..
)

:: Copy the latest version of the GLI classes into the jar directory
if exist jar\org\greenstone (
  rmdir /q /s jar\org\greenstone
)
xcopy /i /e /q classes\org\greenstone jar\org\greenstone

:: Some of the things to go into the JAR file are optional, and may not exist
set optional=
if exist collect.zip (
    set optional=%optional% collect.zip
)

:: Recreate the metadata.zip file (contains the GLI metadata directory)
if exist metadata.zip (
  del /f metadata.zip
)
winutil\zip.exe -r metadata.zip metadata >NUL


:: Build up a list of all the loose files in the classes directory, which includes 
:: both feedback.properties and all dictionary*.properties files, since they all need 
:: to be included in the resulting GLI.jar file.
:: This type of FOR statement does not recurse into subdirs, which is what we want
:: as we want to include all the loose files in the toplevel classes dir in GLI.jar
::for %%G in (classes\*.properties) do echo file is %%G
set propfiles=
for %%G in (classes\*) do (call :concat %%G)
::echo Property files list: %propfiles%
goto :jarcmd

:concat
set propfiles=%propfiles% %1
goto :eof

:jarcmd
:: Jar everything up
::"%JARPATH%\jar" cf GLI.jar .java.policy metadata.zip %optional% help -C classes dictionary.properties -C classes dictionary_es.properties -C classes dictionary_fr.properties -C classes dictionary_ru.properties -C classes feedback.properties -C classes images -C classes xml -C jar com -C jar de -C jar org -C jar javax

:: include all the properties (and other loose) files in the toplevel classes directory into the GLI.jar
:: (Do something similar to get any and all folders inside the toplevel jar folder included into GLI.jar?)
"%JARPATH%\jar" cf GLI.jar .java.policy metadata.zip %optional% help %propfiles% -C classes images -C classes xml -C jar com -C jar de -C jar org -C jar javax


:: Tidy up
del /f metadata.zip

:: Generate the GLIServer.jar file for remote building
"%JARPATH%\jar" cf GLIServer.jar -C classes org/greenstone/gatherer/remote

:: ---- Make signed JAR file for the applet, if desired ----
if  (%1) == (-sign) (

    if not exist appletstore (
      "!JARPATH!\keytool" -genkey -alias privateKey -keystore appletstore -storepass greenstone
    )

    if exist SignedGatherer.jar del /f SignedGatherer.jar
    if exist appletpasswd (
      echo Using jarsigner to make signed jar file ...
      "!JARPATH!\jarsigner" -keystore appletstore -signedjar SignedGatherer.jar GLI.jar privateKey < appletpasswd >NUL 2>NUL
      echo ... done.
    ) ELSE (
      "!JARPATH!\jarsigner" -keystore appletstore -signedjar SignedGatherer.jar GLI.jar privateKey
    )
    echo Installing SignedGatherer in ..\bin\java
    move SignedGatherer.jar ..\bin\java\SignedGatherer.jar
)
:exit

popd
endlocal
