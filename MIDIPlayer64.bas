'-----------------------------------------------------------------------------------------------------------------------
' QB64-PE MIDI Player
' Copyright (c) 2024 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------------------------
'$INCLUDE:'include/BitwiseOps.bi'
'$INCLUDE:'include/GraphicOps.bi'
'$INCLUDE:'include/FileOps.bi'
'$INCLUDE:'include/StringOps.bi'
'$INCLUDE:'include/MathOps.bi'
'$INCLUDE:'include/AnalyzerFFT.bi'
'$INCLUDE:'include/MIDIPlayer.bi'
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' METACOMMANDS
'-----------------------------------------------------------------------------------------------------------------------
$RESIZE:SMOOTH
$EXEICON:'./MIDIPlayer64.ico'
$VERSIONINFO:CompanyName='Samuel Gomes'
$VERSIONINFO:FileDescription='MIDI Player 64 executable'
$VERSIONINFO:InternalName='MIDIPlayer64'
$VERSIONINFO:LegalCopyright='Copyright (c) 2024, Samuel Gomes'
$VERSIONINFO:LegalTrademarks='All trademarks are property of their respective owners'
$VERSIONINFO:OriginalFilename='MIDIPlayer64.exe'
$VERSIONINFO:ProductName='MIDI Player 64'
$VERSIONINFO:Web='https://github.com/a740g'
$VERSIONINFO:Comments='https://github.com/a740g'
$VERSIONINFO:FILEVERSION#=3,1,0,0
$VERSIONINFO:PRODUCTVERSION#=3,1,0,0
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' CONSTANTS
'-----------------------------------------------------------------------------------------------------------------------
CONST APP_NAME = "MIDI Player 64"
CONST FRAME_RATE_MAX& = 60&
' Program events
CONST EVENT_NONE = 0 ' idle
CONST EVENT_QUIT = 1 ' user wants to quit
CONST EVENT_CMDS = 2 ' process command line
CONST EVENT_LOAD = 3 ' user want to load files
CONST EVENT_DROP = 4 ' user dropped files
CONST EVENT_PLAY = 5 ' play next song
CONST EVENT_HTTP = 6 ' user wants to downloads and play random tunes from www.bitmidi.com
' Background constants
CONST STAR_COUNT& = 512& ' the maximum stars that we can show
CONST CIRCLE_WAVE_COUNT& = 32&
$IF WINDOWS THEN
    CONST MIDI_INSTRUMENT_BANK_FILE_FILTERS = "*.wopl|*.op2|*.tmb|*.ad|*.opl|*.sf2|*.sf3|*.sfo|*.sfogg|*.dll"
    CONST MIDI_FILE_FILTERS = "*.mus|*.hmi|*.hmp|*.hmq|*.kar|*.lds|*.mds|*.mids|*.rcp|*.r36|*.g18|*.g36|*.rmi|*.mid|*.midi|*.xfm|*.xmi"
$ELSE
    CONST MIDI_INSTRUMENT_BANK_FILE_FILTERS = "*.wopl|*.op2|*.tmb|*.ad|*.opl|*.sf2|*.sf3|*.sfo|*.sfogg|*.WOPL|*.OP2|*.TMB|*.AD|*.OPL|*.SF2|*.SF3|*.SFO|*.SFOGG"
    CONST MIDI_FILE_FILTERS = "*.mus|*.hmi|*.hmp|*.hmq|*.kar|*.lds|*.mds|*.mids|*.rcp|*.r36|*.g18|*.g36|*.rmi|*.mid|*.midi|*.xfm|*.xmi|*.MUS|*.HMI|*.HMP|*.HMQ|*.KAR|*.LDS|*.MDS|*.MIDS|*.RCP|*.R36|*.G18|*.G36|*.RMI|*.MID|*.MIDI|*.XFM|*.XMI"
$END IF
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' USER DEFINED TYPES
'-----------------------------------------------------------------------------------------------------------------------
TYPE StarType
    p AS Vector3FType ' position
    a AS SINGLE ' angle
    c AS _UNSIGNED LONG ' color
END TYPE

TYPE CircleWaveType
    p AS Vector2FType ' position
    v AS Vector2FType ' velocity
    r AS SINGLE ' radius
    c AS BGRType ' color
    a AS SINGLE ' alpha (0.0 - 1.0)
    s AS SINGLE ' fade speed
END TYPE
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' GLOBAL VARIABLES
'-----------------------------------------------------------------------------------------------------------------------
DIM SHARED AS LONG AnalyzerType, BackgroundType, FreqFact, Magnification
DIM SHARED AmpBoost AS SINGLE
$IF WINDOWS THEN
    DIM SHARED SynthName(MIDI_SYNTH_OPAL TO MIDI_SYNTH_VSTI) AS STRING
$ELSE
    DIM SHARED SynthName(MIDI_SYNTH_OPAL TO MIDI_SYNTH_TINYSOUNDFONT) AS STRING
$END IF
REDIM SHARED AS _UNSIGNED INTEGER SpectrumAnalyzerL(0 TO 0), SpectrumAnalyzerR(0 TO 0)
DIM SHARED Stars(1 TO STAR_COUNT) AS StarType
DIM SHARED CircleWaves(1 TO CIRCLE_WAVE_COUNT) AS CircleWaveType
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' PROGRAM ENTRY POINT
'-----------------------------------------------------------------------------------------------------------------------
_TITLE APP_NAME + " " + _OS$ ' set the program name in the titlebar
CHDIR _STARTDIR$ ' change to the directory specifed by the environment
_ACCEPTFILEDROP ' enable drag and drop of files
SCREEN _NEWIMAGE(640, 480, 32) ' use 640x480 resolution
_ALLOWFULLSCREEN _SQUAREPIXELS , _SMOOTH ' allow the user to press Alt+Enter to go fullscreen
_PRINTMODE _KEEPBACKGROUND ' print without wiping out the background
Math_SetRandomSeed TIMER ' seed RNG
_DISPLAY ' only swap display buffer when we want

AnalyzerType = 2 ' 1 = Wave plot, 2 = Frequency spectrum (FFT)
BackgroundType = 2 ' 0 = None, 1 = Stars, 2 = Circle Waves
FreqFact = 2 ' frequency spectrum X-axis scale (powers of two only [2 - 8])
Magnification = 5 ' frequency spectrum Y-axis scale (magnitude [3 - 7])
AmpBoost = 1! ' oscillator amplitude (1.0 - 5.0)

' Set the synth names
SynthName(MIDI_SYNTH_OPAL) = "Opal"
SynthName(MIDI_SYNTH_PRIMESYNTH) = "Primesynth"
SynthName(MIDI_SYNTH_TINYSOUNDFONT) = "TinySoundFont"
$IF WINDOWS THEN
    SynthName(MIDI_SYNTH_VSTI) = "VSTi"
$END IF

' Initialize the MIDI Player library
IF NOT MIDI_Initialize THEN
    _MESSAGEBOX APP_NAME, "Failed to initialize MIDI Player library!", "error"
    SYSTEM 1
END IF

InitializeStars Stars()
InitializeCircleWaves CircleWaves()

DIM event AS _BYTE: event = EVENT_CMDS ' default to command line event first

' Main loop
DO
    SELECT CASE event
        CASE EVENT_QUIT
            EXIT DO

        CASE EVENT_DROP
            event = OnDroppedFiles

        CASE EVENT_LOAD
            event = OnSelectedFiles

        CASE EVENT_CMDS
            event = OnCommandLine

        CASE EVENT_HTTP
            event = OnBitMidiFiles

        CASE ELSE
            event = OnWelcomeScreen
    END SELECT
LOOP UNTIL event = EVENT_QUIT

_AUTODISPLAY
MIDI_Finalize
SYSTEM
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' FUNCTIONS & SUBROUTINES
'-----------------------------------------------------------------------------------------------------------------------
' Draws the screen during playback
SUB DrawVisualization
    SHARED __MIDI_Player AS __MIDI_PlayerType
    SHARED __MIDI_SoundBuffer() AS SINGLE

    DIM fftBits AS LONG: fftBits = LeftShiftOneCount(__MIDI_Player.soundBufferFrames) ' get the count of bits that the FFT routine will need

    ' Do FFT and calculate power for both left and right channel
    DIM AS SINGLE power
    power = AnalyzerFFTSingle(SpectrumAnalyzerL(0), __MIDI_SoundBuffer(0), 2, fftBits) + AnalyzerFFTSingle(SpectrumAnalyzerR(0), __MIDI_SoundBuffer(1), 2, fftBits)

    CLS , BGRA_BLACK ' clear the framebuffer to black color

    ' Draw the background
    SELECT CASE BackgroundType
        CASE 1
            UpdateAndDrawStars Stars(), 16! * ABS(power)
        CASE 2
            UpdateAndDrawCircleWaves CircleWaves(), 8! * power / 2!
    END SELECT

    IF MIDI_IsPaused OR NOT MIDI_IsPlaying THEN COLOR BGRA_ORANGERED ELSE COLOR BGRA_WHITE

    ' Draw the tune info
    LOCATE 21, 49: PRINT String_FormatLong(INT(_SNDRAWLEN(__MIDI_Player.soundHandle) * 1000#), "Buffered sound: %3i ms");
    LOCATE 22, 57: PRINT String_FormatLong(MIDI_GetActiveVoices, "Voices: %3i");
    LOCATE 23, 49: PRINT String_FormatLong(MIDI_GetVolume * 100, "Current volume: %i%%");
    LOCATE 24, 51: PRINT String_FormatLong((MIDI_GetCurrentTime + 500) \ 60000, "Elapsed time: %.2i"); String_FormatLong(((MIDI_GetCurrentTime + 500) \ 1000) MOD 60, ":%.2i (mm:ss)");
    LOCATE 25, 53: PRINT String_FormatLong((MIDI_GetTotalTime + 500) \ 60000, "Total time: %.2i"); String_FormatLong(((MIDI_GetTotalTime + 500) \ 1000) MOD 60, ":%.2i (mm:ss)");
    LOCATE 26, 56: PRINT "Looping: "; String_FormatBoolean(MIDI_IsLooping, 4);

    COLOR BGRA_CYAN

    IF AnalyzerType = 2 THEN
        LOCATE 19, 4: PRINT "F/f - FREQUENCY ZOOM IN / OUT";
        LOCATE 20, 4: PRINT "M/m - MAGNITUDE SCALE UP / DOWN";
    ELSE
        LOCATE 20, 4: PRINT "V/v - ANALYZER AMPLITUDE UP / DOWN";
    END IF
    LOCATE 21, 5: PRINT "F1 - MULTI-SELECT FILES";
    LOCATE 22, 5: PRINT "F6 - QUICKSAVE FILE";
    LOCATE 23, 4: PRINT "O|o - TOGGLE ANALYZER TYPE";
    LOCATE 24, 4: PRINT "B/b - TOGGLE BACKGROUND TYPE";
    LOCATE 25, 4: PRINT "ESC - NEXT / QUIT";
    LOCATE 26, 4: PRINT "SPC - PLAY / PAUSE";
    LOCATE 27, 4: PRINT "=|+ - INCREASE VOLUME";
    LOCATE 28, 4: PRINT "-|_ - DECREASE VOLUME";
    LOCATE 29, 4: PRINT "L|l - LOOP";

    DIM AS LONG i, xp, yp
    DIM text AS STRING, c AS _UNSIGNED LONG

    ON AnalyzerType GOSUB DrawOscillators, DrawFFT

    ' Draw the boxes around the analyzer viewport
    LINE (20, 48)-(620, 144), BGRA_WHITE, B
    LINE (20, 176)-(620, 272), BGRA_WHITE, B

    _DISPLAY ' flip the frambuffer

    EXIT SUB

    '-------------------------------------------------------------------------------------------------------------------
    DrawOscillators: ' animate waveform oscillators
    '-------------------------------------------------------------------------------------------------------------------
    COLOR BGRA_DARKORANGE
    LOCATE 1, 23: PRINT USING "Current amplitude boost factor = #.##"; AmpBoost;
    COLOR BGRA_WHITE
    LOCATE 3, 29: PRINT "Left channel (wave plot)";
    LOCATE 11, 29: PRINT "Right channel (wave plot)"
    COLOR BGRA_LIME
    LOCATE 3, 3: PRINT "0 [ms]";
    LOCATE 11, 3: PRINT "0 [ms]";
    text = STR$((__MIDI_Player.soundBufferFrames * 1000~&) \ _SNDRATE) + " [ms]"
    i = 79 - LEN(text)
    LOCATE 3, i: PRINT text;
    LOCATE 11, i: PRINT text;

    i = 0
    DO WHILE i < __MIDI_Player.soundBufferFrames
        xp = 21 + (i * 599) \ __MIDI_Player.soundBufferFrames ' 21 = x_start, 599 = oscillator_width

        yp = __MIDI_SoundBuffer(__MIDI_SOUND_BUFFER_CHANNELS * i) * AmpBoost * 47
        c = 20 + ABS(yp) * 5 ' we're cheating here a bit to set the color using yp
        IF ABS(yp) > 47 THEN yp = 47 * SGN(yp) + 96 ELSE yp = yp + 96 ' 96 = y_start, 47 = oscillator_height
        LINE (xp, 96)-(xp, yp), _RGBA32(c, 255 - c, 0, 255)

        yp = __MIDI_SoundBuffer(__MIDI_SOUND_BUFFER_CHANNELS * i + 1) * AmpBoost * 47
        c = 20 + ABS(yp) * 5 ' we're cheating here a bit to set the color using yp
        IF ABS(yp) > 47 THEN yp = 47 * SGN(yp) + 224 ELSE yp = yp + 224 ' 224 = y_start, 47 = oscillator_height
        LINE (xp, 224)-(xp, yp), _RGBA32(c, 255 - c, 0, 255)

        i = i + 1
    LOOP

    RETURN
    '-------------------------------------------------------------------------------------------------------------------

    '-------------------------------------------------------------------------------------------------------------------
    DrawFFT: ' animate FFT frequency oscillators
    '-------------------------------------------------------------------------------------------------------------------
    COLOR BGRA_DARKORANGE
    LOCATE 1, 5: PRINT USING "Current frequence zoom factor = #  /  Current magnitude scale factor = #"; FreqFact; Magnification;
    COLOR BGRA_WHITE
    LOCATE 3, 23: PRINT "Left channel (frequency spectrum)";
    LOCATE 11, 23: PRINT "Right channel (frequency spectrum)";
    COLOR BGRA_LIME
    text = STR$(_SNDRATE \ __MIDI_Player.soundBufferFrames) + " [Hz]"
    LOCATE 3, 2: PRINT text;
    LOCATE 11, 2: PRINT text;
    DIM freqMax AS LONG: freqMax = __MIDI_Player.soundBufferFrames \ FreqFact
    text = STR$(freqMax * _SNDRATE \ __MIDI_Player.soundBufferFrames) + " [Hz]"
    i = 79 - LEN(text)
    LOCATE 3, i: PRINT text;
    LOCATE 11, i: PRINT text;

    DIM barWidth AS LONG: barWidth = _SHR(FreqFact, 1): i = 0
    DO WHILE i < freqMax
        xp = 21 + (i * 600 - barWidth) \ freqMax ' 21 = x_start, 599 = oscillator_width

        ' Draw the left one first
        yp = _SHR(SpectrumAnalyzerL(i), Magnification)
        IF yp > 95 THEN yp = 143 - 95 ELSE yp = 143 - yp ' 143 = y_start, 95 = oscillator_height
        c = 71 + (143 - yp) * 2 ' we're cheating here a bit to set the color using (y_start - yp)
        LINE (xp, 143)-(xp + barWidth, yp), _RGBA32(c, 255 - c, 0, 255), BF

        ' Then the right one
        yp = _SHR(SpectrumAnalyzerR(i), Magnification)
        IF yp > 95 THEN yp = 271 - 95 ELSE yp = 271 - yp ' 271 = y_start, 95 = oscillator_height
        c = 71 + (271 - yp) * 2 ' we're cheating here a bit to set the color using (y_start - yp)
        LINE (xp, 271)-(xp + barWidth, yp), _RGBA32(c, 255 - c, 0, 255), BF

        i = i + 1
    LOOP

    RETURN
    '-------------------------------------------------------------------------------------------------------------------
END SUB


' Initializes, loads and plays a MIDI file
' Also checks for input, shows info etc
FUNCTION OnPlayMIDITune%% (fileName AS STRING)
    SHARED __MIDI_Player AS __MIDI_PlayerType ' we are using this only to access the library internals to draw the analyzer

    OnPlayMIDITune = EVENT_PLAY ' default event is to play next song

    DIM buffer AS STRING: buffer = LoadFile(fileName) ' load the whole file to memory

    IF NOT MIDI_LoadTuneFromMemory(buffer) THEN
        _MESSAGEBOX APP_NAME, "Failed to load: " + fileName + STRING$(2, STRING_LF) + "The MIDI file or the MIDI instrument bank may be corrupt.", "error"
        EXIT FUNCTION
    END IF

    ' Setup the FFT arrays
    REDIM AS _UNSIGNED INTEGER SpectrumAnalyzerL(0 TO __MIDI_Player.soundBufferFrames \ 2 - 1), SpectrumAnalyzerR(0 TO __MIDI_Player.soundBufferFrames \ 2 - 1)

    ' Set the app title to display the file name
    DIM tuneTitle AS STRING: tuneTitle = MIDI_GetSongName
    IF LEN(tuneTitle) = NULL THEN tuneTitle = GetFileNameFromPathOrURL(fileName)
    _TITLE tuneTitle + " - " + APP_NAME

    ' Kickstart playback
    MIDI_Play

    DIM k AS LONG

    DO
        MIDI_Update

        DrawVisualization '  clears the screen and then draws all the fun stuff

        k = _KEYHIT

        SELECT CASE k
            CASE KEY_SPACE ' toggle pause
                MIDI_Pause NOT MIDI_IsPaused

            CASE KEY_PLUS, KEY_EQUALS ' volume up
                IF MIDI_GetVolume < MIDI_VOLUME_MAX THEN MIDI_SetVolume MIDI_GetVolume + 0.01!

            CASE KEY_MINUS, KEY_UNDERSCORE ' volume down
                IF MIDI_GetVolume > MIDI_VOLUME_MIN THEN MIDI_SetVolume MIDI_GetVolume - 0.01!

            CASE KEY_UPPER_L, KEY_LOWER_L ' toggle looping
                MIDI_Loop NOT MIDI_IsLooping

            CASE KEY_UPPER_O, KEY_LOWER_O ' toggle oscillator
                AnalyzerType = AnalyzerType XOR 3

            CASE KEY_UPPER_B, KEY_LOWER_B ' toggle background
                BackgroundType = (BackgroundType + 1) MOD 3

            CASE KEY_UPPER_F ' zoom in (smaller freq range)
                IF FreqFact < 8 THEN FreqFact = FreqFact * 2

            CASE KEY_LOWER_F ' zoom out (bigger freq range)
                IF FreqFact > 2 THEN FreqFact = FreqFact \ 2

            CASE KEY_UPPER_M ' scale up (bring out peaks)
                IF Magnification > 3 THEN Magnification = Magnification - 1

            CASE KEY_LOWER_M ' scale down (flatten peaks)
                IF Magnification < 7 THEN Magnification = Magnification + 1

            CASE 86 ' oscillator amplitude up
                IF AmpBoost < 5.0! THEN AmpBoost = AmpBoost + 0.05!

            CASE 118 ' oscillator amplitude down
                IF AmpBoost > 1.0! THEN AmpBoost = AmpBoost - 0.05!

            CASE KEY_F1 ' load file
                OnPlayMIDITune = EVENT_LOAD
                EXIT DO

            CASE KEY_F6 ' quick save file loaded from ModArchive
                QuickSave buffer, fileName

            CASE 21248 ' shift + delete - you know what this does :)
                IF LEN(GetDriveOrSchemeFromPathOrURL(fileName)) > 2 THEN
                    _MESSAGEBOX APP_NAME, "You cannot delete " + fileName + "!", "error"
                ELSE
                    IF _MESSAGEBOX(APP_NAME, "Are you sure you want to delete " + fileName + " permanently?", "yesno", "question", 0) = 1 THEN
                        KILL fileName
                        EXIT DO
                    END IF
                END IF
        END SELECT

        IF _TOTALDROPPEDFILES > 0 THEN
            OnPlayMIDITune = EVENT_DROP
            EXIT DO
        END IF

        _LIMIT FRAME_RATE_MAX
    LOOP UNTIL NOT MIDI_IsPlaying OR k = KEY_ESCAPE

    MIDI_Stop

    _TITLE APP_NAME + " " + _OS$ ' Set app title to the way it was
END FUNCTION


' Welcome screen loop
FUNCTION OnWelcomeScreen%%
    DIM k AS LONG
    DIM e AS _BYTE: e = EVENT_NONE

    DO
        CLS , BGRA_BLACK ' clear the framebuffer to black color

        UpdateAndDrawStars Stars(), 0.1!

        LOCATE 1, 1
        COLOR BGRA_ORANGERED, 0
        IF TIMER MOD 7 = 0 THEN
            PRINT "         ,-.   ,-.   ,-.    ,.   .   , , ,-.  ,   ;-.  .                   (+_+)"
        ELSEIF TIMER MOD 13 = 0 THEN
            PRINT "         ,-.   ,-.   ,-.    ,.   .   , , ,-.  ,   ;-.  .                   (*_*)"
        ELSE
            PRINT "         ,-.   ,-.   ,-.    ,.   .   , , ,-.  ,   ;-.  .                   (-_-)"
        END IF
        PRINT "        /   \  |  ) /      / |   |\ /| | |  \ |   |  ) |                        "
        COLOR BGRA_WHITE
        PRINT "        |   |  |-<  |,-.  '--|   | V | | |  | |   |-'  | ,-: . . ,-. ;-.        "
        PRINT "        \   X  |  ) (   )    |   |   | | |  / |   |    | | | | | |-' |          "
        COLOR BGRA_LIME
        PRINT "_._______`-' ` `-'   `-'     '   '   ' ' `-'  '   '    ' `-` `-| `-' '________._"
        PRINT " |                                                           `-'              | "
        PRINT " |                                                                            | "
        PRINT " |                                                                            | "
        COLOR BGRA_YELLOW
        PRINT " |                                                                            | "
        PRINT " |                     ";: COLOR BGRA_CYAN: PRINT "F1";: COLOR BGRA_GRAY: PRINT " ............ ";: COLOR BGRA_MAGENTA: PRINT "MULTI-SELECT FILES";: COLOR BGRA_YELLOW: PRINT "                     | "
        PRINT " |                     ";: COLOR BGRA_CYAN: PRINT "F2";: COLOR BGRA_GRAY: PRINT " ............. ";: COLOR BGRA_MAGENTA: PRINT "PLAY FROM BITMIDI";: COLOR BGRA_YELLOW: PRINT "                     | "
        PRINT " |                     ";: COLOR BGRA_CYAN: PRINT "F6";: COLOR BGRA_GRAY: PRINT " ................ ";: COLOR BGRA_MAGENTA: PRINT "QUICKSAVE FILE";: COLOR BGRA_YELLOW: PRINT "                     | "
        PRINT " |                     ";: COLOR BGRA_CYAN: PRINT "ESC";: COLOR BGRA_GRAY: PRINT " .................... ";: COLOR BGRA_MAGENTA: PRINT "NEXT/QUIT";: COLOR BGRA_YELLOW: PRINT "                     | "
        PRINT " |                     ";: COLOR BGRA_CYAN: PRINT "SPC";: COLOR BGRA_GRAY: PRINT " ........................ ";: COLOR BGRA_MAGENTA: PRINT "PAUSE";: COLOR BGRA_YELLOW: PRINT "                     | "
        PRINT " |                     ";: COLOR BGRA_CYAN: PRINT "=|+";: COLOR BGRA_GRAY: PRINT " .............. ";: COLOR BGRA_MAGENTA: PRINT "INCREASE VOLUME";: COLOR BGRA_YELLOW: PRINT "                     | "
        PRINT " |                     ";: COLOR BGRA_CYAN: PRINT "-|_";: COLOR BGRA_GRAY: PRINT " .............. ";: COLOR BGRA_MAGENTA: PRINT "DECREASE VOLUME";: COLOR BGRA_YELLOW: PRINT "                     | "
        PRINT " |                     ";: COLOR BGRA_CYAN: PRINT "L|l";: COLOR BGRA_GRAY: PRINT " ......................... ";: COLOR BGRA_MAGENTA: PRINT "LOOP";: COLOR BGRA_YELLOW: PRINT "                     | "
        PRINT " |                     ";: COLOR BGRA_CYAN: PRINT "O/o";: COLOR BGRA_GRAY: PRINT " ......... ";: COLOR BGRA_MAGENTA: PRINT "TOGGLE ANALYZER TYPE";: COLOR BGRA_YELLOW: PRINT "                     | "
        PRINT " |                     ";: COLOR BGRA_CYAN: PRINT "B/b";: COLOR BGRA_GRAY: PRINT " ....... ";: COLOR BGRA_MAGENTA: PRINT "TOGGLE BACKGROUND TYPE";: COLOR BGRA_YELLOW: PRINT "                     | "
        PRINT " |                     ";: COLOR BGRA_CYAN: PRINT "S|s";: COLOR BGRA_GRAY: PRINT " ....... ";: COLOR BGRA_MAGENTA: PRINT USING "SYNTH: [\           \]"; SynthName(MIDI_GetSynthType);: COLOR BGRA_YELLOW: PRINT "                     | "
        PRINT " |                                                                            | "
        PRINT " |                                                                            | "
        PRINT " |                                                                            | "
        PRINT " |   ";: COLOR BGRA_WHITE: PRINT "DRAG AND DROP MULTIPLE FILES ON THIS WINDOW TO PLAY THEM SEQUENTIALLY.";: COLOR BGRA_YELLOW: PRINT "   | "
        PRINT " | ";: COLOR BGRA_WHITE: PRINT "YOU CAN ALSO START THE PROGRAM WITH MULTIPLE FILES FROM THE COMMAND LINE.";: COLOR BGRA_YELLOW: PRINT "  | "
        PRINT " |    ";: COLOR BGRA_WHITE: PRINT "THIS WAS WRITTEN IN QB64 AND THE SOURCE CODE IS AVAILABLE ON GITHUB.";: COLOR BGRA_YELLOW: PRINT "    | "
        PRINT " |                  ";: COLOR BGRA_WHITE: PRINT "https://github.com/a740g/MIDI-Player-64";: COLOR BGRA_YELLOW: PRINT "                   | "
        PRINT "_|_                                                                          _|_"
        PRINT " `/__________________________________________________________________________\' ";

        k = _KEYHIT

        IF k = KEY_ESCAPE THEN
            e = EVENT_QUIT
        ELSEIF _TOTALDROPPEDFILES > 0 THEN
            e = EVENT_DROP
        ELSEIF k = KEY_F1 THEN
            e = EVENT_LOAD
        ELSEIF k = KEY_F2 THEN
            e = EVENT_HTTP
        ELSEIF k = KEY_UPPER_S OR k = KEY_LOWER_S THEN
            DIM bankFileName AS STRING: bankFileName = _OPENFILEDIALOG$(APP_NAME + ": Select MIDI Instrument Bank", , MIDI_INSTRUMENT_BANK_FILE_FILTERS)
            IF LEN(bankFileName) > NULL THEN MIDI_SetSynth bankFileName, NULL
        END IF

        _DISPLAY ' flip the framebuffer

        _LIMIT FRAME_RATE_MAX
    LOOP WHILE e = EVENT_NONE

    OnWelcomeScreen = e
END FUNCTION


' Processes the command line one file at a time
FUNCTION OnCommandLine%%
    DIM e AS _BYTE: e = EVENT_NONE

    IF GetProgramArgumentIndex(KEY_QUESTION_MARK) > 0 THEN
        _MESSAGEBOX APP_NAME, APP_NAME + STRING$(2, KEY_ENTER) + "Syntax: MIDIPlayer64 [-?] [midifile1.mid] [midifile2.mid] ..." + CHR$(KEY_ENTER) + "    -?: Shows this message" + STRING$(2, KEY_ENTER) + "Copyright (c) 2023, Samuel Gomes" + STRING$(2, KEY_ENTER) + "https://github.com/a740g/", "info"

        e = EVENT_QUIT
    ELSE
        DIM i AS LONG: FOR i = 1 TO _COMMANDCOUNT
            e = OnPlayMIDITune(COMMAND$(i))
            IF e <> EVENT_PLAY THEN EXIT FOR
        NEXT
    END IF

    OnCommandLine = e
END FUNCTION


' Processes dropped files one file at a time
FUNCTION OnDroppedFiles%%
    ' Make a copy of the dropped file and clear the list
    REDIM fileNames(1 TO _TOTALDROPPEDFILES) AS STRING

    DIM e AS _BYTE: e = EVENT_NONE

    DIM i AS LONG: FOR i = 1 TO _TOTALDROPPEDFILES
        fileNames(i) = _DROPPEDFILE(i)
    NEXT
    _FINISHDROP ' this is critical

    ' Now play the dropped file one at a time
    FOR i = LBOUND(fileNames) TO UBOUND(fileNames)
        e = OnPlayMIDITune(fileNames(i))
        IF e <> EVENT_PLAY THEN EXIT FOR
    NEXT

    OnDroppedFiles = e
END FUNCTION


' Processes a list of files selected by the user
FUNCTION OnSelectedFiles%%
    DIM ofdList AS STRING
    DIM e AS _BYTE: e = EVENT_NONE

    ofdList = _OPENFILEDIALOG$(APP_NAME, , MIDI_FILE_FILTERS, , TRUE)

    IF LEN(ofdList) = NULL THEN EXIT FUNCTION

    REDIM fileNames(0 TO 0) AS STRING

    DIM j AS LONG: j = String_Tokenize(ofdList, "|", STRING_EMPTY, FALSE, fileNames())

    DIM i AS LONG: WHILE i < j
        e = OnPlayMIDITune(fileNames(i))
        IF e <> EVENT_PLAY THEN EXIT WHILE
        i = i + 1
    WEND

    OnSelectedFiles = e
END FUNCTION


' Loads and plays random MIDIs from www.bitmidi.com
FUNCTION OnBitMidiFiles%%
    DIM e AS _BYTE: e = EVENT_NONE
    DIM modArchiveFileName AS STRING

    DO
        modArchiveFileName = GetRandomBitMidiFileName

        _TITLE "Downloading: " + GetFileNameFromPathOrURL(modArchiveFileName) + " - " + APP_NAME

        e = OnPlayMIDITune(modArchiveFileName)
    LOOP WHILE e = EVENT_NONE OR e = EVENT_PLAY

    OnBitMidiFiles = e
END FUNCTION


' Gets a random file URL from www.modarchive.org
FUNCTION GetRandomBitMidiFileName$
    DIM buffer AS STRING: buffer = LoadFileFromURL("https://bitmidi.com/random")
    DIM bufPos AS LONG: bufPos = INSTR(buffer, CHR$(KEY_QUOTATION_MARK) + "downloadUrl" + CHR$(KEY_QUOTATION_MARK))

    IF bufPos > 0 THEN
        bufPos = bufPos + 13 ' skip "downloadUrl"
        bufPos = INSTR(bufPos, buffer, CHR$(KEY_QUOTATION_MARK)) ' find the position of the next quote
        IF bufPos > 0 THEN
            bufPos = bufPos + 1 ' skip the quote
            GetRandomBitMidiFileName = "https://bitmidi.com" + MID$(buffer, bufPos, INSTR(bufPos, buffer, CHR$(KEY_QUOTATION_MARK)) - bufPos)
        END IF
    END IF
END FUNCTION


' Saves a file loaded from the internet
SUB QuickSave (buffer AS STRING, fileName AS STRING)
    STATIC savePath AS STRING, alwaysUseSamePath AS _BYTE, stopNagging AS _BYTE

    IF LEN(GetDriveOrSchemeFromPathOrURL(fileName)) > 2 THEN
        ' This is a file from the web
        IF NOT _DIREXISTS(savePath) OR NOT alwaysUseSamePath THEN ' only get the path if path does not exist or user wants to use a new path
            savePath = _SELECTFOLDERDIALOG$("Select a folder to save the file:", savePath)
            IF savePath = "" THEN EXIT SUB ' exit if user cancelled

            savePath = FixPathDirectoryName(savePath)
        END IF

        DIM saveFileName AS STRING: saveFileName = savePath + GetLegalFileName(GetFileNameFromPathOrURL(fileName))

        IF _FILEEXISTS(saveFileName) THEN
            IF _MESSAGEBOX(APP_NAME, "Overwrite " + saveFileName + "?", "yesno", "warning", 0) = 0 THEN EXIT SUB
        END IF

        IF SaveFile(buffer, saveFileName, TRUE) THEN
            _MESSAGEBOX APP_NAME, saveFileName + " saved.", "info"
        ELSE
            _MESSAGEBOX APP_NAME, "Failed to save: " + saveFileName, "warning"
            EXIT SUB
        END IF

        ' Check if user want to use the same path in the future
        IF NOT stopNagging THEN
            SELECT CASE _MESSAGEBOX(APP_NAME, "Do you want to use " + savePath + " for future saves?", "yesnocancel", "question", 1)
                CASE 0
                    stopNagging = TRUE
                CASE 1
                    alwaysUseSamePath = TRUE
                CASE 2
                    alwaysUseSamePath = FALSE
            END SELECT
        END IF
    ELSE
        ' This is a local file - do nothing
        _MESSAGEBOX APP_NAME, "You cannot save local file " + fileName + "!", "error"
    END IF
END SUB


SUB InitializeStars (stars() AS StarType)
    CONST Z_DIVIDER = 4096!

    DIM L AS LONG: L = LBOUND(stars)
    DIM U AS LONG: U = UBOUND(stars)
    DIM W AS LONG: W = _WIDTH
    DIM H AS LONG: H = _HEIGHT

    DIM i AS LONG: FOR i = L TO U
        stars(i).p.x = Math_GetRandomBetween(0, W - 1)
        stars(i).p.y = Math_GetRandomBetween(0, H - 1)
        stars(i).p.z = Z_DIVIDER
        stars(i).c = Graphics_MakeBGRA(Math_GetRandomBetween(64, 255), Math_GetRandomBetween(64, 255), Math_GetRandomBetween(64, 255), 255)
    NEXT
END SUB


SUB UpdateAndDrawStars (stars() AS StarType, speed AS SINGLE)
    CONST Z_DIVIDER = 4096!

    DIM L AS LONG: L = LBOUND(stars)
    DIM U AS LONG: U = UBOUND(stars)
    DIM W AS LONG: W = _WIDTH
    DIM H AS LONG: H = _HEIGHT
    DIM W_Half AS LONG: W_Half = W \ 2
    DIM H_Half AS LONG: H_Half = H \ 2

    DIM i AS LONG: FOR i = L TO U
        IF stars(i).p.x < 0 OR stars(i).p.x >= W OR stars(i).p.y < 0 OR stars(i).p.y >= H THEN
            stars(i).p.x = Math_GetRandomBetween(0, W - 1)
            stars(i).p.y = Math_GetRandomBetween(0, H - 1)
            stars(i).p.z = Z_DIVIDER
            stars(i).c = Graphics_MakeBGRA(Math_GetRandomBetween(64, 255), Math_GetRandomBetween(64, 255), Math_GetRandomBetween(64, 255), 255)
        END IF

        Graphics_DrawPixel stars(i).p.x, stars(i).p.y, stars(i).c

        stars(i).p.z = stars(i).p.z + speed
        stars(i).a = stars(i).a + 0.01!
        DIM zd AS SINGLE: zd = stars(i).p.z / Z_DIVIDER
        stars(i).p.x = ((stars(i).p.x - W_Half) * zd) + W_Half + COS(stars(i).a * 0.5!)
        stars(i).p.y = ((stars(i).p.y - H_Half) * zd) + H_Half + SIN(stars(i).a * 1.5!)
    NEXT
END SUB


SUB InitializeCircleWaves (circleWaves() AS CircleWaveType)
    DIM L AS LONG: L = LBOUND(circleWaves)
    DIM U AS LONG: U = UBOUND(circleWaves)
    DIM W AS LONG: W = _WIDTH
    DIM H AS LONG: H = _HEIGHT

    DIM i AS LONG: FOR i = L TO U
        circleWaves(i).a = 0!
        circleWaves(i).r = Math_GetRandomBetween(10, 40)
        circleWaves(i).p.x = Math_GetRandomBetween(circleWaves(i).r, W - circleWaves(i).r)
        circleWaves(i).p.y = Math_GetRandomBetween(circleWaves(i).r, H - circleWaves(i).r)
        circleWaves(i).v.x = (RND - RND) / 3!
        circleWaves(i).v.y = (RND - RND) / 3!
        circleWaves(i).s = Math_GetRandomBetween(1, 100) / 4000!
        circleWaves(i).c.r = Math_GetRandomBetween(0, 128)
        circleWaves(i).c.g = Math_GetRandomBetween(0, 128)
        circleWaves(i).c.b = Math_GetRandomBetween(0, 128)
    NEXT
END SUB


SUB UpdateAndDrawCircleWaves (circleWaves() AS CircleWaveType, size AS SINGLE)
    DIM L AS LONG: L = LBOUND(circleWaves)
    DIM U AS LONG: U = UBOUND(circleWaves)
    DIM W AS LONG: W = _WIDTH
    DIM H AS LONG: H = _HEIGHT

    DIM i AS LONG: FOR i = U TO L STEP -1
        circleWaves(i).a = circleWaves(i).a + circleWaves(i).s
        circleWaves(i).r = circleWaves(i).r + circleWaves(i).s * 10!
        circleWaves(i).p.x = circleWaves(i).p.x + circleWaves(i).v.x
        circleWaves(i).p.y = circleWaves(i).p.y + circleWaves(i).v.y

        IF circleWaves(i).a >= 1! THEN
            circleWaves(i).s = circleWaves(i).s * -1!
            circleWaves(i).a = 1!
        ELSEIF circleWaves(i).a <= 0! THEN
            circleWaves(i).a = 0!
            circleWaves(i).r = Math_GetRandomBetween(10, 40)
            circleWaves(i).p.x = Math_GetRandomBetween(circleWaves(i).r, W - circleWaves(i).r)
            circleWaves(i).p.y = Math_GetRandomBetween(circleWaves(i).r, H - circleWaves(i).r)
            circleWaves(i).v.x = (RND - RND) / 3!
            circleWaves(i).v.y = (RND - RND) / 3!
            circleWaves(i).s = Math_GetRandomBetween(1, 100) / 4000!
            circleWaves(i).c.r = Math_GetRandomBetween(0, 128)
            circleWaves(i).c.g = Math_GetRandomBetween(0, 128)
            circleWaves(i).c.b = Math_GetRandomBetween(0, 128)
        END IF

        Graphics_DrawFilledCircle circleWaves(i).p.x, circleWaves(i).p.y, circleWaves(i).r + circleWaves(i).r * size, Graphics_MakeBGRA(circleWaves(i).c.r, circleWaves(i).c.g, circleWaves(i).c.b, 255! * circleWaves(i).a)
    NEXT
END SUB
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' MODULE FILES
'-----------------------------------------------------------------------------------------------------------------------
'$INCLUDE:'include/GraphicOps.bas'
'$INCLUDE:'include/ProgramArgs.bas'
'$INCLUDE:'include/FileOps.bas'
'$INCLUDE:'include/StringOps.bas'
'$INCLUDE:'include/GraphicOps.bas'
'$INCLUDE:'include/MIDIPlayer.bas'
'-----------------------------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------------------------
