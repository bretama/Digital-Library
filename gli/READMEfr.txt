L'Interface du Biblioth�caire de Greenstone (Greenstone Librarian Interface)
----------------------------------------------------------------------------

Ce dossier contient l'Interface du Biblioth�caire de Greenstone - Greenstone 
Librarian Interface (GLI), un outil qui vous assiste pour la cr�ation de 
biblioth�ques num�rique avec Greenstone. GLI vous donne acc�s aux fonctions 
de Greenstone � partir d'une interce 'pointer et cliquer' facile � utiliser.

Pour utiliser GLI, vous avez besoin d'une version ad�quate de Java Runtime 
Environment (version 1.4.0 ou sup�rieure). Si vous n'en disposez pas, vous 
pouvez le t�l�charger de http://java.sun.com/j2se/downloads.html

Notez que GLI est lanc� avec Greenstone et suppose qu'il est install� dans 
un sous-r�pertoire de votre installation Greenstone. Si vous avez t�l�charg� 
une des distributions de Greenstone ou si vous avez install� � partir d'un 
CD-ROM, ceci sera le cas.


-- Ex�cuter GLI sous Windows --

Pour ex�cuter GLI sous Windows, parcourez votre syst�me de fichiers jusqu'au 
r�pertoire GLI (en utilisant Windows Explorer), et double-cliquez sur le 
fichier gli.bat. Ce fichier va v�rifier que Greenstone, Perl et Java Runtime 
Environment sont install�s, puis d�marre Greenstone Librarian Interface.


-- Ex�cuter GLI sous Unix --

Pour ex�cuter GLI sous Unix, aller au r�pertoire GLI de votre installation 
Greenstone et lancer le script gli.sh. Ce script va v�rifier que Greenstone, 
Perl et Java Runtime Environment sont install�s (assurez-vous qu'ils sont 
dans le chemin de recherche), puis d�marre Greenstone Librarian Interface.


Pri�re de signaler tous probl�mes rencontr�s lors de l'ex�cution ou de 
l'utilisation de Librarian Interface � greenstone@cs.waikato.ac.nz.


-- Compiler GLI --

Si vous avez t�l�charg� la distribution source de Greenstone, ou si vous 
avez obtenu Greenstone � travers SVN, alors vous avez le code source (Java) 
de Librarian Interface. Le compiler requi�re une version ad�quate de Java 
Software Development Kit (version 1.4.0 ou sup�rieure). Vous pouvez le 
t�l�charger de http://java.sun.com/j2se/downloads.html

Pour compiler ce code source, ex�cutez makegli.bat (Windows) ou makegli.sh 
(Unix). Une fois ceci fait, vous pouvez ex�cuter GLI en suivant les 
instructions ci-dessus.
