' This file is a port to VBScript from VB of the files pptextract.exe, pptextract.frm 
' (and pptextract.vbp, pptextract.vbw), which have been removed after revision 30571.

' It was hard to upgrade the VB pptextract.frm form script in Visual Studio
' to the current Visual Basic, and some packages it needed wouldn't install,
' making it hard to compile up.

' As this VBScript doesn't need to be compiled up, it may be easier to maintain.

' For differences between VBScript and VB, see 
' http://msdn.microsoft.com/en-us/library/ms970436.aspx
' http://www.htmlgoodies.com/beyond/asp/vbs-ref/article.php/3458611/Key-Differences-Between-VB-and-VB-Script.htm
' (Note that VBScript does support reading and writing to files)



'Option Explicit
'Imports PowerPoint = Microsoft.Office.Interop.PowerPoint

' Run as: CScript //Nologo <script> args
' Without using the CScript at the start, it will try to use WScript for which WScript.StdErr is undefined/an invalid handle
' http://stackoverflow.com/questions/774319/why-does-this-vbscript-give-me-an-error
' It appears that the handle StdOut is only available when using a console host (cscript.exe) and not a windowed host (wscript.exe). 
' If you want the code to work, you have to use cscript.exe to run it.

' This is a CScript (console-only). If launched in WScript mode, run as CScript anyway
' From: http://stackoverflow.com/questions/4692542/force-a-vbs-to-run-using-cscript-instead-of-wscript
Sub forceCScriptExecution
    Dim Arg, Str
    If Not LCase( Right( WScript.FullName, 12 ) ) = "\cscript.exe" Then
        For Each Arg In WScript.Arguments
            If InStr( Arg, " " ) Then Arg = """" & Arg & """"
            Str = Str & " " & Arg
        Next
        CreateObject( "WScript.Shell" ).Run _
            "cscript //nologo """ & _
            WScript.ScriptFullName & _
            """ " & Str
        WScript.Quit
    End If
End Sub
forceCScriptExecution

' Where this script actually starts
Dim args
args = WScript.Arguments.Count
If args < 2 Or args > 3 Then
  'WScript.Echo Usage: args.vbs argument [input docx path] [output html path]
  WScript.StdErr.Write ("ERROR. Usage: CScript //Nologo " & WScript.ScriptName & " [input ppt path] [output html path]" & vbCrLf)
  WScript.StdErr.Write ("OR: CScript //Nologo " & WScript.ScriptName & " [-j(pg)/g(if)/p(ng)] [input ppt path] [output img path and filename prefix] " & vbCrLf)
  WScript.Quit
end If

'set ppAPP to a power point application
Dim ppApp 
Set ppApp = CreateObject("PowerPoint.Application")
If CStr(Err.Number) = 429 Then	' 429 is the error code for "ActiveX component can't create object" 
								' http://msdn.microsoft.com/en-us/library/xe43cc8d%28v=VS.85%29.aspx				
	WScript.StdErr.Write ("ERROR: Windows-scripting failed. ppt conversion cannot take place:" & vbCrLf) 
	WScript.StdErr.Write ("   Microsoft Powerpoint cannot be found or cannot be launched. (Error #" & CStr(Err.Number) & ": " & Err.Description & "). " & vbCrLf)		
	WScript.StdErr.Write ("   For converting the latest Office documents, install OpenOffice and Greenstone's OpenOffice extension. (Turn it on and turn off windows-scripting.)" & vbCrLf) 
	WScript.Quit -1 ' http://www.tek-tips.com/viewthread.cfm?qid=1297200
End If

' Declare COM interface constants for PPT File SaveAs types
' http://include.wutils.com/com-dll/constants/constants-PowerPoint.htm
' http://msdn.microsoft.com/en-us/library/ff746500.aspx
  Const ppSaveAsPresentation = 1  '&H1
  Const ppSaveAsPowerPoint7 = 2  '&H2
  Const ppSaveAsPowerPoint4 = 3  '&H3
  Const ppSaveAsPowerPoint3 = 4  '&H4
  Const ppSaveAsTemplate = 5  '&H5
  Const ppSaveAsRTF = 6  '&H6
  Const ppSaveAsShow = 7  '&H7
  Const ppSaveAsAddIn = 8  '&H8
  Const ppSaveAsPowerPoint4FarEast = 10  '&HA
  Const ppSaveAsDefault = 11  '&HB
  Const ppSaveAsHTML = 12  '&HC
  Const ppSaveAsHTMLv3 = 13  '&HD
  Const ppSaveAsHTMLDual = 14  '&HE
  Const ppSaveAsMetaFile = 15  '&HF
  Const ppSaveAsGIF = 16  '&H10
  Const ppSaveAsJPG = 17  '&H11
  Const ppSaveAsPNG = 18  '&H12
  Const ppSaveAsBMP = 19  '&H13
  Const ppSaveAsWebArchive = 20  '&H14
  Const ppSaveAsTIF = 21  '&H15
  Const ppSaveAsPresForReview = 22  '&H16
  Const ppSaveAsEMF = 23  '&H17
  
' Now run the conversion subroutine

If args = 2 Then
PPTtoHTML WScript.Arguments.Item(0),WScript.Arguments.Item(1)
Else
PPTslidesToImgs WScript.Arguments.Item(0),WScript.Arguments.Item(1),WScript.Arguments.Item(2)
End If

' Based on http://stackoverflow.com/questions/12643024/can-i-automatically-convert-ppt-to-html
' AFTER GETTING THIS SCRIPT TO RUN AT LAST, CONVERSION TO HTML STILL DOESN'T WORK, BECAUSE: 
' Although PPT 2010 could still save ppt as html using vb(script), see instructions at http://support.microsoft.com/kb/980553
' for PPT 2013 that doesn't work anymore either. The option to save as html is simply no longer there.
' Maybe we can convert to xml and then to html using a custom xsl stylesheet?
' CONVERSION TO IMAGES SHOULD BE ABLE TO WORK, BUT STILL NEED TO CLEAN UP THAT FUNCTION TO GET THERE
Sub PPTtoHTML(inFile, outHTML)
	'ppApp.Visible = False ' Invalid Request: Hiding the application window is not allowed
	' Open the ppt document
    ppApp.Presentations.Open inFile, 1, 0, 1 ', MsoTriState.msoTrue, MsoTriState.msoFalse, MsoTriState.msoFalse
    Dim prsPres 
	Set prsPres = ppApp.ActivePresentation
    'Call the SaveAs method of Presentation object and specify the format as HTML
    prsPres.SaveAs outHTML, ppSaveAsHTML, 0 ' PowerPoint.PpSaveAsFileType.ppSaveAsHTML, MsoTriState.msoTrue
			' Tristate.msoFalse enum evaluates to 0, see http://msdn.microsoft.com/en-us/library/microsoft.visualbasic.tristate.aspx
    'Close the Presentation object
    prsPres.Close()
    'Close the Application object
    ppApp.Quit()

End Sub

' Porting pptextract.frm Visual Basic form that needs to be compiled to .exe into a VBscript (.vbs)
' Converting PPT slides to images http://vbadud.blogspot.co.nz/2009/05/save-powerpoint-slides-as-images-using.html
' Maybe helpful too: http://stackoverflow.com/questions/13057432/convert-all-worksheet-objects-to-images-in-powerpoint
' http://msdn.microsoft.com/en-us/library/sdbcfyzh.aspx for logical operators
' Like JScript, VBScript uses the FSO to read and write files: http://stackoverflow.com/questions/2198810/creating-and-writing-lines-to-a-file
Sub PPTslidesToImgs(outputType, inFileName, outFileStem)
	' switch statement, http://msdn.microsoft.com/en-us/library/6ef9w614%28v=vs.84%29.aspx
	'WScript.StdErr.Write ("Output stem: " & outFileStem & vbCrLf)
	
	Dim fso
    Set fso = CreateObject("Scripting.FileSystemObject")
	
	Dim outputDir, itemFile
	
	outputDir = outFileStem 'outputDir = Left(outFileStem, InStrRev(outFileStem, "\")) ' outputDir = substring upto final \, no need to escape \ in vbscript	
	itemFile = Mid(outFileStem, InStrRev(outFileStem, "\")+1)
	
	'WScript.StdErr.Write ("outputDir: " & outFileStem & vbCrLf)	
	
	If Not fso.FolderExists(outputDir) Then
       fso.CreateFolder(outputDir)  
	Else 
		WScript.StdErr.Write ("**** Folder " & outputDir & " Already exists" &vbCrLf)	
    End If	
	
	Select Case outputType	
		Case "-g"     outputType = "gif"
		Case "-gif"   outputType = "gif"
		Case "gif"    outputType = "gif"
		Case "-j"     outputType = "jpg"
		Case "-jpg"   outputType = "jpg"
		Case "jpg"    outputType = "jpg"
		Case "-p"     outputType = "png"
		Case "-png"   outputType = "png"
		Case "png"    outputType = "png"
		'Case "htm"
		'Not developed for converting to html yet
		'Currently, if the user choose to convert the PPT to the html file
		'We will only allow users to use the open source method through Greenstone		
	End Select

	
	'generate document_name.item file
	itemFile = outFileStem + "\" + itemFile + ".item"
	
	'Set item = fso.CreateTextFile(itemFile, 2, True) ' ForWriting = 2, default is Unicode = -1, see http://msdn.microsoft.com/en-us/library/314cz14s%28v=vs.84%29.aspx
    ' The default file-write methods in VBScript all create UTF16 Little Endian (USC-2LE) files like Notepad's default, rather than the UTF-8 we want
	' Writing out to a file in UTF-8 is achieved as at: http://stackoverflow.com/questions/10450156/write-text-file-in-appending-utf-8-encoded-in-vb6	
	Dim item
	Set item = CreateObject("ADODB.Stream")
	item.CharSet = "utf-8"
	item.Open
	
 	'WScript.StdErr.Write ("itemFile: " & itemFile & vbCrLf)


'do stuff
    Dim objPA
    Set objPA = CreateObject("PowerPoint.Application")
    objPA.Visible = True
    
    Dim objPPTs
    Set objPPTs = objPA.Presentations
    objPPTs.Open (inFileName)
	
	item.WriteText "<PagedDocument>", 1
	
    n = 1
    Dim slide_shape
    For slide_count = 1 To objPPTs(1).Slides.Count
        current_slide = objPPTs(1).Slides(slide_count).Name
        'generate a text version
        'Set text = fso.CreateTextFile(outputDir + "\Slide" + CStr(slide_count) + ".txt", ForWriting, True)
		Dim text
		Set text = CreateObject("ADODB.Stream") ' http://stackoverflow.com/questions/10450156/write-text-file-in-appending-utf-8-encoded-in-vb6
		text.CharSet = "utf-8"
		text.Open
        If (objPPTs(1).Slides(slide_count).Shapes.HasTitle) Then
            slide_title = objPPTs(1).Slides(slide_count).Shapes.Title.TextFrame.TextRange
        Else
            slide_title = objPPTs(1).Slides(slide_count).Name
        End If
        slide_text = ""
        found_text = True
        For iShape = 1 To objPPTs(1).Slides(slide_count).Shapes.Count
            If (objPPTs(1).Slides(slide_count).Shapes(iShape).TextFrame.HasText) Then
                slide_text = objPPTs(1).Slides(slide_count).Shapes(iShape).TextFrame.TextRange.text
                'MsgBox ("Slide_text:" + slide_text)
                If slide_text <> "" Then
                    text.WriteText slide_text, 1
                Else
                    text.WriteText "This slide has no text", 1
                End If
            End If
        Next
        text_file = outputDir + "\Slide" + CStr(slide_count) + ".txt"
        text.SaveToFile text_file, 2 ' http://stackoverflow.com/questions/10450156/write-text-file-in-appending-utf-8-encoded-in-vb6
        text.Close
        
        If objPPTs(1).Slides.Count >= 1 And slide_count < objPPTs(1).Slides.Count Then
            next_slide = objPPTs(1).Slides(slide_count + 1).Name
        Else
            nextf = " "
        End If
		
		' For the gif, png, jpg files:
		current_slide = "Slide" + CStr(n)
		If nextf <> " " Then
			nextf = outputDir + "\" + "Slide" + CStr(n + 1)
		End If
		prevhtml = outputDir + "\" + current_slide + "." + outputType
		If slide_text = "" Then
		   itemxml item, current_slide + "." + outputType, "", n, slide_title
		Else
		   itemxml item, current_slide + "." + outputType, current_slide + ".txt", n, slide_title
		End If
		
        n = n + 1
        item.WriteText "   </Page>", 1
    Next
    i = 0
	Select Case outputType
		'Case "htm" 'ppts(1).SaveAs outputDir, ppSaveAsHTMLv3
		Case "gif" objPPTs(1).SaveAs outputDir, ppSaveAsGIF
		Case "jpg" objPPTs(1).SaveAs outputDir, ppSaveAsJPG
		Case "png" objPPTs(1).SaveAs outputDir, ppSaveAsPNG
	End Select
                
    item.WriteText "</PagedDocument>", 1
	
	item.SaveToFile itemFile, 2 ' http://stackoverflow.com/questions/10450156/write-text-file-in-appending-utf-8-encoded-in-vb6
	item.Close
	
	objPPTs(1).Close
    Set fso = Nothing
    Set text = Nothing
    Set item = Nothing
    objPA.Quit
End Sub



Sub itemxml(out_item, thisfile, txtfile, num, slide_title)
    out_item.WriteText "   <Page pagenum=" + Chr(34) + CStr(num) + Chr(34) + " imgfile=" + Chr(34) + thisfile + Chr(34) + " txtfile=" + Chr(34) + txtfile + Chr(34) + ">", 1    
    If slide_title <> "" Then
        out_item.WriteText "      <Metadata name=" + Chr(34) + "Title" + Chr(34) + ">" + slide_title + "</Metadata>", 1
        'MsgBox ("Title:" + slide_title)        
    End If
End Sub