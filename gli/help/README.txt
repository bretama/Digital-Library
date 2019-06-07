The following notes talk about the English version of the help. They can be adapted for the other languages by substituting the appropriate two-letter code for 'en'.

en/help.xml is the main help file. This is the file that should be edited when modifying the help.

After the XML file has been modified, the HTML versions and index need to be regenerated. This uses XSLT to transform the XML into HTML.

The generate-html.sh script will do this for English. Just run this script in this directory (gli/help). This generates help_index.xml, and *.htm, one page per section of help.

If you want to do it on Windows or for other languages, you'll need to modify the script.
