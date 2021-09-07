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


**********************************
* VDU DRIVER WORKSPACE LOCATIONS *
**********************************
* $00D0-$00DF VDU driver zero page workspace
* $03ED-$03EE XFER transfer address


VDUSTATUS   EQU   $D0           ; $D0  VDU status
VDUZP1      EQU   VDUSTATUS+1   ; $D1
* VDUTEXTX    EQU   VDUSTATUS+2  ; $D2  text column
* VDUTEXTY    EQU   VDUSTATUS+3  ; $D3  text row
VDUADDR     EQU   VDUSTATUS+4   ; $D4  address of current char cell

FXVDUQLEN   EQU   $D1           ; TEMP HACK
VDUCHAR     EQU   $D6           ; TEMP HACK
VDUQ        EQU   $D7           ; TEMP HACK

* VDUVARS
* VDUTEXTX  EQU $2A0+0 ; text X coord
* VDUTEXTY  EQU $2A0+1 ; text Y coord
VDUTEXTX    EQU   $96           ;COL TEMP
VDUTEXTY    EQU   $97           ;ROW TEMP
VDUCOPYX    EQU   $2A0+2        ; copy cursor X coord
VDUCOPYY    EQU   $2A0+3        ; copy cursor Y coord
* VDUCOPYCHR  EQU $2A0+0 ; char underneath cursor when copying

* VDUCURSOR EQU $2A0+4 ; cursor character
VDUMODE     EQU   $2A0+5        ; current MODE
* VDUCHAR   EQU $2A0+6 ; VDU command, 1 byte
* VDUQ      EQU $2A0+7 ; VDU sequence, 9 bytes

* TEMP, move to VDU.S
* FLASHER      EQU   $290  ; flash counter for cursor
* CURSOR       EQU   $291  ; character under cursor
* CURSORED     EQU   $292  ; character used for cursor
* CURSORCP     EQU   $293  ; character used for edit cursor
* OLDCHAR      EQU   $294  ; character used for copy cursor
* COPYCHAR     EQU   $295  ;




* Start restructuring VDU variables
***********************************
VDUVARS     EQU   $290
* VDUTWINL VDUVARS+$08 ; text window left
* VDUTWINB VDUVARS+$09 ; text window bottom \ window
* VDUTWINR VDUVARS+$0A ; text window right  /  size
* VDUTWINT VDUVARS+$0B ; text window top
*
* VDUTEXTX EQU VDUVARS+$18 ; absolute POS
* VDUTEXTY EQU VDUVARS+$19 ; absolute VPOS
* VDUCOPYX EQU VDUVARS+$1A ;
* VDUCOPYY EQU VDUVARS+$1B ;
* VDUMODE
* CURSOR
* CURSORED
* CURSORCP


* Move editing cursor
* A=cursor key, CS from caller
COPYMOVE    PHA
            BIT   VDUSTATUS
            BVS   COPYMOVE2     ; Edit cursor already on
            JSR   GETCHRC
            STA   COPYCHAR
            LDA   CURSORED
            JSR   PUTCHRC       ; Edit cursor
            SEC
            JSR   COPYSWAP2     ; Initialise copy cursor
            ROR   FLASHER
            ASL   FLASHER       ; Ensure b0=0
            LDA   #$42
            ORA   VDUSTATUS
            STA   VDUSTATUS     ; Turn cursor editing on
COPYMOVE2   PLA
            AND   #3            ; Convert to 8/9/10/11
            ORA   #8
COPYMOVE3   JMP   OUTCHARGO     ; Move edit cursor

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
COPYSWAP1   CLC                 ; CC=Swap TEXT and COPY
COPYSWAP2   LDX   #1
COPYSWAPLP  LDY   VDUCOPYX,X
            LDA   VDUTEXTX,X
            STA   VDUCOPYX,X
            BCS   COPYSWAP3     ; CS=Copy TEXT to COPY
            TYA
            STA   VDUTEXTX,X
COPYSWAP3   DEX
            BPL   COPYSWAPLP
COPYSWAP4   RTS


* Clear to EOL
CLREOL      LDA   VDUTEXTY      ; ROW
            ASL
            TAX
            LDA   SCNTAB,X      ; LSB of row
            STA   ZP1
            LDA   SCNTAB+1,X    ; MSB of row
            STA   ZP1+1
            LDA   VDUTEXTX      ; COL
            PHA
            STZ   VDUTEXTX      ; COL
:L1
            LDA   VDUTEXTX      ; COL
            LSR
            TAY
            BCC   :S1
            >>>   WRTMAIN
:S1         LDA   #" "
            STA   (ZP1),Y
            >>>   WRTAUX
            LDA   VDUTEXTX      ; COL
            CMP   #79
            BEQ   :S2
            INC   VDUTEXTX      ; COL
            BRA   :L1
:S2         PLA
            STA   VDUTEXTX      ; COL
            RTS

* Clear the screen
VDUINIT     STA   $C00F
            LDA   #'_'
            STA   CURSOR        ; Normal cursor
            STA   CURSORCP      ; Copy cursor when editing
            LDA   #$A0
            STA   CURSORED      ; Edit cursor when editing
CLEAR       STZ   VDUTEXTY      ; ROW
            STZ   VDUTEXTX      ; COL
:L1         JSR   CLREOL
:S2         LDA   VDUTEXTY      ; ROW
            CMP   #23
            BEQ   :S3
            INC   VDUTEXTY      ; ROW
            BRA   :L1
:S3         STZ   VDUTEXTY      ; ROW
            STZ   VDUTEXTX      ; COL
            RTS

* Calculate character address
CHARADDR    LDA   VDUTEXTY
            ASL
            TAX
            LDA   SCNTAB+0,X    ; LSB of row address
            STA   VDUADDR+0
            LDA   SCNTAB+1,X    ; MSB of row address
            STA   VDUADDR+1
            LDA   VDUTEXTX
            BIT   $C01F
            SEC
            BPL   CHARADDR40    ; 40-col
            LSR   A
CHARADDR40  TAY                 ; Y=offset into this row
            RTS
* (VDUADDR),Y=>character address
* CC=auxmem
* CS=mainmem


* Print char in A at ROW,COL
PRCHRC      PHA                 ; Save character
            LDA   $C000
            BPL   :RESUME       ; No key pressed
            EOR   #$80
:PAUSE1     JSR   KBDCHKESC     ; Ask KBD to test if Escape
            BIT   ESCFLAG
            BMI   :RESUMEACK    ; Escape, skip pausing
            CMP   #$13
            BNE   :RESUME       ; Not Ctrl-S
            STA   $C010         ; Ack. keypress
:PAUSE2     LDA   $C000
            BPL   :PAUSE2       ; Loop until keypress
            EOR   #$80
            CMP   #$11          ; Ctrl-Q
            BEQ   :RESUMEACK    ; Stop pausing
            JSR   KBDCHKESC     ; Ask KBD to test if Escape
            BIT   ESCFLAG
            BPL   :PAUSE2       ; No Escape, keep pausing
:RESUMEACK  STA   $C010         ; Ack. keypress
:RESUME     PLA

* Put character to screen
PUTCHRC     EOR   #$80          ; Convert character
            TAY
            AND   #$A0
            BNE   PRCHR4
            TYA
            EOR   #$40
            TAY
PRCHR4      PHY
            JSR   CHARADDR      ; Find character address
            PLA                 ; Get character back
            PHP                 ; Disable IRQs while
            SEI                 ;  toggling memory
            BCC   PRCHR6        ; Aux memory
            STA   $C004         ; Switch to main memory
PRCHR6      STA   (VDUADDR),Y   ; Store it
            STA   $C005         ; Back to aux memory
            PLP                 ; Restore IRQs
            RTS


* Return char at ROW,COL in A and X, MODE in Y
BYTE87
GETCHRC     JSR   CHARADDR      ; Find character address
            PHP                 ; Disable IRQs while
            SEI                 ;  toggling memory
            BCC   GETCHR6       ; Aux memory
            STA   $C002         ; Switch to main memory
GETCHR6     LDA   (VDUADDR),Y   ; Get character
            STA   $C003         ; Back to aux memory
            PLP                 ; Restore IRQs
            TAY                 ; Convert character
            AND   #$A0
            BNE   GETCHR7
            TYA
            EOR   #$40
            TAY
GETCHR7     TYA
            EOR   #$80
            TAX                 ; X=char for OSBYTE
            LDY   #$00
            BIT   $C01F
            BMI   GETCHROK
            INY                 ; Y=MODE
GETCHROK    RTS


BYTE86      LDY   VDUTEXTY      ; ROW           ; $86 = read cursor pos
            LDX   VDUTEXTX      ; COL
            RTS

* Perform backspace & delete operation
DELETE      JSR   BACKSPC
:S2         LDA   #' '
            JMP   PUTCHRC
*:S3         RTS

* Perform backspace/cursor left operation
BACKSPC
            LDA   VDUTEXTX      ; COL
            BEQ   :S1
            DEC   VDUTEXTX      ; COL
            BRA   :S3
:S1         LDA   VDUTEXTY      ; ROW
            BEQ   :S3
            DEC   VDUTEXTY      ; ROW
            LDA   #39
            BIT   $C01F
            BPL   :S2
            LDA   #79
:S2
            STA   VDUTEXTX      ; COL
:S3         RTS


* Output character to VDU driver
* All registers trashable
OUTCHAR
*
* Quick'n'nasty VDU queue
            LDX   FXVDUQLEN
            BNE   ADDTOQ
            CMP   #$01
            BEQ   ADDQ          ; One param
            CMP   #$11
            BCC   OUTCHARGO     ; Zero param
            CMP   #$20
            BCS   OUTCHARGO     ; Print chars
ADDQ        STA   VDUCHAR       ; Save initial character
            AND   #$0F
            TAX
            LDA   QLEN,X
            STA   FXVDUQLEN
            BEQ   OUTCHARGO1
QDONE       RTS
QLEN        DB    -0,-1,-2,-5,-0,-0,-1,-9
            DB    -8,-5,-0,-0,-4,-4,-0,-2
ADDTOQ      STA   VDUQ-256+9,X
            INC   FXVDUQLEN
            BNE   QDONE
OUTCHARGO1  LDA   VDUCHAR
* end nasty hack
*
OUTCHARGO   CMP   #$00          ; NULL
            BNE   :T1
            BRA   :IDONE
:T1         CMP   #$07          ; BELL
            BNE   :T2
            JSR   BEEP
            BRA   :IDONE
:T2         CMP   #$08          ; Backspace
            BNE   :T3
            JSR   BACKSPC
            BRA   :IDONE
:T3         CMP   #$09          ; Cursor right
            BNE   :T4
*            JSR   CURSRT
            JSR   VDU09
            BRA   :IDONE
:T4         CMP   #$0A          ; Linefeed
            BNE   :T5
            LDA   VDUTEXTY      ; ROW
            CMP   #23
            BEQ   :TOSCROLL     ; JGH
            INC   VDUTEXTY      ; ROW
:IDONE      RTS
* BRA   :DONE
:TOSCROLL   JMP   SCROLL        ; JGH
:T5         CMP   #$0B          ; Cursor up
            BNE   :T6
            LDA   VDUTEXTY      ; ROW
            BEQ   :IDONE
            DEC   VDUTEXTY      ; ROW
*            BRA   :IDONE
            RTS
:T6         CMP   #$0D          ; Carriage return
            BNE   :T7
            LDA   #$BF
            AND   VDUSTATUS
            STA   VDUSTATUS     ; Turn copy cursor off
            STZ   VDUTEXTX      ; COL
*            BRA   :IDONE
            RTS
:T7         CMP   #$0C          ; Ctrl-L
            BEQ   :T7A
            CMP   #$16          ; MODE
            BNE   :T8
            LDA   VDUQ+8
            STA   VDUMODE
            EOR   #$07
            AND   #$01
            TAX
            STA   $C00C,X
:T7A        JSR   CLEAR
*            BRA   :IDONE
            RTS
:T8         CMP   #$1E          ; Home
            BNE   :T9
            STZ   VDUTEXTY      ; ROW
            STZ   VDUTEXTX      ; COL
*            BRA   :IDONE
            RTS
:T9
            CMP   #$1F          ; TAB
            BNE   :T9B
            LDY   VDUQ+8
            CPY   #24
            BCS   :IDONE
            LDX   VDUQ+7
            CPX   #80
            BCS   :IDONE
            BIT   $C01F
            BMI   :T9A
            CPX   #80
            BCS   :IDONE
:T9A
            STX   VDUTEXTX      ; COL
            STY   VDUTEXTY      ; ROW
            RTS
:T9B        CMP   #$7F          ; Delete
            BNE   :T10
            JSR   DELETE
*            BRA   :IDONE
            RTS
:T10        CMP   #$20
            BCC   :IDONE
            CMP   #$80
            BCC   :T10A
            CMP   #$A0
            BCS   :T10A
            LDX   VDUMODE
            CPX   #$07
            BNE   :T10A
            LDA   #$20
:T10A       JSR   PRCHRC        ; Store char, checking keypress

* Perform cursor right operation
VDU09
            LDA   VDUTEXTX      ; COL
            CMP   #39
            BCC   :S2
            BIT   $C01F
            BPL   :T11
            CMP   #79
            BCC   :S2
:T11
            STZ   VDUTEXTX      ; COL
            LDA   VDUTEXTY      ; ROW
            CMP   #23
            BEQ   SCROLL
            INC   VDUTEXTY      ; ROW
:DONE       RTS
*           BRA   :DONE
:S2
            INC   VDUTEXTX      ; COL
            BRA   :DONE
SCROLL      JSR   SCROLLER
*            STZ   VDUTEXTX ; COL
            JSR   CLREOL
*:DONE
            RTS

* Scroll whole screen one line
SCROLLER    LDA   #$00
:L1         PHA
            JSR   SCR1LINE
            PLA
            INC
            CMP   #23
            BNE   :L1
            BIT   VDUSTATUS
            BVC   :L2           ; Copy cursor not active
            JSR   COPYSWAP1
            LDA   #11
            JSR   OUTCHARGO
            JSR   COPYSWAP1
:L2         RTS

* Copy line A+1 to line A
SCR1LINE    ASL                 ; Dest addr->ZP1
            TAX
            LDA   SCNTAB,X
            STA   ZP1
            LDA   SCNTAB+1,X
            STA   ZP1+1
            INX                 ; Source addr->ZP2
            INX
            LDA   SCNTAB,X
            STA   ZP2
            LDA   SCNTAB+1,X
            STA   ZP2+1
            LDY   #$00
:L1         LDA   (ZP2),Y
            STA   (ZP1),Y
            STA   $C002         ; Read main mem
            >>>   WRTMAIN
            LDA   (ZP2),Y
            STA   (ZP1),Y
            STA   $C003         ; Read aux mem
            >>>   WRTAUX
            INY
            CPY   #40
            BNE   :L1
            RTS

* Addresses of screen rows in PAGE2
SCNTAB      DW    $800,$880,$900,$980,$A00,$A80,$B00,$B80
            DW    $828,$8A8,$928,$9A8,$A28,$AA8,$B28,$BA8
            DW    $850,$8D0,$950,$9D0,$A50,$AD0,$B50,$BD0


* TEST code for VIEW
BYTE75      LDX   VDUSTATUS
            RTS
BYTE76      LDX   #$00
            RTS
BYTEA0      LDY   #79           ; Read VDU variable $09,$0A
            LDX   #23
            RTS
* TEST










