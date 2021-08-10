* VDU.S
****************************************************
* Apple //e VDU Driver for 40/80 column mode (PAGE2)
****************************************************

**********************************
* VDU DRIVER WORKSPACE LOCATIONS *
**********************************
* $00D0-$00DF VDU driver zero page workspace

VDUSTATUS   EQU   $D0           ; $D0  VDU status
VDUZP1      EQU   VDUSTATUS+1   ; $D1
VDUCOL      EQU   VDUSTATUS+2   ; $D2  text column
VDUROW      EQU   VDUSTATUS+3   ; $D3  text row
VDUADDR     EQU   VDUSTATUS+4   ; $D4  address of current char cell

FXVDUQLEN   EQU   $D1           ; TEMP HACK
VDUCHAR     EQU   $D6           ; TEMP HACK
VDUQ        EQU   $D7           ; TEMP HACK


* Clear to EOL
CLREOL      LDA   ROW
            ASL
            TAX
            LDA   SCNTAB,X      ; LSB of row
            STA   ZP1
            LDA   SCNTAB+1,X    ; MSB of row
            STA   ZP1+1
            LDA   COL
            PHA
            STZ   COL
:L1         LDA   COL
            LSR
            TAY
            BCC   :S1
            >>>   WRTMAIN
:S1         LDA   #" "
            STA   (ZP1),Y
            >>>   WRTAUX
            LDA   COL
            CMP   #79
            BEQ   :S2
            INC   COL
            BRA   :L1
:S2         PLA
            STA   COL
            RTS

* Clear the screen
CLEAR       STZ   ROW
            STZ   COL
:L1         JSR   CLREOL
:S2         LDA   ROW
            CMP   #23
            BEQ   :S3
            INC   ROW
            BRA   :L1
:S3         STZ   ROW
            STZ   COL
            RTS

* Print char in A at ROW,COL
PRCHRC      PHA
            LDA   $C000         ; Kbd data/strobe
            BMI   :KEYHIT
:RESUME     LDA   ROW
            ASL
            TAX
            LDA   SCNTAB,X      ; LSB of row address
            STA   ZP1
            LDA   SCNTAB+1,X    ; MSB of row address
            STA   ZP1+1
            LDA   COL
            BIT   $C01F
            BPL   :S1A          ; 40-col
            LSR
            BCC   :S1
:S1A        >>>   WRTMAIN
:S1         TAY
            PLA
            EOR   #$80
            STA   (ZP1),Y       ; Screen address
            >>>   WRTAUX
            RTS
:KEYHIT     STA   $C010         ; Clear strobe
            AND   #$7F
            CMP   #$13          ; Ctrl-S
            BEQ   :PAUSE
            CMP   #$1B          ; Esc
            BNE   :RESUME
:ESC        SEC
            ROR   ESCFLAG       ; Set ESCFLAG
            BRA   :RESUME
:PAUSE      STA   $C010         ; Clear strobe
:L1         LDA   $C000         ; Kbd data/strobe
            BPL   :L1
            AND   #$7F
            CMP   #$11          ; Ctrl-Q
            BEQ   :RESUME
            CMP   #$1B          ; Esc
            BEQ   :ESC
            BRA   :PAUSE

* Return char at ROW,COL in A and X, MODE in Y
BYTE87
GETCHRC     LDA   ROW
            ASL
            TAX
            LDA   SCNTAB,X
            STA   ZP1
            LDA   SCNTAB+1,X
            STA   ZP1+1
            LDA   COL
            BIT   $C01F
            BPL   :S1A          ; 40-col
            LSR
            BCC   :S1
:S1A        STA   $C002         ; Read main memory
:S1         TAY
            LDA   (ZP1),Y
            EOR   #$80
            STA   $C003         ; Read aux mem again
            TAX
            LDY   #$00
            BIT   $C01F
            BMI   :GETCHOK
            INY
:GETCHOK    RTS

BYTE86      LDY   ROW           ; $86 = read cursor pos
            LDX   COL
            RTS

* Perform backspace & delete operation
DELETE      JSR   BACKSPC
*            LDA   COL
*            BEQ   :S1
*            DEC   COL
*            BRA   :S2
*:S1         LDA   ROW
*            BEQ   :S3
*            DEC   ROW
*            LDA   #79
*            STA   COL
:S2         LDA   #' '
            JSR   PRCHRC
:S3         RTS

* Perform backspace/cursor left operation
BACKSPC     LDA   COL
            BEQ   :S1
            DEC   COL
            BRA   :S3
:S1         LDA   ROW
            BEQ   :S3
            DEC   ROW
            LDA   #39
            BIT   $C01F
            BPL   :S2
            LDA   #79
:S2         STA   COL
:S3         RTS

** Perform cursor right operation
*CURSRT      LDA   COL
*            CMP   #78
*            BCS   :S1
*            INC   COL
*            RTS
*:S1         LDA   ROW
*            CMP   #22
*            BCS   :S2
*            INC   ROW
*            STZ   COL
*:S2         RTS

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
            LDA   ROW
            CMP   #23
            BEQ   SCROLL
            INC   ROW
:IDONE      RTS
; BRA   :DONE
:T5         CMP   #$0B          ; Cursor up
            BNE   :T6
            LDA   ROW
            BEQ   :IDONE
            DEC   ROW
            BRA   :IDONE
:T6         CMP   #$0D          ; Carriage return
            BNE   :T7
*           JSR   CLREOL
            STZ   COL
            BRA   :IDONE
:T7         CMP   #$0C          ; Ctrl-L
            BEQ   :T7A
            CMP   #$16
            BNE   :T8
            LDA   VDUQ+8
            EOR   #$07
            AND   #$01
            TAX
            STA   $C00C,X
:T7A        JSR   CLEAR
            BRA   :IDONE
:T8         CMP   #$1E          ; Home
            BNE   :T9
            STZ   ROW
            STZ   COL
            BRA   :IDONE
:T9         CMP   #$7F          ; Delete
            BNE   :T10
            JSR   DELETE
            BRA   :IDONE
:T10        CMP   #$20
            BCC   :IDONE
            JSR   PRCHRC

* Perform cursor right operation
VDU09       LDA   COL
            CMP   #39
            BCC   :S2
            BIT   $C01F
            BPL   :T11
            CMP   #79
            BCC   :S2
:T11        STZ   COL
            LDA   ROW
            CMP   #23
            BEQ   SCROLL
            INC   ROW
:DONE       RTS
;           BRA   :DONE
:S2         INC   COL
            BRA   :DONE
SCROLL      JSR   SCROLLER
*            STZ   COL
            JSR   CLREOL
;:DONE
            RTS

* Scroll whole screen one line
SCROLLER    LDA   #$00
:L1         PHA
            JSR   SCR1LINE
            PLA
            INC
            CMP   #23
            BNE   :L1
            RTS

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



