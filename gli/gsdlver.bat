@echo off

:: This batch script returns the version of greenstone that is running
set _VERSION=1

:: first parameter is the value of gsdlpath
if exist %1\gs3-setup.bat set _VERSION=3
if exist %1\setup.bat set _VERSION=2


