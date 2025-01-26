'-----------------------------------------------------------------------------------------------------------------------
' QB64-PE MIDI Player
' Copyright (c) 2024 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------------------------
'$INCLUDE:'include/GraphicOps.bi'
'$INCLUDE:'include/Pathname.bi'
'$INCLUDE:'include/StringOps.bi'
'$INCLUDE:'include/ImGUI.bi'
'$INCLUDE:'include/MIDIPlayer.bi'
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' METACOMMANDS
'-----------------------------------------------------------------------------------------------------------------------
$VERSIONINFO:CompanyName='Samuel Gomes'
$VERSIONINFO:FileDescription='MIDI Player 64 executable'
$VERSIONINFO:InternalName='MIDIPlayer64'
$VERSIONINFO:LegalCopyright='Copyright (c) 2024, Samuel Gomes'
$VERSIONINFO:LegalTrademarks='All trademarks are property of their respective owners'
$VERSIONINFO:OriginalFilename='MIDIPlayer64.exe'
$VERSIONINFO:ProductName='MIDI Player 64'
$VERSIONINFO:Web='https://github.com/a740g'
$VERSIONINFO:Comments='https://github.com/a740g'
$VERSIONINFO:FILEVERSION#=3,0,0,0
$VERSIONINFO:PRODUCTVERSION#=3,0,0,0
$EXEICON:'./MIDIPlayer64.ico'
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' CONSTANTS
'-----------------------------------------------------------------------------------------------------------------------
CONST APP_NAME = "MIDI Player 64"

CONST SCREEN_WIDTH& = 640&
CONST SCREEN_HEIGHT& = 400&

CONST FRAME_COLOR~& = _RGBA32(0, 0, 0, 128)
CONST FRAME_BORDER_WIDTH_X& = 48&
CONST FRAME_BORDER_WIDTH_Y& = 64&

CONST BUTTON_FONT& = 14&
CONST BUTTON_WIDTH& = 78&
CONST BUTTON_HEIGHT& = 32&
CONST BUTTON_GAP& = 8&
CONST BUTTON_COUNT& = 6&
CONST BUTTON_X& = SCREEN_WIDTH \ 2& - (BUTTON_WIDTH * BUTTON_COUNT + BUTTON_GAP * (BUTTON_COUNT - 1)) \ 2&
CONST BUTTON_Y& = SCREEN_HEIGHT - (FRAME_BORDER_WIDTH_X + BUTTON_HEIGHT) \ 2&

CONST VOLUME_TEXT_X& = (SCREEN_WIDTH - 4& * 8&) \ 2&
CONST VOLUME_TEXT_Y& = (SCREEN_HEIGHT \ 2&) + (BUTTON_FONT * 4&)

CONST BUTTON_VOLUME_M_X& = VOLUME_TEXT_X - BUTTON_GAP * 2& - BUTTON_HEIGHT
CONST BUTTON_VOLUME_P_X& = VOLUME_TEXT_X + 4& * 8& + BUTTON_GAP * 2&
CONST BUTTON_VOLUME_Y& = VOLUME_TEXT_Y - (BUTTON_HEIGHT - BUTTON_FONT) \ 2&

CONST REEL_COLOR~& = BGRA_WHITE
CONST REEL_RADIUS& = 37&
CONST REEL_LEFT_X& = 190&
CONST REEL_RIGHT_X& = 446&
CONST REEL_Y& = 184&

CONST WP_DIV& = 8&
CONST WP_WIDTH& = SCREEN_WIDTH \ WP_DIV
CONST WP_HEIGHT& = SCREEN_HEIGHT \ WP_DIV

CONST TITLE_WIDTH& = SCREEN_WIDTH - FRAME_BORDER_WIDTH_Y * 3&
CONST TITLE_CHARS& = TITLE_WIDTH \ 8&
CONST TITLE_X& = (FRAME_BORDER_WIDTH_Y * 3&) \ 2&
CONST TITLE_Y& = BUTTON_FONT * 2& + FRAME_BORDER_WIDTH_X

CONST TIME_X& = (SCREEN_WIDTH - 13& * 8&) \ 2&
CONST TIME_Y& = (SCREEN_HEIGHT \ 2&) - (BUTTON_FONT * 2&)

CONST PLAY_ICON_X& = (SCREEN_WIDTH - 1& * 8&) \ 2&
CONST PLAY_ICON_Y& = (SCREEN_HEIGHT \ 2&)

CONST FRAME_RATE_MAX& = 60&

$IF WINDOWS THEN
    CONST MIDI_FILE_FILTERS = "*.mus|*.rmi|*.mid|*.midi|*.xmi"
$ELSE
    CONST MIDI_FILE_FILTERS = "*.mus|*.rmi|*.mid|*.midi|*.xmi|*.MUS|*.RMI|*.MID|*.MIDI|*.XMI|*.Mus|*.Rmi|*.Mid|*.Midi|*.Xmi"
$END IF

' Program events
CONST EVENT_NONE%% = 0%% ' idle
CONST EVENT_QUIT%% = 1%% ' user wants to quit
CONST EVENT_CMDS%% = 2%% ' process command line
CONST EVENT_LOAD%% = 3%% ' user want to load files
CONST EVENT_DROP%% = 4%% ' user dropped files
CONST EVENT_PLAY%% = 5%% ' play next song
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' USER DEFINED TYPES
'-----------------------------------------------------------------------------------------------------------------------
TYPE UIType ' bunch of UI widgets to change stuff
    cmdOpen AS LONG ' open dialog box button
    cmdPlayPause AS LONG ' play / pause button
    cmdNext AS LONG ' next tune button
    cmdIncVolume AS LONG ' increase volume button
    cmdDecVolume AS LONG ' decrease volume button
    cmdRepeat AS LONG ' repeat enable / disable button
    cmdPort AS LONG ' select MIDI port button
    cmdAbout AS LONG ' shows an about dialog
END TYPE

TYPE PlaySessionInfoType
    tuneTitle AS STRING ' song name
    mm AS _UNSIGNED LONG ' total minutes
    ss AS _UNSIGNED LONG ' total seconds
    format AS STRING ' file format
    port AS _UNSIGNED LONG ' port number being used
    portName AS STRING ' port name being used
END TYPE
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' GLOBAL VARIABLES
'-----------------------------------------------------------------------------------------------------------------------
DIM SHARED BackgroundImage AS LONG ' the CC image that we will use for the background
DIM SHARED UI AS UIType ' user interface controls
DIM SHARED PlaySessionInfo AS PlaySessionInfoType ' info that remains constant for a single playback session
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' PROGRAM ENTRY POINT
'-----------------------------------------------------------------------------------------------------------------------
InitProgram

DIM event AS _BYTE: event = EVENT_CMDS ' default to command line event first

' Main loop
DO
    SELECT CASE event
        CASE EVENT_QUIT
            EXIT DO

        CASE EVENT_DROP
            event = ProcessDroppedFiles

        CASE EVENT_LOAD
            event = OnSelectedFiles

        CASE EVENT_CMDS
            event = OnCommandLine

        CASE ELSE
            event = OnWelcomeScreen
    END SELECT
LOOP UNTIL event = EVENT_QUIT

_AUTODISPLAY
WidgetFreeAll
_FREEIMAGE BackgroundImage
SYSTEM
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' FUNCTIONS & SUBROUTINES
'-----------------------------------------------------------------------------------------------------------------------
' Draws a frame around the screen
SUB DrawFrame
    Graphics_DrawFilledRectangle 0, 0, SCREEN_WIDTH - 1, FRAME_BORDER_WIDTH_X - 1, FRAME_COLOR
    Graphics_DrawFilledRectangle 0, SCREEN_HEIGHT - FRAME_BORDER_WIDTH_X, SCREEN_WIDTH - 1, SCREEN_HEIGHT - 1, FRAME_COLOR
    Graphics_DrawFilledRectangle 0, FRAME_BORDER_WIDTH_X, FRAME_BORDER_WIDTH_Y - 1, SCREEN_HEIGHT - FRAME_BORDER_WIDTH_X - 1, FRAME_COLOR
    Graphics_DrawFilledRectangle SCREEN_WIDTH - FRAME_BORDER_WIDTH_Y, FRAME_BORDER_WIDTH_X, SCREEN_WIDTH - 1, SCREEN_HEIGHT - FRAME_BORDER_WIDTH_X - 1, FRAME_COLOR
END SUB


' Draws one cassette reel
SUB DrawReel (x AS LONG, y AS LONG, a AS LONG)
    STATIC drawCmds AS STRING, clr AS _UNSIGNED LONG
    STATIC AS LONG angle, xp, yp

    ' These must be copied to static variables for VARPTR$ to work correctly
    angle = a
    xp = x
    yp = y
    clr = REEL_COLOR

    ' We'll setup the DRAW commands just once to a STATIC string
    IF LEN(drawCmds) = 0 THEN drawCmds = "C=" + VARPTR$(clr) + "BM=" + VARPTR$(xp) + ",=" + VARPTR$(yp) + "TA=" + VARPTR$(angle) + "BU35BR1D10L1U10L1D10"

    ' Faster with unrolled loop
    DRAW drawCmds
    angle = angle + 45
    DRAW drawCmds
    angle = angle + 45
    DRAW drawCmds
    angle = angle + 45
    DRAW drawCmds
    angle = angle + 45
    DRAW drawCmds
    angle = angle + 45
    DRAW drawCmds
    angle = angle + 45
    DRAW drawCmds
    angle = angle + 45
    DRAW drawCmds
    Graphics_DrawCircle xp, yp, REEL_RADIUS, clr
    Graphics_DrawCircle xp, yp, REEL_RADIUS - 1, clr
END SUB


' Draws both reels at correct locations and manages rotation
SUB DrawReels
    STATIC angle AS _UNSIGNED LONG

    DrawReel REEL_LEFT_X, REEL_Y, angle
    DrawReel REEL_RIGHT_X, REEL_Y, angle

    IF NOT MIDI_IsPaused THEN angle = angle + 1
END SUB


' This draws everything to the screen
SUB DrawScreen
    CLS , 0 ' clear screen with black with no alpha
    DrawWeirdPlasma
    _PUTIMAGE , BackgroundImage
    DrawReels
    DrawFrame

    DIM AS _UNSIGNED LONG ctm, cts

    IF LEN(PlaySessionInfo.tuneTitle) THEN
        DIM text AS STRING: text = LEFT$(PlaySessionInfo.tuneTitle, TITLE_CHARS)

        COLOR BGRA_BLACK
        _PRINTSTRING (TITLE_X + (TITLE_WIDTH - _PRINTWIDTH(text)) \ 2, TITLE_Y), text

        text = LEFT$(PlaySessionInfo.format + " " + CHR$(179) + " " + PlaySessionInfo.portName + " (" + _TOSTR$(PlaySessionInfo.port, 0) + ")", TITLE_CHARS)
        _PRINTSTRING (TITLE_X + (TITLE_WIDTH - _PRINTWIDTH(text)) \ 2, TITLE_Y + BUTTON_FONT), text

        ctm = _CAST(_UNSIGNED LONG, MIDI_GetCurrentTime / 60)
        cts = _CAST(_UNSIGNED LONG, MIDI_GetCurrentTime MOD 60)
    END IF

    COLOR BGRA_WHITE
    _PRINTSTRING (TIME_X, TIME_Y), String_FormatLong(ctm, "%02u:") + String_FormatLong(cts, "%02u / ") + String_FormatLong(PlaySessionInfo.mm, "%02u:") + String_FormatLong(PlaySessionInfo.ss, "%02u")

    COLOR BGRA_BLACK
    _PRINTSTRING (VOLUME_TEXT_X, VOLUME_TEXT_Y), String_FormatLong(_CAST(_UNSIGNED LONG, MIDI_GetVolume * 100#), "%3u%%")

    IF MIDI_IsPaused THEN
        COLOR BGRA_ORANGERED
        _PRINTSTRING (PLAY_ICON_X - 4, PLAY_ICON_Y), STRING$(2, 179)
    ELSE
        COLOR BGRA_YELLOW
        _PRINTSTRING (PLAY_ICON_X, PLAY_ICON_Y), CHR$(16)
    END IF

    WidgetDisabled UI.cmdPlayPause, LEN(PlaySessionInfo.tuneTitle) = 0
    WidgetDisabled UI.cmdNext, LEN(PlaySessionInfo.tuneTitle) = 0
    WidgetDisabled UI.cmdRepeat, LEN(PlaySessionInfo.tuneTitle) = 0
    WidgetDisabled UI.cmdPort, LEN(PlaySessionInfo.tuneTitle) <> 0
    PushButtonDepressed UI.cmdPlayPause, NOT MIDI_IsPaused _ANDALSO LEN(PlaySessionInfo.tuneTitle) <> 0
    PushButtonDepressed UI.cmdRepeat, MIDI_IsLooping

    WidgetUpdate ' draw widgets above everything else. This also fetches input

    _DISPLAY ' flip the framebuffer
END SUB


' Weird plasma effect
SUB DrawWeirdPlasma
    $CHECKING:OFF

    STATIC AS LONG w, h, t, imgHandle
    STATIC imgMem AS _MEM

    DIM rW AS LONG: rW = WP_WIDTH
    DIM rH AS LONG: rH = WP_HEIGHT

    IF w <> rW _ORELSE h <> rH _ORELSE imgHandle >= -1 THEN
        IF imgHandle < -1 THEN
            _FREEIMAGE imgHandle
            _MEMFREE imgMem
        END IF

        imgHandle = _NEWIMAGE(rW, rH, 32)
        imgMem = _MEMIMAGE(imgHandle)
        w = rW
        h = rH
    END IF

    DIM AS LONG x, y
    DIM AS SINGLE r1, g1, b1, r2, g2, b2

    WHILE y < h
        x = 0&
        g1 = 128! * SIN(y / 16! - t / 22!)
        r2 = 128! * SIN(y / 32! + t / 26!)

        WHILE x < w
            r1 = 128! * SIN(x / 16! - t / 20!)
            b1 = 128! * SIN((x + y) / 32! - t / 24!)
            g2 = 128! * SIN(x / 32! + t / 28!)
            b2 = 128! * SIN((x - y) / 32! + t / 30!)

            _MEMPUT imgMem, imgMem.OFFSET + (4& * w * y) + x * 4&, _RGB32((r1 + r2) / 2!, (g1 + g2) / 2!, (b1 + b2) / 2!) AS _UNSIGNED LONG

            x = x + 1&
        WEND

        y = y + 1&
    WEND

    DIM imgGPUHandle AS LONG: imgGPUHandle = _COPYIMAGE(imgHandle, 33)
    _PUTIMAGE , imgGPUHandle
    _FREEIMAGE imgGPUHandle

    t = t + 1&

    $CHECKING:ON
END SUB


' Processes the command line one file at a time
FUNCTION OnCommandLine%%
    DIM e AS _BYTE: e = EVENT_NONE

    IF GetProgramArgumentIndex(ASC_QUESTION_MARK) > 0 THEN
        ShowAboutDialog
        e = EVENT_QUIT
    ELSE
        DIM i AS LONG: FOR i = 1 TO _COMMANDCOUNT
            e = OnPlayMIDITune(COMMAND$(i))
            IF e <> EVENT_PLAY THEN EXIT FOR
        NEXT
    END IF

    OnCommandLine = e
END FUNCTION


' Initializes, loads and plays a MIDI file
' Also checks for input, shows info etc
FUNCTION OnPlayMIDITune%% (fileName AS STRING)
    SHARED InputManager AS InputManagerType

    OnPlayMIDITune = EVENT_PLAY ' default event is to play next song

    IF NOT MIDI_PlayFromFile(fileName) THEN ' We want the MIDI file to loop just once
        _MESSAGEBOX APP_NAME, "Failed to load: " + fileName + STRING$(2, _CHR_LF) + "Reason: " + MIDI_GetErrorMessage, "error"
        EXIT FUNCTION
    END IF

    ' Set the app title to display the file name
    PlaySessionInfo.tuneTitle = Pathname_GetFileName(fileName)
    _TITLE PlaySessionInfo.tuneTitle + " - " + APP_NAME ' show complete filename in the title
    PlaySessionInfo.tuneTitle = LEFT$(PlaySessionInfo.tuneTitle, LEN(PlaySessionInfo.tuneTitle) - LEN(Pathname_GetFileExtension(PlaySessionInfo.tuneTitle))) ' get the file name without the extension
    ' Get other play session info
    PlaySessionInfo.mm = _CAST(_UNSIGNED LONG, MIDI_GetTotalTime / 60)
    PlaySessionInfo.ss = _CAST(_UNSIGNED LONG, MIDI_GetTotalTime MOD 60)
    PlaySessionInfo.format = MIDI_GetFormat
    PlaySessionInfo.port = MIDI_GetPort
    PlaySessionInfo.portName = MIDI_GetPortName(MIDI_GetPort)
    IF LEN(PlaySessionInfo.portName) = 0 THEN PlaySessionInfo.portName = "Virtual"

    DO
        DrawScreen

        IF WidgetClicked(UI.cmdNext) _ORELSE InputManager.keyCode = _KEY_ESC _ORELSE InputManager.keyCode = KEY_UPPER_N _ORELSE InputManager.keyCode = KEY_LOWER_N THEN
            EXIT DO

        ELSEIF _TOTALDROPPEDFILES > 0 THEN
            OnPlayMIDITune = EVENT_DROP
            EXIT DO

        ELSEIF WidgetClicked(UI.cmdOpen) _ORELSE InputManager.keyCode = KEY_UPPER_O _ORELSE InputManager.keyCode = KEY_LOWER_O THEN
            OnPlayMIDITune = EVENT_LOAD
            EXIT DO

        ELSEIF WidgetClicked(UI.cmdPlayPause) _ORELSE InputManager.keyCode = KEY_UPPER_P _ORELSE InputManager.keyCode = KEY_LOWER_P THEN
            MIDI_Pause NOT MIDI_IsPaused

        ELSEIF WidgetClicked(UI.cmdRepeat) _ORELSE InputManager.keyCode = KEY_UPPER_L _ORELSE InputManager.keyCode = KEY_LOWER_L THEN
            MIDI_Loop NOT MIDI_IsLooping

        ELSEIF WidgetClicked(UI.cmdIncVolume) _ORELSE InputManager.keyCode = KEY_PLUS _ORELSE InputManager.keyCode = KEY_EQUALS THEN
            MIDI_SetVolume MIDI_GetVolume + 0.01!

        ELSEIF WidgetClicked(UI.cmdDecVolume) _ORELSE InputManager.keyCode = KEY_MINUS _ORELSE InputManager.keyCode = KEY_UNDERSCORE THEN
            MIDI_SetVolume MIDI_GetVolume - 0.01!

        ELSEIF WidgetClicked(UI.cmdAbout) THEN
            ShowAboutDialog

        ELSEIF InputManager.keyCode = 21248 THEN ' shift + delete - you know what this does :)
            IF _MESSAGEBOX(APP_NAME, "Are you sure you want to delete " + fileName + " permanently?", "yesno", "question", 0) = 1 THEN
                KILL fileName
                EXIT DO
            END IF
        END IF

        _LIMIT FRAME_RATE_MAX
    LOOP UNTIL NOT MIDI_IsPlaying

    MIDI_Stop

    ' Clear these so that we do not keep showing dead info
    PlaySessionInfo.tuneTitle = _STR_EMPTY
    PlaySessionInfo.mm = 0
    PlaySessionInfo.ss = 0
    PlaySessionInfo.format = _STR_EMPTY
    PlaySessionInfo.port = 0
    PlaySessionInfo.portName = _STR_EMPTY

    _TITLE APP_NAME ' set app title to the way it was
END FUNCTION


' Processes a list of files selected by the user
FUNCTION OnSelectedFiles%%
    DIM ofdList AS STRING
    DIM e AS _BYTE: e = EVENT_NONE

    ofdList = _OPENFILEDIALOG$(APP_NAME, , MIDI_FILE_FILTERS, "MIDI Files", _TRUE)

    IF LEN(ofdList) = NULL THEN EXIT FUNCTION

    REDIM fileNames(0 TO 0) AS STRING

    DIM j AS LONG: j = String_Tokenize(ofdList, "|", _STR_EMPTY, _FALSE, fileNames())

    DIM i AS LONG: FOR i = 0 TO j - 1
        e = OnPlayMIDITune(fileNames(i))
        IF e <> EVENT_PLAY THEN EXIT FOR
    NEXT

    OnSelectedFiles = e
END FUNCTION


' Welcome screen loop
FUNCTION OnWelcomeScreen%%
    SHARED InputManager AS InputManagerType

    DIM e AS _BYTE: e = EVENT_NONE

    DO
        DrawScreen

        IF InputManager.keyCode = _KEY_ESC THEN
            e = EVENT_QUIT

        ELSEIF _TOTALDROPPEDFILES > 0 THEN
            e = EVENT_DROP

        ELSEIF WidgetClicked(UI.cmdOpen) _ORELSE InputManager.keyCode = KEY_UPPER_O _ORELSE InputManager.keyCode = KEY_LOWER_O THEN
            e = EVENT_LOAD

        ELSEIF WidgetClicked(UI.cmdIncVolume) _ORELSE InputManager.keyCode = KEY_PLUS _ORELSE InputManager.keyCode = KEY_EQUALS THEN
            MIDI_SetVolume MIDI_GetVolume + 0.01!

        ELSEIF WidgetClicked(UI.cmdDecVolume) _ORELSE InputManager.keyCode = KEY_MINUS _ORELSE InputManager.keyCode = KEY_UNDERSCORE THEN
            MIDI_SetVolume MIDI_GetVolume - 0.01!

        ELSEIF WidgetClicked(UI.cmdAbout) THEN
            ShowAboutDialog

        ELSEIF WidgetClicked(UI.cmdPort) THEN
            DIM ports AS _UNSIGNED LONG: ports = MIDI_GetPortCount

            IF ports THEN
                IF MIDI_SetPort(VAL(_INPUTBOX$(APP_NAME, "Current port is" + STR$(MIDI_GetPort) + ": " + MIDI_GetPortName(MIDI_GetPort) + _CHR_LF + _CHR_LF + "Enter new port number (0 to" + STR$(ports - 1) + "):", _TOSTR$(MIDI_GetPort, 0)))) THEN
                    _MESSAGEBOX APP_NAME, "Port set to" + STR$(MIDI_GetPort) + ": " + MIDI_GetPortName(MIDI_GetPort), "information"
                ELSE
                    _MESSAGEBOX APP_NAME, "Failed to set MIDI port!", "error"
                END IF
            ELSE
                _MESSAGEBOX APP_NAME, "No MIDI port detected!", "warning"
            END IF
        END IF

        _LIMIT FRAME_RATE_MAX
    LOOP WHILE e = EVENT_NONE

    OnWelcomeScreen = e
END FUNCTION


' Processes dropped files one file at a time
FUNCTION ProcessDroppedFiles%%
    ' Make a copy of the dropped file and clear the list
    REDIM fileNames(1 TO _TOTALDROPPEDFILES) AS STRING

    DIM e AS _BYTE: e = EVENT_NONE

    DIM i AS LONG: FOR i = 1 TO _TOTALDROPPEDFILES
        fileNames(i) = _DROPPEDFILE(i)
    NEXT
    _FINISHDROP ' This is critical

    ' Now play the dropped file one at a time
    FOR i = LBOUND(fileNames) TO UBOUND(fileNames)
        e = OnPlayMIDITune(fileNames(i))
        IF e <> EVENT_PLAY THEN EXIT FOR
    NEXT

    ProcessDroppedFiles = e
END FUNCTION


' Shows the About dialog box
SUB ShowAboutDialog
    _MESSAGEBOX APP_NAME, APP_NAME + STRING$(2, _CHR_LF) + _
        "Syntax: MIDIPlayer64 [-?] [midifile1.mid] [midifile2.mid] ..." + _CHR_LF + _
        "    -?: Shows this message" + STRING$(2, _CHR_LF) + _
        "Copyright (c) 2024, Samuel Gomes" + STRING$(2, _CHR_LF) + _
        "https://github.com/a740g/", "info"
END SUB


' Initializes everything we need
SUB InitProgram
    CONST SIZE_COMPACTCASSETTE_PNG_BI_42837 = 42837~&
    CONST COMP_COMPACTCASSETTE_PNG_BI_42837 = -1%%
    CONST DATA_COMPACTCASSETTE_PNG_BI_42837 = _
        "eNpVvQOAHMwaBLi2bdu2bdu2bdt21rZt28zatn3533nMVn2qQXWkgpw4LBQWFAAAAKykhIgSAACgwL/b4xBg/y4zQTiq/l0BOiuJCwHUzuKc/7sDYi4oKwgA0BAP/WUI+u8+pIOEpjMAANzgf2dAVAqpAACA0gtJ" + _
        "EUEVD72rb/ctkwnV3fg+edXtzW35HBw3MzaLIjdFHUkwUGAxJAmhENDg+gE2yQiDmEiw369vwBPrBBE0gkTbfhFiEAkJoSOakOqAhxMGbmZu7n3IPzc9qqef4ivXN2V5fgfTN9XFPzx1XhcvM212K6e5XKfLlIqq" + _
        "bMERMXV/EXYfzPs6AxJLmHvlu7QB5idSc+GbqwtOgWGtz/SN9N4E7GBEIUxGFawIkmOdClRIkQuUHIBSg1DvtI8EB4p1QFyiczopyG2yU9ZO2ZBreSnrbrchzzNH81yF8Iw0n4eOGrckd5rD7LzS5Ze/GpcbbNdq" + _
        "DHE/h6u0Xbsw/VefXasgAn26YdwzqfP5AlibqwUBSA5Xq0PL6X7ezP1GHtx7PmMfLjZv13PaA2raYQVa/1pSA339wP8k+pw9VWhCU18zS+dMU7/QTC/cqgX7dus6j6MoyzCOlFJ06qKhn5yBlpjCSk9RszSiqddU" + _
        "O83QshOPb1XluYp7f7Ur2ozY6lAB+r16+/dpeu5+X3rfGO+YSeBl1p5SY9GGA20TIRVoBH/Uk5E3fBfbBvuisNg0ygITmdnawZQXVlr+KaUvirPR/l3BOSKjs2mWFaZpim2t0YavX2hNxNnwyGunJSCy/AOTa91u" + _
        "W40jctAKO6nmS0W98cZr8xLn1mXL/cmDtgn2aaNaJkSTLqhZ6mv8p/xyufiD7b1n1dV4yLd1nU1rl6A2XPZis9OL2TOvps1WseyCicn4uD2aC1REsrec4LtWUfoFyoMAoO0TJmb6Z1paf0Oz6RGi9YCNLhXg97mu" + _
        "2+uleUVVMwe7+48Y2VN3IXCmbxRlaYbRp4Wm8Cb46qJBiPy7jTpnM0c0RtbvJ3NfJX8rtk0yALmusfabvf1Hx0a2T+vfXX5xywIWKYZ5+LBSVB3TBIrPf6uLomyDbdsyrSXMgElrrZBsOPzvCAjdrD3YIxruV3Y7" + _
        "Gr8L6UYK+JP+2k0JT/h0+zsu3uG/+xVwMmyyzrD8DahCgTZgT4D41+VJbLMswyhK3idiYl6BiGwoJMmACcBsZEkxGogsBcOx3Kvb8U3hIcgPuIzF7wy6j01LV7weta1BG/KuAPrU8+wAFE8nR1fYD2vSYgRT0kbA" + _
        "Dg0zYbd49z/8yeFlygtd0KliOHKo5FLdiPo07y2IREUXFIxkRoWvxT3zfd2+XDZHa0n65/wfL51VPo8nRemudCM+awzvWpT21BIQG3OMoij5OgyHlSINVC2zGBIAtiHUVYkoHGY6oDMQsPp+jncf3yQDVkYeVabQ" + _
        "KeGvMHdT6u9DebkSIEh5qyNEWTSl/zc1DQkp1lHv8Gc2ZKpuiG8DMCQDUqEhkC+QApu2dVRAowNYk3g6WDVLCnBP2wpABFCf/ijj0ZMMALjogflGoSWOO0mjrQz2/7UEIBExQRI4ZpjJiMlMZr56EqGRpRqxmQRy" + _
        "qnIOzjxuTsIUA2DqHOdE9iLkHqzrGpj3epI3DfpRs7XwbAi7v1L+7KlpOo4d9zAI5b7rS77NfOroLJvjitN34nUij0NS/XLGXgSvto5LKv8PXnmDCLFRptQE6CMriqqoJvftoY0S6Cd1Lha4m9MLY3VHg1+9NNBu" + _
        "4MR9iqgwSBRJomqRDFT4KryUUe7eM/6bSuhuaiCfjd8ffM55dUS6qz/41elakphSOEGCGbShnzd98eG/Fz3lKiahSqmgpYaO0N6cL83kjs8z7EsTMNuV/cXgarGD9x9V/40EP14hVA0hhjGn71Nw1ueNL2rJvFxI" + _
        "IgxghD0Lp+MZK473mq266UmHpBuLFTItPRLAndS+Znq2gYld3NMh8V7RjgxTSMDyb0x0fO7xz++n4FnzROW6r1ssGFi4vtbJ0efN0dW5s0AopPUcK2kfZenbsBAZmtRc0e0PAfpc7iCGhYawMAgzf3zUaeCrf4iy" + _
        "+07oc5DVlX6lFxbZP3/gQRxJ2GkdcME2UAfh6Osc9OnqKZidDUmCKtBF2/pOjE/60yuwapGwIuwVwEOhqVApns7xmguv/MILC6LPfydGnvefgd3kU1AlYLa/BuObtPRM+pCm1GDyCBHEDU1N9sswbL3vd02kq0Ee" + _
        "QGgFCtFnAEIm4ZQ27VDF3ky+HbfG6iLuTX7xUDc1HVYRwqreB2CIY0pxmaevxV4DO1BFQMBaW+pzzF10REsUIdYMQwmxOMsvscgujfk/BLDDqYNVQlepEP5VAhUNsHID27xOBM7EaIyuynn2rbZqZnwDGFiqQrnI" + _
        "NWMKQqkpwLIr05iT2RQYgoalH+/Ue9XCwHf4A/XH1uBL45ctMV8IR5wmKcrKds39L2zuP0OFwQgU98b9IEyAt4GmlO9ZL1wRkkGJi3KTXFoPxC1kK14e41R92KHaOKQFjBOWaR1F7BSrT2PICxY6p27MukOikuwT" + _
        "w3c6M2X2UMsstcwqjb8EMQhetJgxqCkRKeLPo6IKsnYv15LVqtKdNEOujkSMx0gqyrJARSPAECcVWsgp8ukm7VekEMbvV1xXSDTkcLkDEARmm6IkieqiEiKNUi6YxqkhDs/c7gu364vvetLO+odCrkE9BBbPQcjJ" + _
        "gKiTOWW2rE1ZtD2rorXjNdz2O6aGpuFJZTANzo60PG8SUPHquCyGg9yqNultbcykKvcgaUPsEBIGPpi6ESIVin0ob9tWAGNYI1WFyPgwQQ2aYGprsM0czWdtX9SezYfK1YfmvwAcRU5hRckQ0h9oXVvkeUYwMsmE" + _
        "BRQisGJVSIRimm5UOpCobWdSmgh7qE9a7uXlV07VRcTVj4WaK7MV8MUi6pgw/EY0/5d/zjXvmecFhz/R5xOodamgefBrX1jn86qsyeGIYEfdQlfqf2EQpbAWX022/yZzf2LuHeWF/11Sgpm8uppoG860vP4TveOY" + _
        "OXcs0Vj8HDIC1HiVazNSY9ikeTj5VU2Tz9lpTWmpFqdA/210DVYsKGcGJgZhz0MEPZjh0KkylQ4dj0fyc5CJU/ahJy7484Xw81XRQnRt+IZx+H4AWzAYIIrEPfNfsjmIBN4WKl5MeQGVPk+Fhs8r9TYLjeLbsJmd" + _
        "blF3rl8xIh2GmCdktpCw1Q0jFq4clm66DiLH5z3ye1jqdcEl/Jehr9IA9J9G144F8rYWZ6+wIB1yAIh1V6ppVYwYKJiNNOFQD9bwiwKwwnVfJYQxVElAgja+fv4Ll2N4ZBADmCn1JVjUcswGFmDy7G0giCexJbhA" + _
        "ZB7L0OMfEUpFQwcXFozgs+7t9yfWzsaxvwVl/gNY6sk17bHSpALJ2n/ZEJDebcGNcDpN22kGihnJzKr1cU7FFWI8VJB7LsCQiWJOE6PcE+Fr+V4+lRj8YmkfYnMNfb7fmOUfx8h2K7vHdpfC3j1821Fi8rzT39+Y" + _
        "Y/g3LeAIFmxBI6xoIsXt4B3l+ZH4DZBEBMU6B105qonRO792qHtNDwK1HbF1iABbncaIV42RKmzZ0QwY7Ka+Y9aXt2MhCiPAWQLUPGBRRAUgEhVig2md4UdHdWR41sw4CSskL32aC6/AilJtr7YO13JTsLn3M92S" + _
        "zREmU9ANHqbSP4GujDPi9W+THjtxJiGPm7O/DjvsVq6NvzLZZkFBk5fGmatZy8expgbPlqrNk/4YqgDBaCHKjNp0wUv9xNF/nLgirattjZYgEXSYrtS6O+zQkpzDAMpI1C16q4TkpxXujqgFVi6NuXyimILXSXVR" + _
        "BXBoY0G1CHp2R9mmxKv1XJ90DbxxtibH717aOXG/Dd7w1AG8OubE88/JPdw7bcny/fC1Jd+CHZ6uy/H51XHPUKu+sL0a1BCz4DJHMydwL2cVMNt3oqXf2TBoAjVXTuf1BYDM7D78l4SR84/S4lSDHAGQXQO6QqET" + _
        "QM/USHsa48GEb684J49V46KcDnN5KRyNzBFIIKyAKTQYTYwoV+wzuBlVsByM7rDqrZ1GovZUGYlCUqqsXGarnVlgN6R/Ys93wlNtTPIajIfGWVdPrG9LesekhjrNMWagn49c7WhE71hiSvjHqbFGYR/0yi1qp5i9" + _
        "CopNmTp7i03bZrl7TU6gTg5fmwzxJgcea/xvDDtgHg3fV445KXYhj/uyO1m1xkYvx0pWazp3+NJcq0jqH+5EZyUnQktNC5TSavlkMs1ZsmRZnDEqRLMIEfWgrCgdKADRIqx+xtSFgHCQ8rcV0T2QxIiHzCBiqWbp" + _
        "dVBRR6TAdTUP/p7wzGVuzz235exZfqIJGNqBFTdn2Imx7gqjBHGkwAgLEowpII2DdSgUBm+R1omml9pVljlgzcle2RmLVe0Q6EdryI69Rnr6xjHsYxV5+sqvjPfA5Rm+2QxtLfUv7hLc7lvCOV/vl4Su3KB5gtMz" + _
        "ax81adjaZ3HbKl8T4PP7OfH54Sc/3J9mpsSnTBHg0/cZ8undFLleNVRoF6FgMPbOHddoX16ue2B6YHFAcYWe7jfBO7xOhHu+evMP7rKYn83SM7TZ41lO72nBYbPM+vLsJT3nNKJeGDoUqe1pAfmc9ry2O/8+n36/" + _
        "Mf5zkPRwAHJwkW2ow6SDLPXqKEpgD/nnM9GvRU6+z3VWn4/rvElnNDOO088jVXg1nAJXuEOYgvkCmzkQT/+2d+PIe2vZR/nar/v+N9axOt5eP3JPrZRMzu5WTd3rB+7XvMOZ23eAPxueZnE4gy2NEn4kPT90PWwi" + _
        "oGIQDFIBcR1uEzVjcOb8P/S9Jn+OWlDbEjsfusRowJkxoGEIyIZKMXfYpJXQ8SK3WU8ueN8EIAJ/FkFPdj/59LwOOHafMOVPJppAT71Px/+WQY4wFXjiBRGqEMACEynqW1zWzZiO40+x+NVY/kyk8uNZfmUdruHp" + _
        "9yV329lvq1baTRzIJNd5rNr6XDLb7XtsmJ5cgQp1BUsi6oigKmoufbR9YO+QW8cSkAkLjdjUkbjXMq7XC+skgWDgFpBqBSeReug0bkJYv2B1hCLwIKHwtk1fVCR3O8z56X0Not/nbKCqcenGmAlALgqMjAlVP/tv" + _
        "dj39o1KOmQqP4QYI+kqs2Cw5dx/83vx9zruSL3hdUG3mgHmSLpZNYGJbJq1WjUWfsdqBPRMcTr0zt74bbXI8M/8FC6kAXZas4cSjTfQWGO0SgYvauPSg0fxIo9BMBUce+4evy7r9zpF+q7JoiTgsheQCJUKtQMAW" + _
        "LGhW3vpKuf+qlcMEKwpAVzgp6ZKwsm0vbPlzTa8Dym594iOEbOuedsu/EM/D575Qei99v2MiQFtwdJEAoOPDsNNLRludtTfFJkkSXWE/qpBYhSJr9PfxOadvBzDyXfcEvTAZ8wCgsspSFYhBrhUsQ3umMb0p/2Wr" + _
        "e8Ft5WYtg6moMv2e+M3aP2M8ToGVuyMgsbzcg3cZuMWOGQpGAY2MQ9o/169XnQv6SIBJIgtaH9HKRrXpb2QlgENloJLDx4GFdxEtNDecAlMzS2foKJnEGRhcXUrykWWDyMvkBzEKJln/6hq8UxSUoCApUU3Ut8qD" + _
        "i2BwjbMnje55wFhj7xVx09/24jZVrHdwSSAbSYLLlvdV/7drn3rD8HYSoBQRjgUII8Og5jZFLAZvHsgspTNvKH2Hyk3j22kaZjf460mDO5BIusoJApAAdAgmH8RL/Zl/C8nCu2qZgiqSonbmULxgMMsZBCFahx5L" + _
        "IPnLTrdvm4owjygInhKHNTmKQ+f8sX3rqSwL+a+0QTQg9sQBnICfrzU8p010q7nVAbFZCpyw7Ig5ueJRYDylUqEVK8r7eXvb+1+qB1UVtrYHPi1s0RAZ7yYwk+DcNI3y6lMkjoBEVUvtWHzM2ryl8L/D1K/fXqoZ" + _
        "+Nc4uiwhNNFF7V1ropsqoE3O79Irr8UyugfVR3WSKirb29lwBeCAAYtW6oVK0Q9Z7G/uf9XgGB0soiiPeDKoMaJUsSViINESBoBr+2krg2WfAVM3RFXm/kjfJ3IRSzOxDhJg3O76mQ9BtmEsXD2ZQL9GsDXWMHqG" + _
        "XSBqiaVUEEZ3A8ctIkz5GALDxC1v1IS1vmTs/fN/Nufyrgx7yCxSJEXX6lRwoWoRwIM/+43cdotSJE6hllq9S3jZIr56C5MuEtA1wuEItAA6Gq6Rw1ZmMzKRIoAAu75H+ScaVE++dNjL2Sf2uc7if2BXsVi4F0po" + _
        "YMNPseIa5e8+hrCwv9nlY4Ehl2Qr7ItSZDN3H+/6zdmBFQ3UQiokDdoFEBLaggdH0FvjYAvDlCCjPIP26tcaT1pQ6lHbTUnQNCpW+4v+N9YnjZIZBVcpFookM6+qht4VOzhEbhwoc6Zqqli7bHvvU/vbJxXgqyiA" + _
        "Ec1hUSzlsE5+2BUu93TJCracGKRSRjTUAXRAR87axFgbNBFUbJ8nQJXkILTMIw5mK1yt6Oc6q//GTqde2eA3gzAkAAGldtC+k8XdmrkqbCwAsjnI1UaNZ9wGggEVn5YLFkR+8eN2AKYsHVD0440gHLGxla8quHId" + _
        "70N0sFWQ6oogYPLEgS1MXTwBMVoy8Fxn8383bTaDAf03jNj1ZrU+04a4ZuTOAJknaHGGVjQVDPsWqIuoP8u482yPrAhbJga6XdtDtTJ3bB1sBjKenoIKiqoCoP+NKi0lsmH+IG5InWUERZnHDyF1XUw8S2+FdgGA" + _
        "Q1Jt7/pxhQIx7gMQzBjxeXrEAOJBf8cb9AtAtPCrBW+zC50YTQkFAyCcQEwBhZ8hCKAC+soHVVIuxSACaiExIBo4eByk6L9PlO7XjZMQTWp6DMif2tCsvwF4BXF2sCobofifnsaW4Bl0pXAXaEF1hb0MhzcciZe9" + _
        "pYkEIKMUB9hglZ4drjuhqwUEQLsxsS+phRjAVgTmMVCcdB606Zv/x8eO5YLJKoKw+ipgmidKXTEuWeERYkQVuGb3mNqSlWsHVmVYIc+dWkGGY1z8D6+zvPDmaBteFgqf0CStOfCTgECpAIsIMXnF2lbMUjnmO+Uu" + _
        "9Rf+5+xqlvNEoCTDAzCX5XKHNk7cmOOk1rNM3XGQfG6B0UlrW35jo2rztPXcQDLjiN0AwwIQwNZ3EM7yUqyrcdfG9aqBP+PFVDEx37j0KrjURKN+K3UWUZSl7V8ZW72Ny1DiWl0CEMReH7ZGKcyrFwC4VHF4pJcQ" + _
        "BuD/otMVmaW9S2upFt4mzTsrC0eQCgeYxbsXvuAMFpgOdOq+SbG10vAbutV/jfn8a+wjslUMqyYIS5C1OIH0ErRI0vLJAxG7RCJW+w8VYd7x5s6zvxsu4kcSBANfbiGhmFntmi15DXWTI8wk3QjipoBd3Bf5uaLY" + _
        "0n95ypRhgIVqOCPAaBGh44/wijAEpSrFPA3vasZ97VGro2aG0TL8vA1zrB8Om3jOofG3OhkRliLLOViR/bxZ3MJ/XMkYNp0kI5GtCqEaE0QYAz2iVQq4tx6tOlaYQOTMZNDarq8IQ8/C/N8cccSeoS0uoOKj65MX" + _
        "Z/ODKe/JCtmIyZfBEv8LglIFMrS+tkWxImhrtunQqzfsXnzByqTUncSXbnHSRP3jQ8LkFrDHXL67YpRGbwJksUcZIeugePrZDPOAcA2I6nKMIyjx4GIxBMGj5RiL9e2JbFx0OLFlihEwnEQkhlOnTT6fXX7ua7J+" + _
        "xqsbYEB+sc5EyGE9slItlw9Z4FrM3bYoFdA894jscGEM//nCTwRtg8QT6V7RgpANzhPCK2bSntsSh8ihxt6GXyRmbGWj8L8gaQaRuhzvbIlglGmpgNCU9kPuCydWP1H632QcB8tPtWShtFLKqeim6C4haCXpGFNZ" + _
        "3ybtSXhtI//NRo92Nc5+nS0MlMhKIFWBUiP8bxbImjcmLKPn2eYx9cm/JoxOGRQTFEW1YIcxJu3sYwjpYQc0cKTmsKqbuuwe/kVQIAzYEK7lGTIVVsh/oY40ANFmaNgjYMbQxRKy85Bb97aK7581y8arYtl6SsS9" + _
        "Ut50wSdCbNdDd3vH5Aik6qSooUqYneoahjc34lXiIbpPLBiAiWbEdA419Fs+gwndgGBLLGJX+4r+B+8hIOCzxikCYnO5AOrSOH2HfavZUYaay8r8xB5r265i3E0bsg4ToB7dsIcfsQybRgyx4HAMul5xBwe5hI5e" + _
        "9ugr3q+Z7P/8VSpmMdujsjFCMV+bE0P47Fk8+5B0iEBDNasHL+/V+vdwchra5xwDSbUZKD4Zp4GZewGWDKnUCqXhcnfI55/dB7BON7t9p2Hs9v308KFfTPQANpbfJBf3KpFas42F1cTh9TG6wFLH3ODD1pNZG25d" + _
        "jX/82X9AMJiR6/zG3DW0fTqZ+QIIRLk0fXqDgoigIAJcgFKMt0j9mGLkk8mRIC3WCIxfcWIZXb71l81qtssqrZCblPjOTLnoZMtV0sbe/8MVGCSFRUyQgXBQfGQZLgjRmbib/OhxoMUWadIqWTusVunLpG0o0sAb" + _
        "X2zeYMTwz1bKGzCk7J2rC6YY+QWAXaofStW/yqiZkUic0mDMrJS2M4mb4yJcD4vYD0oL4vMwgrmCtaQZyC6wa2KF74bF+ImtEYgjWBs2aWKq8XXT/tB3xaaPZKUYCagnpmBHXoow/FvR5CTEGMZLpWp5NGNYNyEm" + _
        "NjxqttIF56jhTgsYy7x1uRiKVYwYhDpiGL/4Ov3kbA7zudGOUR2CtqiIEQkVOVB07gnGE/OZddRy0hBCS/vUUcJKDCP0N268VwOI8zijQzkTkApzPpPrGSTjmFrrsKbEwb/CfRSQlQQICjIIQfDlGFQ0lUFhLOYQ" + _
        "YLCMHEKhNo06t3lmBcjB+PpqsY+IyEWbYDB65LTQgqNJkR2lu1bX+UbGNIJGx7Xp4X3ubTznbQ1osn3sWni/PecPZz+WnlW72LRrfWPprthT2t96TTajL9jvPUvHBGAyNKeS/16Y+8XtV09OuzaMfAm3UGIiVKnK" + _
        "y7fS8NaCLxmAHox+R5Y7lf3Rpvnq7fP9ocM+YTsJao4N0qJhTNmtVCIhp8hFErskr2jIhvNVzyoCjCpkhhXB2MUWNF6OwgaZLKbZfRZbNxXol2ZOswHFioklNWySoRB7y4coBGV/WPREgdXVXqI4WISu8da/3b2H" + _
        "2fYQJSZJuiCeoOLDaju5vmb49Grc0I27XIKaxN+tWrJpsbjKQaw2xuEVak7G7hHqx3LInKzto+BlatBqWNG9WAfkDCvN2ajjUXIX2LGl9CaQORg2w0rzbXV9q4dJEczE39g9X+8yGSD/2DTLjvNnURnUlJD2M3+a" + _
        "Hfe6l7y8cd6lWk4DbPHWah5W24JLbfFWcsrVcJYdl7pHQ/0kO+5YL1SiO082PfLam+4bjIFompVmqsdq+8FmCK7WOJYhWTPtE9Uu+HgaYma6fvE1+HjFr7ooExXL7vp2C0sNWt4OtgNV7TM3jNlEzQLdsW8LMweR" + _
        "69x9CLMa8a+vPHP01J/eskztE2HR1UtDxCxiQ1CMxDCrvxiLe7MXZ8aQpGohG7yPPlc34p5Df+AbnZ4ZP8bgDRrBrGxIhJHLmgTCgY3bBsv7j0ih8MHp3TrOJcdm4Pk/o9f+mFHbET/MnnDbigUcpdXCgjQMBzw5" + _
        "Ij1e99enAcSi86CKmlnkdI039H17w/HfAeo9p32CC1dNIQLFaIVEODZizVnH/O7Qic2NjT+0v1VLMnekLJ6zUD3gwd1vjqG3P0oEqCFLgVL2nxBQJrnN769xvzXbGJ3lDXwsHKsEgsVo4+f5ecfGlTF10jR0z4w7" + _
        "Yttme/As1E3F8XTED/Pdv2Ydy8Zhb7dmH4r7W1NFDzhFIIooDeW0yyq/13Hy+bqMxa+poBWj12JNySQzzQ6L4aa3cciByKBZS54PDJrTubbfB8fXY0jlDjONBaAxQLMoY5ej6nlagbvSvCjGQEG68u2gFdK0Nu2a" + _
        "Ff/E/9Y6A86WfX5O2H+/0ug601aJo981NTVoX/MOjDR0b4YmTFITlovHGtu1zC3V8ub2nLxwr0rq/WP1V2kA/q+unEwkAvRBEbGIhq3vGmke0wEAwQr7lCBbTvHA/u92dhq9yeq954aTvGlSBhOQTTtL7GFmEfpw" + _
        "uJhR7D9EF19Ohk8T1WBMqDIMGKrlQGXwrB3WvSPe2sxff6Ys5wb/yIILchDiqd6Z9mMAui6EGuSIlr0dBUJd0BYz3OPtu9gJ8KKAZvSXuUvbadF6OLUdZR0nbRQWY1aWHz4GSoXIuArwOFpULsI0iB+rzC9b1oo4" + _
        "YKlKsiFqoGgf+NM76uEpVI+WX2UGoY+ADmDLOn9QyRWYh/AImKbQQJQoPhCY6HU420evvkd//UX35zO35xR7vfBN0UTGJl8UHbFJpiQKCYiZZlWJNFB8ydM+DsOum/F729Dvpgba0n1sAhID08+V8FPN6fDN9k/O" + _
        "p9AKtZgJZX0iZfBY8FQKmJRA77fymWBcG7BPjmvA+k692DpjiP3dYYCtTaVKEzLcWxghe8XLPa0hf7mbPPR+n+rhLHsZFDXn1BtoQDjzFEYspJMYyScTUGEVQsKjk8aDfjgkiF9cZcDf/QGZeUZyNuoRjETqZlZh" + _
        "u4hldCh/wrkLBJ51GOf4cWqdmMPX3CuLvzns0/GNcNdvS/eOm11yw2QWDV3AQLevGUZ3DdYLWRQwDBmESB3++MsuNCeyeI1NETvPigDide5umZ9UnnQRPS9fNNOJRkWMAiYVWLhjx5KLDCHG0bxYkm6uAQkCPDDm" + _
        "BtFgTpwolEQoevhAZplEoEaoomUoQ6t1i9NFJtAQJHxnNK8wOpHIAue/MbvLgSIKGoOsQt1du2INtceCgPS5FsJCwBh7CVJfgd4bBwJ+GT6MKel8/XDW2kKC7YBVT4glgZeZeZz3QnvHH3+9b8qOc8KOTXsCNUcJ" + _
        "o0nKEjSGHEu2YdA9O48uFYwQpJntQvJa1PEn4/Oex4Z/bSrzksyTlZLd+P3tBfIUc2aszh/y3aPDJis+9fXO1+bpx+YD97WqeUf8jtCt7XIVWzv0ICgpFOPhO+Q1p5wqLXvw2ztkDTf78LOOt/+Xtz7cG45+0Zrz" + _
        "hAq/plqAGkSL0EB1giWXeO1tv+7RLGITxaLYFwurpPejrdhWraBC8QDYIkwrIuKSdl7quhrTCG7BwemuQNWLGZVu+F3A6NldIqKnIF9AQmziybuoOZHlVMYNVCwIBZBWGCaMgKyzICLyxF4D/dtTCUucFjVMSjFZ" + _
        "2cr+jrdqf+n9EeEuqTM3YGG5RO6zRnNV8hJUuW7t/tjCMKoYyzydOLFadQTs2Cj3PpfXuft83E/P8wqgjyXZcRisG/mFeyqG0ePwjgyYRkpMIbwyFjLcCo3cjZFtlE0azZBUk4bRcXJOEK8MG/fEUUqBjvA1nboN" + _
        "jOV7NXH3sGPz5Jarbo6dMs8Fv2t6bMqU3PMbT4VkVpW2uHtHziuPkagRgbTOoDBdIEeFJiqEzFVWlCVXPXSQA+pQo99ZluK+KveT5dB17OR9bQ13n/gTXTPNAmXcukWh8lbMGtDwyf2qZ70ZNkl6gpREMoQDDjVy" + _
        "yQQoVqssiyV8ggNODJH5q0cR6/pnlUFAnof+PVadf5ZYcHEJykBpTV040ooVA6NJNQukAWyzHgOWZUaIpjoxnf3Q1eABnQDmyZ/wnBImUAPTpmfagRMm7XBtLsxiFF/3hQzJYzkaZh+Fa/TB4eRtbMj7fcAY/H2T" + _
        "N63Ds71ygyQZRlgsAUYV2CqQRvX8oyA5qcfNAZbyXIEqTtbaNmaoHKAWeaHgIjJlfe9V7LLtg7f355Cwpmol0XZ4+VY68m+bwB3gLSp+yqR6SGWAglCE3FdQpJ8LEqQaItdOo1RwqaPOUp0DqgGufyPDFL2uf0jX" + _
        "yxx5JBVSrvREeUKohEfS6oqrrFKdGZLnNYpY0VFnLcbiBPEaVLl8MvGI66bsOYi1gSok3WmN/ouu+igiVyFdb1bUKjfvP56IGCN0Wa93oajqY2mcl1KeRzH9QT8zf1boqPbxJBo9dV+zdhn+WRz3tu4FnI/0/TWM" + _
        "EAGXAyZIvV8ADP11WwX/sOadvdVBf1pUE6PmUM5FwgGBBovGwhU0+kipqrn4mCunIBU7eTPN+WAWZmnakPgmULJHLa+aBgILjNRsVT9ARIgVHWbKN4IMnFhcuKvnxW9EEBpaSSWv6RnVWKgwYM7Z7CSzhJiFyWev" + _
        "UFmCH0IUUCfE9IbNRMP2jBODdddgpwVDHvQQ/gjr93zmt+NpQH/LXx++kpkzDd6I8A1sHdulCgGsv2n4XdFXkR7UCSs2YAgiVy96lQsv3k+KBDOh0bvNMopaqIhh9eTtM8b/fVOLW+BuDipnx5CkzdWCLYMF26jb" + _
        "rqKSxCEPlHJQ5HyoFO7rf49Xy+nMv/uE/qo0y6WSnw6hsIhO3rtO8QJfLBhLT0LCa4ggmUwmWlGrhx8fd3nIvmAQkVb/4UMH8kBAwzlWRIHf+06x22If2CGXPhI2ZMxolIjQBURCuQQNEhuSxj31dUDD/Pl6+AAm" + _
        "V2B1sr5FKAexKjB3GBUlp+lwfyBa6ZZduEn8JAWTYLnclqQTQ4X8XKKs40mhOIYt81XO1UIBGHQgLPCHODvbcHdH9MT89I5uaJaVcVagsRes7qkLVHWh7KKV038faNsNXdkLK5cEFqlkrPi2TTVHb1FbWD0k+6/v" + _
        "zwQVv7djprznHhBsiBrmpaTu1JSFOWZCLnps2q6gdMS1UVnHCsKf7kCaYfhfUfIM56qvLfXuDPE8H+aqtasiKxZGrJJjBsuTdlmDaS92DHsc8Tn39v1Sa626ju+4nSxgDfmsZAdNiPm1XhyswlBy1uUZA1bPiLWu" + _
        "SiVEiiqB3sbBwL53grW6rQnq3TeGYz3uRABAGaT91HJtzDVxGEq7Q5yLOlPZGAJJegvq9sdxmL62jKactrdvXm8ONJTT5HBfJdtl/XYmDypULOimK/76PF/vk0xur4TV3p6FQ/1UpjYUJMs1rXBEYWKQqEL5ru0B" + _
        "dFJpaWmaP1zSt1+inafpFq5UWHR/t4UbiyRsRfEkBpR5dhRClGAknMDW1pUnTs02+szpH8NfDuFuTOdyRU/MTu+wCOJj9ZMN+zEGqEMa86/cPFw6ZNu2C7j6hjvA5Za424ZjGgwKpGRpq4DUZLHQkcqFJjBP39Oi" + _
        "ScdmVXlKtvfPpNDFaIaLuXbZsTbxpRICFt4G6kDD/hw1zIwcCjoSXpzTcw3wtA9f9j5CW+q7xqxYwy3MZWvAEuRzv/xqXYIdJuPv/ZTgtem4+5y0zP0UujYR247Y6tABwYwGBlmFRgi3EsKuxjPRAXr16+oc9+v3" + _
        "5V2m3x6k2nNJdpjTAiZ9/LIajuRXk/lGHkQTLgipDI8W2Cc/PFnK0jOcQ6pagOwXMuewDorX5R5yw7NsqEM424URoAnj8IEkQkjrK3IYzg304Gz5J6wmBl9xNudlqkXnsj6JUoJAIYYEDAu6gcCQvVsdgzkdaJwO" + _
        "UmyvwFWdziZuu2cde+ObWVqSxl2zNDQZLvYU+UkFqYPcy452Hp5b5jP29RcgqzP6rwBqfaJbzrRSmGOr6J2DEiYLJFMEqariJB42HjHIXnF5Rxb94+znfzr6L4TL2n97k5/S1SzA4GeNUKvVbQCkXXAfCw4qexdV" + _
        "h9h1NU7CxNU17iZtkkAOcetIBVITVuXQ4Fonrc/lkxmMWLOw/lvi5mF530/0eV6vkMc13JJJbY7YIQ3GoUeb0PZdLcj6RSiZ0UGpvDI9d562VTX+t6c5/aX//UBLFRzDlAwTQ4Agaa+9114JKzyKCKkLWPh2r5g6" + _
        "B6AE7dj4XgQKUyqseLCmaxL7uMEb57VmrkQANYX5E+trtuXxq4ZCCeIxEzhydkf1m6bwqXmwzSluy4d3jf/yXOezuszh7QP57AuGWs1C2kCVSure8atIBDovfx0hvxLhdoFK4QX64xvuL/0EtuwLDv9oQ5kv1Fje" + _
        "L80Lz7GYi6OZQCkhpjwbRSElHvGwfN0eYEyBivxCvY7rUHL7e6b86fCS3eG4q3qR96kGUsESfUV3kmU/SLzSK1YI0llarh7q2afAPvAFb4qvTprjUeehzne1/H6nvC/VmF0PXps7Ij4QXmwPPHCJRveJyQHHRgj8" + _
        "TSA3evbXbrC3Zq61kRV6CuS8oHYUHjxjnT+8t0byg61gAROmEtkiSgAVmFD5KccukSjuXn4VhIgvsUAThcfMtXvK4VGbrg4SIBcMXui2zGTzjZtx+vo6hm4pFGmBDVwMQXL+5fDDH365bdc4VEELkPLq4wLMqT/e" + _
        "Wl9/Bzh/rApGWlZHZ8OaPJAhkBQioW42RkTt3pfLnIf6PMBmDsUtTzGpKWyBdCFTVBInWMNInfq7GacjjEc1H6YNchQiF5sIFPmLVVBLKTrWJ/c/DnH8XpQ5PrY2NXkccwxkWVIozlntTrW5RkqIktRdHCtoUgqE" + _
        "0E843C6TOe+vyup/w5BVOg6NNBfhpRzCoBYCDkgSog1XNcxiTGc10GJN41umsaKRCYUnSMoZF+pejPqkxyDF7TgGWPM+WOJ2f1BO4PGL4VMocs8gcGX6tYOZ44JTj+uyYf2u9nCkmTkJRX41leDJ+cSr781EIiIS" + _
        "spCW9LBPhVMVbYqygDJihEQdevuP6CQditb+AiY9qUu7Ppv3tUHy24Bzm8cggrjs/bYZj+/hI8w8V0rd5ZMVQYFqHRuE6WctGC2pZAyptzwaqV7QK/k4ioGiG7QkPr56v97RbYJoTR/VBFZFrZUHQyNpQIJ+yuHs" + _
        "h53yRhO37QTYntCkgtoenms1q8irU5/UaP+13pJHOztVcciOyPT9NO+T2nnZqEtq63lTbcxgNcde3T4J6l1G+eFXfGAMkjIFCo2NItVXWTdL7lnTn2Kd86ACr+UUTDz1ODUqr69QPXIMJulRJ5zncUvAtvOnErfv" + _
        "gWRmHlIqL9d5YkSpY+l2mO8sGfL8mfqDwOe92rmJZsv3CU7/xeX5GK1Pau89wT5eMDp9lUvTNQOR11S38TZBvKiRRWnV06gA2kwjJWO24b+tqvN7Veb4/LxGuKpkSYCggF2Ina7hFBquXb+FhOcYluyM2UNT6XPR" + _
        "P8T4sagQ7k7puZ0t1XhYn8808CwNtTaoDBvhxF4OTLjsSXsVYfuA+/s0qvu4TnoOMEF7TSOF/2yRcI0hYPCgsbfoNZlvIo0L97Xi3eF3bNz9EFtG8aoVJDAWhI3BX3hYrhjLhRw7itE1c8lM0P9XBo0WulWFz8kn" + _
        "8XajLRxY7e00NMYT3+INyh5GDycVQ014YvC+ymOyKXf2q2Go2iOePpoj+8+wYLLo+e+aVbnf/nfeL60/s991zV0S+89TmfWUj/TcA6goqIgtOQGNSdxKtDTP1098vcsupUtJrLDxEMkN98hxuEUzD2h+NdUDcnj7" + _
        "B6e8+f3dwLItrAfwDlRHEOwHWc0gfN93dO+7/dhcC+rPtv33U5+PQx/PGoinaMlHc+BURn/1zLwzNc9XL7zzL+8rka88mcF9hkH9zmGNA5Ozz0IHW1vu7X0mNTWO7rXyXw6cWYuUHwmhfo4KW/Y6VTk9GaXzGAzB" + _
        "2ZoH59+bJs+ntGyNDjd81dWIuB0sCDNzoSWP01qpxZMFZ1u79netz6zNW421u7b/Yi4QSiHx017buisxH5tUcj5fHChZcSJtpxs/pmduuUdcJwZhR1ex7b03C6V+F29EQcrZSJ4nxZ/jZZ1R4qa0LrQQb+ehXoN6" + _
        "jaAphWREhhSwF95zLDuvWeYMTpcAveMKFUXze7DGxV1+7CNO/9cH+w/4LkL+gLad+1j/99Z0n290PeFDz8fC19SDezK3Lu8BZncD/DWeY7OTuKuCKtBchOAhO0RN76ht4WUDYJQLSzzuYdc5D6hPOHwTVWkoINUh" + _
        "BQ3BlE+t2C9P+88v+4/B7QT8/jqfc/aflby+O2y/8vh3HeqTXi0t5n4nVQN0c06vzRmc3hcsKuhQMCnUbsRuRxCmF/W7fxTkz1B0zlabwBzEsYFLmCBpRzypNV2wm2rdLkedpAOONdcArrx/QeACU8v7G2AgSr4H" + _
        "uCVxymxhZdcL8NbRcjx9yhmrPfaEKMAAOl1nLflD1RgxEAaum6GotVK07kFCLxyjvKAkplh+uf7LnUuQovCY5k2W9R0DpkQcm7MIrZpxvixCp6roY6Wwjvencga3T4AfhAqfgIIqK8uw3y033y12nfeUtP5z7f72" + _
        "Dd7v5Yj+s7u9/wS7TptF0+2MykT3mHquXt/c9AFeHO/zBI7H4ooHtm+RUY1MKi0pKVht7JuJZi1/OPFUo9v3cPM+n+KxMtK6+wqhnc+J8rrzAYSWaFEeeb6gJWbvK73eT+za90B038vtoiQdpP/jQZ332ZzeV+Wl" + _
        "1qjfrRCDCWBMRC2YfId5XFGeE/JYrgstKGO/PWkiCCzDZWgXdlj81cR7v1Bw16kTlPW4MApaZeIDUQsn5lGLAiNnna7BBRtJBbQONPqzlOJIZbxKUQCYy2B963Z/cYEDU0V2p6xOLjfm0KyvT4RorSVNPYbULrmK" + _
        "m0M4lULpsQZp+DDGc+AQc03LU+l9FMwYzapR1wqHRbcayGvMPnDtBLAnGFsvD0HsootLz+neARG772RNM9xNmbJatZhoM1diSdgF9O9RU9/Np5jdSeO+/L853XLvZ9FvYx8VKssjSkU1Gtz3A9b2XJud/HuXtCip" + _
        "KskHSqJWyc8FHPW7Q+a/so8mHu8zRDNu3YfzG08Xz7tW0rLJ90MLEc2844JS3mxXNZyiMqlQxlkPhI9F+Yx5537R3kdm53dT7+t5t039mlkX8YftNaJ8ERJ0Rtib8605O5PTKyAK44/mCNzNxjqOVHsf09aGlZJW" + _
        "NGzWoF4gzFOAK3ZFTX+RrYVvLfF19ejZAwDUDkfK2W9bBUebMMQ8jZSKK0fkG1xDVxcmum8y8BMCcrQRL9nTAqsIcYSUIN9mfNYJyf0MLDAU/Gv6GTiEcM+wQ93Ee/lRevjZ62lwGe/m0e3rjGNZcOjHMVnZ4aR3" + _
        "c6bz1yr2uv8Zgel8+SqrWLZY2kksz2+8/kslP27OB2N/Xd9Z1W7n7tRSpd07oWBF9SI11Ave1lTgZZ2gFjMKkSLcqkZm0TEnjNgFRCCCkQxbooWHEcOiwSDTBKhhvU/mqr3Lj20NviYZW2XsqnClmfFUElUfIVh7" + _
        "vaGGXstUaHEj8spZx4bTVd8+SI1x+HmYQDnKBAxsarQ31vvU71mcvdftnikv2NtKeu8D7+fjKvrc87ORqhrV6HwN1FYgaBzvu9dDpuYyOIumO+yCxhpLbrg25q1mTknyWMQ0nQg4tOy12bW4ELinrPuhJ22ADSjq" + _
        "QBgUtpWkmTX+/rUAy17g9FGExGnX7ufnM/AVRBexALV14f2oUYV8yaZTCNiBuiGMUVEcQzqoz4LGIRjymJbYsj4D7oI2TN9Wg5U4uCygzRVYfHX8GIYIbCiy3OzxFvfuXo830401Fpqqw4RhJ1N9VOPrh/WEfXeY" + _
        "nt29aCiwa/l0Ve/BK99pKj7OzrZxuP7XYJ1//gqDPnd4pB0zpktTDK8810DgoTiEZly6AKmkIk+peKgEQKi6EFaR1HHFB2lKbuWTBGb5ZHvvFbpESUpJ/GZVxq1JT0xN+oArWV2eR65ubd0HqIe8pppKibhvPo1v" + _
        "c+Ur1DC1nCyOKuN8Xq3tVpaO3Ek8zske7Jqg2RmIPLk6Fkgt5Lt693GTvutcVjAe8deFdO/JU8uFnmO7iFSwGp+Uc3gd36gqu560aH/VAakfQsxgDJiabl7f300TV78wIWC9i34IRXQOBVJb4jpvhUONNjbmdj1J" + _
        "w2wP5bE3luDclRJCuH3qakHV78MLcI05H7Q+5AVYsbGDV1t441hlkGfHqCkZKR93uK0EGVFi/FEe1DKxHuGr0dUpYV0R2enDy0AUGML6LM0d9rUj4tUAy73GDg97JOIxD6CNH9AXXV8YTZ189G/UlmNqTZoo+++a" + _
        "9J6L6+BkPjiPz9Pvsj7u2vfXaY87MDUhyGhmnN4TDugZshIwKu7FUGzuHW3D0tSlHP1ixj4JZzt6N7+w0S+i2A7e9hHNh3fRLGdvi+mbAdrp0e+TVwM0M8vZ+Oo8bP2+CG2c2vRQTSzjS2zt6t0znuTV7NANl7zn" + _
        "D17r1dMmbyO+tnAfP8QmjmDtDGL5MRYztPlObAkTIFn8Z4jI+zOnqR3r2kJXA3jfexDyCPBztd37Pr7byx0eteF4Sr+vOPUe3zxr3yphEgmXNqtmrSteR9SXfiLVa5s/y/yyrDlwgUt0dxZLd3c+wXpm9YStcVx4" + _
        "0ySN2HPsRPxJLD1hYLQZVB+VYNleZErxuLi8TqcKDRqqVIKixff6O4+lkPofNQ3c7BkoSPxTuFOZkYfYisWl+bSzkoW9rnYMs4eIWx3ROB/ZfSfDxL69P/H8Mpx5pIr0CqaJKRcIW3ShV2yue8EiUapYR7y9V8os" + _
        "GJLuW+Up4Cfm79+hmH+jZf1Mf3nEg8cKQBxBUNUm+da2vIjJc59ZTGpF2UGgyGleOn8/a/5VV/p8Pzbx6HovJ3kfPc5p9A6VHqFDeu2furfHufA+MdNaTKCqwdJ6PwinEbz2oeY8h2pHe4Ys7w5eh4xYXeI7Iu5R" + _
        "f2v5PjazoZCNKKDtqWwiDPXcm/y6pqBCalahPTLr/WBKKsqDmITFEAq2zx0ubncgCTtzxFyltpkjS9Te+w8ainB+p80TrzNLlFXXJ5vyruh3njx33zKN0z227jrsv+71tVu+Nv1uMtCFz7xnvx7FOR/l8ftBCNGl" + _
        "+4mBBtJzpnl3nWuHnk+9thZvmsqU90eUM9fRbHhFUtaP6zaXCcyNDyrbNlXkxcaA3OP0Rh5cxSkawVrJBv6Cm6eXkyS9FmDAFNz/V4OhI1lT2xmvgWR8AWB3HHZH62dp2FCWTrJ19idD1CdESYF2LZruz/2Gbf4l" + _
        "N2YI4UWbofXrlWyvD8IaALsji3orkieoqOK5c5S6vPBd9ZsJ6Va64Woeh7/dlKZG/jGpO4xQZzrg2BaitYWe81hd4nhb1j7TKqjkqWJTyBf/vT31OTxPnOKv9Tjf3HUQ3rjd3WgSMoUZw2bO6f0l5HtIvy3U0CJj" + _
        "R7toKAwAGQA9jvHQu2uUH9PzdoVaxIQmU/t8wwvlECql6yogIQhmMCoy7bL7fvt5vr3/btPy75hNXsXOLwosZSQQ8nZNdf89wV94yhVTHKOIbBFliRul0I6zzn1BieN5RuPSWnRl2K1pH+3yf4fW/5L173mp4fF7" + _
        "q9X/aCDnbba47XVetZBODJs62/bPAv852abh9wrEvDxg4MA+Q+KwhtV3dwvNnmvzVOsy8G8rZCLERC/yli4eFISM6T5ut2WmSIgXC8bEhPa5lySnwNLEGarLL0LWugZqwd8rcJ76+ul7j4sk34zaXLdFbxfDHymX" + _
        "1927Bhdav2plCUFBcHUr3jMOdM2O65YiLINpR3mUIb2AtdbNX+DIs+ypmT2UjkNTWuC4FRwToEf3oYYjn/QhmHVE3/edyA3+zOR0QnAUqsCrS8VT+SyllvQD8H/aqOu0btj+zKt9IKhfvGV0tuCHHoPbZwa/KDJu" + _
        "H7XCFf6FHoAo1VV8gfLq4euxy/OrE6/bLNq9hH/Ui/djP36+1bO//hh4aXg+/Kzj3mVb05/0/OD9+Daq33H3VtkGWqI/f/F+iuarrcy4BSt+UtyuDoAik2CKgmCOjp7G3wjXKqkjrLRM+HUlnYDfW9F/zrudcOA3" + _
        "ZgljOQOP3+gSOHxThKIOSSDRRI2JfFR4lRkdeyDTtVaWnxFIcmmxYwag7DW04Vcsz1i2u3QV5v3yetKN3ptCeTMJRr5GaGnpbGP2v3D974dAPI1hHHgeDOQSleLYxZIDCAS58ydkXELUZ1KgPVC0PD2peE63mlS3" + _
        "iX6R56nzdWBTi1UMPUBL1A3bQOfqjh16a9Rgn1l6ojv3849PPvlPgY+FKJnzModkRTfygqkj358Tr3SjgGcHjpWNGmfw/wh/ar+h5ddwjKNHaBwFVzJjl39iKapUIaWCJBhBJLLSqZ6lCiMQu5oCMGGsoF5ytI/O" + _
        "KQahBmDknAWDSNu3Fj6MqYJZrGgl1YhF/PPfEjoDS9hoZ2iaWRaNxPU/LnqaaQ/io3ojqAPhjxctj3xQAD0I42bmGdzN8LbHkk+pGGi8ELCsPPMWdwW+nxRYshbuypsR10Ou0DZ1MtckdJspXSnZgthRE3FHrfpC" + _
        "fQKfoH/pD49Ov5mQbLePVopasBzAKX+0oYExljT6DMHXcQHjdJVWyPl7Cx5ceT6mLLDwOJqBqBVZ4vwC0G4/y/VFOiLW2P52CiwFcgUDy2wQYzhss5UuEYcEwSQUgqsGUn9qoCxdG0RT+Z1+2Aa9GDNDoMIiM1DH" + _
        "N6qg+CyPYtZlETvPeekbacm+4O/IFyUqqqJaiZwmfPpdP+o/xwfj1hH4faDuPujVfPEn/mNIQDNmydULMfRWw+rSrLPsNprEOvBp4K7Ns5fP+GWe1TGuXx0c5k0CWODcHzlBjkVO/lp1jBxjW72eWs5NKaFj5Uz4" + _
        "7bf4vXubv54zs+oQtz7v7Ltt4O76C/SogMHzOdmGjo58HcyJucsMVWElmBp6FvmZpE90B1WqxX1Y4eWhSJv2xl2+Mn3Ym/KqRt5VjiDp9Il62MYgh9DFGHSbfthLt0iVbAVrpOrjFsaVApYoOtu1Mi6sWPFv3apY" + _
        "+1GEKZmNSbdfZeyr9j5j63/g7l79qdDPjGFxq9688GHXl7PYUh6USFmw+uSShJ4jhEpylQTVu1h23/H0nJZqfFZ6Ywa1J+XCTtAVaxhGEzvATDeI7acRSETQIXbJp7RUPHQQpHbLEucULALTcs34hI95d8JZ8Fvr" + _
        "lxm/Vvl7on8dL0jCdeNkkzWhFVJQP+OuTsPkf1mwxOGW6LxcZAz60m89l6Z67yEJAYF4Ll/93lJrxA7Na1hNVgnM1dov7XdniM1nGcqAAJcxGieNGXksqPU+tk4XO445UlmtsXslbN7Tk8JZIN+OZ8fqmpJx6vUO" + _
        "fFAmxgvUytW4c75i+U1brhYd2PSqctnbKh0+X522oXNHAq3j7x3qhIlBXtyrfn+69D9sf+fq52tpfr6z/U+6bq/df8T9Wydo4Pr+Hj517cwtgt8OcoQ/B05CaUir6RwFCqvfp8/5UbHfZpZBNcR8iIKbM1c7eiAz" + _
        "WFFE2emYM3+IYptja1yu0rx+2D5UB2JCRhzI9mMMvYfL32dF687icMTwd8ZXbkT5FAIudhNshoUkJvIhNA9mx/hO8dr13IR4XjfdaLi31rTHbiPtRf/ulRkzgBC7VJcGlC8gdWdm+qAAWccQIOUnYch2aJwT4LeH" + _
        "173nyJ9W2XNPWpUVL00l+qCeGTccaQbrbZQlthipbOY/+QoSWyvtTQQrvAWJ7RTCkBY8sTSh6VF3qzMpQmU/3okel/k9tr0d93nji6O/wnbvDyxBTy4gi3dcKOdJulrwF1AxHmhWDF7ffmzZ//QdzrmU3H21fU+b" + _
        "n05uShXGnwwovZ3pfxO/bjnjQ+sl7A1A1EahfhY/dx95zhU5T6mmkIGVVRMaGSGwPUYmry0GQzZI01i+sMTsqXPzPGH7T1ptFBga86pFxh1oUT6O1R1k+b/jZEHTzmrN2VRc6VPpf/n3fmnvMtK0UEer/yxa572P" + _
        "73xtk2un4QSr7m918U8T+//i6eSW3PiFaoj7vwPF6zmnuPt9q98dIYdTVCEVzT/y5kzUrx6Q7qmcpfLmzIzHFCm7TdiGMcfJbRC2weY0BJta0xCKAM5J95tguvPdIfC/iP+OL27pfajjj5pjLgvDutuA1r7KA6V5" + _
        "BTnS1D55TrqOwXefvHDP1mz4ZoO0V9HVpxGC0Ub0Hfg/c8dDcxCtWmWl6gnDYGWGCshLe4mmr8x6SjkD6qdaaO5/+qp1TamoDjxcMF2vqKp5205WGrU0yfQtFWxbK6eRTl2bRsmlF9JoWukXL2mXUKidu6mdpfvK" + _
        "vc46f0xLMtBVBBd9lWHd1tmwVjihm4IBRxQYbi+eGetYmoz+geO7aKFiTckM7UCjNXKAYrQcFr/wg6FGdvQ8KrMSOEamrkOMIQvCbi4iBMP3qmiRpiDIFNSGs8d8S5Eyw9d0vkIdzdHUmGSN5vWDjQiYYRK6WB3z" + _
        "bEa5s2iCfOUdfnhgQu/STftbRdNGr5SGeq0XH/0HVW2zqrqaThmN9I9edskLk6rmwo3bYmPZds2a998etqk/pGnc6B3rmkYlPUJtmyPopAXqe4rLnWdmyV4+96Q2+JVcYhaOHYpPmSJ+myO1EA66xx06CAPLYglH" + _
        "nQQI5HhJYl6ZigW4vnCg5rSrwwjPYqEYXSPFGcyOLzQkcswWscIXG4Gi9UTNPC6fvhKiWNCcbFlCsNHMTc1YsJV7lxdzu91H2Dd6zrvqGP4/B+q99Mxg+tp3KDbExM5srMbRVlBodxo9XfHsMdDgxLHSrFgxMHip" + _
        "GCBtO1REX7PpP2WvsG5+QHviv0Nr27qfO2CFnUOY0cgQLdQI98TrzUAlCqi2KgN/YWxyelWHDR0g6GDFWwKAI521oOEipopNl5FaJuGsae7n9lDMYDPCivZhldQW5NeukpxI5JC5oEC91Dwm7HtfHHPRPWDuq5Sl" + _
        "/Q9ZrZlhtIuW9UF0u/Cs0NOaNQsXve68j37NMK4KkHSXA2Es1HKbpqYSxoVY5JCIK+ZrTDhg1FLyn2Xw5Hk8MMOkhVAnaIyWvqokyyAv/2U7mNXaz+L+0rkcKEmcWQ0Z1N1OKwwZqSeRIauY3cAEMl17jfoFeJaL" + _
        "TZKkdI15ON68NXv/YrcYHxAw6fP0EA7/iDMJKIssUcYbUyTMUaGoHBoUNB/U7xRTBsj5VVs35nINrEIVz+jGBazdbludxUuViO0gFnwJl+BIsISZxfr+URpubJVJxUHtKq4Iu67i9HLrB8Mo79GSQDnlAWqX2HmF" + _
        "/GqGN5al4AANo7MpwoOm2N0nZOAdjxbiBU9UUgsmsfOITOGLOD+RrVy/GPQtcqe/UFBGtKtczZUUohNAb47K98gg5thYRpsSdhYdQyZsnqrj+RXYoM0xJqRBErxSFIV6tZtCOS+UqxUZRtDYtdCWfZ3HK96l1ZVn" + _
        "m0+QeIyXtU0PdqlglTHloxDnejobQ6iXZsNbbHSRAM4grGhiJ6A7etcR3ivCNfMohd4HA1GQ2Nzq8PqgxLDeb51i+ppbKb1653RABjEFhqkB8cbmsjBnBEQhGOe0cY6II0rhLR5GhmwRILh+NCIkcZC41EuORWrV" + _
        "Utip3+QMo5EOJs3je23DtQHlBlUYLAYvkH9BORSwlMHfACBSyUEG1s9c0LWDRLxs8EotOy3uQlAAjFLWSH0xjBFHAoiwywyxY9QhKdBSc/QQWIodnDMxMzN8X1NlWbHqY7y8snjY3NAjAOhSAQC/sm7si5u1+NsW" + _
        "drUKsYIZPHCfCa5bsovkiI2eSmr8Wa31l7w4UjLznxTNdHOa2nr9kdTRTPFhUVc1eBy7D8u+Fy5rsfnXUoepd+6j5VN7hRSAFohqt5MSOu2KjqsHyqiw85aWkQy/tfgwF0kstshIvCOE7gg1fwZKPFLEQtS/Py7z" + _
        "uP6l8OG23xPs2mx4shfdpFz1aCYsqqWEJq7ePBB4jZwphiQjB7i/4inLQIpWKlchaSy5V+t+rGxWriLG52/cG0Q10D7UaEWK4p+r6j5jYel/odJFAkCthfXP96oa3ncT2pVyw0oBQ5QUkxegAnlVI5GIt1Y/wU1i" + _
        "B7Nmor14C5EY6YBGsWqztPd8FEki6Se3jGBW1Z+6SEVR6wifcaNxMPivU4c79Dyb5WnE6xIBhMvk1UTdwSKU44DKI5/0MjA83BQaLtYeJhKsICogi1MpmSkJAiqAVNvC1VpwQHh5ykye78Y1azmCkoGzLmoKLTQV" + _
        "nz8tVIffg1FtoIAKAWYJmbikta/0RsfgBSTARjp3xszlge5HJSVHxwIs4tMUh8lEk8SQ8Ay+/tikIq1iCaWINVjvw/8DzvQKZCFKZVOfXa4lRBW8Qif6rfm5QxWDUAD93frO+/MI/RV7U33AFDMcDjeskk4imSgW" + _
        "kigtFx6FEAzyDuEbZUHYWt7FdAF+JVlIzAVNjlijOWp2zxHoPYIgit1x3nuFSZEY+0ACkjHPRCm/WKjikTGCCk6aQmrSj9+vWFlHYGmS39bnlzoyNfWnwA+VgUixQjFVRTR+ErwaqlXKCg64YLfIc4XvQQ04UQPc" + _
        "CBFmw0yDhLhRj1Yw7q/AqDKXFIIKlmOFnRPSa4X4/niIJz+b9GUBSANHsjMlsSBZrldXeZ5tfv5yOf0mVcntPFb5sOaMjFmCwiJb2CMdtupGAZLwuvygVoOPrVbwAGSRI4H9CU7XBYDFFx/UAgASQzkiV9XUE7ft" + _
        "8DAnOlSIsVWv3bVkHU33h38gIOF8Y1yqW/bNhVX1LFNKhm91IDGqs8g9q1Xor4nksit7p+gKaH4WWR36Gapu1IvVlngBk1i02iP10qw8BA3t+JorSSV3jIZPX77Vaz2EYAqVbCnoXjRb2wztvBVbvfHHnizh5eZK" + _
        "uaMTiuvnDSjFpb2M7nMzW5gMg4tNGphYAtZ98LIzGKqbLVgvCVAzRtC6BWgaBpdFG0LNn/jAIyetKn3rSzStkQBZ7IS9F0KDwjHvJkIdbwd+F++GS4mkmOZBC4P3LVAu6SqBfkSIIC16ev/j2+6bj/smPcjul2d+" + _
        "J4e89bkryadh+78xLyN419G2UkA7IhvqJiIPuQCyqQ/JsERkXBsfVFIDz14AKal66YXbI8VOzWImE+lrvXu2df5/xy1rMXqPcPs8jFO70r2xtSXJwPqWC3wdMa1tUThslHgoc2AHW8TjFq1mi/lgg8u2kQ6J8Inf" + _
        "z9RBx0uIolCeG4o2StSb95+6ghxCIRwUbA7AwhLub26KmzWFcyL2Q40WZCn6IHfLBLFCyaQtTWFTQR5g4q62oZ2986FAWEM+moxpa6FcZnUF1P82qzBiHfEEimedXK7lvEHtq+j5RWN0dDKJNbHsWt9+Mfm1RCMi" + _
        "l/BViAeR8NcCJpn3Fv9MkWtHiSY0thgro0KsGlT1X4SafmwHhUWqySr4lOvxbX1O7heszDbRWeU3ExUmpJOaeaY2LsUj2iY13zKiQGB1brk9MzaaIT+bVsIlWxCspAMKOXlqZoORcAhFFTq6dZYiPnRGiFfpMgXF" + _
        "uDuzy1bg81zAFQmovdT2SySERCUcAIqd21vA7nA224VcKtTF6CoH1y4A1l4e2EUdtRQzTvtCBE5rvFxzj0cerjkW7I5BReaDkgvRhR03mVfM0ifvCxSMi3DHXm3yvcr77VfeU/Pkvr36f1d54+nZ+LxXIsaACYbc" + _
        "WGWXiMspv0NZy8CwJXYOCIM6Vca2sNpFuSoU3myAHB9MKOd4/4vSOaTIEIKWaT+p+u/Su96isYb8n9B9jR6+pLs7q1CqpOxCZy7nf3jlz54Ou2SRuUAZq9VQ2zHtuPyANfmCX0WREMT6IFgLGU0KmxtQQaBi9ZDP" + _
        "T02H+jPI0aBdwBXN3MKlubxmDknNViG5+u5ZKBZdvz8kMaQcGweKdzfJB1xyn8qwFOpY0F7urrLzRLpOG0YNxHJpmuJu3k3VZvWLHwDLwJBV6D6i1Oo+dhqgeWo1KL1/f3dsHi8MFGBRgxz2E8U1exwIYQONBfz6" + _
        "FebYgYbmqeS+AvwfihXP3sA54nhhZxcuXTl/zzR9UDMQo9kLo3I0dNcfpYvEeXY8+vV8QEPMjYqUKNzjVtzCxWf1+peRiSEFlm3dvUDpe47BXuivhgyMh6eeVY1Asu22EKKSKIPp6pn2VSob2NlqLzcJYOOx6TBU" + _
        "c0wO7Z3EM6YpuAfvPipX9rIbNKHOMxSNIyxUmOzBMEVcsPX7RgKJI7YPOCqSVAMVGuedfD5ixwKhQfRhxILfLDT73aTT8LhkvT05wTAXAqTmpb7Xei/cd+80D9c8eO7s/U/L7PQuXnrPuiEjFC0NLdw+nvC5ZN1L" + _
        "givGdMj06QPys0ZBoHvvgt8C6k9Y/R4EAGEjIEY5IbIGO0RPGIBWOYIwOsvwSl7PRJlaAJRM1OibH9L9f/K+tvqw+a8PA8v6zl3Ve+xLPzqXNPujJJRhXKTpcj1TUktI6xkfOKGI0mR4Xbh4vksPp4+mLFZEx5Ok" + _
        "rFCSLATpapQs/POr5HG63R772xtiWYQCinL2RS1SBXsP8/zc13haL4HJCTsHbOThIRSRsHGkGyXsgiSTduTG7VGEiPobDepoPU8SOXN9zwh6vQOn3zgWkCaMrmF6xOkavR5gtNAYAYKJ4iMeCLV7XzL935C9R+d+" + _
        "NQ5C/Z+cxdVqvnzLn0TOg7MIWFaUeHzSdnjhRX/5I1FqPURQEEcEcbYFrqTKwVYhViqu/RdJI6iCMmBpjwOgA80wy/E6BE6PMCFIY8+QiHGxNW7c/Peq/O8/4+JSDozj9N8jfztOMVM/mx6ZN5i9OpRhOBpc5P4c" + _
        "JnbhDas6oiADUZHF/V63GdY9PF3a793ZRC7ofWEUCuvixaBESRqfXAL95Qs5A0MuK5A1x+OPHffi3RWzFGlimweNIgXYngZg4t4yNm+vBomAkcXRLvH6xVqQ4deTSsc/DEOEjLKYUP3M7j7omNt38YYU6o9GEmEE" + _
        "ChNYsHs8AyZPhK6aLmUnQqvBmWtvtf99+9T/dWYmTvecvgtb+108MGT1bztY19ZUVCEdm9fV3D/afm3o7JahnnOAQDLKGflwXPOlIgnDj546xOaXJDBTmoAhwBoPNojq7wCfnefsGq6eccSrFmdmJcfTzPnd9H9e" + _
        "zdPF4X9p6Ef/Payb7X68OIjvSsv+7FiQSpjWiiqc6wiXW+B0xzO3yfIn7l0D4GluHkbf+tGJ0/UO0kRGwMdVEbO052WjS59hSFkUi1Nf9bEZGZ4dc1si0TgYIQmr2EB1Ew/ook6XZSykXUdc3fRpkzukqIrq2EBr" + _
        "479G08go27wmxYoHBIUJoDjF45Ru/0WJdUvfwkIZ5lDMu796xaf6PdDveYaNryB54/292xS//avdXab/fukFBxt0tLoXlfTovjPkC58HlA0kZ5UDLkJqBaxqPNYLN8YWAPfju0joV81uCSR1BWWdQ+d8vlyU83UG" + _
        "rPInCNN4gkcJo+jU7OHSTOo39/ejyd5DhnQA/+eP/hbzq8QnPV+G+lxvW0UWdZCIeUN0mZzzTS/4hA5aHvUySzFKb8jOmMcLc97c9AEfzzcKpnfE87WRBcgCioxxN67taqlJMTSO+jJ0elntih1DzSQ0193pBiOb" + _
        "5ye2MFOwTuEzaMbeloaxeSiLT2rRe3Ez2nM5Ul0UxtBAVe1BVe6rj5w7nZhuwmrymQbTRMa1p5z/kdxsLl8waoEhLFxitNqzInours9zWd59XJ7nz5srHXju/Rj/a5C3mtru94Jmz03zfeVE+obG2EZyGcdvojej" + _
        "an+UaDJQDoovu1t4WNI7l4zOeyQ8KSdvUytMMRucZAx5BVJHvqZKTu+pHd2WLz5tg0SuoiWC4orQt6v79eut30/ezzR0mHmnj8cCt9/9+20urL/XzmXTZr6YUZ6lIOz+vjPPU2DXGV2NEanWj/GcKIIinctm9x3l" + _
        "3GFaEfQ014EEOXIwsoh5mqQtJ1UTmfF6rhUUjugVEDu4rgFgt5ok1XZP2TgHz/wUbp3nKu7U4WZrdGyug3L5RYC8FXpGu6E5seDoSh0iEJn0bp7kJnnRDxzso6TlWyOYNzbw6CI99YkZusdE0w/oHI9HgvjHQs9Y" + _
        "NgcRCNCshhxtzUMi/Lbs55GmDpY5ZUkUZCXhGfNUvv930u73vrf+80me5+Qb7w3Y7qMzv8cjrv3HhDc21s9FYCVHZ06klBkJwCNdmb9jahe/Ezo6t+3JsEHQALUHoSUAYKGQv3CMPzmfJhIJJXkltIwOjp0U60pZ" + _
        "2CJDWrf6wzj47cHghPj4n6LAEVRBKFH83JUi2Dl93l9bftfbx5+j5zYYOWfI9m9afs+V6J0v5lcz0ec1eORcz4HI2aB2Jobw4Gheup9HXhc8vqmcmfFKDBoRhBgJGNQWn6z0vqPH9v2AvS8oEOTTjq1m34l+DKQ/" + _
        "Z+HX5s28gJck/RpWRV4j+zgCwb5kGl7s0ofl2waV9XZ8T7iG6iASJeXy7iUCuFDWDNRbJ5TLY7Eo8xQopmwgL6qmOekuyegt92nXRBe0PXUIMOx/OGZx5/zRDFviYR2DXJI744LqE07fkss83/7gGxwHitdTSZiV" + _
        "gyCqCqFS1HS9/DT+hsl/L+X1mn1ZcQ9M7X44z3mb7H5tShOvYT0viCuqMBlbmGD2OKN7Pvnil7if4Mg6mvDBHqVr8JKKvpTLWi74cdK4lrh9tz8pfbUPWzxj34MVvqhIJCqJpAKoAM1ypdHTPO679+XNCpdlDiFU" + _
        "i4qKqpR3F463zETt+h/n/V6s/b7C913/Tayywf79Nvb3ufP+eWn7OYwd/Ubr6GHDGJEgEBdFOSEh7po/KYDfnjgHxzOTs3kQxmtIjrrbu0D63R+hP+Fs257uFUOuALCPlGdRA+gabgeBINCC6eyHwqjxlRM+inaU" + _
        "vk2jfJD9Ix0l+JcGePf9hv1G67eXG0jGtOS5UQT3KK663xjW/gysCIEna5BmlDXpp47+7Nm6NbzlNGpB6cN0wKdp4jHv+3zrhVL+uAC6bAIxBt4iqRAmjCwtFRz/5OfVJ2J2yDxDMYMZrSpBXcqwppbt8fQk9CfP" + _
        "/Gdf/muP2v8Xlv/lYvf7GFucrp3Qb+/V/71D/+ez7jex7Pul6ndXbuF7hltbx3kn8m++BhAgYVPawxbojectOOd3g/c4kMlzVQrGU1/clPbcojhV1Qc0XgAPhFph1Ry5NVYcw3o3E6RAllM+ar7zB8xr3+W3js8d" + _
        "SyZEh+M60x6wx3zuhaz5x3Xee38w/Nex9M5LGP7bRd9H6mlcnjNS74e93/MovfflXO/H0Cvf3clnFzX/BuSHz6FxnSroslYjT5m/YWj4zqcg3s+ZuKMof9xnaKDaEsbQ0DWqXbb9XeNpb8AQdHSIHj9f+XCCRTbP" + _
        "TQScg3WMdEByZ79VEQpiXQcwtIPUOSwMToEoMB4FtqxKpLPWFVBXFuqNqL2PLtwTdsdhUPTjmxUFYrKhUBRcD6jRt7QyHpL51QPSKQItfk/A912wz/lpd0BdzznBKbeuSlaEGkZn8CBApDOmzT1VW7QSc0ymaMxh" + _
        "3c6voN/R6U4/b8GAjTMai1g4YQsy6fxAk/8vX9yWF7J85wlI77FHOVVDZUrmAgdusBOHRszd7Kftm/T5E5ZRyHump1OksyzEPCTp6d+pbW3hx6m/HR0nPKijEEYxQIVGms1pfufnOTxTmfC+MY/wf8g0DFeDSSJ5" + _
        "1PgGrK6ORVxFtztBFfCeffkumX9If8KMn0Tv6Nhqn+0/kJFdbRERK1fwXr//bt4V5FPCpVJgxxbV1gkSaVcidvYWNrSPP7ftjv4gqytySBum9EYOoFTupVKNG6Uditzwt/z9jDUz05rldFrLP4YRhXgKEhfKr578" + _
        "wbvk68Gc7rM4pKTJ+keWAIzvMgdQUbeZTz33fPEPB3nhh8vpoLRUI5cPxrpVX9p/r0D9TlTd74L83zGnMepHnGBeoC9j+C8lq/EuWltiihtWS445EJV3LBwvloW7P2hvj6Z/hEOqXoTTCFdFAi3HmgZrRK+cwV7o" + _
        "0re8viO/WNt2G+joVv+n62WQpk33F+FwEjF1lAzmgN8mCjC05K9Z0J5sfopEwM0Q/EPUnCefvu8SIZ1LJ4glkZbRGWEBXCTpppfgZiBAxEjVQGeMX98erv8zvM83/Q+Y+At+mA+bnux0fxIWhMsk0gbzHLNdR2Im" + _
        "ttx8Xh4wkG4N2Kf6QoGCEzEG/imfXXuMjUlQhhRwL9W5J6j1CpbkrZjlOkwLHKdzLnTZ7H/RvNT9ApFkLmH6QChqKuNr7UI+qLhW5zsM1YEqp0LNc8LcD23Edk1hQ0B+eljsNxIOsUDj+q5g14s6djH5PQBakreV" + _
        "NGWP97vRyO2WSNzOE4l5Dc/85I5P6vC+MkWvQbBCQVWVURCB2uBCspPIEQOwxihdGwBZRZjMiKqeqLzJZHXhstppfwe8467A2/PtixOtR7A6Gv+ocnhvgKKAxvNop+/Uuvfqd2zNd6CJs31N0c37iPAD3OpqDgE0" + _
        "4q3+EtLBKd6aWgQoRMyOw/UChv9J/BcD8m4dcFwnC4UybYDNwiiA43a+vkfEOrjevOSolRx3Tt+bFCJha7EFkJ6RhRVmZkm74CZLlL/lDRbyTABIRz4AVsTbsRao5pk1PR6A2IhGYMTAeSr0uP/2ZwH8rZf/y7H2" + _
        "r792Vg63nlqEcxQKWVzkDffUj3W889Uwo1nc1Rjt9IFwPozq8gzISJSBLM4cECHvmMKETI01EW+eY0Rg96Um7zdFvN9dEU2eHwotr9L72S3p/ZbYYAAArGSJQA5Sg9+QGihJ/RF17n3KJkObjrQlj6lEvCkuFo/R" + _
        "1YvzLaK1MQvqJd4Yj677l1/rpC8q7YGl7sq146t+L/TmbSJ4sOYpeTNm4bCqWmAC94uOL6p3nkvQhvFnRp42QfkiLKrWaGSr0FV2oWVKWKURqA5WDfJuDhKLQcxIhCmZwMql4/0WaNot/wQvPA/ENZ4sIhN+rAOE" + _
        "IxQ4jxgwPI8Lvf6LJv3RVO8ZdPvxOk+sEeatr8o+DF4d3L0W/8QxsQBCo1i0chne0Yr9e3gBSIZ5JIBxn9pInSvcFgwTzAX0Qj+5UYau1v61/sP1peTFPYHABG0VnRfLv9DWsEnW/4YrkaxeJoCkd1CtjY1skPeX" + _
        "kZTILZCefjF9AcCNPp5uIHvnPvyrv+4LSbyuJ5XKOukdo2uenKiWqeABsE7K2C+sh7zW6GVc0OyVdj4newQTvYuBLKuZSpUKtsGcKrGAiVjD2FiCDHSX+uwV6u/U1BO+V8ijO5/A6QES7WHCcoDM4qIGqZumWPPb" + _
        "c6vi8EkJipEFK0ibOX1vZf/wXDwiOnbeFIQo/gT2GZgnxUdGtyCF13p3ZN2jH/ymB8xj4mVmN2d7/P3nJgX8N54RLlFYPqqW18fUdrke5lmBOxAoIwhiZ4FQFuyLjjsqODy+meMuTyxwtAqHyuGYroJPY4TYBo+U" + _
        "MKOTL496WuHs06bupPjsgu8dDDk+j2zZdmmB4vmhy5kCUs0aFJLH3VUwzyln3sDr7v35ls8BgiCqNmo5GoJ5K6aLxpjkPzYqUZnsJfrVbhciqbu3VIZ3EP5z9idnxx2C1w0gR9qvUpNLNeWgNdgR65+PsdS/bjGx" + _
        "7zoFe85cu1d7O/+nACcVcJRmZ3Z/UYCm2CYYINTYEwWK7/14yNXfArJOKEEtGZAM6cCuX/UcUfgHoDJIKmzm1GNPJ1z/J5j/8HT3YYhG57lOg2FhTQ4xxqtbIPWsRGVEut88LTgcvuF0z9DshXZ+vQsgc0jjbtYo" + _
        "BhekuNlUcj5gZF5Tr2D3ZlHfaonPPffY+fRMpz2gJmT6hFGrQIRX/3sYjiBmfdKUBMmeVpZIcjFOyVwV1QKVtz+FAktFNd/KRAP/Dqgj6K38Nqle0y4BoVbgP8k8Z5lF1rUO1oYdzWiQEVbshty1IiO3qCc6qkjZ" + _
        "TnNUxjRi79f60zfC9bZ0G0e4NSsycK9gVzjqIEahvidGllTESjtBf8vIF6vs4yZ0DvcPlpUNaBbbsCnsI8AHmniyKD9/i2d4VPgc74C6r+Wyu42811Cex4uqDGjQ0HjfKALUwgUQzJ7fVqJmhkKJiscaxisg7Rs+" + _
        "zyj83yL/o4Xg8Ls1nKiaHawEG2nkaQ4xr74EEoHh+vrF0xr9rxlkeztqu0MlyPpEbrp1BF0wN4j03qCkTpwkF/oSSGMQjwToP2yCZvjgQNV56oLAhLJo21NmHm9GA/rdh3NvO/q//DgcLjknMmk20HxJpGxa50rq" + _
        "O+q5CEAXOLE9zNN0dAc2wdNYGZZGjRw6tBxDNhtF+l5C++c8XoErdtmV6koooER7MQMMOdtT0YQSKQBCSuQi6cEkyjGIBtsCsIw/eSQVygsUjmCgxhRF4SIwMNYhYgAIOerdqFdknqaHfvHqfH7fkZ4RygDr+R6I" + _
        "MaPxY508FKmAHSJAyyiif6OFVJXUSEsYp2noGNrcc8Wc08KcTTzjrJvryXqr9NrEV26DMD7+sKHj84p3bY6gBMrAEC3sb5d6cuW4LiAoiwlvSGk6/BR8vgWh9+So93wttZ98EJsMHEa5fXVbZh1JFFqZSJhfbrrB" + _
        "bgiic1DVH/RGiapm2B9vuT4Q+r3R/o5vAIffib8KM8tfSydVWn4iRD4+LUNcDGi80Dx3PH8gb1jb9Rn/eXb93+IzTOGi65AASiobZ8lCuaI8F8GM0pBFWnGDaPhv40sDqcCCOA1rMAQanHa0/z289v99/WrbfeNP" + _
        "CT1c3wFdzkAkrsLt1sA94zTeGkAovE2mAIlMtlbDOjsN89Vj3EGgGkkwe3BSTBe6MFt7UtP2pEZpK60On8tjibo0IJl1MasmJFkZAiBKMQ7vEKkmS/wgt7ITprk4G+mUltiuwcXK7R5+O5iFLqh24MPUqDawRiJG" + _
        "sj9eyvmr1i9KLMmTh7DYFbHIxYHvGmVEY5729+kB7/dZf3vWvHuvRMfbCD+zObExAIWcgUm/Ol0bUT/2GslgOxSXVEBl3BynTC73IHznQU7uVl53jyf62vrOZjM8/z5jeQnmQvFw3f2GyP/Nvtf6ANh2xDbmbr4W" + _
        "oUx9VcIvGGh9Z5eDxC93VF1+FIJyjcWjI59STvOqWFxSodsoig46mlbvAXPuGF3/WUrP4zI2h8cdP77aLSM1qhTWckv0imvYKVLNwJqmw3p+GsvEM5imjaXGcFXzBURwOQiCrqmdZggrXDV4mVi2nFp2+XtiPIBI" + _
        "8oR4wbBS2kNXqRCJTyT6EMviKyVjYUAKS9cCKG+9A132pegtVAlyU47xIERMUwd1IUB2AnSECoO4vTvQlrU+FmdCp1rd1ZoBbMnCIFu2sTsQGd3cdGndsOWcTzZiUWfFRiHK4ZeY/D3FGJP/h1V/Et1vZ6r9fJjP" + _
        "6do4Ck5NOCoPk1zA/M4wZxy1a1SkEKWcRTrv0mUEIQ8waZ74MNU5WoVfeJLVkw4D5n9EKmvMzZeA9d0iIpZZMrBB0O4bPX53+1jc5Tv4oWMrQr81obcQ1QKeUk3Tpr+M71DS57TvHaf39lFfbqW8/fJKU2jBeFSE" + _
        "N4dQtjq3s1pMUFhA2CXagY+vS1U6bkQSarDymeWK0G9fSIAUziL6dU85fXPMaa2dTw6NV+bZz1oZdS5SHrm/zn66EDBZYtkqIgsNktLhhNyBDjAeP223c7XNMcqf8ITLK47iO1Ksyg5BPpQ8AnyBA2sGwopwPctF" + _
        "OWZ0oEdkqnbEmDQO5AIdtYxeZ295EthnJTp35tX/WP3xwZwvWNiZtpxLYkUUiTQyJmnnmLQXqwFlNVcbkiP2mMMir1WtK2Zr8qzGNhUsgt+K/JLInonrzbRsnRS4ZJoRCW43UKTC8muHnNQglkR9TqtFuZo6byrk" + _
        "Y4rtqxNU5gzxo+pIyeFwBfx9ML03gd1/SP3Rlv6D5ea2reP0iliF7+I6xlERnfxe2i5xoDm1PwBH9FKgpAHQAxs7MEpcFneOSioNu+y+cQn2pQJcrdZ+/HBsOG7t7UX+yYVS4iM28lQRw6f4wr0mBKWKpnX3Y3tY" + _
        "EYsIkFqqFPBUWsY+ExyPd+Z9llLPbUrR7+eyL7Puu9B/KtmeQ3DJq/mMqIAb4kTb+NW2qBY6m7i1794cDQMTipwkr8FLmaiumHVdLQsEGmT3sGVOyx5wh85NPOA8LGe1aTC0/HexJbQPlS0aTJl9aEZhaSmhEi8b" + _
        "JY8SlgD+2ZfS24w5121pxWcD3Y+u72tGf2yt+42Zo8shIDle5+jo3dnlA/fOd1ksDzQYbhaTfDeuDC3xLNcAhDrLp1/GizMI5oBG7pdv4SdGo/EIzHjESBbMqB6L4lMXr9shDVx+d0p48TQ175ny68T/x6z3cteX" + _
        "ds7/pczhSwBYKHzwVUk5zgrJ+Fpk+1tOcapt4dCQ+5pGCEFFyxq4cHTCrbXmGGuMpFYh/3yfe7fn0zOQfgLCyHksKpqIj8mlaR1ulUMI2GJ5KAXo+5H66vu06w3+H1B8t8pxjr3bYiZgC3gSrA4nyx8l/HAJgJ4j" + _
        "fLYChXbzAJrAsIMPk1Bls7pHvV34J3l8Tuz23Y90s394gDXhkOprQH1WjegXCo8RzUj3ULms6sUaRKoaEQuq5/IylFi1HPj1HvKjOmLe3975dx4TYPyhUFLL9OELHwJuAybeurXt9kDl+7Kw81ygw+HxT/t3wGTN" + _
        "70zBn02LSZ8tn9oOdIiI8b1hCc+jW3eZiEnOG8GfGG7CmQAbYpf9AmTl/nBx4kC5u/CzJBE3t//hFBSOMeEbFM0VQJhaeMSt7bu3+vxr7rvAFbZM+5+ydT8Hkggk69KaVz+kDW/cx8Iacr5SjrbRS/DrPSq9H52+" + _
        "06XirOtfjEJ8g4QA7N7UKTvQHRRJq2h9USXbWH0Jc9pZzO7X6idqOjcvnSvwG+/mmUxvPAPPc5xfnwdDPJ5HiKqke4NTomZoBu8B1oBHhZRzdzBR+BOaJ2gI2DvQdZ4TuvDK2c+9LIUXguwUd0LrEh+wSbgjZoWY" + _
        "4282FjP28dP8Pq60OgHjn8WHE54nsupdVT4//yrkXGMSfP+fQmaaPEHPFrIU88kqPR/74FeGB7/VI1IN8N4oz/L+9na+vFCagCqD1hHl0+yt+lsIdjzu6VhxuKbXecO46Tlnk97QP8wYOAVXIpYUy35eWR9SdIs5" + _
        "El8WXoVxzNcNzkA4qedsYr47XrsF+HsOFFvn3+Hzh+BFvyWsE4hcV2e5o5YU5WPYYwf/+z/31ySHkLTd+boAg+bVD1nwuBuEgzDkvICnHeZnoLfniLRev/quS8LjNVwGZgjSAp2ZCc3doWTA5ZTQUiox4epRhCuH" + _
        "I6VEyPwlanUKasFugb7beRoe+oEJT+AZksFd+Sh9eYSCqm9Oy8JD1f20UEpjJoHs8g2gOgk7GGy88b/ShTopPv335UFjTlkWEtAcJJ0TJkwTnXb4XUbuxIlkanzEgPepJX7N6e0Hc/Q7GgTD9g0pAm5nQgJNKc+Z" + _
        "3AS4WEOmwW+MBTMZAiGkmnGoQhkeJmwQVRzdMXb1hrS/QdeXaIRXmtf3Md1nahjZ9n/bpDAZn1v2Z8PAghLRwU3uFvdbDefqYkGlRzBELNbx+LmivgZ+eoxIH0j8mzKdFZYAPvpke12N/vSwuf80QwWPWIFFjGoe" + _
        "lbEZ8ziNnjBOAAEqViF8XoZK4iVAahKU0BLIFhkr1gWRalBTBHw5awQ8iDUD9yTt6OdUsnpugqbN+X3mSBoqn3O8p91k1J5Od2+2g346KT59W4un7k/w1jB8HxkgwUni1ajzoTE2ZGXEaPkSBQcMKmrqG8byargF" + _
        "DfQCEoKMhGKO7zI+3BYhiyfUXxdYZElGTO0DvOy1TccMwZT3P7jsf0H5fC+O/gG/4KsQ347oPoFkkOplLD7r6rEYq569xvcZvYq4obY1agd5N9L32akTyuecJsfAKPWHRGpTkCVjocBhQVCDMqiss57FkEIH2RS1" + _
        "CCy7eORtu2PLOJB9TE1eLb3UKKm28UcrnMWH1oru8FJaXIS8uYFZonhpAVoKp4BxJ791Og9haJVP7yHxAYt+bCo1vGBLBGMVpHAVLhUjVgeR5B0Y7gtZGVZTG55Vyj/yzEi/YKepNtDRkhqGtKPmFXfkg67+uDa5" + _
        "7C2SBYUuhyOEC9vzgClkqJKkNXMkFU++46bd9z/+dOlmN2J7peZDxVTg1BCgQvJeBMoy7BloHfxrZjk/i6wiqEI2zVo4gWOPkHVvCrcji0P25FE6voVd5sVPHIUhOmxMQkBW26Q0t5C4RUaCpcpASeadE2heryNv" + _
        "iZna75iRVT/UzSfXH8Iwwz4jPmndjeOedEnWIVFJHQWz4y0zGsSKRkwJcJvViRBrfJk8sHyajIFJQSc+V7XveP9qJqn0nQLp6v9IQiyrNl5TZFiI3Jrk1eUqoPJsPbhtT19zyK4i/W8MRNi7rboxTTOtCTqW4H2i" + _
        "SeafcFusGJT0SP5nIEYgkduSNYX1IMH3Q8GoWRhPkKlCXxTVn9j34Jv7+Fl4bln894+yygA129KjPxfPlrsDfMmrddLVXasfvq3po3NNmkkfGYLRoXyWdhcsfLlEG+AAYEL9XoBGRSwV5FRGFF28MYyXRoB26F1E" + _
        "/X0/3fZ40yKFWrAsKZd6J2T+hwmIgr44Uji/VJQnk/PpFHiM7+X/SWk2hMk9rKHeZdVdi22aAAghXw833G/KGYOUFwDRrHLK6epM9j7Q+5nyCtsB/2vW/9tW/xHcs0iQH6S/NJtQihf5xlcJaB7RukEKt9CcFyTJ" + _
        "lDNOPuO/nSsoNHbNDhXaMQr968PjVy87Y8MJDoOOSi1xGN+kRmSaBsT53Mxv0/kPd2XXra2vIgD6np/rGn7Py/zu4PE1bfu2tKKRIxekScJig8orNuWiMHaamBpoCshkGRN6KRdAyYgqfdyfr/7TzyQ1cvpEnkeS" + _
        "nC5ZJhYM+4zc2BiWOGSYmOTl3zR4ftLUe77evQPffbLdbTeOPgtRto/B//64fcL/uhPnW9vAA5iFNqiXrCNFAmaxJb8GEaLinmA0zguRHOH/T6eUL4K3s4VWS4MbRU4CaU9CWNdeZIMnVrgIGVf1fML8lNP/doj+" + _
        "twL//fyvu/nmOhvgz3r8V4LndZX/3oz/+wI84buODibB3qECR+zLbrtXz4o7z3VI88EOatRYtAyGvIZ/+H/K0ef3MsnDmKTLzJvFuy0gGS/bsagapKCjMZIjCDFF6qAfcHxeL4a9b5u/h9l9R11k3KL2Iba3X3l9" + _
        "130h/r2nxPTWJ5xTbG7u1KBiRF2Vo2fz91X1nlr6NtkCoKjoh9uMO6C5i7ssskupctaGCYl0d+UgGLp6M1y4u2qRC1vWTyCK5U7iiFSzNGztv08T6d8vVf4+4mZBtoh7/n7f1tPsfTfgux9t7n4ZmTRFUodrBw4p" + _
        "LWUY9FEzDH5XIrbkrpBQglQqRha3hGwcZv+J5xIhCJSgbuuFUCBtFA+pg8Iib2u1Du5BSOoRYoUSit55zo6pzT3E7r7A2n/H797Lbh6wtkoH8L8872Lyea2J85XtWhwko4yCUMrFaJtfZaRYwfiEgw2z+40qYoSM" + _
        "7lUx/QcKYwFISFIrvGVWOAtkOoJ4IMI32BgsbnZp4mN0QDnSxXqkQKamEPGp8Ov2J2ed97W8rTbUVhKA/1O4v4Le58Xv6/Xv20I8AhbmCthjaVQ7BizZwrpZBdlA4Kb0N+t6xO8ysRYhF52dfG/6f+4BJRQahkgV" + _
        "WrkhEGMglLQOpkfseDTjtsRRqO9QTA8rpOZ5EryPr46/z9x7TL37U9f7XEWO04KnjbTX5vfpfvl58zMfDe0IomjTO0CYRJRqA/z8x9YGCpOYs0KSCSGiyWMklbvVS/4/bV1WkfIg89kgaD4w3whhDCV4OjCgDpLx" + _
        "cgDUssx6Qc0czb2jDnG9L3P+j2jsxCksm34z4a82/Y8F969vXnzjBsvDarWFB0ABDXY7d3OMFWAYIu2IgIk1SHfGEIFiXlRJEkwwq/X/CcmPFb+QC4gG50KhLGAQxWJw6kXydsZ2eXOPMVgwcBh7viUyf/W7+29y" + _
        "j75mh1wzrEP7dgUzauYAUIMKIgh8jUvEsWCZbG2bFoEQc/W7bM1fKQviisMKrgSklXvIpNQrF9ifvvxvlxOoFlQPiRCkHtZhBVCKBxyReSqxWPQItT0ECMbay9akuCfoGQ2DkIU4cwAma47N214Hl7zYelowTTvI" + _
        "g0AZ8OTsJ59UGm7EFlF3lr0BM//7QCMTdNQLBZQGCV058wLBuh6o0cUJ80AgWUOHQYlf/0ZMv/+MD4lBkBFQyrZgtKBXCNUm63W0uD2dO46DmYh5FG/PQuGIMAhIj4jfFniTqH/DLyb5hFHRC5TJ+L6I2Fm8u7ct" + _
        "OWwMVl1ESzlEgHPTaCXdBbTbFZj8UiKnscii8X9CvcFck9kHFGnUGZFiCRJGFQXUilg45B2yixRWQNW4wKR/lH0aqdpjHsk+qOxDbRsk2OPdLIgNBdRW6Hw9W4PyOVKANYM/53IOc511jcbrWpRyq/Hh/jNoHUII" + _
        "xh8CJOA0DeoczyOcqZ1DLbhkMHmKrE6f9LgsIBYJFZDVFAVVmhgQrQ2YTWIBaow+tZVz1fAYP01DhbUAs1lec7z9b/w3Bs2d/Gx6mBMsRRZOY360tf+2cXIDJrx4RseGxbtW2fq+o0zDltXamBaI0Ub++nIyUkG0" + _
        "oKU+DKZh6299UdIkD4BVwOZvtQapOO3GzyUo1UKnIDqqyfHxA9TdGsvzPyPc8XXL5H2n2bbBq5QIKhwi9PhvUVIH+t8IgaB2MCrNkuF3nelv+XqGczswK82M129iRe8X2vfb8pBkAQzEYuru8VaR97aOUwDgm3kH" + _
        "oFZAerIlslJrZtvemCnxcw0yRGDIAlCDNaCjmXmk9l5/D/Df9nzNNSzwiOxp9qiC7xMBrGn7j1g6fTu7m0w3DL7FPnkW0jPp9FePM8DmOVRLLG9Oa6N5f76G8PO/i4lNvF8PawakeZRYoTjFyGJe1mliIeJcaQL+" + _
        "QhCJJdPLCCnOr5sdzT/HsAFei3UDc2cMOYG04DEcE/u0WmaF/GXUAkjWdvELW7GOd9BvG8L/et59AP+9g0fhNY3XmZrWgUsy9PUJ8TD5DjKC0gDCrOTWdNOm6Zpqt2nTmHXruZqAGBY8zYXZvneC0ehw8+VrxcEe" + _
        "eUk/9N7w0nRrq3528skLNhVgJL50b+3ujbty8VTi/Wvh2f3/3HLa3nDifH5SiUzuqmJYGufg6RrfSCX9OZr7SfK/oUE+OTl7lq4fIqyvjKQmw+Biky7CwBAUquR8jolizTlcsMUSbM1Bvfl9P8Zfwv9+1jf73SJc" + _
        "TqlOuyvOrjN+EZ0jDaGSzS2LbGXjV4c15MCxq6fD1ToVS62sPEPjlVFExOOMt6572Ar13Xo6yvZ82cnZ+OKIJWZQZp1Q7OzvHs1sA4snLSbD+GW+o5dRAIycYZntw4b2aefl1eaS/7qAFIqYui8mxg9YeCz+tsYV" + _
        "+h5PnuV0wsOsoHj+E4fDRGOLewMvpYBMPiRYdNhOloxjFvw4vMB973nYcsAp/pLXPvfXGxqrJ+Pim/wPebnB4lTsaYxYs9ev5Kmm/7bka+sLT9Fr6bnn2u7mGx8SrM9zpriPwqWvmN79ek8N7bJH2P0jyVV77Uou" + _
        "arrGmtgrPvfczYUWTVNvs+V8MT5XDpUTXudr0df92M1+rzi9g9Ut0U8/3sv0XKHgHVH5sGftIe2wBd2mqK0DKgGI6BJBfce046k3v8gr/k9mNYwLbYroAPq2A3bfnXFdnb27sE00gP/Vmn+mb1O4QlcagKqwT70C" + _
        "4WhBAZaMRy/iBVANY28bCAPhbKCUAtU/Itt816yuzuHtF/qt5NTlfmV7Y/ir+kgzTecQ6/ykK1bEKL5D5wArvIP0F/0wxqYygTWkm7A5vZC1K1H1aLZp0RZIagdFh8wlLXyMRSuoQcidFG/JKgVD8W8PWD6L+QH0" + _
        "dcvhupiqxaxYtEodMunJhpmgQsHmnEABqz2E3rm7MjEUQ5NBuVTJ2QhSlvUzBbV0n0s+Q5cFxYfUBj4ec9eYgktqY8QYzbTLORqmqamgoV1dyRqciimXmKFdfEkX1p2lyNyBTbpbnWAqyfl7T9qs0/JCAtbQl560" + _
        "90aRJHqTee2UU1mk1df89G1TM/3HusOF8YumGj0Mf7y3ObeOzdww7qKr2uJL7CrtrFt7OxfyZt2wtz7nLbgICVBT9D1GogQQNDMvXW0rgsC/BYFpKzLAmZ7WVKMbveTAzrB90bSaA4iaCjmpNnw24hFD1aFj0R68" + _
        "GNEAdzq1PCGd+oOWb32hqmv/ELaHJVRWa+0pasZbVVHLqhXUImTuqmGPxQxmrKG8JpIip7tmdsiNtdyScKGk8PFH461pBgg/RA/x8u900IA69hqrqEbGuWKKsWsN+uVKfa3mx3YAfX4d7sscFfonKh/H7J+OvFee" + _
        "rYJdzxT3CqM6zrgjzM+exc02hJpmK0XEmEj8QMAuO3ChlAcxhQ0Ozr86J+2X3/jFj+y/Miepg1A9hXPRdl5Qfd/E/Lxy9Jf1tEBfibtvpnDT1eQCKpSsYibleRZV1KvedlSAtYYTbyUKwKqKi7cuDKKhXfMnMhvG" + _
        "C1oivJ+Mb374h1nNVKQS+aY0f/z6Mzhe5vM5qJ+m3kxbPXJAOgmll4CoVgXqFGSyPLYjjWBQVG0cMVHFUvwiiNzMDj/8EOvZ/ISZse27Yu4HLSREFSgc86VuCpuVVaJYwVRJ50BuU/MVtawyk6RA6eMQUszIVFKV" + _
        "vEY4g+UvpfTdRQ1W0556SDGkIaSo0aOU7vUazjPU8PLwEYPUTxqT5CwRre/1Mi0F6iJ+bmZHvbMsBdoAjEFugZ01RbtcMKxXbdRBL0H0KZllC5bUqyNPM+ag1CZhtPGXULh6KFw3Prj+Pb70xM2Qp1qdQrfTpW72" + _
        "D0rsfohVCS+xs6eiTVGIQE31Bi0zDeSp4hWEvz0BgDGxJguT4a9hYFmzS7U6OW3gFib3OxdexJUmcmeogMawZB5Ol+dvMMxKdZ3fAQ1IrttM1dYRe+UOYude4YgDWCMYBWvwGshD3JxFGBWXWEdIkp0QaCCNxfUX" + _
        "a89gpNI7+KoIKqmlFRBUQ51pI686Kg1wMBeL+bUDMTUUwQPS1ewzMhTUI+C4aZpsNsC8+kzp6k9SwUYaJXvVGi/6rgF6xOb8YTuDNlDqpsr+lK3pXjB3/3Lerddt+NnX9ec4EDDkXbR9e2xenw7SXt3X4JwyLqfY" + _
        "fJQe6iqCAekCEM2o4eCZSWZ2UW+T7C3D897ysMd88flrjNDq61OXr4yqohlm6KvKtt8TQxvaJch5qspsIjfwdxDQQMWoq1o/+MfowSQStQLYiGnapIaMooEIRTUxej6NcTpFEwqVRso0hCp/rXtHiYiDaaj6yCmm" + _
        "bEplTFLiDG5qUJUUyxxFT5K3fAIHrENJfkdRRWAhVAgPML7CrSVECqCFydGAshpgthnWtGiimJym17Jm88M9DhTaSBXBTIyY6sKj498LqdBSwDzzJyj5NG4hxcV5gQ2LveikUrAPo7DLD1JaxUkxuQXaCW3MXv1F" + _
        "kXN2J6G6fNJ59XFFLqppjLuZnEZtIyzMAn0m4sBWKNmUeRsFN2gttE48rPM3TGBR4rJdaks2Zp+6iNPheQuzdT/BgnmG+SmnsxFnlyCCWJiopOpEQy9Q3VBMahRNsG8k8fyqwepQqrmKTtBMihINnSFF18+jVQUz" + _
        "OC/SjkC/gC3IVGeJumFO4TktG8UkSBSoTFSpy4TC4ZJX1K4voRMY3kiRJE1g0ZwRRoqjzBKEgTTUrOJTmhVSWimdmzuIVhpC53utVPmHMCJLXT3VDJ6iU1eJv6llKqKPOWFwl7Ko/VFGWJymx4rc1ewlYs/IsTmN" + _
        "UCwryhQWeJcKiCk5GvBC+4TKD9WAB5bNZgxG9YUe1gkIm7UDMBAJR41txjEfcFZJAKySAbffCH/6fs0bqXjYkPbkfy/oGbtuISpBrxkh65EEhSMzYIQ65Bo36di4pZQFfAQRjBkHxoRgVUkkQKsUk5iglFRRyG4u" + _
        "o/lGOXMc1xHOsBXwEcwdRSNnmLwqJe44sg2rkmpZWYaJTAXhR7jA2YhVSD0vsNFWDUQWQ2aCZLkw6uYRhO9QU5uOsEoGk4qNFwWIKQinyiuppMBnD6KBXDFB5G9Q6RU4xYkprGBEVYk0wVQhVxdgpCxheqkSaMbU" + _
        "SWlDJk3fGuHpiJmFNm6FiyBF8V0xmfnm3dMUUCSKAuk/piNKHOjotKXnuBAsUlBLnFVUA9thovhosxec0xReENcCCsWnuLxmC77xjmCZUpRgnrybbcTKqBhr0HrXRlizjkQlE83vt49gtUQlyafyzwSLIgXvRQWh" + _
        "hdWBklgL5drPjLNpm9dCuyNReLPoiqxhUHxliiT11FyCxtiwLeh34lF8bYoEF+jHH3KqHxpgKpGSWRFSEIAuqIfNMhrlb5w6gZRS95hsNPd05OQFfEKnnGw0F9qC1PAOcUKgiMFugcniH9dUCEdd3OmEP0B9zS0i" + _
        "BkBKyKMoTFaJ+BSKJ2mMIChgGRVSn2qiQ9B4TDhL4okK22GeTZdRwgK0pBVIXwFrLtUvDDGMx4ORRChqQgvjXdFueTug+KbuTAFnBVVFBfOfEi4MMKlYpiao493TqFKly6F0cK9UYAZgOqRYKniVdxVIZvXt3JCH" + _
        "LZvo7v6VKKe3O/InriJA3al5vw3sNmLUv/ret2jGmsnHz99qw7050npVF11Pa+mWXp3mYbliWzZ3yGxYJFNIBCQCD9GmljR6d8EjwEnfAEHk2mwWCaH1Rw08YLDGE6OrPBpMrYjrYGAIDMBDpqX0S0uPsu7+6ZWT" + _
        "1dM86b6RESPCw3zmeX/ImeVN/1TW9ap9K1MTz+4gNhjfRvS8REW0qPXXwtzRf83xD2kvXUYTCIOVF/Q4w93RbaV0afvLLbWeZxipMtAlgA+Ymo0gaEtm04ebhNAu4GtK6MuJJCCED24zSiYz/o3c2g6bI3J8aD2N" + _
        "Z/i5vWisRRZBxlex7Ikews0mHYPXVQcggdPsfKq6tOCqc8zcLZZb5t/9SNvSGF6PPey1ZfDEy1uwCvL2xUOctkq08N1CUF9VQd1dXe8GMb5zDaWNSmHf6bO2bjRCIQ9bZAQGYVyYEv/7pYXc1Fbxx+jvGfSsRcR5" + _
        "cNk9bVE1gUuybNJwMAIDUtlvIkvZfE2Siyu84zjGYvi4p3jmcUPd002H9eZNruwF+AWvHK+n3mhzlROw2LSY/jk+9A7ysrKJaPcq7Nq5V+jrQoe4XdMb5tXzyEoHTfzrX29c49/Yl4fin6jzD9gq884bX+2PdImU" + _
        "DJ9o1OAGR9T05blOvY5MPijsyQ9PSqlDLadswsiK2tz7i0m465PG1n6M6MptbuCvE/7PNZolhPZkgN/++C+2nzVckv4/IQtt5nD2rZeAvVQZLPYWw9U49BiLUZmsEbHJhFl6ZjEizobW8yzsp7TlFANUVFFzKPYp" + _
        "BkBW/dkCDMWPCEyER0FYoqT5593sUVgKyAcdqhiHgoXXzZRM47YmBlWPWFMJHjMGwAXqZQZL7zQ/bsGPGgNonITMINJORIBWoJio935NLjKrp12niCJ3o8EQhKGzYCiiNf3lMZaihii8ngaLk7pptYQ2ONGmXAjC" + _
        "DI5Yw9jhEfNmiRUj1ljdjpS+0SdhPHOQVVylTLIxdY9kpJ88fmDCaYM8w43V4VsG0TAtZoe56q+5uYgUNbLQtKEjJwvCjvw9Zor2Nd58Ax71QdLvJG0ZRGPZMz8o1XbNqt2nKXxzEBV2hC3W7nIPNL27FbtGIDbV" + _
        "zvUVuxISx68fWW+q/p0N/pIEJlGUTCzskZlu34IHXYZGeQrCNvzAO6MMeMEGoNon5ZJgEEke0RBGMBrB6ziMbEwSxkZdWW92Um1cPe42F4BuyQ5jwPGM7IbkcW6srRWytegf3WkE7AuV3dqSh2YXvrS3T6TXn34I" + _
        "gNZFTVnLbIoRErD0FUXbaG7dehIwBKxkZKxvF69sUfRJpLDJS9A9NTCJdN164baEEGjIU6skG1LLTY0Zb4lnuLfIQFaCwzaQh0e+YZqpayPqawqEQ3ZpkjRLMJNXfthgfcoWEwxUGE2aen25Q91JfvDCVWhFQbqU" + _
        "x/p9r64d98SVbB/5zUzteSlw1Nlz5itql/D329+U53NGaufG+hprY0aFB7+tnbUfM7rNNfGjXBiMGrHfI3B/m/z/uPLjhAy7VP2YHkjZ5XWKkw2/sJDRPWFEfuurFAYIXdEP6Lu7u6K78gQ0QxBRzz1lewVsQ7DE" + _
        "At8My8HUMwbB2ASundGhULv8sbwW6xLi7qmONd6LQULyLHorLt6w3cQMp1KcEQu6wthJB0nhkGl3uyHD0vP2lsBK2w2/6Vz1neytms4evHm3KTqlfWxttKN299BbYvDIqMWv3Xx+cRl62nzYUrvd/pyBLT4H9hzS" + _
        "3hyw+KrPTPHDcOvgHkikvbXLE2JyVLZ5Wufz0eSGYd4R1Z7XDHpa+P6riuhFDoZxKhQmTjw8HCkrid7cMxPPdRH3PLcxcK/qOSdZJYG0tgJQ6HjqcfAVQdLjR7z/MfYI21OAz9KoiIHTS00v1NWXdz9XXBMQDlm7" + _
        "4ooepSVQ5ZXB4rPbL0UUwwHZdZ3YiwzsY31yx74OVFfVUjt/1xte8aGKvzWK54g85idsfwaewycYQWFUBPSMgNS67IreCeiIsdVz2vPaY+vZeig1xRbnBpveNg34cl9I3Z+nRWGBIOSU8R22M08uuy10XxVWmW8o" + _
        "S4SGiPynJOPP+oycxhygnSBEzo0ykI39H+CvJ8ElsedXUln80tqcfEeidmy3hJOS3OgPT73g9q+AUfvOXXWsXfLQ3HwUrz7+gnTXrrs0I+/qlNqwAe1JGqjZV0pAsMWhH8DA4VCOK2cFfl6SqVgE1psidytC9QIV" + _
        "Ct+II7YhxdvXYkeUbw8Fsc2DTuutusPrlzeOkUfcgw2qG/bDLSR7t+j4tmHyrtFN3EOuGO7RGvI+Yj4r3hFdx7X48O2DAvRXxp3naOv7Zf+bmC4BTCON4q/Q+LXGvBSIN6gGRpCb3drxWSsGbkqh35a8H8st7zzS" + _
        "ENtSB2tRi2QVQz0Q7bd3vMS011voWCI+oKixrlnLAHGWvSq0JhcT7mt1nMyT5ze3CDFQM4PrFWNolVW3FV0dFUgyqt2XQ2GbGelmPIzR8PU0dKM/dWPs906PdqXnxt472YfYCKv0fxJGcxrsqw+4i/J+PB/Fyqk0" + _
        "DRWhxzQD8eMz3Fc2io6etxg28XZ4HaKJXHZRalsGGyve4fu+VH+6fDWDvo7zvvE5OXzT2TgutDH2ojMGXT0attz3RTENVMrpAGu08PL+OLr6iWnQJZYIX5RfGKi9EN2HVT/eh4owzh4+Wvw1+TNW8jY/dY1AF13q" + _
        "c8BbO97AR3BOffoAc/n94okIqm6iccooaKnMY6fw5+HFD37hhDPTOYLKNje5y+35oM1Tbkesa9XWIjqHZ6Pn5XDTD97Reke7jrrZE20uet6MMhcjcI5Gs+tbuIdrt70cZ0u6SuyOLXdzVXIFo5vxyDa6Lc1AZpoa" + _
        "QWaZuNnus1ulnoxL2AKXb0oBcFOM1Mr+cGz5Y6Z752+uN7VpFjQT395ZjTHZLV8xJuqCcnKsnobH+e0qrAcoTP0tXJVxAP89cV9sX0Mw6bgczF2Z3425h8Md20Dzmk2g9vZOZi64UOOFh2lEFGOXEAsTEmGt3bGV" + _
        "w2k6z/uoO8dnap3z+8BrA7risVkJqlUhprJApopIFWwdCjSodTlZlG1qd+yJybNGg94d5r0H7ArgOlojGdUwHbmUIvXo2Jdozbrbo85q/wFCFFQj24h2sC3QFOVRDWFV6kgBk5aI6eGICCYtyqGBI8ghqERUvFVw" + _
        "c+AxYIorjbkfSDImQdgxC0PuiGfrCCFjLSNfJcyBEE8vSwYbA3dQMLWCtYYM0NLUOuBJuM0wOTQwYT1HhGeXU2k6gpMwK5RMbeHfJScperoY9CCkcrJBD8r8wBGQUvUg+pBSiJg6AhOFeGO9PGFeNDFoQon88zFx" + _
        "hlzIWhQdtNs11Hm0ez9dQFvMpS6aPagCHQg+6HYcMecC3LFGMWaLsQUqS5ZgMxzauEnQ5hKkK65aIFFSlkOLKHW6/NzR0+y1MC8c211UB1GDp7uQojrf1N2HEnqCPH8J3SMQxJxzlHxj/97v2F16rh8iSyI11/SF" + _
        "BVeJ+Ej3HYNliHC2Q+2+L3rNrx59sldrewb/ryn9477ddJA3dP9/gDWP4BukAKztGLjdg3ug69G86nrwQTKI+C6fGRDyfVDUtORugOM/9Nj/ghXYJg7WkuUhQrQMqdO66RhMxtTbFKr5JY7BESqEWCgtS7isHIGO" + _
        "tojXFEyCVCVmgsm+1EIZt7AgUQQXsC2IyLHKHr0sDnLdLIncrmte0DA8CNmm0GDkQC5MhAzDJ6wZ8qQ5Y9Coj/67kD7EBJ0aJPH3FMFWIla8UFWthqihyuwf10zTNLiAmaJR4BBODlV9B2sdVU0NTnC0xBkjNLbD" + _
        "OUxgZI6jueZZ1a2KxkbEkSoQ2odVRcvgMMykDGVfXkVm0YxC2BbERJRwTDyLdioOC72XCSphyxWidb4/7zzPlG5MXVk+EcAsVGpgl8ILWaVgg2iBveTBQn1Xv1/en0L4NBWYSIJWQbDS3BSRrvTml2OCoQgqsACe" + _
        "2vP4fNTf24POC3SEYxNWzrul4de74WYLGP75GWwXBYqZRfjh7CCXCmii9juw7vP2R9qTdQ7AwtkxqRvGHPS794lRWNrSr4XaaejOuX/S3i3ImvF46phTiiFrvrAcFhfb4FU+RSS2UICaUMDnqA+CDpzOwNASvgTu" + _
        "YOXAz2ClLUtGjH2czk4DT0acWmWcZL4YZaRiSos11jGhyUqTTGyywZ1avXfgMltoptEeKzrPqOrcz6fJUIUNLwqqqgwzktlU4cFJ1VFBFT9MqqosuM8VX4JEn4piA8GTJefRVsmREau6M1IkPIS069jbNxl+bxwE" + _
        "P14YyGjyFJ3H8OfSf3DAGhJPhpRHg364B7x2av3Y/gNu5NMKInmf8mujdr9nMLykKcqWiZAGLVdGnDudhoGIV9zOOjjhMfxeeOCCNPRv1PJoqCMWQuXoOPHiPNpqOTHiPJn0FNXHFiq1B+GmA6YrDixU7VJzl91W" + _
        "DaKBttZkpgNL70mOuYyUTrmz6TIPMYq5DTa4h3oeCx42aYmfaURT5X+Kppln0VHBTeXsaE6nooaY4neMhfqzMMxGGaATNWMjd2rpK7OKFAMB0FWH7stFFGsrw7pxCrCM/NUy/L8QPebu0fnHnvaBfRT3ZJg2pWXu" + _
        "VrqNIesMILbMA6ShbXUfx3ofDrk9gzcioXVibBevdnLKLtiEPp4MatKboVkqOigIxCZiDHhp8nQXllEPk4WjukVUIW2lV0Ee/ia34V3ioo2EtEcHeYVDBk56WsHSdJc9Tw5yY8Gq1JTBRs3ARq/uByVpTxU6NhfS" + _
        "aIkTT3bH9p3WDGFmtMHhF0qXeG7XHjR1iqZ6TA+qIn+jWW0aBFZ1AoZMsXFdTMbo4k7FmKq1hNCUXgqJzHeORtxVx1rWMOqo2j55NUWNJci0l2efiZbUMhip9eWxMl4tYiEfplPumq4Ucp7rdNMR8VhjVUeylaar" + _
        "RrOCCbZXGuPWXoDNRJyKQMjCDh9GOCywmZDdODqq1hw2lZKuY3hBN3WO5M+3cuxNthytHgj7lHa0cISKIuf5r9FFj4r6e9WOUNJoi0czucdtaWnV0Wxi2Hc3PjXwuxge8yDxHOCq3tEIy2h3CRwDdbSozCqHBswU" + _
        "3SHeeew6aWjEwcN36KjxdHUXQtFxkZxxOdfp/xIYZGPFiAoUP/J5kLsdgNwgzwMvrxUXdHJFBMAHKrS0vyPpesA9HJ5V1WmKyWOvIkBMuNRb50gMBEzlM4rMcYFpQcuB2IeMClgfmHhlH/BFjwVD1AQagBly3Vxx" + _
        "XZv5MPdNgZi7+PIh4+zVDBsjPb7RwCWrwsTWQ32+495z8SFbLbjyRZ5anz+UPW27du0Gf+l2nx8rM1Y5D112+mlS4g2p7NL1aOK/uiXw8x7e+CQ8P2r9YeYaT//LgJwT62hu7F3z2GC1q+otPd3ElXZQu4bf6be3" + _
        "5GhO8hKf0nqJ3LArUjCOjkk4pVCk08p63UyAjaqjo6OgylrQx1CaT+i3oB/ufinaIAtbeqiIf7uClqE+F1v7+KIOL2mN+YSRZZ1OYzZHAScuQclyMc8jnPV2LJfsoJ0/ES37YMYcU9aBdHj4BUc28ulpX3iT9B3e" + _
        "GgX/4LamE4q4WtaBdT7SVnqbDrr6/ODq2J77o5VRuznVFGUv6z/kCn5vfc4++Dy1uF1k4TNbdVlby9htZ5NOdy3W67dj2LvjKjoQwmFJDSgjkdpx3UlRKm1thPFYcskV/nZkFTMeEl1Eee0j2JRxWCMMPqSwgo8A" + _
        "tz7WP3m0H0flyc3Y33ZK53ffug5kLUEFdh7EZ+v3w9PcxV2NTkpq8QTH3Hxzpny6QOTRH/xWXnqQxjrH5xPVZ8PJ5RFACd3sKlG2g2BnrNLZOVYzn8GOIRrJF6B2z/0IV7fiX+A2dTnTeVP1pjsf0Nbj0/P2Zz3J" + _
        "HLUPmv24i/n2g3h5uwgp75HO89OS/eE6wT1V3AhcOdKP+NZu8wyYQeICucoH99mrHWwYtHQkomHC46MH3tIcVs1mKyaieT5ZJq22D58+MElyy6Ho8bSklgejc0hKwxfgsLff/DMFIE+29V9xbqRQcNr/7dyL4/KM" + _
        "qGoDcVSZIphYadaRkYwfl5A4wO7qc1MFg9TztCOCXbM8pPuux3ELi1G6KcZumGGHvR1i2Gnrghx23rqgi1GqvwA7l/GP+aS6h794FnTr7kpYotooKvBxDHaA8eclr8Cujsnm2vWuTgW63fTokT7kgP8bBDbisG0e" + _
        "sE7XUJTh6cmFZwW2ZLcOUsz6GYlTdMdmlIxLfhbmeGBAvUvuYzR0VqeRymgNLHvvzrboTfCK+heeR+Ksa9mRE7Tea7cwWcMAgx3VaRpY96sz3lPy6eDjS/QRvHLKuYfQAoV6/ByEa7JKlpJrbQ86fXzMNrzr8YDs" + _
        "Tb3XNWVjMi1aF1P/dlg/Iw6cvXtBgkumHt81G8iLY4oIgVdWq2CBZYa+DoM73h8UE81AWjGW3hLIaylFZK+hQsKCHnJ2ASygXYm2k+2kf7DQYpTiLtr+/y+oZF9lwOfS3pJ0ptb+bEZx/z1VI3sF8gx37UtV4sSq" + _
        "1xTjzHV4P4JMf6TuBrO5KwdjEdEVU7sdmSraV3jpXU4dkxXeA3zphHDym0LwwEcy2IUyeQPdoL+mAzSKKBUZnecYOz6OOW48MGExsnHW0T7MzvJhierUsHS9XoqVnRvHncmOSij7FuQDRTiYt95RKw/Twyij6fzz" + _
        "xUf76owPwUAnroHuYP5Y3pEfKJMqI6xy3/Hid5UXlrTlW0Edn03SP9DVtiaK4P+vb32kvcrudCluqQBLYCZEB5A02ZmHr5w93vcFQrapBtHlX+TTtWiCPDWJnHCqRsrwMXKcPzlJfd8BV38kxPO80w/2BXUskYe6" + _
        "ayBN37WYEFRNb7RMmPbfFrqOxOE5/vDk8/iOa8PvCk0lBScb+6SNqF+wdoejh0FUJsRDRzUWd/KU2Vox1TmidoZf3o77WVJM8NJb3iUqeW6RAMKpBb5ygeDpWAHXSQFtwYe0s76d2EJnI+1JuascukU/XwWV4fuM" + _
        "S4SeDxAS9YAmWCftxiGv1SEjvkq13uIw/Uxrx+zw7r8NIJKXJcrJx3PycgqJJZ7LPiCWul6mYaa9QioTGFQf7w8Z8z2ehQzR8x0cHUWEx+Pd3YXvGDo5De97pJCd8odeu6ITBhjZjLo4CWTQWtKdlsObEKEAWeCA" + _
        "we82+SYjana09MGP6J5cVfLYpQCwi5d54wLxSzkHbDKkANwO3gHCxu+GGPZ+Lrbs28XvFzzxbARJ9K+hzmzAKJCVkWuArKkE/32+53Fmq4N0fWYDOtAwsjxws5iI4LthIiOaziZNAX00yzSzUz71lpUQyTg59OBH" + _
        "Qs2xjYjdAljFXBbt2ndN1qU/VZadaH23UHFyYjKNM3d8ifm4iELAIUpk7GHaf/WsRU4Ke30U8qqutn3lBrl5oigi6IRkfLcSJvl3odHFVQf8gEV5rbdC6ebWx31hslMg8W3k8onAUU6EVV+pga8usFVo5OYZuA7U" + _
        "2K759nGyjiPkiu6lOE6rNOH8XHoqrv7NthHDNiHR92JZQIV5J994IIaulUeikiqqXecmvLTSp7dkEqYFqskYkx54bUthxfDqOZCHDNZuY4UVEryEPHuJefKApNOP/AzwP/sMumgxtM2DcEwRvRzwlilstv7yosiZ" + _
        "BD54J1TixgJ04RjtwnQvvfxoXzB7FAlYdP0jXgsbqC67JSqEMjFWhGhqiYlKigSSXA5fVBG4OpB79iKKsMSId3AUamll0lsMG3e4JExWBElGrwZPyhaVZArqqaazmXmxs974UOYoVLwG+wJN+FFCrGtIlRuq9ZC6" + _
        "IZiliiiYxHt7CUXKZDlz2LOMVMin3CmvWqJFV1i7NNUOj5gDRrVGUJzeZC0uCbXskkbINN2DDoItSxM86MJEVqedm6u/n4W25FH8nO+o92u66CCxSR6xmKox5KFDtGGwToU5WvoHzxtiQtwo/AfbUPdrRV+9Hda9" + _
        "9eecA0Go33ODg2+W+a9L7A9DOz0gVIObWIjwhKaOrsNP1a7hT/acht8tZZmnGCNVreUwuGa0H+U68jYBoJt3ppWTI37hZ6GXnuPzvrIP9IgFkGywvRWAjV7CMekB6i5LOxnW5S0o9ZpSgjlxlM/kwD2lpmL1ac3B" + _
        "0jY0SEbbjJcE9PQKE9qckq2X23lVFZToQHUNn6b8UBeBqryyjmpFULgSxRSjxaviBjNKY3f/ESj0bqGpJAWUkGah5sFkIq9Li7enwggK6YiJFHOe6FTJbKp6+hHposLBZXFH4gwHBqrFdYbvXUb87i/eFHk6CpFF" + _
        "GkYOV7dbW4Na+Q1J/yxmEIzsd8Bc2lKsMfu+HBhGt/fbTZe98nvYvPGI6uWhCZXj2aagjFxOYwyrYuBI4z7274X6W0ve76bPp/0vUN/L79fv18Xv5+sb+u9dHhN336ABexhYnRZQDNTDvZHjMPl6p6nmik4zKzib" + _
        "ccqpBcR6d38Ksc4mQhYWdVDE6GjC09MtcCSrCkEbaXj4GM6fXIe7u5C2He/hIvEyHq9TXbldr2yaubV0yXc9ECmcRa06jIlMiT0GWR752AGpgfHq9EqUjKOiNXsImoX7U5Zopc7m+4kYJXZ8bGFFrdEaEn6fih/v" + _
        "ZKBDiEFQeWSeJfAyHP8XXLzuV7b43jc68Dzv6CF3PAYuHhITNqng1avbIckL+MmLnaBIOeBSzYlFzlxevrGVBe0Xqinp4oJl8zsJhKzW482+p7n3ld9D+/uF32fo7l/3H8Tdj2z/8LrfQ//Bh4kmjTqCKvfm7OhS" + _
        "ckA7u+iOsEfYyg8HDx/sG5t3/m/871Nz/7Pdn28PWJae5dBnlmDr6InEfAq08EKywwXNkQ36L6L43x/6gilSivbOAj06z6/ovsHX3z7/fsMWAyLFxYCa1yclRPFex6RFZG05EYdoUiygZHH4hHwQ47vI+0grkzBR" + _
        "zPDX7aSsDb5XZ/ISOWqogvH5IciRAUAtk2U2P4dBiYRDxhGLKErx8sidYsLzK5iprVSCinYIQd2/RxUjEokxBWsTAMWWkbqJl6a+ScuqkotjbZAW2BZB4loFoGSzCtAxMBbsIKsOPdXeiPmA2ccx4sRwjTFD9yh1" + _
        "ezwajCamE097AZKKxZjJLNMdaqu8lttMVeH7sCjwcOMPQeTq8plzdBCVayrielSLB2IFg8P9G/Tf1Lk/Q/6Sj9/ky6qx1tpf76hzvfd8fT9tfoF3RzGHdPgEJ51YegY98wuwnnVfQbvv2n2jeb91v4ua9Oex6+eQ" + _
        "IB4KZsZkE9nXW1Cl5M/P6gGfqUl778+7b3Dyv89tmRk5Ss4IhNCB3apOxh1vM/Hvq/R+yDP5CePPRYnvnfZX8XYYQK8uvwgj72Eb78y5Pl8ZkVDiyZSlFJEnV45v1pOItpsikvNYQq/H20z+7uQFVealFKXjFOSc" + _
        "flb3auVB5npU0QiFmyXJQLRckTSu0Z866kt39DW5dHx8pw9F0nR0pzx+v8Sz9LMeXz/hOfzch4e7bxC3POCiHRuI4ce+gyinATBmespzpzq8fKdfReQ+XwPiPm//zq/B8e0fdzmaujU17kdgVQmnZKKxhPjxHFl4" + _
        "w577bD1Zf7X3ppijkonJkiWVJuUga1Pd5S+eyzRcVCzo48qW1Z3RorFgO5P26vrIP4tWjMDzdxSzYm79Pn17f6d2+yEdOPSki8CJFSzw+I83d9+4PK+JgrGqYdy9AhyPKBceOzC0FOFOYIHg1SJv++Vg7vB5pvO+" + _
        "F3ZfbwlPoW0sM7y23xafwvvJOohQkg9997p+D9bmgxVTiAJwBjCk5Vg67oinNpLjM3VpxknhoPWeETxozah3OLPIFFpoO9xlysCbbYMrlVCIgwKcr6Wgppt8egCItuSRhAM45hKzk873Q6rrI+KTN0QtJxhSVg1i" + _
        "E05BV9fbCWd9a9scbZV0EjpLPN3EHgcwL4Dnej8Bdzz/ws9B1AAjntgKUzy8Kdke+cOWgz/nTj06V3oF0li7aBZEg/oxlmnpEariZoYyvvGYL7AtKN5EK/wtHTfDfLcIqaVKJstCHmogMhENvM0l9k4DMiWAjMo3" + _
        "ypARQ4FYecfUOxyV1/EWf5GuAoV3NaA1gml67cP/FtUSXgUxYYoEUkTmB3svPzq4vH28v4pi6urVVigDb2cEQcvoSvO/HPPPoTc8wPACvxoG+J3jfzdX+cP//XAurIObgUlY1UYjCr93Xx6/OIKQlFEQtddTVHsy" + _
        "/Adr9fWpMn/ikVlqK77AspzPL0rR8OuMUFPtIMviw4zQ7aG7n4xynt1Vy0/+j++baG+0Gnu1yWEMjLA2uI6CmJoC/AC1rIKOQtSgEp48Q0es2N7Qw40g0L/6poAig3WqvDdBrcVcFlQ2WAV1yWfYyU2UItq1py3l" + _
        "NRJhr8boz4Gt+eLaZdmi6+tNCeMebqtlJkqkIezUVqZRZiZWVC6/kWjRQ0NDA98EsXQYA110c4/lx6I+9ePP8nsqC2EoXUJsWcqYeI4+zxCttRihgRCBhY7HlWXeNTzvuSxCVunI59kQk71xX7SysaTUjPi9Z4gA" + _
        "q7Xabhhh41P3YXBwJHopFF/IUt9H+u9FK412AzIwyFvDX72f4duPHpaVHHetgms1UPtAba4tQy9FkbtkRkzHOTV+zGRvCpvIGl5PTr3Uc+bCyw+EIXVA0Opwo/MK+tp2m5MYOPKQ1gJb6geasRNTpq8E1kPiFvWx" + _
        "I3e/p80FSgRUrJIeKVar4dPtYd+PTijv61oomUcg5TWZJgy8Yoe/tB7Fcmsll359dnetYxncLtMF8Su3O+KXOxG2+6Jrt2GIjTxDGMFzBHMyOSKUpK1NlzkbtXnXfIZJvbYwqTq05OTkJoCzva+EMzaIbWorCGVh" + _
        "Mv2bZ4mdl9b0MEWJ1bJQIz2fMkDieCiZMv0YLr0CZMgoBRknuP6bUMg8RZ3HBNiGtXTvvPrvWGZfe04ZN2xX0wC/y3nfzoZs+jk8Ni7PSXDPjmHjYmh5WGoqE2nSOIorw3RpIbOdIv1xhVHiCKLD+RcDfzF6aSio" + _
        "p+BJ6MCtl+p9HlKqH3Dw8IwfgJJRIxreuOxGk1NUGEQxT8E+fV/TwLoQtxnKk0EW7Rz5KIgjb9aFPwqhFTjjN1+hm66Pb0lKCYnfm/dRVzUlsyteuYJEGfhuuG1q5jsD6A0r4v62cN8qPnZDiEEAaXIOHoHWahkx" + _
        "omhOrNiMHo+dctwyZkaOwtBX4M3Tmg2bF1bw6iCeXiNoSgZyBnV5iBlOqaptl+pjgyTCpPO0VIFlVXK9v/e97fKpG/Ov4fL7vnr8gP/e4Z9MJMMnNEbUttsHzkj3fqXij3LGRzDwcQiFppKc+fa3xr36vYl7KqDd" + _
        "bxogPQanT319JJTbUBI1u868HzOLJTNqoqHb+mCfRttwkln0n5BqMg6yr3i9bRpKa19DAZ64ymq3HJV6a6bsobLejyipNkO2R5tmpWNPv14h1yU4fhkIMFQ2pzOnpTsXX2KAyWDyf+1Qe9rdQ4uX4xbRaDOG+A6F" + _
        "tNvXV1EHWQuiasdw+N0BOHOa683c14pymXalB+4chHqJ2zHvfF+oU6jUpxYpFIiuKeVDDHDu/Eyfepp7SRwPfnDC5fdPkJw2Vrzp6n9TIS/NhlveDDoz9uf9zP3EPLr6fhXB74IeVF6zuSCngO0vpPtFtPW+eaaJ" + _
        "zi4dk7rqIqdJ0zkbqkGN6fvF03/H0T9Oi25T1lOwXe+02mNt1SKkr5HedM2rwTaNzdVrzp7VtBWqnOng5LbJmoSMIvwlqxzCGEAhZYuvZJDAedHJTtgJjVAqb457Nxow2kD4K5ALSQxujDqaWdKvoD/rkK6ecCyZ" + _
        "ug+6YrAzn0vRi7DDnbYCo85+fwzrWORpDRtqEmIq7foSc7xCKgshURbXxJ60Tq7ScAyR7BqtJrREUx9O2joOeYrebiqL5pOjDB2lSiqtvXwF6ktqOqGgCrfjnT73s75moDJvQbDUPpFMhzY9osznlU3/3dX3x4zp" + _
        "Ir0ZsojD0hMr5T45jGoq/ret76GpCxPg1eG0t38TjeFnT/4bXVz9H0CijI3TPusqIXCKlBzKoLeIExSgs73vun7fl31BfLoBqNMTIXP+z+KZfvfOGojLbYqypNrpLVTM96npgKSSqoQM/H1792t9korU8Pyfme0I" + _
        "BAmmnERhpecVclsg52FNrwJlUsAhROZceMy8fFFm5oKOsjPHPnKHvjnB0JL+tqwhfsFrYJphJ55b/m9nCBM0rqqHK3uz9BY6z0qbsyCazIyqVxYxXvIW2CxtKujqOfx+k978H6R83h8JI835k6BFbn3EUXGAbmJw" + _
        "O8opnGIh8f6P3jzv5LsELLQrRoKKKTxv2/r7d495pyxTDP2pgUxtCuwqo0xQuZMaOlm+3K4IPgKP1W/ZvwN563fjTuj2h70wd+5ft7+yim8K/mY+w+Kr9mcgbn6dMlmiLdsMmqk4otjwRO2DSimgstuFAbckmMgQ" + _
        "ZNqpRWSzpevcF574FH/e7QQuw6pe+U8++35o/1mtOScfT2ktGgjxkWaDWYBoWBRBS9eOPAlj/+eqqknTo2VAYww+Ev7aGdvfKunfJL1C9nVgES9i+JJnOHQe482mE0/IMwyD+glISfsU3Or82uOvQ/J/RWT89zy6" + _
        "5S6XkWEIjQh5vzez89YgAGAUk7iIBlscAkqfDtFxxGHz6eN0v2BAZiCTh9USc4oEdhHw+tjpFzf/C7GGddTvhftP4qlZwBwryI2DBZTYSIZogUnAxoGXWIzd+lkoTRGqMDPmQox00IzFhYa+ZIwaST6weljjzPu+" + _
        "7wKtl4u0ToUxBmpW5cHV/aHFozVtbdRiLgFH2yrw8iqhbLf+DG2W+ecpL1TWqeNxdaVROMvCBClS+FSnk0TnbXTfgF9CKQmBF6clcKnqpEFmhpE/zAlbeZI5cfUEZCVOvNQkU6WcKdmpgZPAyjKPXdpyzVCIxRkB" + _
        "4dXctOPeFaGGNJ1CV39j7GCCxtD+ueKyr+xcibFf0ZbYBH2bdk8/SrJkzjdm7jriq1HAcXM+jmYUObpHMrAkM3f1tk5NTF5srVp0cIsiIZLA9oeHXVKD8+6oPayslxe9FGFjnAY4fhI3HfjOPjrr80FU0T3g2JKw" + _
        "irAKbj2nJ1+hrfXf3GxSkOJniS5RJB9DisXq8PZFFsodXYnE0lh4scNbdo9tBFVrkrOwMXTWiR0ffZgTMBBoK9A8NIEYiFNZ0ZU3jnjaBHnoGKp08zkHW+gK9yrGBUqJujjCa+JF147TQoKFJzrJAGFLuQDRawHD" + _
        "gtyOD44n2NzK2JuGZj3vIi1OYYA4rLmRjeN9f86EH7eRHow9bs0J7feIqfMU4HsI66LjgvtHqV/zcngSRU0WDWhBNt2jLYD9zufRR4VuTcLKAiwZiHwhb0bz+5/wmHqZUlLbFploqCQ0Hqti6vy5KxcCUDcXfYtF" + _
        "cWy0xizsK9g6dS9reqcBdo8NhUivyB2x79Wz8zPUZk0lyke1+w2ttrq+tWZKqUae06svypXGCx0iQASwIQPjpOQ9u+FW6pLE/AZHDpxqUUdHvx5xo0InzXo3UgxaWZUi51GbN1yI1cIC0ZZj5uuIA+/owLrebUd+" + _
        "MAupnbSgVzPnWp/+2zM/L2Bc4StBYRZHzM6uG4xdPnQhFs/2KdCL0pOri5z7e8qyZGA5naHycU6s1LfU8AwQSXnaBSmoq7gJPHVjyY/IIYeMG1hfqHLrvv37dPnRYIvuFyu7eYtmCyzUcmiaXD5jPVbuDPZughii" + _
        "UT3kFDVlM94LDHNyjJqnuFgnA9jrQUbe6YxcHX2ObdRXLRDAt3j/nzqZurTnq6JkIFZMNg6WalGOxE38Y4fMnjkTHhF0zbfYN755XXUgxb06HPPdL7hd3y/CW78b3tIk2zepYLv1xnccFNI2U6bbisJO4fRi7ZQz" + _
        "rm/s7gHrsFkVOeb9e3s/fHWU7m9i/b27oxCZRo5bmUWmMxmV28C4vq0R+Jsg2R+JP4zlhJ0rVjy3lbxv+j/j/p2qv7d0O6PRDAIBu6/sfladLEzYu6V1TcQsM8khwwU2ndW3qvIRSvlO/KdTun48CDxE9d3dB599" + _
        "L7ZiGnHw8exh5FYCycdSZ1TNXB2mT+9EVAz2d2B1WJahHxcHmE3vMe69d9oZvZ8BWycJG9+ZQ9fAkfzVav6baXPyZBiGT019v+RF6QeANwe2W+4QW/vQ8PJf6nHwC50DkXtITSzXj9at7kQO7PprhsZw9Ljp3rOg" + _
        "tSHtwyYtrmcjqLXPKeLkJscQ5Hs1e8yEGJGLeakmyhvMHObRrWfbc5+wO3vPgVSVgUOHxlJMlRswWvFRtW1FyxJ5LqcvhdQn6EJTm7BvVVZeyI+bqPQkgEBfR7vfeUdD0VZU46rbLCqmvftDuzu5uItFz0ipZdsE" + _
        "T0gz0YN4QtlpDSqkfrhC+R3dw7q0DUZ3hSZ6FbqhAJmyH/7XSBMP5b+vSmq+u3uwfIQUFonB7ihHR7c5BvCj2K3TeSwsEjrDkLRLJQ8v9yiKvG+X/nv8G1xP1w7o9sb4MPXx/r+/P/hxCHRCFgZ4Y1+up5mHrEFh" + _
        "7Q8pgDPvoFNVmlubQ6zYzm5SLPbIqM3JLyykmGFthhkvocKAiiKhBIBFJ7Jvk8IjLt9ELWPPbl4Dd2wwSzcYcKdtsVkU95b9R6DhZWVvkoJqaY71h6jZ2EHqManYQsJ3eMbXYhY1I57yq6GZIy25NLtInc2aEvCa" + _
        "eKJ8oHK2owMmIJP7c9/D8rNsynZjut2we7sAUF+kuOTsMowA/w6SonIitUIGQf8HqgZvvQ=="


    $RESIZE:SMOOTH
    SCREEN _NEWIMAGE(SCREEN_WIDTH, SCREEN_HEIGHT, 32)
    _TITLE APP_NAME ' set default app title
    CHDIR _STARTDIR$ ' change to the directory specifed by the environment
    _ACCEPTFILEDROP ' enable drag and drop of files
    _ALLOWFULLSCREEN _SQUAREPIXELS , _SMOOTH ' allow the user to press Alt+Enter to go fullscreen
    _DISPLAYORDER _HARDWARE , _HARDWARE1 , _GLRENDER , _SOFTWARE ' draw the software stuff + text at the end
    _PRINTMODE _KEEPBACKGROUND ' set text rendering to preserve backgroud
    _FONT BUTTON_FONT

    ' Decode, decompress, and load the background from memory to an image
    BackgroundImage = _LOADIMAGE(Base64_LoadResourceString(DATA_COMPACTCASSETTE_PNG_BI_42837, SIZE_COMPACTCASSETTE_PNG_BI_42837, COMP_COMPACTCASSETTE_PNG_BI_42837), 33, "memory, sxbr2")

    DIM buttonX AS LONG: buttonX = BUTTON_X ' this is where we will start
    UI.cmdOpen = PushButtonNew("Open", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, _FALSE)
    buttonX = buttonX + BUTTON_WIDTH + BUTTON_GAP
    UI.cmdPlayPause = PushButtonNew("Play", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, _TRUE)
    buttonX = buttonX + BUTTON_WIDTH + BUTTON_GAP
    UI.cmdNext = PushButtonNew("Next", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, _FALSE)
    buttonX = buttonX + BUTTON_WIDTH + BUTTON_GAP
    UI.cmdRepeat = PushButtonNew("Loop", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, _TRUE)
    buttonX = buttonX + BUTTON_WIDTH + BUTTON_GAP
    UI.cmdPort = PushButtonNew("Port", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, _FALSE)
    buttonX = buttonX + BUTTON_WIDTH + BUTTON_GAP
    UI.cmdAbout = PushButtonNew("About", buttonX, BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT, _FALSE)
    UI.cmdDecVolume = PushButtonNew("-V", BUTTON_VOLUME_M_X, BUTTON_VOLUME_Y, BUTTON_HEIGHT, BUTTON_HEIGHT, _FALSE)
    UI.cmdIncVolume = PushButtonNew("+V", BUTTON_VOLUME_P_X, BUTTON_VOLUME_Y, BUTTON_HEIGHT, BUTTON_HEIGHT, _FALSE)

    _DISPLAY ' only swap display buffer when we want
END SUB
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' MODULE FILES
'-----------------------------------------------------------------------------------------------------------------------
'$INCLUDE:'include/ProgramArgs.bas'
'$INCLUDE:'include/GraphicOps.bas'
'$INCLUDE:'include/Pathname.bas'
'$INCLUDE:'include/StringOps.bas'
'$INCLUDE:'include/Base64.bas'
'$INCLUDE:'include/ImGUI.bas'
'$INCLUDE:'include/MIDIPlayer.bas'
'-----------------------------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------------------------
