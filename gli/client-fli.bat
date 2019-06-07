@echo off

pushd "%CD%"
CD /D "%~dp0"

set PROGNAME=Fedora
set PROGNAME_EN=Fedora Librarian Interface
set PROGABBR=FLI

:: run GLI in fedora mode
call client-gli.bat -fedora %*

:done
:: ---- Clean up ----
set PROGNAME_EN=
set PROGABBR=
set PROGNAME=

popd
