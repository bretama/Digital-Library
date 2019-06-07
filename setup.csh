setenv GSDLLANG en
setenv GSDLHOME `pwd`
setenv GSDLOS `uname -s | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz'`
setenv PATH $PATH\:$GSDLHOME/bin/script\:$GSDLHOME/bin/$GSDLOS
if ($?MANPATH) then
  setenv MANPATH $MANPATH\:$GSDLHOME/packages/mg/man
else
  setenv MANPATH $GSDLHOME/packages/mg/man
endif
if ("$GSDLLANG" == "es") then
  echo "Su ambiente ha sido configurado para correr los programas Greenstone."
else if ("$GSDLLANG" == "fr") then
  echo "Votre environnement a ИtИ configuИre avec succХs pour exИcuter Greenstone"
else if ("$GSDLLANG" == "ru") then
  echo "Ваше окружение было успешно настроено, чтобы установить Greenstone"
else
  echo "Your environment has successfully been set up to run Greenstone"
endif
