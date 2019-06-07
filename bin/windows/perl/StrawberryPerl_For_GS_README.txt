
README
Strawberry Perl 5.18.2.2 modified for Greenstone
"32bit PortableZIP edition (no USE_64_BIT_INT) version"
__________________________________________________

26 July 2016

Because of the fix that Georgy Litvinov needed to make to deal with surrogate pair/invalid UTF-8 errors when processing some PDFs, this left warnings being printed out when using perl 5.8 to build any GS collections. Moreover, perl 5.8 was too old to handle the fix and would print out errors on documents that had such problematic characters. We found perl 5.16 could cope. However, we had to move to Strawberry since Active Perl would only offer the latest versions of perl (5.24 at the time of writing) for free. We had to shift to perl 5.18 since that's the perl version installed on Mac OS Yosemite, and we wanted to keep our other GS systems in sync with that.

We downloaded StrawBerry Perl from "5.18.2.1" "32bit PortableZIP edition (no USE_64_BIT_INT)" from http://strawberryperl.com/releases.html
( http://strawberryperl.com/download/5.18.2.1/strawberry-perl-no64-5.18.2.1-32bit-portable.zip )

Versions 5.18.4 and 5.18.2.1, although available, were problematic. Their perl executables for the "32bit PortableZIP edition (no USE_64_BIT_INT)" versions came up as having Trojans in them as per Symantec endpoint protection. So we shifted to the previous version: 5.18.2.1.


Strawberry Perl is a Perl for Windows.

After unzipping the download, the README file says:
  If you want to use Strawberry Perl Portable not only from portableshell.bat,
  add c:\myperl\perl\site\bin, c:\myperl\perl\bin, and c:\myperl\c\bin
  to PATH variable

(where myperl is the folder into which StrawberryPerl was extracted)
  
perl\site\bin is empty. In fact, all of perl\site is empty except for subfolders. So there's no need to add this to the PATH.

It was however initially necessary to add c\bin to the PATH to get GLI to launch and build a collection. But there are several locations in Greenstone that make use of perl\bin, such as build.xml's perl-for-building target. As changing all of them to include c\bin as well may get complicated, the solution now is to merge the extracted perl's c\bin subfolder with the extracted perl's perl\bin subfolder. The .dll, .config and .bat files from c\bin seem enough (leaving out .exe), although so far it seems that c\bin\libexpat-1_.dll on its own suffices for running GLI and building. Neverthless, we're merging all dll files of c\bin into perl\bin, in case any of the other dlls there may be needed (such as libexslt-0_.dll).


This produces the cut-down version of Strawberry Perl 5.18.4 for Greenstone that we're now using since 26 July 2016.
