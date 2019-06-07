L'Interface du Bibliothécaire de Greenstone (Greenstone Librarian Interface)
----------------------------------------------------------------------------

Ce dossier contient l'Interface du Bibliothécaire de Greenstone - Greenstone 
Librarian Interface (GLI), un outil qui vous assiste pour la création de 
bibliothèques numérique avec Greenstone. GLI vous donne accès aux fonctions 
de Greenstone à partir d'une interce 'pointer et cliquer' facile à utiliser.

Pour utiliser GLI, vous avez besoin d'une version adéquate de Java Runtime 
Environment (version 1.4.0 ou supérieure). Si vous n'en disposez pas, vous 
pouvez le télécharger de http://java.sun.com/j2se/downloads.html

Notez que GLI est lancé avec Greenstone et suppose qu'il est installé dans 
un sous-répertoire de votre installation Greenstone. Si vous avez téléchargé 
une des distributions de Greenstone ou si vous avez installé à partir d'un 
CD-ROM, ceci sera le cas.


-- Exécuter GLI sous Windows --

Pour exécuter GLI sous Windows, parcourez votre système de fichiers jusqu'au 
répertoire GLI (en utilisant Windows Explorer), et double-cliquez sur le 
fichier gli.bat. Ce fichier va vérifier que Greenstone, Perl et Java Runtime 
Environment sont installés, puis démarre Greenstone Librarian Interface.


-- Exécuter GLI sous Unix --

Pour exécuter GLI sous Unix, aller au répertoire GLI de votre installation 
Greenstone et lancer le script gli.sh. Ce script va vérifier que Greenstone, 
Perl et Java Runtime Environment sont installés (assurez-vous qu'ils sont 
dans le chemin de recherche), puis démarre Greenstone Librarian Interface.


Prière de signaler tous problèmes rencontrés lors de l'exécution ou de 
l'utilisation de Librarian Interface à greenstone@cs.waikato.ac.nz.


-- Compiler GLI --

Si vous avez téléchargé la distribution source de Greenstone, ou si vous 
avez obtenu Greenstone à travers SVN, alors vous avez le code source (Java) 
de Librarian Interface. Le compiler requière une version adéquate de Java 
Software Development Kit (version 1.4.0 ou supérieure). Vous pouvez le 
télécharger de http://java.sun.com/j2se/downloads.html

Pour compiler ce code source, exécutez makegli.bat (Windows) ou makegli.sh 
(Unix). Une fois ceci fait, vous pouvez exécuter GLI en suivant les 
instructions ci-dessus.
