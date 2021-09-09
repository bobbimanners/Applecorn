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


**********************************
* VDU DRIVER WORKSPACE LOCATIONS *
**********************************
* # marks variables that can't be moved
*
* VDU DRIVER ZERO PAGE
**********************
* $00D0-$00DF VDU driver zero page workspace
VDUSTATUS    EQU   $D0              ; $D0 # VDU status
* bit 7 = VDU 21 VDU disabled
* bit 6 = COPY cursor active
* bit 5 = VDU 5 Text at graphics cursor
* bit 4 = (Master shadow display)
* bit 3 = VDU 28 Text window defined
* bit 2 = VDU 14 Paged scrolling active
* bit 1 = Don't scroll (COPY cursor or VDU 5 mode)
* bit 0 = VDU 2 printer echo active
*
VDUCHAR      EQU   VDUSTATUS+1      ; $D1
VDUADDR      EQU   VDUSTATUS+4      ; $D4  address of current char cell

BYTEVARBASE  EQU   $190             ; For Merlin-8/Merlin-16

* VDU DRIVER MAIN WORKSPACE
***************************
FXLINES      EQU   BYTEVARBASE+217  ; Pages scrolling line counter
FXVDUQLEN    EQU   BYTEVARBASE+218  ; Length of pending VDU queue
VDUVARS      EQU   $290

* *TEMP*
FLASHER      EQU   $290             ; flash counter for cursor       -> BYTEVARBASE+193 -> KBD
CURSOR       EQU   $291             ; character used for cursor      -> VDUVAR+??
CURSORED     EQU   $292             ; character used for edit cursor -> VDUVAR+??
CURSORCP     EQU   $293             ; character used for copy cursor -> VDUVAR+??
OLDCHAR      EQU   $294             ; character under cursor         -> KBD?
COPYCHAR     EQU   $295             ; character under copy cursor    -> KBD?

VDUTWINL     EQU   VDUVARS+$08      ; # text window left
VDUTWINB     EQU   VDUVARS+$09      ; # text window bottom \ window
VDUTWINR     EQU   VDUVARS+$0A      ; # text window right  /  size
VDUTWINT     EQU   VDUVARS+$0B      ; # text window top
*
VDUPIXELS    EQU   VDUVARS+$13      ; *TEMP*
VDUBYTES     EQU   VDUVARS+$14      ; *TEMP*  ; bytes per char
VDUMODE      EQU   VDUVARS+$15      ; *TEMP*  ; current MODE
VDUSCREEN    EQU   VDUVARS+$16      ; *TEMP*  ; Screen type, MODE 7?
*
VDUTEXTX     EQU   VDUVARS+$18      ; absolute POS
VDUTEXTY     EQU   VDUVARS+$19      ; absolute VPOS
VDUCOPYX     EQU   VDUVARS+$1A      ; absolute COPY cursor X posn
VDUCOPYY     EQU   VDUVARS+$1B      ; absolute COPY cursor Y posn
* CURSOR
* CURSORED
* CURSORCP
VDUQ         EQU   VDUVARS+$27      ; *TEMP* $27..$2F


* Output character to VDU driver
********************************
* On entry: A=character
* On exit:  All registers trashable
*           CS if printer echo enabled for this character
* 
OUTCHAR      LDX   FXVDUQLEN
             BNE   ADDTOQ           ; Waiting for chars
             CMP   #$7F
             BEQ   CTRLDEL          ; =$7F - control char
             CMP   #$20
             BCC   CTRLCHAR         ; <$20 - control char
             BIT   VDUSTATUS
             BMI   OUTCHEXIT        ; VDU disabled
             JSR   PRCHRC           ; Store char, checking keypress
             JSR   VDU09            ; Move cursor right
OUTCHEXIT    LDA   VDUSTATUS
             LSR   A                ; Return Cy=Printer Echo Enabled
             RTS

CTRLDEL      LDA   #$20             ; $7F becomes $20
CTRLCHAR     CMP   #$01
             BEQ   ADDQ             ; One param
             CMP   #$11
             BCC   CTRLCHARGO       ; Zero params
ADDQ         STA   VDUCHAR          ; Save initial character
             AND   #$0F
             TAX
             LDA   QLEN,X
             STA   FXVDUQLEN        ; Number of params to queue
             BEQ   CTRLCHARGO1      ; Zero, do it now
QDONE        CLC                    ; CLC=Don't echo VDU queue to printer
             RTS
ADDTOQ       STA   VDUQ-256+9,X
             INC   FXVDUQLEN
             BNE   QDONE
CTRLCHARGO1  LDA   VDUCHAR
CTRLCHARGO   ASL   A
             TAY
             CMP   #$10             ; 8*2
             BCC   CTRLCHARGO2      ; ctrl<$08, don't echo to printer
             EOR   #$FF             ; ctrl>$0D, don't echo to printer
             CMP   #$E5             ; (13*2) EOR 255
CTRLCHARGO2  PHP
             JSR   CTRLCHARJMP      ; Call routine
             PLP
             BCS   OUTCHEXIT        ; If echoable, test if printer enabled
             RTS                    ; Return, CC=Don't echo to printer

OUTCHARGO    ASL   A                ; Entry point to move COPY cursor
             TAY                    ;  (TEMP and scroll screen)
CTRLCHARJMP  CPY   #6*2
             BEQ   CTRLCHAR6        ; Always allow VDU 6 through
             BIT   VDUSTATUS
             BMI   VDU00            ; VDU disabled
CTRLCHAR6    LDA   CTRLADDRS+1,Y
             PHA
             LDA   CTRLADDRS+0,Y
             PHA
VDU27
VDU00        RTS                    ; Enters code with CS=(ctrl>=8 && ctrl<=13)

QLEN         DB    -0,-1,-2,-5,-0,-0,-1,-9  ; 32,1 or 17,18,19,20,21,22,23
             DB    -8,-5,-0,-0,-4,-4,-0,-2  ; 24,25,26,27,28,29,30,31
CTRLADDRS    DW    VDU00-1,VDU01-1,VDU02-1,VDU03-1
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
             LDA   #$01             ; Set Printer Echo On
             BNE   SETSTATUS

* VDU 5 - Text at graphics cursor
VDU05        LDX   VDUBYTES
             DEX
             BEQ   SETEXIT          ; 1 byte per char, text only
* Turn cursor off and other stuff
             LDA   #$20             ; Set VDU 5 mode
             BNE   SETSTATUS

* VDU 14 - Select paged scrolling
VDU14        STZ   FXLINES          ; Reset line counter
             LDA   #$04             ; Set Paged Mode
             BNE   SETSTATUS

* VDU 21 - Disable VDU
VDU21        LDA   #$80             ; Set VDU disabled

SETSTATUS    ORA   VDUSTATUS        ; Set bits in VDU STATUS
             STA   VDUSTATUS
SETEXIT      RTS

* VDU 3 - End print job
VDU03
*           JSR   flush printer
             LDA   #$FE             ; Clear Printer Echo
             BNE   CLRSTATUS

* VDU 4 - Text at text cursor
VDU04
* Turn cursor on and other stuff
             LDA   #$DF             ; Clear VDU 5 mode
             BNE   CLRSTATUS

* VDU 15 - Disable paged scrolling
VDU15        LDA   #$FB             ; Clear paged scrolling
             BRA   CLRSTATUS

* VDU 6 - Enable VDU
VDU06        LDA   #$7F             ; Clear VDU disabled

CLRSTATUS    AND   VDUSTATUS
             STA   VDUSTATUS
             RTS



* Move editing cursor
* A=cursor key, CS from caller
COPYMOVE     PHA
             BIT   VDUSTATUS
             BVS   COPYMOVE2        ; Edit cursor already on
             JSR   GETCHRC
             STA   COPYCHAR
             LDA   CURSORED
             JSR   PUTCHRC          ; Edit cursor
             SEC
             JSR   COPYSWAP2        ; Initialise copy cursor
             ROR   FLASHER
             ASL   FLASHER          ; Ensure b0=0
             LDA   #$42
             ORA   VDUSTATUS
             STA   VDUSTATUS        ; Turn cursor editing on
COPYMOVE2    PLA
             AND   #3               ; Convert to 8/9/10/11
             ORA   #8
COPYMOVE3    JMP   OUTCHARGO        ; Move edit cursor

** Turn editing cursor on/off
*COPYCURSOR  BIT   VDUSTATUS
*            BVC   COPYSWAP4  ; Copy cursor not active
*            PHP              ; Save CS=Turn On, CC=Turn Off
*            JSR   COPYSWAP1  ; Swap to edit cursor
*            LDA   COPYCHAR   ; Prepare to turn edit cursor off
*            PLP
*            BCC   COPYCURS2  ; Restore character
*COPYCURS1   JSR   GETCHRC    ; Get character under edit cursor
*            STA   COPYCHAR
*            LDA   #$A0       ; Output edit cursor
*COPYCURS2   JSR   PUTCHRC
**                            ; Drop through to swap back

* Swap between edit and copy cursors
*COPYSWAP    BIT   VDUSTATUS
*            BVC   COPYSWAP4  ; Edit cursor off
COPYSWAP1    CLC                    ; CC=Swap TEXT and COPY
COPYSWAP2    LDX   #1
COPYSWAPLP   LDY   VDUCOPYX,X
             LDA   VDUTEXTX,X
             STA   VDUCOPYX,X
             BCS   COPYSWAP3        ; CS=Copy TEXT to COPY
             TYA
             STA   VDUTEXTX,X
COPYSWAP3    DEX
             BPL   COPYSWAPLP
COPYSWAP4    RTS


* Clear to EOL
CLREOL       LDA   VDUTEXTY         ; ROW
             ASL
             TAX
             LDA   SCNTAB,X         ; LSB of row
             STA   ZP1
             LDA   SCNTAB+1,X       ; MSB of row
             STA   ZP1+1
             LDA   VDUTEXTX         ; COL
             PHA
             STZ   VDUTEXTX         ; COL
:L1
             LDA   VDUTEXTX         ; COL
             LSR
             TAY
             BCC   :S1
             >>>   WRTMAIN
:S1          LDA   #" "
             STA   (ZP1),Y
             >>>   WRTAUX
             LDA   VDUTEXTX         ; COL
             CMP   #79
             BEQ   :S2
             INC   VDUTEXTX         ; COL
             BRA   :L1
:S2          PLA
             STA   VDUTEXTX         ; COL
             RTS

* Clear the screen
*VDUINIT     STA   $C00F
*            LDA   #'_'
*            STA   CURSOR        ; Normal cursor
*            STA   CURSORCP      ; Copy cursor when editing
*            LDA   #$A0
*            STA   CURSORED      ; Edit cursor when editing
CLEAR        STZ   VDUTEXTY         ; ROW
             STZ   VDUTEXTX         ; COL
:L1          JSR   CLREOL
:S2          LDA   VDUTEXTY         ; ROW
             CMP   #23
             BEQ   :S3
             INC   VDUTEXTY         ; ROW
             BRA   :L1
:S3          STZ   VDUTEXTY         ; ROW
             STZ   VDUTEXTX         ; COL
             RTS

* Calculate character address
CHARADDR     LDA   VDUTEXTY
             ASL
             TAX
             LDA   SCNTAB+0,X       ; LSB of row address
             STA   VDUADDR+0
             LDA   SCNTAB+1,X       ; MSB of row address
             STA   VDUADDR+1
             LDA   VDUTEXTX
             BIT   $C01F
             SEC
             BPL   CHARADDR40       ; 40-col
             LSR   A
CHARADDR40   TAY                    ; Y=offset into this row
             RTS
* (VDUADDR),Y=>character address
* CC=auxmem
* CS=mainmem


* Print char in A at ROW,COL
PRCHRC       PHA                    ; Save character
             LDA   $C000
             BPL   :RESUME          ; No key pressed
             EOR   #$80
:PAUSE1      JSR   KBDCHKESC        ; Ask KBD to test if Escape
             BIT   ESCFLAG
             BMI   :RESUMEACK       ; Escape, skip pausing
             CMP   #$13
             BNE   :RESUME          ; Not Ctrl-S
             STA   $C010            ; Ack. keypress
:PAUSE2      LDA   $C000
             BPL   :PAUSE2          ; Loop until keypress
             EOR   #$80
             CMP   #$11             ; Ctrl-Q
             BEQ   :RESUMEACK       ; Stop pausing
             JSR   KBDCHKESC        ; Ask KBD to test if Escape
             BIT   ESCFLAG
             BPL   :PAUSE2          ; No Escape, keep pausing
:RESUMEACK   STA   $C010            ; Ack. keypress
:RESUME      PLA

* Put character to screen
PUTCHRC      EOR   #$80             ; Convert character
             TAY
             AND   #$A0
             BNE   PRCHR4
             TYA
             EOR   #$40
             TAY
PRCHR4       PHY
             JSR   CHARADDR         ; Find character address
             PLA                    ; Get character back
             PHP                    ; Disable IRQs while
             SEI                    ;  toggling memory
             BCC   PRCHR6           ; Aux memory
             STA   $C004            ; Switch to main memory
PRCHR6       STA   (VDUADDR),Y      ; Store it
             STA   $C005            ; Back to aux memory
             PLP                    ; Restore IRQs
             RTS


* Return char at ROW,COL in A and X, MODE in Y
BYTE87
GETCHRC      JSR   CHARADDR         ; Find character address
             PHP                    ; Disable IRQs while
             SEI                    ;  toggling memory
             BCC   GETCHR6          ; Aux memory
             STA   $C002            ; Switch to main memory
GETCHR6      LDA   (VDUADDR),Y      ; Get character
             STA   $C003            ; Back to aux memory
             PLP                    ; Restore IRQs
             TAY                    ; Convert character
             AND   #$A0
             BNE   GETCHR7
             TYA
             EOR   #$40
             TAY
GETCHR7      TYA
             EOR   #$80
             TAX                    ; X=char for OSBYTE
             LDY   #$00
             BIT   $C01F
             BMI   GETCHROK
             INY                    ; Y=MODE
GETCHROK     RTS


BYTE86       LDY   VDUTEXTY         ; ROW           ; $86 = read cursor pos
             LDX   VDUTEXTX         ; COL
             RTS

* Perform backspace & delete operation
VDU127
DELETE       JSR   BACKSPC
:S2          LDA   #' '
             JMP   PUTCHRC
*:S3         RTS

* Perform backspace/cursor left operation
VDU08
BACKSPC
             LDA   VDUTEXTX         ; COL
             BEQ   :S1
             DEC   VDUTEXTX         ; COL
             BRA   :S3
:S1          LDA   VDUTEXTY         ; ROW
             BEQ   :S3
             DEC   VDUTEXTY         ; ROW
             LDA   #39
             BIT   $C01F
             BPL   :S2
             LDA   #79
:S2
             STA   VDUTEXTX         ; COL
:S3          RTS


VDU10
             LDA   VDUTEXTY         ; ROW
             CMP   #23
             BEQ   :TOSCRL          ; JGH
             INC   VDUTEXTY         ; ROW
             RTS
:TOSCRL      JMP   SCROLL           ; JGH

VDU11
             LDA   VDUTEXTY         ; ROW
             BEQ   :DONE
             DEC   VDUTEXTY         ; ROW
:DONE        RTS

VDU13
             LDA   #$BF
             JSR   CLRSTATUS        ; Turn copy cursor off
             STZ   VDUTEXTX         ; COL
             RTS

* Initialise VDU driver
***********************
* On entry, A=MODE to start in
* Assumes workspace has been zero'd by kernel startup
*
VDUINIT      STA   VDUQ+8

* VDU 22 - MODE n
*****************
* At the moment only MODEs available:
*  MODE 3 - 80x24 text
*  MODE 6 - 40x24 text
*  MODE 7 - 40x24 with $80-$9F converted to spaces
*  MODE 0 defaults to MODE 3
*  All others default to MODE 6
*
VDU22        LDA   VDUQ+8
             AND   #$07
             STA   VDUMODE
             LDX   #$01             ; 80-col
             CMP   #$00
             BEQ   VDU22A           ; MODE 0 -> MODE 3, 80x24, text
             CMP   #$03
             BEQ   VDU22A           ; MODE 3 -> MODE 3, 80x24 text
             DEX                    ; All other MODEs default to 40-col
VDU22A       STA   $C00C,X          ; Select 40col/80col
             STA   $C003            ; Alt charset off
             STA   $C055            ; PAGE2
             STA   $C00F
*
* Set up default cursors
             LDA   #'_'
             STA   CURSOR           ; Normal cursor
             STA   CURSORCP         ; Copy cursor when editing
             LDA   #$A0
             STA   CURSORED         ; Edit cursor when editing
* JSR VDU15 ; Turn off paged scrolling
* JSR VDU20 ; Reset colours
* JSR VDU26 ; Reset windows
* ; Drop through into VDU12, clear screen


VDU12
             JMP   CLEAR

VDU30
             STZ   VDUTEXTY         ; ROW
             STZ   VDUTEXTX         ; COL
             RTS

VDU31
             LDY   VDUQ+8
             CPY   #24
             BCS   :DONE
             LDX   VDUQ+7
             CPX   #80
             BCS   :DONE
             BIT   $C01F
             BMI   :T9A
             CPX   #40
             BCS   :DONE
:T9A
             STX   VDUTEXTX         ; COL
             STY   VDUTEXTY         ; ROW
:DONE        RTS

* Perform cursor right operation
VDU09
             LDA   VDUTEXTX         ; COL
             CMP   #39
             BCC   :S2
             BIT   $C01F
             BPL   :T11
             CMP   #79
             BCC   :S2
:T11
             STZ   VDUTEXTX         ; COL
             LDA   VDUTEXTY         ; ROW
             CMP   #23
             BEQ   SCROLL
             INC   VDUTEXTY         ; ROW
:DONE        RTS
:S2          INC   VDUTEXTX         ; COL
             BRA   :DONE
SCROLL       JSR   SCROLLER
             JSR   CLREOL
             RTS

* Scroll whole screen one line
SCROLLER     LDA   #$00
:L1          PHA
             JSR   SCR1LINE
             PLA
             INC
             CMP   #23
             BNE   :L1
             BIT   VDUSTATUS
             BVC   :L2              ; Copy cursor not active
             JSR   COPYSWAP1
             LDA   #11
             JSR   OUTCHARGO
             JSR   COPYSWAP1
:L2          RTS

* Copy line A+1 to line A
SCR1LINE     ASL                    ; Dest addr->ZP1
             TAX
             LDA   SCNTAB,X
             STA   ZP1
             LDA   SCNTAB+1,X
             STA   ZP1+1
             INX                    ; Source addr->ZP2
             INX
             LDA   SCNTAB,X
             STA   ZP2
             LDA   SCNTAB+1,X
             STA   ZP2+1
             LDY   #$00
:L1          LDA   (ZP2),Y
             STA   (ZP1),Y
             STA   $C002            ; Read main mem
             >>>   WRTMAIN
             LDA   (ZP2),Y
             STA   (ZP1),Y
             STA   $C003            ; Read aux mem
             >>>   WRTAUX
             INY
             CPY   #40
             BNE   :L1
             RTS

* Addresses of screen rows in PAGE2
SCNTAB       DW    $800,$880,$900,$980,$A00,$A80,$B00,$B80
             DW    $828,$8A8,$928,$9A8,$A28,$AA8,$B28,$BA8
             DW    $850,$8D0,$950,$9D0,$A50,$AD0,$B50,$BD0


* Unimplemented
* May end up moving graphics bits to seperate source

* VDU 1 - Send one character to printer
VDU01        RTS

* VDU 16 - CLG, clear graphics window
VDU16        RTS

* VDU 17 - COLOUR n - select text or border colour
VDU17        RTS

* VDU 18 - GCOL k,a - select graphics colour and plot action
VDU18        RTS

* VDU 19 - Select palette colours
VDU19        RTS

* VDU 20 - Reset to default colours
VDU20        RTS

* VDU 23 - Program video system and define characters
VDU23        RTS

* VDU 24,left;bottom;right;top; - define graphics window
VDU24        RTS

* VDU 25,k,x;y; - PLOT k,x;y; - PLOT point, line, etc.
VDU25        RTS

* VDU 26 - Reset to default windows
VDU26        RTS

* VDU 28,left,bottom,right,top - define text window
VDU28        RTS

* VDU 29,x;y; - define graphics origin
VDU29        RTS




* OSBYTE &75 - Read VDUSTATUS
*****************************
BYTE75       LDX   VDUSTATUS
             RTS

* TEST code for VIEW
* OSBYTE &A0 - Read VDU variable
********************************
BYTEA0       LDY   #79              ; Read VDU variable $09,$0A
             LDX   #23
             RTS
* TEST

