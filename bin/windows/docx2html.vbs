Option Explicit

' http://www.robvanderwoude.com/vbstech_automation_word.php
' http://www.nilpo.com/2008/06/windows-scripting/reading-word-documents-in-wsh/ - for grabbing just the text (cleaned of Word mark-up) from a doc(x)
' http://msdn.microsoft.com/en-us/library/3ca8tfek%28v=VS.85%29.aspx - VBScript Functions (CreateObject etc)
' http://msdn.microsoft.com/en-us/library/aa220734%28v=office.11%29.aspx - SaveAs Method. Expand "WdSaveFormat" section to see all the default filetypes Office 2003+ can save as

' Error Handling:
' http://blogs.msdn.com/b/ericlippert/archive/2004/08/19/error-handling-in-vbscript-part-one.aspx
' http://msdn.microsoft.com/en-us/library/53f3k80h%28v=VS.85%29.aspx 


' To Do:
' +1. error output on bad input to this file. And commit.
' +1b. Active X error msg when trying to convert normal *.doc: only when windows scripting is on and Word not installed.
' +1c. Make docx accepted by default as well. Changed WordPlugin.
' 2. Try converting from other office types (xlsx, pptx) to html. They may use other constants for conversion filetypes
' 3. gsConvert.pl's any_to_txt can be implemented for docx by getting all the text contents. Use a separate subroutine for this. Or use wdFormatUnicodeText as outputformat.
' 4. Try out this script on Windows 7 to see whether WSH is active by default, as it is on XP and Vista.
' 5. What kind of error occurs if any when user tries to convert docx on a machine with an old version of Word (pre-docx/pre-Word 2007)?
' 6. Ask Dr Bainbridge whether this script can or shouldn't replace word2html, since this can launch all versions of word (not just 2007) I think. 
' Unless some commands have changed? Including for other Office apps, in which case word2html would remain the correct program to use for those cases.


' gsConvert.pl expects error output to go to the console's STDERR 
' for which we need to launch this vbs with "CScript //Nologo" '(cannot use WScript if using StdErr
' and //Nologo is needed to repress Microsoft logo text output which messes up error reporting)
' http://www.devguru.com/technologies/wsh/quickref/wscript_StdErr.html
Dim objStdErr, args
Set objStdErr = WScript.StdErr

args = WScript.Arguments.Count
If args < 2 then
  'WScript.Echo Usage: args.vbs argument [input docx path] [output html path]
  objStdErr.Write ("ERROR. Usage: CScript //Nologo " & WScript.ScriptName & " [input office doc path] [output html path]" & vbCrLf)
  WScript.Quit
end If

' Now run the conversion subroutine
Doc2HTML WScript.Arguments.Item(0),WScript.Arguments.Item(1)
	' In terminal, run as: > docx2html.vbs C:\fullpath\to\input.docx C:\fullpath\to\output.html
	' In terminal, run as: > CScript //Nologo docx2html.vbs C:\fullpath\to\input.docx C:\fullpath\to\output.html
	' if you want echoed error output to go to console (instead of creating a popup) and to avoid 2 lines of MS logo.
	' Will be using WScript.StdErr object to make error output go to stderr of CScript console (can't launch with WScript).
	' http://www.devguru.com/technologies/wsh/quickref/wscript_StdErr.html


Sub Doc2HTML( inFile, outHTML )
' This subroutine opens a Word document,
' then saves it as HTML, and closes Word.
' If the HTML file exists, it is overwritten.
' If Word was already active, the subroutine
' will leave the other document(s) alone and
' close only its "own" document.
'
' Written by Rob van der Woude
' http://www.robvanderwoude.com
    ' Standard housekeeping
    Dim objDoc, objFile, objFSO, objWord, strFile

    Const wdFormatDocument                    =  0
    Const wdFormatDocument97                  =  0
    Const wdFormatDocumentDefault             = 16
    Const wdFormatDOSText                     =  4
    Const wdFormatDOSTextLineBreaks           =  5
    Const wdFormatEncodedText                 =  7
    Const wdFormatFilteredHTML                = 10
    Const wdFormatFlatXML                     = 19
    Const wdFormatFlatXMLMacroEnabled         = 20
    Const wdFormatFlatXMLTemplate             = 21
    Const wdFormatFlatXMLTemplateMacroEnabled = 22
    Const wdFormatHTML                        =  8
    Const wdFormatPDF                         = 17
    Const wdFormatRTF                         =  6
    Const wdFormatTemplate                    =  1
    Const wdFormatTemplate97                  =  1
    Const wdFormatText                        =  2
    Const wdFormatTextLineBreaks              =  3
    Const wdFormatUnicodeText                 =  7
    Const wdFormatWebArchive                  =  9
    Const wdFormatXML                         = 11
    Const wdFormatXMLDocument                 = 12
    Const wdFormatXMLDocumentMacroEnabled     = 13
    Const wdFormatXMLTemplate                 = 14
    Const wdFormatXMLTemplateMacroEnabled     = 15
    Const wdFormatXPS                         = 18
	
    ' Create a File System object
    Set objFSO = CreateObject( "Scripting.FileSystemObject" )

    ' Create a Word object. Exit with error msg if not possible (such as when Word is not installed)
	On Error Resume Next
    Set objWord = CreateObject( "Word.Application" )
	If CStr(Err.Number) = 429 Then	' 429 is the error code for "ActiveX component can't create object" 
									' http://msdn.microsoft.com/en-us/library/xe43cc8d%28v=VS.85%29.aspx		
		'WScript.Echo "Microsoft Word cannot be found -- document conversion cannot take place. Error #" & CStr(Err.Number) & ": " & Err.Description & "." & vbCrLf
		objStdErr.Write ("ERROR: Windows-scripting failed. Document conversion cannot take place:" & vbCrLf) 
		objStdErr.Write ("   Microsoft Word cannot be found or cannot be launched. (Error #" & CStr(Err.Number) & ": " & Err.Description & "). " & vbCrLf)		
		objStdErr.Write ("   For converting the latest Office documents, install OpenOffice and Greenstone's OpenOffice extension. (Turn it on and turn off windows-scripting.)" & vbCrLf) 
		Exit Sub
	End If

    With objWord
        ' True: make Word visible; False: invisible
        .Visible = False

        ' Check if the Word document exists
        If objFSO.FileExists( inFile ) Then
            Set objFile = objFSO.GetFile( inFile )
            strFile = objFile.Path
        Else
            'WScript.Echo "FILE OPEN ERROR: The file does not exist" & vbCrLf
            objStdErr.Write ("ERROR: Windows-scripting failed. Cannot open " & inFile & ". The file does not exist. ")
            ' Close Word
            .Quit
            Exit Sub
        End If

        'outHTML = objFSO.BuildPath( objFile.ParentFolder, _
        '          objFSO.GetBaseName( objFile ) & ".html" )

        ' Open the Word document
        .Documents.Open strFile

        ' Make the opened file the active document
        Set objDoc = .ActiveDocument

        ' Save as HTML -- http://msdn.microsoft.com/en-us/library/aa220734%28v=office.11%29.aspx
        objDoc.SaveAs outHTML, wdFormatFilteredHTML

        ' Close the active document
        objDoc.Close

        ' Close Word
        .Quit
    End With
End Sub 