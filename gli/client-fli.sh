#!/bin/sh

PROGNAME="Fedora"
export PROGNAME

PROGNAME_EN="Fedora Librarian Interface"
export PROGNAME_EN

PROGABBR="FLI"
export PROGABBR

# run GLI in fedora mode
./client-gli.sh -fedora $*
