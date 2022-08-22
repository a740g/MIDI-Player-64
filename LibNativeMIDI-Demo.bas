'-----------------------------------------------------------------------------------------------------
' LibNativeMIDI Demo
' Copyright (c) 2022 Samuel Gomes
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------
'$Include:'./LibNativeMIDI.bi'
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' CONSTANTS
'-----------------------------------------------------------------------------------------------------
Const APP_NAME = "LibNativeMIDI Player Demo"
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' GLOBAL VARIABLES
'-----------------------------------------------------------------------------------------------------
Dim Shared Volume As Single
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' PROGRAM ENTRY POINT
'-----------------------------------------------------------------------------------------------------
Title APP_NAME + " " + OS$ ' Set app title to the way it was
ChDir StartDir$ ' Change to the directory specifed by the environment
AcceptFileDrop ' Enable drag and drop of files
AllowFullScreen SquarePixels , Smooth ' All the user to press Alt+Enter to go fullscreen
Volume = 1 ' Set initial volume as 100%

ProcessCommandLine ' Check if any files were specified in the command line

Dim k As Long

' Main loop
Do
    Cls
    Print APP_NAME
    Print "-------------------------"
    Print
    Print "DRAG AND DROP MULTIPLE MOD FILES ON THIS WINDOW TO PLAY THEM SEQUENTIALLY."
    Print "YOU CAN ALSO START THE PROGRAM WITH MULTIPLE FILES FROM THE COMMAND LINE."
    Print "THIS WAS WRITTEN IN QB64 AND THE SOURCE CODE IS AVAILABLE ON GITHUB."
    Print "https://github.com/a740g/QB64-LibNativeMIDI"

    Do
        k = KeyHit
        Limit 15
    Loop Until k <> 0 Or TotalDroppedFiles > 0

    ProcessDroppedFiles
Loop Until k = 27

If MIDI_Play(Chr$(0), 0) Then
    Print: Print "LibNativeMIDI shutdown successfully."
End If

End
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' FUNCTIONS & SUBROUTINES
'-----------------------------------------------------------------------------------------------------
' Initializes, loads and plays a MIDI file
' Also checks for input, shows info etc
Sub PlaySong (fileName As String)
    Dim As Single startTime, currentTime, elapsedTime

    startTime = Timer
    If Not MIDI_Play(fileName + Chr$(0), 1) Then ' We want the MIDI file to loop just once
        Print: Print "Failed to load "; fileName; "!"
        Exit Sub
    End If

    ' Set the app title to display the file name
    Title APP_NAME + " - " + GetFileNameFromPath(fileName)

    Print: Print "Playing "; GetFileNameFromPath(fileName); " (press ESC to stop, SPC to pause, +/- for volume)..."

    Dim As String minute, second, sPaused
    Dim k As Long, paused As Byte

    Do
        currentTime = Timer
        If startTime > currentTime Then startTime = startTime - 86400
        elapsedTime = currentTime - startTime

        Locate , 1
        minute = Right$("00" + LTrim$(Str$(elapsedTime \ 60)), 2)
        second = Right$("00" + LTrim$(Str$(elapsedTime Mod 60)), 2)
        If paused Then sPaused = "Paused " Else sPaused = "Playing"
        Print Using "Elapsed time: &:& (mm:ss) | Volume = ###% | &"; minute; second; Volume * 100; sPaused;

        k = KeyHit

        Select Case k
            Case 32
                paused = Not paused
                If paused Then
                    MIDI_Pause
                Else
                    MIDI_Resume
                End If

            Case 43, 61
                Volume = Volume + 0.01
                If Volume > 1 Then Volume = 1
                MIDI_SetVolume Volume

            Case 45, 95
                Volume = Volume - 0.01
                If Volume < 0 Then Volume = 0
                MIDI_SetVolume Volume
        End Select

        Limit 15
    Loop Until Not MIDI_IsPlaying Or k = 27 Or TotalDroppedFiles > 0

    Print: Print "Done!"

    MIDI_Pause

    KeyClear

    Title APP_NAME + " " + OS$ ' Set app title to the way it was
End Sub

' Processes dropped files one file at a time
Sub ProcessDroppedFiles
    If TotalDroppedFiles > 0 Then
        ' Make a copy of the dropped file and clear the list
        ReDim fileNames(1 To TotalDroppedFiles) As String
        Dim i As Unsigned Long

        For i = 1 To TotalDroppedFiles
            fileNames(i) = DroppedFile(i)
        Next
        FinishDrop ' This is critical

        ' Now play the dropped file one at a time
        For i = LBound(fileNames) To UBound(fileNames)
            PlaySong fileNames(i)
            If TotalDroppedFiles > 0 Then Exit For ' Exit the loop if we have dropped files
        Next
    End If
End Sub


' Processes the command line one file at a time
Sub ProcessCommandLine
    Dim i As Unsigned Long

    For i = 1 To CommandCount
        PlaySong Command$(i)
        If TotalDroppedFiles > 0 Then Exit For ' Exit the loop if we have dropped files
    Next
End Sub

' Gets the filename portion from a file path
Function GetFileNameFromPath$ (pathName As String)
    Dim i As Unsigned Long

    ' Retrieve the position of the first / or \ in the parameter from the
    For i = Len(pathName) To 1 Step -1
        If Asc(pathName, i) = 47 Or Asc(pathName, i) = 92 Then Exit For
    Next

    ' Return the full string if pathsep was not found
    If i = 0 Then
        GetFileNameFromPath = pathName
    Else
        GetFileNameFromPath = Right$(pathName, Len(pathName) - i)
    End If
End Function
'-----------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------
