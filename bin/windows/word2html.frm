VERSION 5.00
Begin VB.Form Form1 
   Caption         =   "Form1"
   ClientHeight    =   1380
   ClientLeft      =   60
   ClientTop       =   450
   ClientWidth     =   3825
   LinkTopic       =   "Form1"
   ScaleHeight     =   1380
   ScaleWidth      =   3825
   StartUpPosition =   3  'Windows Default
   Begin VB.Label W 
      Alignment       =   2  'Center
      Caption         =   "Word to HTML"
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   24
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   615
      Left            =   360
      TabIndex        =   0
      Top             =   360
      Width           =   3375
   End
End
Attribute VB_Name = "Form1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False

Private Sub Form_Load()
    'For solving the backward compatability of MS Automation with VB script
    'We need to use the late binding technique, in which mean that we need to
    'define all Office Automation variable as an Object first and it can then
    'to decide the office version at run-tim.
    
    'Creat a Word Application
    Dim objWA As Object
    Set objWA = CreateObject("Word.Application")
    objWA.Visible = True
    
    Dim cmdln As String
    Dim src As String
    Dim dst As String
       
    cmdln = LCase(Command())
    'MsgBox ("Command:" + cmdln)
    'cmdln = Chr(34) & "H:\chi\gsdl\collect\WordTest\import\word03_01.doc" & Chr(34) & Chr(34) & "H:\chi\gsdl\collect\WordTest\tmp\word03_01.html" & Chr(34)
    src = Trim(Left(cmdln, (InStr(cmdln, ".doc") + 4)))
    src = Mid(src, 2, Len(src) - 2)
    'MsgBox ("Src:" + src)
    If InStr(src, ":") <> 2 Then src = CurDir + "\" + src
    dst = Trim(Right(cmdln, Len(cmdln) - (InStr(cmdln, ".doc") + 4)))
    dst = Mid(dst, 2, Len(dst) - 2)
    If InStr(dst, ":") <> 2 Then dst = CurDir + "\" + dst
        
    
    'Create a Word Document Object and Open a Word Document
    Dim objWD As Object
    Set objWD = objWA.Documents
    
    objWD.Open (src)
    objWD(1).SaveAs dst, wdFormatHTML
    objWD(1).Close

    ' Quite Word Application
    objWA.Quit
    
    'Release Objects
    Set objWA = Nothing
    Set objWD = Nothing

    End
End Sub
Function getoutput(line)
    cmdln = line
    While InStr(cmdln, ".ppt")
        cmdln = LTrim(Right(cmdln, Len(cmdln) - (InStr(cmdln, ".ppt") + 3)))
    Wend
    If Right(CurDir, 1) = "\" Then cmdln = CurDir + cmdln Else cmdln = CurDir + "\" + cmdln
    If LTrim(cmdln) = "" Then cmdln = cmdln + "out"
    If Right(cmdln, 1) <> "\" Then cmdln = cmdln + "\"
    getoutput = cmdln
End Function

Function getargs(line)
    x = LTrim(line)
    If InStr(x, "-") = 1 Then
        getargs = Left(line, InStr(line, " "))
    End If
End Function

Function getdir(line)
    x = LTrim(Right(line, Len(line) - Len(getargs(line))))
    If InStr(x, ":") <> 2 Then
        direc = CurDir
        If Right(direc, 1) <> "\" Then direc = direc + "\"
    End If
    
    While InStr(x, "\")
        direc = direc + Left(x, InStr(x, "\"))
        x = Right(x, Len(x) - InStr(x, "\"))
    Wend
    getdir = direc
End Function

Function getfile(line)
    x = LTrim(Right(line, Len(line) - Len(getargs(line))))
    While InStr(x, "\")
        x = Right(x, Len(x) - InStr(x, "\"))
    Wend
    getfile = x
End Function
