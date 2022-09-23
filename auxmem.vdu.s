* AUXMEM.VDU.S
* (c) Bobbi 2021 GPLv3
*
* Apple //e VDU Driver for 40/80 column mode (PAGE2)
*
* 15-Aug-2021 Optimised address calculations and PRCHRC.
*             Entry point to move copy cursor.
*             Start to consolidate VDU workspace.
* 16-Aug-2021 Added COPY cursor handling.
* 21-Aug-2021 CHR$(&80+n) is inverse of CHR$(&00+n)
* 21-Aug-2021 If screen scrolls, copy cursor adjusted.
* 05-Sep-2021 Starting to prepare VDU workspace.
* 09-Sep-2021 New dispatch routine.
* 22-Sep-2021 More VDU workspace, started MODE definitions.
* 23-Sep-2021 More or less sorted VDU workspace.
* 26-Sep-2021 Merged together JGH VDU updates and Bobbi GFX updates.
*             Moved all graphics screen access code to gfx.s
*             All 65816-specific code disabled.
* 29-Sep-2021 Windows VDU 26, VDU 28, VDU 29, colours VDU 20.
* 01-Oct-2021 VDU 18 (GCOL), start on updating VDU 25 (PLOT).


**********************************
* VDU DRIVER WORKSPACE LOCATIONS *
**********************************
* # marks variables that can't be moved
*
* VDU DRIVER ZERO PAGE
**********************
* $00D0-$00DF VDU driver zero page workspace
VDUSTATUS     EQU   $D0                    ; $D0 # VDU status
* bit 7 = VDU 21 VDU disabled
* bit 6 = COPY cursor active
* bit 5 = VDU 5 Text at graphics cursor
* bit 4 = (Master shadow display)
* bit 3 = VDU 28 Text window defined
* bit 2 = VDU 14 Paged scrolling active
* bit 1 = Don't scroll (COPY cursor or VDU 5 mode)
* bit 0 = VDU 2 printer echo active
*
VDUCHAR       EQU   VDUSTATUS+1            ; $D1 current control character
VDUTEMP       EQU   VDUCHAR                ; &D1
VDUADDR       EQU   VDUSTATUS+2            ; $D2 address of current char cell
VDUBANK       EQU   VDUADDR+2              ; $D4 screen bank
VDUADDR2      EQU   VDUADDR+3              ; $D5 address being scrolled
VDUBANK2      EQU   VDUBANK+3              ; $D7 screen bank being scrolled
PLOTACTION    EQU   VDUSTATUS+8            ; &D8
OLDCHAR       EQU   OSKBD1                 ; &EC character under cursor
COPYCHAR      EQU   OSKBD2                 ; &ED character under copy cursor
* VDU DRIVER MAIN WORKSPACE
***************************
FXLINES       EQU   BYTEVARBASE+217        ; Paged scrolling line counter
FXVDUQLEN     EQU   BYTEVARBASE+218        ; Length of pending VDU queue
VDUVARS       EQU   $290
VDUVAREND     EQU   $2ED

GFXWINLFT     EQU   VDUVARS+$00            ; # graphics window left
GFXWINBOT     EQU   VDUVARS+$02            ; # graphics window bottom \ window
GFXWINRGT     EQU   VDUVARS+$04            ; # graphics window right  /  size
GFXWINTOP     EQU   VDUVARS+$06            ; # graphics window top
TXTWINLFT     EQU   VDUVARS+$08            ; # text window left
TXTWINBOT     EQU   VDUVARS+$09            ; # text window bottom \ window
TXTWINRGT     EQU   VDUVARS+$0A            ; # text window right  /  size
TXTWINTOP     EQU   VDUVARS+$0B            ; # text window top
GFXORIGX      EQU   VDUVARS+$0C            ;   graphics X origin
GFXORIGY      EQU   VDUVARS+$0E            ;   graphics Y origin
*
GFXPOSNX      EQU   VDUVARS+$10            ;   current graphics X posn
GFXPOSNY      EQU   VDUVARS+$12            ;   current graphics Y posn   
GFXLASTX      EQU   VDUVARS+$14            ;   last graphics X posn
GFXLASTY      EQU   VDUVARS+$16            ;   last graphics Y posn
VDUTEXTX      EQU   VDUVARS+$18            ; # absolute text X posn = POS+WINLFT
VDUTEXTY      EQU   VDUVARS+$19            ; # absolute text Y posn = VPOS+WINTOP
VDUCOPYX      EQU   VDUVARS+$1A            ;   absolute COPY text X posn
VDUCOPYY      EQU   VDUVARS+$1B            ;   absolute COPY text Y posn
*
PIXELPLOTX    EQU   VDUVARS+$1C            ;   PLOT graphics X in pixels
PIXELPLOTY    EQU   VDUVARS+$1E            ;   PLOT graphics Y in pixels
PIXELPOSNX    EQU   VDUVARS+$20            ;   current graphics X in pixels
PIXELPOSNY    EQU   VDUVARS+$22            ;   current graphics Y in pixels
PIXELLASTX    EQU   VDUVARS+$24            ;   last graphics X in pixels
PIXELLASTY    EQU   VDUVARS+$26            ;   last graphics Y in pixels
VDUWINEND     EQU   PIXELLASTY+1           ; VDU 26 clears up to here
*
CURSOR        EQU   VDUVARS+$28            ;   character used for cursor
CURSORCP      EQU   VDUVARS+$29            ;   character used for copy cursor
CURSORED      EQU   VDUVARS+$2A            ;   character used for edit cursor
*
VDUQ          EQU   VDUVARS+$2B            ;   $2B..$33
VDUQGFXWIND   EQU   VDUQ+1                 ;   Neatly becomes VDUVARS+$2C
VDUQPLOT      EQU   VDUQ+5                 ;   Neatly becomes VDUVARS+$30
VDUQCOORD     EQU   VDUQ+5
*
VDUVAR34      EQU   VDUVARS+$34
VDUMODE       EQU   VDUVARS+$35            ; # current MODE
VDUSCREEN     EQU   VDUVARS+$36            ; # MODE type
TXTFGD        EQU   VDUVARS+$37            ; # Text foreground
TXTBGD        EQU   VDUVARS+$38            ; # Text background
GFXFGD        EQU   VDUVARS+$39            ; # Graphics foreground
GFXBGD        EQU   VDUVARS+$3A            ; # Graphics background
GFXPLOTFGD    EQU   VDUVARS+$3B            ; # Foreground GCOL action
GFXPLOTBGD    EQU   VDUVARS+$3C            ; # Background GCOL action
VDUBORDER     EQU   VDUVARS+$3D            ;   Border colour
VDUCOLEND     EQU   VDUBORDER              ; VDU 20 clears up to here
*
VDUVAR3E      EQU   VDUVARS+$3E
VDUBYTES      EQU   VDUVARS+$3F            ;   bytes per char, 1=text only
VDUCOLOURS    EQU   VDUVARS+$40            ; # colours-1
VDUPIXELS     EQU   VDUVARS+$41            ; # pixels per byte
VDUWORKSP     EQU   VDUVARS+$42            ;   28 bytes of general workspace
VDUWORKSZ     EQU   VDUVAREND-VDUWORKSP+1
*

* Screen definitions
*                     1     3        6  7  ; MODEs sort-of completed
SCNTXTMAXX    DB    79,39,19,79,39,19,39,39  ; Max text column
SCNTXTMAXY    DB    23,23,23,23,23,23,23,23  ; Max text row
SCNBYTES      DB    01,08,01,01,01,01,01,01  ; Bytes per character
SCNCOLOURS    DB    15,07,15,01,01,15,01,01  ; Colours-1
SCNPIXELS     DB    00,07,00,00,00,00,00,00  ; Pixels per byte
SCNTYPE       DB    01,128,0,01,00,00,00,64  ; Screen type
* b7=FastDraw
* b6=Teletext
* b0=40COL/80COL

* Colour table
CLRTRANS16    DB    00,01,04,08,02,14,11,10
              DB    05,09,12,13,06,03,07,15
CLRTRANS8     DB    00,05,01,01,06,02,02,07

********************************************************************
* Note that we use PAGE2 80 column mode ($800-$BFF in main and aux)
*           and    PAGE1 HGR mode ($2000-$23ff in main only)
********************************************************************

* Addresses of start of text rows in PAGE2
SCNTAB        DW    $800,$880,$900,$980,$A00,$A80,$B00,$B80
              DW    $828,$8A8,$928,$9A8,$A28,$AA8,$B28,$BA8
              DW    $850,$8D0,$950,$9D0,$A50,$AD0,$B50,$BD0

* Addresses of start of pixel rows in PAGE1
HGRTAB        DW    $2000,$2080,$2100,$2180,$2200,$2280,$2300,$2380
              DW    $2028,$20A8,$2128,$21A8,$2228,$22A8,$2328,$23A8
              DW    $2050,$20D0,$2150,$21D0,$2250,$22D0,$2350,$23D0

* Output character to VDU driver
********************************
* On entry: A=character
* On exit:  All registers trashable
*           CS if printer echo enabled for this character
* 
OUTCHAR       LDX   FXVDUQLEN
              BNE   ADDTOQ                 ; Waiting for chars
              CMP   #$7F
              BEQ   CTRLDEL                ; =$7F - control char
              CMP   #$20
              BCC   CTRLCHAR               ; <$20 - control char
              BIT   VDUSTATUS
              BMI   OUTCHEXIT              ; VDU disabled
OUTCHARCP     JSR   PRCHRC                 ; Store char, checking keypress
              JSR   VDU09                  ; Move cursor right

* OSBYTE &75 - Read VDUSTATUS
*****************************
BYTE75
OUTCHEXIT     LDA   VDUSTATUS
              TAX
              LSR   A                      ; Return Cy=Printer Echo Enabled
              RTS

CTRLDEL       LDA   #$20                   ; $7F becomes $20
CTRLCHAR      CMP   #$01
              BEQ   ADDQ                   ; One param
              CMP   #$11
              BCC   CTRLCHARGO             ; Zero params
ADDQ          STA   VDUCHAR                ; Save initial character
              AND   #$0F
              TAX
              LDA   QLEN,X
              STA   FXVDUQLEN              ; Number of params to queue
              BEQ   CTRLCHARGO1            ; Zero, do it now
QDONE         CLC                          ; CLC=Don't echo VDU queue to printer
              RTS
ADDTOQ        STA   VDUQ-256+9,X
              INC   FXVDUQLEN
              BNE   QDONE
CTRLCHARGO1   LDA   VDUCHAR
CTRLCHARGO    ASL   A
              TAY
              CMP   #$10                   ; 8*2
              BCC   CTRLCHARGO2            ; ctrl<$08, don't echo to printer
              EOR   #$FF                   ; ctrl>$0D, don't echo to printer
              CMP   #$E5                   ; (13*2) EOR 255
CTRLCHARGO2   PHP                          ; Save CS=(ctrl>=8 && ctrl<=13)
              JSR   CTRLCHARJMP            ; Call routine
              PLP
              BCS   OUTCHEXIT              ; If echoable, test if printer enabled
              RTS                          ; Return, CC=Don't echo to printer

OUTCHARGO     ASL   A                      ; Entry point to move COPY cursor
              TAY
CTRLCHARJMP   CPY   #6*2
              BEQ   CTRLCHAR6              ; Always allow VDU 6 through
              BIT   VDUSTATUS
              BMI   VDU00                  ; VDU disabled
CTRLCHAR6     LDA   CTRLADDRS+1,Y
              PHA
              LDA   CTRLADDRS+0,Y
              PHA
VDU27
VDU00         RTS

QLEN          DB    -0,-1,-2,-5,-0,-0,-1,-9  ; 32,1 or 17,18,19,20,21,22,23
              DB    -8,-5,-0,-0,-4,-4,-0,-2  ; 24,25,26,27,28,29,30,31
CTRLADDRS     DW    VDU00-1,VDU01-1,VDU02-1,VDU03-1
              DW    VDU04-1,VDU05-1,VDU06-1,BEEP-1
              DW    VDU08-1,VDU09-1,VDU10-1,VDU11-1
              DW    VDU12-1,VDU13-1,VDU14-1,VDU15-1
              DW    VDU16-1,VDU17-1,VDU18-1,VDU19-1
              DW    VDU20-1,VDU21-1,VDU22-1,VDU23-1
              DW    VDU24-1,VDU25-1,VDU26-1,VDU27-1
              DW    VDU28-1,VDU29-1,VDU30-1,VDU31-1
              DW    VDU127-1


* Turn things on and off
************************

* VDU 2 - Start print job
VDU02
*           JSR   select printer
              LDA   #$01                   ; Set PrinterEcho On
              BNE   SETSTATUS

* VDU 5 - Text at graphics cursor
VDU05         LDX   VDUPIXELS
              BEQ   SETEXIT                ; 0 pixels per char, text only
* Turn cursor off and other stuff
              LDA   #$20                   ; Set VDU 5 mode
              BNE   SETSTATUS

* VDU 14 - Select paged scrolling
VDU14         STZ   FXLINES                ; Reset line counter
              LDA   #$04                   ; Set Paged Mode
              BNE   SETSTATUS

* VDU 21 - Disable VDU
VDU21         LDA   #$80                   ; Set VDU disabled

SETSTATUS     ORA   VDUSTATUS              ; Set bits in VDU STATUS
              STA   VDUSTATUS
SETEXIT       RTS

* VDU 3 - End print job
VDU03
*           JSR   flush printer
              LDA   #$FE                   ; Clear Printer Echo
              BNE   CLRSTATUS

* VDU 4 - Text at text cursor
VDU04
* Turn cursor on and other stuff
              LDA   #$DF                   ; Clear VDU 5 mode
              BNE   CLRSTATUS

* VDU 15 - Disable paged scrolling
VDU15         LDA   #$FB                   ; Clear paged scrolling
              BRA   CLRSTATUS

* VDU 6 - Enable VDU
VDU06         LDA   #$7F                   ; Clear VDU disabled

CLRSTATUS     AND   VDUSTATUS
              STA   VDUSTATUS
              RTS


* Editing cursor
****************
* Move editing cursor
* A=cursor key, CS from caller
COPYMOVE      PHA
              BIT   VDUSTATUS
              BVS   COPYMOVE2              ; Edit cursor already on
              JSR   GETCHRC
              STA   COPYCHAR
              LDA   CURSORED
              JSR   PUTCHRC                ; Edit cursor
              SEC
              JSR   COPYSWAP2              ; Initialise copy cursor
              ROR   FLASHER
              ASL   FLASHER                ; Ensure b0=0
              LDA   #$42
              ORA   VDUSTATUS
              STA   VDUSTATUS              ; Turn cursor editing on
COPYMOVE2     PLA
              AND   #3                     ; Convert to 8/9/10/11
              ORA   #8
COPYMOVE3     JMP   OUTCHARGO              ; Move edit cursor

* Swap between edit and copy cursors
COPYSWAP1     CLC                          ; CC=Swap TEXT and COPY
COPYSWAP2     LDX   #1
COPYSWAPLP    LDY   VDUCOPYX,X
              LDA   VDUTEXTX,X
              STA   VDUCOPYX,X
              BCS   COPYSWAP3              ; CS=Copy TEXT to COPY
              TYA
              STA   VDUTEXTX,X
COPYSWAP3     DEX
              BPL   COPYSWAPLP
COPYSWAP4     RTS


* Write character to screen
***************************
* Perform backspace & delete operation
VDU127        JSR   VDU08                  ; Move cursor back
              LDA   #' '                   ; Overwrite with a space
              BNE   PUTCHRC

* Display character at current (TEXTX,TEXTY)
PRCHRC        PHA                          ; Save character
              LDA   $C000
              BPL   :RESUME                ; No key pressed
              EOR   #$80
:PAUSE1       JSR   KBDCHKESC              ; Ask KBD to test if Escape
              BIT   ESCFLAG
              BMI   :RESUMEACK             ; Escape, skip pausing
              CMP   #$13
              BNE   :RESUME                ; Not Ctrl-S
              STA   $C010                  ; Ack. keypress
:PAUSE2       LDA   $C000
              BPL   :PAUSE2                ; Loop until keypress
              EOR   #$80
              CMP   #$11                   ; Ctrl-Q
              BEQ   :RESUMEACK             ; Stop pausing
              JSR   KBDCHKESC              ; Ask KBD to test if Escape
              BIT   ESCFLAG
              BPL   :PAUSE2                ; No Escape, keep pausing
:RESUMEACK    STA   $C010                  ; Ack. keypress
:RESUME       PLA

* Put character to screen
* Puts character to text screen buffer, then in graphics mode,
* writes bitmap to graphics screen
PUTCHRC       PHA
              EOR   #$80                   ; Convert character to screen code
              TAX
              AND   #$A0
              BNE   PRCHR4
              CPX   #$20
              BCS   PRCHR3                 ; Not $80-$9F
              BIT   VDUSCREEN
              BVC   PRCHR3                 ; Not teletext
              LDX   #$E0                   ; Convert $80-$9F to space
PRCHR3        TXA
              EOR   #$40
              TAX
PRCHR4        JSR   CHARADDR               ; Find character address
              TXA                          ; Get character back
              BIT   VDUBANK
              BPL   PRCHR5                 ; Not AppleGS, use short write
              >>>   WRTMAIN
              STA   [VDUADDR],Y
              >>>   WRTAUX
              BRA   PRCHR8
PRCHR5        BCC   PRCHR6                 ; Aux memory
              >>>   WRTMAIN
PRCHR6        STA   (VDUADDR),Y            ; Store it
PRCHR7        >>>   WRTAUX
PRCHR8        PLA
              BIT   VDUSCREEN
              BPL   GETCHROK
              JMP   PRCHRSOFT              ; Write character to graphics

* OSBYTE &87 - Read character at cursor
***************************************
* Fetch character from screen at (TEXTX,TEXTY) and return MODE in Y
* Always read from text screen (which we maintain even in graphics mode)
BYTE87
GETCHRC       JSR   CHARADDR               ; Find character address
              BIT   VDUBANK
              BMI   GETCHRGS
              BCC   GETCHR6                ; Aux memory
              STA   $C002                  ; Read main memory
GETCHR6       LDA   (VDUADDR),Y            ; Get character
              STA   $C003                  ; Read aux memory
              TAY                          ; Convert character
              AND   #$A0
              BNE   GETCHR7
              TYA
              EOR   #$40
              TAY
GETCHR7       TYA
              EOR   #$80
              LDY   VDUMODE                ; Y=MODE
              TAX                          ; X=char
GETCHROK      RTS
GETCHRGS      BCC   GETCHR8                ; Aux memory
              STA   $C002                  ; Read main memory
GETCHR8       LDA   [VDUADDR],Y            ; Get character
              STA   $C003                  ; Read aux memory
              TAY                          ; Convert character
              AND   #$A0
              BNE   GETCHR9
              TYA
              EOR   #$40
              TAY
GETCHR9       TYA
              EOR   #$80
              LDY   VDUMODE                ; Y=MODE
              TAX                          ; X=char, set EQ/NE
              RTS


* OSBYTE &86 - Get text cursor position
***************************************
BYTE86        LDY   VDUTEXTY
              LDX   VDUTEXTX
              RTS

* Calculate character address
*****************************
* NB: VDUBANK at VDUADDR+2 is set by VDU22
CHARADDR      LDA   VDUTEXTY
CHARADDRY     ASL
              TAY
              LDA   SCNTAB+0,Y             ; LSB of row address
              STA   VDUADDR+0
              LDA   SCNTAB+1,Y             ; MSB of row address
              STA   VDUADDR+1
              LDA   VDUTEXTX
              BIT   $C01F
              SEC
              BPL   CHARADDR40             ; 40-col
              LSR   A
CHARADDR40    TAY                          ; Y=offset into this row
              LDA   VDUBANK
              AND   #$FE
              BCS   CHARADDROK
              ORA   #$01
CHARADDROK    STA   VDUBANK
              RTS
* (VDUADDR),Y=>character address
*  VDUBANK   = AppleGS screen bank
* CC=auxmem, CS=mainmem, X=preserved

* Calculate character address in HGR screen memory
* This is the address of the first pixel row of the char
* Add $0400 for each subsequent row of the char
HCHARADDR     LDA   VDUTEXTY
              ASL
              TAY
              CLC
              LDA   HGRTAB+0,Y             ; LSB of row address
              ADC   VDUTEXTX
              STA   VDUADDR+0
              LDA   HGRTAB+1,Y             ; MSB of row address
              ADC   #$00
              STA   VDUADDR+1
              RTS
* (VDUADDR)=>character address, X=preserved


* Move text cursor position
***************************
* Move cursor left
VDU08         LDA   VDUTEXTX               ; COL
              CMP   TXTWINLFT
              BEQ   :S1
              DEC   VDUTEXTX               ; COL
              BRA   :S3
:S1           LDA   VDUTEXTY               ; ROW
              CMP   TXTWINTOP
              BEQ   :S3
              DEC   VDUTEXTY               ; ROW
              LDA   TXTWINRGT
              STA   VDUTEXTX               ; COL
:S3           RTS

* Move cursor right
VDU09         LDA   VDUTEXTX               ; COL
              CMP   TXTWINRGT
              BCC   :S2
:T11          LDA   TXTWINLFT
              STA   VDUTEXTX               ; COL
              LDA   VDUTEXTY               ; ROW
              CMP   TXTWINBOT
              BEQ   SCROLL
              INC   VDUTEXTY               ; ROW
:DONE         RTS
:S2           INC   VDUTEXTX               ; COL
              BRA   :DONE
SCROLL        JSR   SCROLLER
              LDA   TXTWINLFT
              STA   VDUTEXTX
              JSR   CLREOL
              RTS

* Move cursor down
VDU10         LDA   VDUTEXTY               ; ROW
              CMP   TXTWINBOT
              BEQ   :TOSCRL                ; JGH
              INC   VDUTEXTY               ; ROW
              RTS
:TOSCRL       JMP   SCROLL                 ; JGH

* Move cursor up
VDU11         LDA   VDUTEXTY               ; ROW
              CMP   TXTWINTOP
              BNE   :S1
              LDA   VDUTEXTX               ; COL
              CMP   TXTWINLFT
              BNE   :DONE
              JSR   RSCROLLER
              LDA   TXTWINLFT
              STA   VDUTEXTX
              JSR   CLREOL
              RTS
:S1           DEC   VDUTEXTY               ; ROW
:DONE         RTS

* Move to start of line
VDU13         LDA   #$BF
              JSR   CLRSTATUS              ; Turn copy cursor off
              LDA   TXTWINLFT
              STA   VDUTEXTX               ; COL
              RTS

* Move to (0,0)
VDU30         LDA   TXTWINTOP
              STA   VDUTEXTY               ; ROW
              LDA   TXTWINLFT
              STA   VDUTEXTX               ; COL
              RTS

* Move to (X,Y)
** TODO
VDU31         LDY   VDUQ+8
              CPY   #24
              BCS   :DONE
              LDX   VDUQ+7
              CPX   #80
              BCS   :DONE
              BIT   $C01F
              BMI   :T9A
              CPX   #40
              BCS   :DONE
:T9A          STX   VDUTEXTX               ; COL
              STY   VDUTEXTY               ; ROW
:DONE         RTS


* Initialise VDU driver
***********************
* On entry, A=MODE to start in
*
VDUINIT       STA   VDUQ+8
*            JSR   FONTIMPLODE       ; Reset VDU 23 font

* VDU 22 - MODE n
*****************
* At the moment only MODEs available:
*  MODE 1 - 280x192 HGR graphics, 40 cols bitmap text
*  MODE 3 - 80x24 text
*  MODE 6 - 40x24 text
*  MODE 7 - 40x24 with $80-$9F converted to spaces
*  MODE 0 defaults to MODE 3
*  All others default to MODE 6
*
* Wait for VSync?
VDU22         LDA   VDUQ+8
              AND   #$07
              TAX                          ; Set up MODE
              STX   VDUMODE                ; Screen MODE
              LDA   SCNCOLOURS,X
              STA   VDUCOLOURS             ; Colours-1
              LDA   SCNBYTES,X
              STA   VDUBYTES               ; Bytes per char
              LDA   SCNPIXELS,X
              STA   VDUPIXELS              ; Pixels per byte
              LDA   SCNTYPE,X
              STA   VDUSCREEN              ; Screen type
              JSR   NEGCALL                ; Find machine type
              AND   #$0F
              BEQ   :MODEGS                ; MCHID=$x0 -> Not AppleGS, bank=0
              LDA   #$E0                   ;  Not $x0  -> AppleGS, point to screen bank
:MODEGS       STA   VDUBANK
              LDA   #$01
              JSR   CLRSTATUS              ; Clear everything except PrinterEcho
              LDA   #'_'                   ; Set up default cursors
              STA   CURSOR                 ; Normal cursor
              STA   CURSORCP               ; Copy cursor when editing
              LDA   #$A0
              STA   CURSORED               ; Edit cursor when editing
              JSR   VDU20                  ; Default colours
              JSR   VDU26                  ; Default windows
              STA   $C052                  ; Clear MIXED
              LDA   VDUSCREEN
              BMI   VDU22G                 ; b7=1, graphics mode
              AND   #$01                   ; 40col/80col bit
              TAX
              STA   $C00C,X                ; Select 40col/80col
              STA   $C051                  ; Enable Text
              STA   $C055                  ; PAGE2
              STA   $C00F                  ; Enable alt charset
* Fall through into CLS


* Clear areas of the screen
***************************
VDU12         STZ   FXLINES
              LDA   TXTWINTOP
              STA   VDUTEXTY
              LDA   TXTWINLFT
              STA   VDUTEXTX

* Clear the text screen buffer
:L1           JSR   CLREOL
              BIT   VDUSCREEN
              BPL   :S2
              JSR   HSCRCLREOL
:S2           LDA   VDUTEXTY               ; ROW
              CMP   TXTWINBOT
              BEQ   :S3
              INC   VDUTEXTY               ; ROW
              BRA   :L1
:S3           LDA   TXTWINTOP
              STA   VDUTEXTY               ; ROW
              LDA   TXTWINLFT
              STA   VDUTEXTX               ; COL
              RTS

* Clear the graphics screen buffer
VDU12SOFT     JMP   VDU16                  ; *TEMP*

VDU22G        STA   $C050                  ; Enable Graphics
              STA   $C057                  ; Hi-Res
              STA   $C054                  ; PAGE1
              STA   $C00C                  ; Select 40col text
              JMP   VDU12                  ; Clear text and HGR screen


* Clear to EOL, respecting text window boundaries
CLREOL        JSR   CHARADDR               ; Set VDUADDR=>start of line
              INC   TXTWINRGT
              BIT   VDUBANK
              BMI   CLREOLGS               ; AppleGS
              BIT   $C01F
              BPL   :FORTY                 ; 40-col mode
:EIGHTY       LDX   VDUTEXTX               ; Addr offset for column
:L1           TXA                          ; Column/2 into Y
              LSR
              TAY
              LDA   #$A0
              BCS   :MAIN                  ; Odd cols in main mem
              STA   (VDUADDR),Y            ; Even cols in aux
              BRA   :SKIPMAIN
:MAIN         >>>   WRTMAIN
              STA   (VDUADDR),Y
              >>>   WRTAUX
:SKIPMAIN     INX
              CPX   TXTWINRGT
              BMI   :L1
              BRA   CLREOLDONE
:FORTY        LDA   #$A0
:L2           >>>   WRTMAIN
              STA   (VDUADDR),Y
              >>>   WRTAUX
              INY
              CPY   TXTWINRGT
              BMI   :L2
CLREOLDONE    DEC   TXTWINRGT
              BIT   VDUSCREEN
              BPL   :NOHIRES
              JMP   HSCRCLREOL             ; Clear an HGR line
:NOHIRES      RTS
CLREOLGS      BIT   $C01F
              BPL   :FORTY                 ; 40-col mode
:EIGHTY       LDX   VDUTEXTX               ; Addr offset for column
:L1           TXA                          ; Column/2 into Y
              LSR
              TAY
              BCS   :E0                    ; Odd cols
              LDA   #$E1                   
              STA   VDUBANK
              LDA   #$A0
              >>>   WRTMAIN
              STA   [VDUADDR],Y            ; Even cols in bank $E1
              >>>   WRTAUX
              BRA   :SKIPE0
:E0           LDA   #$E0
              STA   VDUBANK
              LDA   #$A0
              >>>   WRTMAIN
              STA   [VDUADDR],Y            ; Odd cols in bank $E0
              >>>   WRTAUX
:SKIPE0       INX
              CPX   TXTWINRGT
              BMI   :L1
              BRA   CLREOLDONE
:FORTY        LDA   #$E0
              STA   VDUBANK
              LDA   #$A0
:L2           >>>   WRTMAIN
              STA   [VDUADDR],Y
              >>>   WRTAUX
              INY
              CPY   TXTWINRGT
              BMI   :L2
              BRA   CLREOLDONE


* Scroll areas of the screen
****************************
* Scroll text window up one line
SCROLLER      LDA   TXTWINTOP
:L1           PHA
              JSR   SCR1LINE
              BIT   VDUSCREEN
              BPL   :S0
              JSR   SCR1SOFT               ; Scroll graphics screen
:S0           PLA
              INC
              CMP   TXTWINBOT
              BNE   :L1
              BIT   VDUSTATUS
              BVC   :S1                    ; Copy cursor not active
              JSR   COPYSWAP1
              LDA   #11
              JSR   OUTCHARGO
              JSR   COPYSWAP1
:S1           RTS

* Scroll text window down one line
RSCROLLER     DEC   TXTWINTOP
              LDA   TXTWINBOT
              DEC   A
:L1           PHA
              JSR   RSCR1LINE
              BIT   VDUSCREEN
              BPL   :S0
              JSR   RSCR1SOFT              ; Scroll graphics screen
:S0           PLA
              DEC   A
              CMP   TXTWINTOP
              BNE   :L1
              BIT   VDUSTATUS
              BVC   :S1                    ; Copy cursor not active
              JSR   COPYSWAP1
              LDA   #11
              JSR   OUTCHARGO
              JSR   COPYSWAP1
:S1           INC   TXTWINTOP
              RTS

* Copy line A to line A+1, respecting text window boundaries
RSCR1LINE     PHA
              INC   A
              JSR   CHARADDRY              ; VDUADDR=>line A+1
              LDX   #2
:L0           LDA   VDUADDR,X              ; Copy VDUADDR->VDUADDR2
              STA   VDUADDR2,X
              DEX
              BPL   :L0
              PLA
              PHA
              JSR   CHARADDRY              ; VDUADDR=>line A+1
              BRA   DOSCR1LINE

* Copy line A+1 to line A, respecting text window boundaries
SCR1LINE      PHA
              JSR   CHARADDRY              ; VDUADDR=>line A
              LDX   #2
:L0           LDA   VDUADDR,X              ; Copy VDUADDR->VDUADDR2
              STA   VDUADDR2,X
              DEX
              BPL   :L0
              PLA
              PHA
              INC   A
              JSR   CHARADDRY              ; VDUADDR=>line A+1
DOSCR1LINE    INC   TXTWINRGT
              BIT   VDUBANK
              BMI   SCR1LINEGS             ; AppleGS
              LDX   TXTWINLFT              ; Addr offset for column
              BIT   $C01F
              BPL   :FORTY                 ; 40-col mode
:EIGHTY
:L1           TXA                          ; Column/2 into Y
              LSR
              TAY
              BCS   :MAIN                  ; Odd cols in main mem
              LDA   (VDUADDR),Y            ; Even cols in aux
              STA   (VDUADDR2),Y
              BRA   :SKIPMAIN
:MAIN         >>>   WRTMAIN
              STA   $C002                  ; Read main memory
              LDA   (VDUADDR),Y
              STA   (VDUADDR2),Y
              STA   $C003                  ; Read aux memory
              >>>   WRTAUX
:SKIPMAIN     INX
              CPX   TXTWINRGT
              BMI   :L1
              BRA   SCR1LNDONE
:FORTY        TXA
              TAY
:L2           >>>   WRTMAIN
              STA   $C002                  ; Read main memory
              LDA   (VDUADDR),Y
              STA   (VDUADDR2),Y
              STA   $C003                  ; Read aux memory
              >>>   WRTAUX
              INY
              CPY   TXTWINRGT
              BMI   :L2
SCR1LNDONE    DEC   TXTWINRGT
              PLA
              RTS
SCR1LINEGS    LDX   TXTWINLFT
              BIT   $C01F
              BPL   :FORTY                 ; 40-col mode
:EIGHTY       
:L1           TXA                          ; Column/2 into Y
              LSR
              TAY
              BCS   :E0                    ; Odd cols
              LDA   #$E1                   
              STA   VDUBANK
              STA   VDUBANK2
              >>>   WRTMAIN
              STA   $C002                  ; Read main memory
              LDA   [VDUADDR],Y            ; Even cols in bank $E1
              STA   [VDUADDR2],Y
              STA   $C003                  ; Read aux memory
              >>>   WRTAUX
              BRA   :SKIPE0
:E0           LDA   #$E0
              STA   VDUBANK
              STA   VDUBANK2
              >>>   WRTMAIN
              STA   $C002                  ; Read main memory
              LDA   [VDUADDR],Y            ; Odd cols in bank $E0
              STA   [VDUADDR2],Y
              STA   $C003                  ; Read aux memory
              >>>   WRTAUX
:SKIPE0       INX
              CPX   TXTWINRGT
              BMI   :L1
              BRA   SCR1LNDONE
:FORTY        TXA
              TAY
              LDA   #$E0
              STA   VDUBANK
:L2           >>>   WRTMAIN
              STA   $C002                  ; Read main memory
              LDA   [VDUADDR],Y
              STA   [VDUADDR2],Y
              STA   $C003                  ; Read aux memory
              >>>   WRTAUX
              INY
              CPY   TXTWINRGT
              BMI   :L2
              BRA   SCR1LNDONE

* Copy text line A+1 to line A for HGR bitmap gfx mode
SCR1SOFT      JMP   HSCR1LINE

* Copy text line A to line A+1 for HGR bitmap gfx mode
RSCR1SOFT      JMP   HRSCR1LINE

* VDU 16 - CLG, clear graphics window
VDU16         JMP   HSCRCLEAR


* Colour control
****************
* VDU 20 - Reset to default colours
VDU20
* THE FOLLOWING TWO LINES ARE FOR GS ONLY & NOT SAFE ON //c
*             LDA   #$F0
*             STA   $C022                  ; Set text palette
              LDX   #VDUCOLEND-TXTFGD
              LDA   #$00
VDU20LP       STA   TXTFGD,X               ; Clear all colours
              DEX                          ; and gcol actions
              BPL   VDU20LP
* THE FOLLOWING LINE IS FOR GS ONLY & NOT SAFE ON //c
*             STA   $C034                  ; Set border
              LDA   #$80
              JSR   HSCRSETTCOL            ; Set txt background
              LDX   #$00
              LDA   #$80
              JSR   HSCRSETGCOL            ; Set gfx background
              LDA   VDUCOLOURS
              AND   #$07
              PHA
              STA   TXTFGD                 ; Note txt foreground
              JSR   HSCRSETTCOL            ; Set txt foreground
              LDX   #$00
              PLA
              STA   GFXFGD                 ; Note gfx foreground
              JMP   HSCRSETGCOL            ; Set gfx foreground

* VDU 17 - COLOUR n - select text or border colour
VDU17         LDA   VDUQ+8
              CMP   #$C0
              BCS   VDU17BORDER
* TO DO *
              JMP   HSCRSETTCOL
VDU17BORDER   AND   #$0F
              STA   VDUBORDER
              TAX
              LDA   CLRTRANS16,X
              STA   $C034
              RTS

* VDU 18 - GCOL k,a - select graphics colour and plot action
VDU18         LDY   #$02                   ; Y=>gfd settings
              LDA   VDUQ+8                 ; GCOL colour
              PHA
              CMP   #$80
              BCC   VDU18A
              INY                          ; Y=>bgd settings
VDU18A        LDA   VDUQ+7                 ; GCOL action
              STA   GFXPLOTFGD-2,Y         ; Store GCOL action
              TAX                          ; X=GCOL action
              PLA
              AND   VDUCOLOURS
              STA   GFXFGD-2,Y             ; Store GCOL colour
              TAY
              LDA   CLRTRANS8,Y            ; Trans. to physical
              PHP
              ROL   A
              PLP
              ROR   A                      ; Get bit 7 back
              JMP   HSCRSETGCOL

* VDU 19 - Select palette colours
VDU19         RTS


* Window (viewport) control
***************************
* VDU 26 - Reset to default windows
VDU26         LDA   #$F7
              JSR   CLRSTATUS              ; Clear 'soft window'
VDU26A        LDX   #VDUWINEND-VDUVARS
              LDA   #$00
VDU26LP       STA   VDUVARS,X              ; Clear all windows
              DEX                          ; and all coords
              BPL   VDU26LP                ; and origin, etc.
              LDY   VDUMODE
              LDA   SCNTXTMAXY,Y
              STA   TXTWINBOT              ; Text window height
              LDA   SCNTXTMAXX,Y
              STA   TXTWINRGT              ; Text window width
              LDY   VDUPIXELS
              BEQ   VDU26QUIT              ; No graphics
              LDX   #GFXWINRGT-VDUVARS
              JSR   VDU26SCALE             ; GFXWID=TXTWID*PIXELS-1
              LDA   TXTWINBOT
              LDY   #8                     ; GFXHGT=TXTHGT*8-1
              LDX   #GFXWINTOP-VDUVARS
*
* Convert text count to pixel count
* VDUVARS,X=(A+1)*Y-1
VDU26SCALE    PHA
              CLC
              ADC   VDUVARS+0,X
              ORA   #$01
              STA   VDUVARS+0,X
              LDA   VDUVARS+1,X
              ADC   #$00
              STA   VDUVARS+1,X
              PLA
              DEY
              BNE   VDU26SCALE
VDU26QUIT     RTS

* VDU 28,left,bottom,right,top - define text window
VDU28         LDX   VDUMODE
              LDA   VDUQCOORD+2            ; right
              CMP   VDUQCOORD+0            ; left
              BCC   VDUCOPYEXIT            ; right<left
              CMP   SCNTXTMAXX,X
              BEQ   VDU28B
              BCS   VDUCOPYEXIT            ; right>width
VDU28B        LDA   VDUQCOORD+1            ; bottom
              CMP   VDUQCOORD+3            ; top
              BCC   VDUCOPYEXIT            ; bottom<top
              CMP   SCNTXTMAXY,X
              BEQ   VDU28C
              BCS   VDUCOPYEXIT            ; top>height
VDU28C        LDY   #TXTWINLFT+3-VDUVARS   ; Copy to txt window params
              BEQ   VDU28D
              JSR   VDUCOPY4
              LDA   TXTWINLFT              ; Cursor to top-left of window
              STA   VDUTEXTX
              LDA   TXTWINTOP
              STA   VDUTEXTY
VDU28D        RTS

* VDU 24,left;bottom;right;top; - define graphics window
VDU24         RTS
* If right<left, exit
* If right>width, exit
* If top<bottom, exit
* If top>height, exit
* scale parameters
              LDY   #GFXWINLFT+7-VDUVARS   ; Copy to gfx window params
              LDA   #$08
              BNE   COPYVDUQ

* VDU 29,x;y; - define graphics origin
VDU29         LDY   #GFXORIGX+3-VDUVARS    ; Copy to ORIGIN

* Copy four bytes from VDU queue to VDU workspace
VDUCOPY4      LDA   #$04                   ; 4 bytes to copy

* Copy parameters in VDU Queue to VDU workspace
COPYVDUQ      LDX   #VDUQ+$08-VDUVARS      ; End of VDU queue

* Copy A bytes from VDUVARS,X to VDUVARS,Y
VDUCOPY       STA   VDUTEMP
VDUCOPYLP     LDA   VDUVARS,X
              STA   VDUVARS,Y
              DEX
              DEY
              DEC   VDUTEMP
              BNE   VDUCOPYLP
VDUCOPYEXIT   RTS


* PLOT master dispatch
**********************
* VDU 25,k,x;y; - PLOT k,x,y - PLOT point, line, etc.
*
* The PLOT canvass extends in four directions, with the visible
* screen a portion in the positive quadrant.
*             |
*  (-ve,+ve)  |  (+ve,+ve)
*             +---------+
*             |         |
*             | visible |
*             | screen  |
* ------------+---------+--
*           (0,0)
*             |
*             |
*  (-ve,-ve)  |  (+ve,-ve)
*             |
*             |
* 
* PLOT actions occur over the whole canvas, with the result of
* the actions that cross the visible screen written to the graphics
* buffer. For example, a trangle draw between (-100,-100), (-100,+100),
* (+100,+150) will draw a partial triangle in the visible screen.
* 
* k is in VDUQ+4
* x is in VDUQ+5,VDUQ+6
* y is in VDUQ+7,VDUQ+8
*

* TO DO:
* clip to viewport

VDU25         LDA   VDUQ+4
              AND   #$04                   ; Bit 2 set -> absolute
              BNE   :S0
              JSR   RELCOORD               ; Relative->Absolute coords
              BRA   :S1
:S0           JSR   ADJORIG                ; Adjust graphics origin
:S1           LDX   #7
VDU25BACKUP1  LDA   PIXELPLOTX+0,X         ; Copy pixel coords
              STA   PIXELPLOTX+4,X         ; POSN becomes LAST
              DEX                          ; and PLOT becomes POSN
              BPL   VDU25BACKUP1
              LDX   #3                     ; Copy PLOT coords
VDU25BACKUP2  LDA   GFXPOSNX,X             ; POSN becomes LAST
              STA   GFXLASTX,X
              LDA   VDUQPLOT,X             ; and PLOT becomes POSN
              STA   GFXPOSNX,X
              DEX
              BPL   VDU25BACKUP2
              LDA   VDUPIXELS
              BEQ   :S2
              JSR   HGRPLOTTER
:S2           LDA   $C000                  ; This and PRCHRC need to be
              EOR   #$80                   ; made more generalised
              BMI   VDU25EXIT              ; No key pressed
              JSR   KBDCHKESC              ; Ask KBD to test if Escape
VDU25EXIT     RTS

* Adjust graphics origin
ADJORIG      CLC
             LDA   GFXORIGX+0
             ADC   VDUQ+5
             STA   VDUQ+5
             LDA   GFXORIGX+1
             ADC   VDUQ+6
             STA   VDUQ+6
             CLC
             LDA   GFXORIGY+0
             ADC   VDUQ+7
             STA   VDUQ+7
             LDA   GFXORIGY+1
             ADC   VDUQ+8
             STA   VDUQ+8
             RTS

* Add coordinates to GFXPOSNX, GFXPOSNY
RELCOORD     CLC
             LDA   GFXPOSNX+0
             ADC   VDUQ+5
             STA   VDUQ+5
             LDA   GFXPOSNX+1
             ADC   VDUQ+6
             STA   VDUQ+6
             CLC
             LDA   GFXPOSNY+0
             ADC   VDUQ+7
             STA   VDUQ+7
             LDA   GFXPOSNY+1
             ADC   VDUQ+8
             STA   VDUQ+8
             RTS

* Program video system and define characters
********************************************
VDU23         RTS


* Read from VDU system
**********************
* OSWORD &09 - Read POINT
WORD09        RTS

* OSWORD &0A - Read character bitmap
WORD0A        RTS

* OSWORD &0B - Read palette
WORD0B        RTS

* OSWORD &0C - Write palette
WORD0C        RTS

* OSWORD &0D - Read gfx coords
WORD0D        RTS

* OSBYTE &A0 - Read VDU variable
BYTEA0        CPX   #$40                   ; Index into VDU variables
              BCC   BYTEA02
              TXA
              SBC   #$20
              TAX
BYTEA02       LDY   VDUVARS+1,X
              LDA   VDUVARS+0,X
              TAX
              RTS


* PRINTER DRIVER
****************
* VDU 1 - Send one character to printer
VDU01         RTS

















