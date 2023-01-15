* AUXMEM.VDU.S
* (c) Bobbi 2021-2022 GPLv3
*
* Apple //e, //c & IIGS VDU Driver for 40/80 column mode (PAGE2)
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
*                     0   1   2   3           6   7  ; MODEs sort-of completed
SCNTXTMAXX    DB     79, 39, 39, 79, 39, 39, 39, 39  ; Max text column
SCNTXTMAXY    DB     23, 23, 23, 23, 23, 23, 23, 23  ; Max text row
SCNBYTES      DB     08, 08, 08, 01, 01, 01, 01, 01  ; Bytes per character
SCNCOLOURS    DB     03, 15, 07, 01, 01, 01, 01, 01  ; Colours-1
SCNPIXELS     DB     04, 02, 07, 00, 00, 00, 00, 00  ; Pixels per byte
SCNTYPE       DB     65, 64,128, 01, 00, 00, 00, 32  ; Screen type
* b7=FastDraw -> HGR mode
* b6=SHR mode on Apple IIgs
* b5=Teletext
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
OUTCHARCP2    JSR   VDU09                  ; Move cursor right

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
              CPX   #$07                   ; 7 pixels per char, HGR
              BEQ   SETEXIT
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
VDU04         LDA   #$DF                   ; Clear VDU 5 mode
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
              JSR   SHOWWTCURSOR           ; Show write cursor
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

              LDA   VDUSTATUS
              AND   #$20                   ; Bit 5 VDU5 mode
              BEQ   :S1
              JMP   PRCHR7                 ; Jump over text mode stuff

:S1           BIT ESCFLAG
              BMI :RESUME
              JSR ESCPOLL
              BCS :RESUME
              BMI :RESUME
              CMP #$13
              BNE :RESUME
:PAUSE0       JSR ESCPOLL
              BMI :RESUME
              BCS :PAUSE0
              CMP #$11
              BNE :PAUSE0
              BRA :RESUME

              LDA   KEYBOARD
              BPL   :RESUME                ; No key pressed
              EOR   #$80
:PAUSE1       JSR   KBDCHKESC              ; Ask KBD to test if Escape
              BIT   ESCFLAG
              BMI   :RESUMEACK             ; Escape, skip pausing
              CMP   #$13
              BNE   :RESUME                ; Not Ctrl-S
              STA   KBDSTRB                ; Ack. keypress
:PAUSE2       LDA   KEYBOARD
              BPL   :PAUSE2                ; Loop until keypress
              EOR   #$80
              CMP   #$11                   ; Ctrl-Q
              BEQ   :RESUMEACK             ; Stop pausing
              JSR   KBDCHKESC              ; Ask KBD to test if Escape
              BIT   ESCFLAG
              BPL   :PAUSE2                ; No Escape, keep pausing
:RESUMEACK    STA   KBDSTRB                ; Ack. keypress
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
              LDA   #$20
              BIT   VDUSCREEN
              BEQ   PRCHR3                 ; Not teletext
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
              BRA   PRCHR7
PRCHR5        BCC   PRCHR6                 ; Aux memory
              >>>   WRTMAIN
              STA   (VDUADDR),Y            ; Store in main
              >>>   WRTAUX
              BRA   PRCHR7
PRCHR6        STA   (VDUADDR),Y            ; Store in aux
PRCHR7        PLA
              BIT   VDUSCREEN
              BPL   :NOTHGR
              JMP   HGRPRCHAR              ; Write character to HGR
:NOTHGR       BVC   :NOTSHR
              JMP   SHRPRCHAR              ; Write character to SHR
:NOTSHR       RTS
 

* Wrapper around PUTCHRC used when showing the read cursor
* On entry: A - character used for cursor
SHOWRDCURSOR  TAX                          ; Preserve character
              BIT   VDUSCREEN
              BVS   :SHR
              TXA
              JMP   PUTCHRC
:SHR          TXA                          ; Recover character
              SEC                          ; CS: Show cursor
              CLV                          ; VC: Read cursor
              JMP   SHRCURSOR


* Wrapper around PUTCHRC used when showing the write cursor
* On entry: A - character used for cursor
SHOWWTCURSOR  TAX                          ; Preserve character
              BIT   VDUSCREEN
              BVS   :SHR
              TXA
              JMP   PUTCHRC
:SHR          TXA                          ; Recover character
              SEC                          ; CS: Show cursor
              BIT   SETV                   ; VS: Write cursor
              JMP   SHRCURSOR


* Wrapper around PUTCHRC used when removing the read cursor
* On entry: A - character which was obscured by cursor
REMRDCURSOR   TAX                          ; Preserve character
              BIT   VDUSCREEN
              BVS   :SHR
              TXA
              JMP   PUTCHRC
:SHR          TXA                          ; Recover character
              CLC                          ; CC: Remove cursor
              CLV                          ; VC: Read cursor
              JMP   SHRCURSOR


* Wrapper around PUTCHRC used when removing the write cursor
* On entry: A - character which was obscured by cursor
REMWTCURSOR   TAX                          ; Preserve character
              BIT   VDUSCREEN
              BVS   :SHR
              TXA
              JMP   PUTCHRC
:SHR          TXA                          ; Recover character
              CLC                          ; CC: Remove cursor
              BIT   SETV                   ; VS: Write cursor
              JMP   SHRCURSOR


* Wrapper around OUTCHARCP used when drawing the read cursor
* On entry: A - character which was obscured by cursor
PUTCOPYCURS   TAX                          ; Preserve character
              BIT   VDUSCREEN
              BVS   :SHR
              TXA
              JMP   OUTCHARCP
:SHR          TXA                          ; Recover character
              CLC                          ; CC: Remove cursor
              CLV                          ; VC: Read cursor
              JSR   SHRCURSOR
              JMP   OUTCHARCP2


* OSBYTE &87 - Read character at cursor
***************************************
* Fetch character from screen at (TEXTX,TEXTY) and return MODE in Y
* Always read from text screen (which we maintain even in graphics mode)
BYTE87
GETCHRC       JSR   CHARADDR               ; Find character address
              BIT   VDUBANK
              BMI   GETCHRGS
              BCC   GETCHR6                ; Aux memory
              STZ   RDMAINRAM              ; Read main memory (IRQs off)
GETCHR6       LDA   (VDUADDR),Y            ; Get character
              STZ   RDCARDRAM              ; Read aux memory
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
              STZ   RDMAINRAM              ; Read main memory (IRQs off)
GETCHR8       LDA   [VDUADDR],Y            ; Get character
              STZ   RDCARDRAM              ; Read aux memory
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
              BIT   RD80VID
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


* Generic return for all SHRVDUxx returns to aux mem
VDUXXRET      >>>   ENTAUX                 ; SHRVDU08 returns here
              RTS

* Move text cursor position
***************************
* Move cursor left
VDU08         LDA   VDUSTATUS
              AND   #$20                   ; Bit 5 -> VDU5 mode
              BEQ   VDU08VDU4              ; VDU5 not in effect
              BIT   VDUSCREEN
              BVC   VDU08DONE              ; VDU5 but not SHR
              >>>   XF2MAIN,SHRVDU08
VDU08VDU4     LDA   VDUTEXTX               ; COL
              CMP   TXTWINLFT
              BEQ   :S1
              DEC   VDUTEXTX               ; COL
              BRA   VDU08DONE
:S1           LDA   VDUTEXTY               ; ROW
              CMP   TXTWINTOP
              BEQ   VDU08DONE
              DEC   VDUTEXTY               ; ROW
              LDA   TXTWINRGT
              STA   VDUTEXTX               ; COL
VDU08DONE     RTS

* Move cursor right
VDU09         LDA   VDUSTATUS
              AND   #$20                   ; Bit 5 VDU 5 mode
              BEQ   VDU09VDU4              ; VDU5 not in effect
              BIT   VDUSCREEN
              BVC   VDU09DONE              ; VDU5 but not SHR
              >>>   XF2MAIN,SHRVDU09
VDU09VDU4     LDA   VDUTEXTX               ; COL
              CMP   TXTWINRGT
              BCC   VDU09RGHT
              LDA   TXTWINLFT
              STA   VDUTEXTX               ; COL
              LDA   VDUTEXTY               ; ROW
              CMP   TXTWINBOT
              BEQ   SCROLL
              INC   VDUTEXTY               ; ROW
VDU09DONE     RTS
VDU09RGHT     INC   VDUTEXTX               ; COL
              BRA   VDU09DONE
SCROLL        JSR   SCROLLER
              LDA   TXTWINLFT
              STA   VDUTEXTX
              JSR   CLREOL
              RTS

* Move cursor down
VDU10         LDA   VDUSTATUS
              AND   #$20                   ; Bit 5 -> VDU5 mode
              BEQ   VDU10VDU4              ; VDU5 not in effect
              BIT   VDUSCREEN
              BVC   VDU10DONE              ; VDU5 but not SHR
              >>>   XF2MAIN,SHRVDU10
VDU10VDU4     LDA   VDUTEXTY               ; ROW
              CMP   TXTWINBOT
              BEQ   VDU10SCRL
              INC   VDUTEXTY               ; ROW
VDU10DONE     RTS
VDU10SCRL     JMP   SCROLL

* Move cursor up
VDU11         LDA   VDUSTATUS
              AND   #$20                   ; Bit 5 -> VDU5 mode
              BEQ   VDU11VDU4              ; VDU5 not in effect
              BIT   VDUSCREEN
              BVC   VDU11DONE              ; VDU5 but not SHR
              >>>   XF2MAIN,SHRVDU11
VDU11VDU4     LDA   VDUTEXTY               ; ROW
              CMP   TXTWINTOP
              BNE   VDU11UP
              LDA   VDUTEXTX               ; COL
              CMP   TXTWINLFT
              BNE   VDU11DONE
              JSR   RSCROLLER
              LDA   TXTWINLFT
              STA   VDUTEXTX
              JSR   CLREOL
              RTS
VDU11UP       DEC   VDUTEXTY               ; ROW
VDU11DONE     RTS

* Move to start of line
VDU13         LDA   VDUSTATUS
              AND   #$20                   ; Bit 5 -> VDU5 mode
              BEQ   VDU13VDU4              ; VDU5 not in effect
              BIT   VDUSCREEN
              BVC   VDU13DONE              ; VDU5 but not SHR
              >>>   XF2MAIN,SHRVDU13
VDU13VDU4     LDA   #$BF
              JSR   CLRSTATUS              ; Turn copy cursor off
              LDA   TXTWINLFT
              STA   VDUTEXTX               ; COL
VDU13DONE     RTS

* Move to (0,0)
VDU30         LDA   TXTWINTOP
              STA   VDUTEXTY               ; ROW
              LDA   TXTWINLFT
              STA   VDUTEXTX               ; COL
              RTS

* Move to (X,Y)
VDU31         LDY   VDUQ+8
              CPY   #24
              BCS   :DONE
              LDX   VDUQ+7
              CPX   #80
              BCS   :DONE
              BIT   RD80VID
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
* MODEs available:
*  MODE 0 - 640x200 SHR graphics, 80x24 bitmap text (GS only)
*  MODE 1 - 320x200 SHR graphics, 40x24 bitmap text (GS only)
*  MODE 2 - 280x192 HGR graphics, 40x24 bitmap text
*  MODE 3 - 80x24 text
*  MODE 4 --> MODE 6
*  MODE 5 --> MODE 6
*  MODE 6 - 40x24 text
*  MODE 7 - 40x24 with $80-$9F converted to spaces
*
* On //e, MODE 0 -> MODE 3
*         MODE 1 -> MODE 6
*
VDU22         JSR   NEGCALL                ; Find machine type
              AND   #$0F
              BEQ   :NOTGS                 ; MCHID=$x0 -> Not AppleGS, bank=0
              LDA   #$E0                   ;  Not $x0  -> AppleGS, point to screen bank
:NOTGS        STA   VDUBANK
              LDA   VDUQ+8
              AND   #$07

              BIT   VDUBANK
              BMI   :INIT                  ; Skip if GS
              CMP   #$00                   ; Mode 0?
              BNE   :S1
              LDA   #$03                   ; --> Mode 3 instead
              BRA   :INIT
:S1           CMP   #$01                   ; Mode 1?
              BNE   :INIT
              LDA   #$06                   ; --> Mode 6 instead
 
:INIT         TAX                          ; Set up MODE
              STX   VDUMODE                ; Screen MODE
              LDA   SCNCOLOURS,X
              STA   VDUCOLOURS             ; Colours-1
              LDA   SCNBYTES,X
              STA   VDUBYTES               ; Bytes per char
              LDA   SCNPIXELS,X
              STA   VDUPIXELS              ; Pixels per byte
              >>>   WRTMAIN
              STA   SHRPIXELS
              >>>   WRTAUX
              LDA   SCNTYPE,X
              STA   VDUSCREEN              ; Screen type
              LDA   #$01
              JSR   CLRSTATUS              ; Clear everything except PrinterEcho
              LDA   #'_'                   ; Set up default cursors
              STA   CURSOR                 ; Normal cursor
              STA   CURSORCP               ; Copy cursor when editing
              LDA   #$A0
              STA   CURSORED               ; Edit cursor when editing
              JSR   VDU20                  ; Default colours
              JSR   VDU26                  ; Default windows
              STA   FULLGR                 ; Clear MIXED mode
              BIT   VDUSCREEN
              BPL   :NOTHGR
              JMP   HGRVDU22               ; b7=1, HGR mode
:NOTHGR       BVC   :NOTSHR
              JMP   SHRVDU22               ; b6=1, SHR mode
:NOTSHR       LDA   VDUSCREEN
              AND   #$01                   ; 40col/80col bit
              TAX
              STA   CLR80VID,X             ; Select 40col/80col
              STA   TEXTON                 ; Enable Text
              STA   PAGE2                  ; PAGE2
              STA   SETALTCHAR             ; Enable alt charset
              LDA   #$80                   ; Most significant bit
              TRB   NEWVIDEO               ; Turn off SHR
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
              BPL   :NOTHGR
              JSR   HGRCLREOL
              BRA   :NOTSHR
:NOTHGR       BVC   :NOTSHR
              JSR   SHRCLREOL
:NOTSHR       LDA   VDUTEXTY               ; ROW
              CMP   TXTWINBOT
              BEQ   :S1
              INC   VDUTEXTY               ; ROW
              BRA   :L1
:S1           LDA   TXTWINTOP
              STA   VDUTEXTY               ; ROW
              LDA   TXTWINLFT
              STA   VDUTEXTX               ; COL
              RTS


* Clear the graphics screen buffer
VDU12SOFT     JMP   VDU16                  ; *TEMP*


* Clear to EOL, respecting text window boundaries
CLREOL        JSR   CHARADDR               ; Set VDUADDR=>start of line
              INC   TXTWINRGT
              BIT   VDUBANK
              BMI   CLREOLGS               ; AppleGS
              BIT   RD80VID
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
              BPL   :NOHGR
              JMP   HGRCLREOL              ; Clear an HGR line
:NOHGR        BVC   :NOSHR
              JMP   SHRCLREOL              ; Clear an SHR line
:NOSHR        RTS
CLREOLGS      BIT   RD80VID
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
              BPL   :NOTHGR
              JSR   HGRSCR1LINE            ; Scroll HGR screen
              BRA   :NOTSHR
:NOTHGR       BVC   :NOTSHR
              JSR   SHRSCR1LINE            ; Scroll SHR screen
:NOTSHR       PLA
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
              BPL   :NOTHGR
              JSR   HGRRSCR1LINE           ; Reverse scroll HGR screen
              BRA   :NOTSHR
:NOTHGR       BVC   :NOTSHR
              JSR   SHRRSCR1LINE           ; Reverse scroll SHR screen
:NOTSHR       PLA
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
              BIT   RD80VID
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
              STZ   RDMAINRAM              ; Read main memory (IRQs off)
              LDA   (VDUADDR),Y
              STA   (VDUADDR2),Y
              STZ   RDCARDRAM              ; Read aux memory
              >>>   WRTAUX
:SKIPMAIN     INX
              CPX   TXTWINRGT
              BMI   :L1
              BRA   SCR1LNDONE
:FORTY        TXA
              TAY
:L2           >>>   WRTMAIN
              STZ   RDMAINRAM              ; Read main memory (IRQs off)
              LDA   (VDUADDR),Y
              STA   (VDUADDR2),Y
              STZ   RDCARDRAM              ; Read aux memory
              >>>   WRTAUX
              INY
              CPY   TXTWINRGT
              BMI   :L2
SCR1LNDONE    DEC   TXTWINRGT
              PLA
              RTS
SCR1LINEGS    LDX   TXTWINLFT
              BIT   RD80VID
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
              STZ   RDMAINRAM              ; Read main memory (IRQs off)
              LDA   [VDUADDR],Y            ; Even cols in bank $E1
              STA   [VDUADDR2],Y
              STZ   RDCARDRAM              ; Read aux memory
              >>>   WRTAUX
              BRA   :SKIPE0
:E0           LDA   #$E0
              STA   VDUBANK
              STA   VDUBANK2
              >>>   WRTMAIN
              STZ   RDMAINRAM              ; Read main memory (IRQs off)
              LDA   [VDUADDR],Y            ; Odd cols in bank $E0
              STA   [VDUADDR2],Y
              STZ   RDCARDRAM              ; Read aux memory
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
              STZ   RDMAINRAM              ; Read main memory (IRQs off)
              LDA   [VDUADDR],Y
              STA   [VDUADDR2],Y
              STZ   RDCARDRAM              ; Read aux memory
              >>>   WRTAUX
              INY
              CPY   TXTWINRGT
              BMI   :L2
              BRA   SCR1LNDONE


* VDU 16 - CLG, clear graphics window
VDU16         BIT   VDUSCREEN
              BPL   :NOTHGR
              JMP   HGRCLEAR
:NOTHGR       BVC   :NOTSHR
              JMP   SHRCLEAR
:NOTSHR       RTS


* Colour control
****************
* VDU 20 - Reset to default colours
VDU20
              BIT   VDUBANK                ; Check if GS
              BPL   :S1                    ; If not, skip SHR call
              JSR   SHRDEFPAL              ; Default palette
              LDA   #$F0
              STA   TBCOLOR                ; Set text palette B&W
              STZ   CLOCKCTL               ; Set border
:S1           LDX   #VDUCOLEND-TXTFGD
              LDA   #$00
VDU20LP       STA   TXTFGD,X               ; Clear all colours
              DEX                          ; and gcol actions
              BPL   VDU20LP
              LDA   #$80                   ; Black background
              JSR   SETTCOL                ; Set txt background
              LDX   #$00                   ; GCOL 'set' mode
              LDA   #$80                   ; Black background
              JSR   HGRSETGCOL             ; Set HGR background
              BIT   VDUBANK
              BPL   :S1                    ; Skip if not GS
              LDX   #$00                   ; GCOL 'set' mode
              LDA   #$80                   ; Black background
              JSR   SHRSETGCOL             ; Set SHR background
:S1           LDA   VDUCOLOURS
              AND   #$07
              PHA
              STA   TXTFGD                 ; Note txt foreground
              JSR   SETTCOL                ; Set txt foreground
              LDX   #$00                   ; GCOL 'set' mode
              PLA
              STA   GFXFGD                 ; Note gfx foreground
              JSR   HGRSETGCOL             ; Set gfx foreground
              BIT   VDUBANK
              BPL   :S2                    ; Skip if not GS
              LDX   #$00                   ; Default GCOL action
              LDA   #$07                   ; White
              JSR   SHRSETGCOL             ; Set SHR foreground
:S2           RTS

* VDU 17 - COLOUR n - select text or border colour
VDU17         LDA   VDUQ+8
              CMP   #$C0
              BCS   VDU17BORDER
              JMP   SETTCOL 
VDU17BORDER   AND   #$0F
              STA   VDUBORDER
              TAX
              LDA   CLRTRANS16,X
              STA   CLOCKCTL
              RTS

* Helper function to set text FG/BG colour in HGR & SHR modes
SETTCOL       JSR   HGRSETTCOL             ; Set txt foreground
              BIT   VDUBANK
              BPL   :NOTGS
              JSR   SHRSETTCOL             ; Set txt background
:NOTGS        RTS


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
              PHA
              AND   VDUCOLOURS
              STA   GFXFGD-2,Y             ; Store GCOL colour
              PLA
              BIT   VDUBANK
              BPL   :S1                    ; Skip if not GS
              JSR   SHRSETGCOL             ; Set SHR background
:S1           TAY
              LDA   CLRTRANS8,Y            ; Trans. to physical
              PHP
              ROL   A
              PLP
              ROR   A                      ; Get bit 7 back
              JMP   HGRSETGCOL

* VDU 19 - Select palette colours
* VDU 19, logcol, physcol, red, green, blue
VDU19         LDA   VDUQ+5                 ; Second parm
              CMP   #16                    ; If 16, then use RBG values
              BEQ   :RGB
              LDA   VDUQ+4                 ; First parm (logcol)
              ASL                          ; Double it
              TAX                          ; Log colour in X
              LDA   VDUQ+5                 ; Second parm (physcol)
              ASL                          ; Double it
              TAY                          ; Phys colour in X
              BIT   VDUBANK                ; Check if GS
              BPL   :S1                    ; If not, skip SHR call
              TXA                          ; Copy log colour to A for call
              >>>   XF2MAIN,SHRPALCHANGE
:S1           RTS
:RGB          LDA   VDUQ+6                 ; 3rd parm (red)
              AND   #$0F
              TAY                          ; Red in Y
              LDA   VDUQ+4                 ; First parm (logcol)
              ASL                          ; Double it
              TAX                          ; Log colour in X
              LDA   VDUQ+7                 ; 4th parm (green)
              AND   #$0F
              ASL
              ASL
              ASL
              ASL
              STA   :TMP
              LDA   VDUQ+8                 ; 5th parm (blue)
              AND   #$0F
              ORA   :TMP                   ; Green+Blue in A
              BIT   VDUBANK                ; Check if GS
              BPL   :S1                    ; If not, just return 
              >>>   WRTMAIN
              STX   SHRVDUQ                ; Stash X for call to main
              >>>   WRTAUX
              >>>   XF2MAIN,SHRPALCUSTOM
:TMP          DB    $00


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
              BIT   VDUBANK                ; Is this a GS?
              BPL   VDU26PT2               ; Nope
              >>>   XF2MAIN,SHRVDU26
VDU26RET      >>>   ENTAUX
VDU26PT2      LDX   #GFXWINRGT-VDUVARS
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
              BCC   VDU28EXIT              ; right<left
              CMP   SCNTXTMAXX,X
              BEQ   VDU28B
              BCS   VDU28EXIT              ; right>width
VDU28B        LDA   VDUQCOORD+1            ; bottom
              CMP   VDUQCOORD+3            ; top
              BCC   VDU28EXIT              ; bottom<top
              CMP   SCNTXTMAXY,X
              BEQ   VDU28C
              BCS   VDU28EXIT              ; top>height
VDU28C        LDY   #TXTWINLFT+3-VDUVARS   ; Copy to txt window params
              BEQ   VDU28EXIT
              JSR   VDUCOPY4
              LDA   TXTWINLFT              ; Cursor to top-left of window
              STA   VDUTEXTX
              LDA   TXTWINTOP
              STA   VDUTEXTY
VDU28EXIT     RTS

* VDU 24,left;bottom;right;top; - define graphics window
VDU24         BIT   VDUBANK                ; Check if this is a GS
              BMI   :GS
              RTS                          ; If not, hasta la vista
:GS           LDX   #$05
              JSR   ADJORIG                ; Adjust x2,y2
              LDX   #$01
              JSR   ADJORIG                ; Adjust x1,y1
              LDX   #$00
              >>>   WRTMAIN
:L1           LDA   VDUQGFXWIND,X          ; Copy to main mem for SHR
              STA   SHRVDUQ,X
              INX
              CPX   #$08
              BNE   :L1
              >>>   WRTAUX
              >>>   XF2MAIN,SHRVDU24
VDU24RET      >>>   ENTAUX
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
* TO DO: Clip to viewport

VDU25         LDA   VDUQ+4
              AND   #$04                   ; Bit 2 set -> absolute
              BNE   :S0
              JSR   RELCOORD               ; Relative->Absolute coords
              BRA   :S1
:S0           LDX   #$05                   ; Coords at VDUQ+5
              JSR   ADJORIG                ; Adjust graphics origin
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
              JSR   GFXPLOTTER
:S2           LDA   KEYBOARD               ; This and PRCHRC need to be
              EOR   #$80                   ; made more generalised
              BMI   VDU25EXIT              ; No key pressed
              JSR   KBDCHKESC              ; Ask KBD to test if Escape
VDU25EXIT     RTS

* Wrapper around call to HGR/SHR plotting routine
GFXPLOTTER   LDX   #3
:L1          LDA   VDUQ+5,X
             PHA
             DEX
             BPL   :L1
             BIT   VDUSCREEN
             BPL   :S1
             JSR   HGRPLOT
             BRA   GFXPLOTTER2
:S1          BVC   GFXPLOTTER2
             JSR   VDUCOPYMAIN             ; Copy VDUQ to main mem
             >>>   XF2MAIN,SHRPLOT
GFXPLOTRET   >>>   ENTAUX
GFXPLOTTER2  LDX   #0
:L1          LDA   VDUQ+5,X
             STA   PIXELPLOTX,X
             PLA
             STA   VDUQ+5,X
             INX
             CPX   #4
             BCC   :L1
             RTS

* Adjust graphics origin
* On entry: X - offset into VDUQ
ADJORIG       CLC
              LDA   GFXORIGX+0
              ADC   VDUQ+0,X
              STA   VDUQ+0,X
              LDA   GFXORIGX+1
              ADC   VDUQ+1,X
              STA   VDUQ+1,X
              CLC
              LDA   GFXORIGY+0
              ADC   VDUQ+2,X
              STA   VDUQ+2,X
              LDA   GFXORIGY+1
              ADC   VDUQ+3,X
              STA   VDUQ+3,X
              RTS

* Add coordinates to GFXPOSNX, GFXPOSNY
RELCOORD      CLC
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
* VDU 23,charnum,row1,row2,row3,row4,row5,row6,row7,row8
VDU23         BIT   VDUSCREEN               ; Check we are in SHR mode
              BVS   :SHR
              RTS
:SHR          JSR   VDUCOPYMAIN             ; Copy VDUQ to main mem
              >>>   XF2MAIN,SHRUSERCHAR

* Copy VDUQ to SHRVDUQ in main memory
VDUCOPYMAIN   LDY   #$00
:L1           LDA   VDUQ,Y                  ; Copy VDUQ to SHRVDUQ
              >>>   WRTMAIN
              STA   SHRVDUQ,Y
              >>>   WRTAUX
              INY
              CPY   #16
              BNE   :L1

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
BYTEA0        CPX   #$40                    ; Index into VDU variables
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

