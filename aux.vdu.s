***********************************************************
* Apple //e VDU Driver for 80 column mode (PAGE2)
***********************************************************

* Clear to EOL
CLREOL      LDA   ROW
            ASL
            TAX
            LDA   SCNTAB,X    ; LSB of row
            STA   ZP1
            LDA   SCNTAB+1,X  ; MSB of row
            STA   ZP1+1
            LDA   COL
            PHA
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
            LDA   $C000       ; Kbd data/strobe
            BMI   :KEYHIT
:RESUME     LDA   ROW
            ASL
            TAX
            LDA   SCNTAB,X    ; LSB of row address
            STA   ZP1
            LDA   SCNTAB+1,X  ; MSB of row address
            STA   ZP1+1
            LDA   COL
            LSR
            TAY
            BCC   :S1
            >>>   WRTMAIN
:S1         PLA
            ORA   #$80
            STA   (ZP1),Y     ; Screen address
            >>>   WRTAUX
            RTS
:KEYHIT     STA   $C010       ; Clear strobe
            AND   #$7F
            CMP   #$13        ; Ctrl-S
            BEQ   :PAUSE
            CMP   #$1B        ; Esc
            BNE   :RESUME
:ESC        SEC
            ROR   ESCFLAG     ; Set ESCFLAG
            BRA   :RESUME
:PAUSE      STA   $C010       ; Clear strobe
:L1         LDA   $C000       ; Kbd data/strobe
            BPL   :L1
            AND   #$7F
            CMP   #$11        ; Ctrl-Q
            BEQ   :RESUME
            CMP   #$1B        ; Esc
            BEQ   :ESC
            BRA   :PAUSE

* Return char at ROW,COL in A
GETCHRC     LDA   ROW
            ASL
            TAX
            LDA   SCNTAB,X
            STA   ZP1
            LDA   SCNTAB+1,X
            STA   ZP1+1
            LDA   COL
            LSR
            TAY
            BCC   :S1
            STA   $C002       ; Read main memory
:S1         LDA   (ZP1),Y
            STX   $C003       ; Read aux mem again
            RTS

* Perform backspace & delete operation
BACKSPC     LDA   COL
            BEQ   :S1
            DEC   COL
            BRA   :S2
:S1         LDA   ROW
            BEQ   :S3
            DEC   ROW
            STZ   COL
:S2         LDA   #' '
            JSR   PRCHRC
:S3         RTS

* Perform backspace/cursor left operation
NDBSPC      LDA   COL
            BEQ   :S1
            DEC   COL
            BRA   :S3
:S1         LDA   ROW
            BEQ   :S3
            DEC   ROW
            STZ   COL
:S3         RTS

* Perform cursor right operation
CURSRT      LDA   COL
            CMP   #78
            BCS   :S1
            INC   COL
            RTS
:S1         LDA   ROW
            CMP   #22
            BCS   :S2
            INC   ROW
            STZ   COL
:S2         RTS

* Output character to VDU driver
* All registers trashable
OUTCHAR     CMP   #$00        ; NULL
            BNE   :T1
            BRA   :IDONE
:T1         CMP   #$07        ; BELL
            BNE   :T2
            JSR   BEEP
            BRA   :IDONE
:T2         CMP   #$08        ; Backspace
            BNE   :T3
            JSR   NDBSPC
            BRA   :DONE
:T3         CMP   #$09        ; Cursor right
            BNE   :T4
            JSR   CURSRT
            BRA   :DONE
:T4         CMP   #$0A        ; Linefeed
            BNE   :T5
            LDA   ROW
            CMP   #23
            BEQ   :SCROLL
            INC   ROW
:IDONE      BRA   :DONE
:T5         CMP   #$0B        ; Cursor up
            BNE   :T6
            LDA   ROW
            BEQ   :DONE
            DEC   ROW
            BRA   :DONE
:T6         CMP   #$0D        ; Carriage return
            BNE   :T7
            JSR   CLREOL
            STZ   COL
            BRA   :DONE
:T7         CMP   #$0C        ; Ctrl-L
            BNE   :T8
            JSR   CLEAR
            BRA   :DONE
:T8         CMP   #$1E        ; Home
            BNE   :T9
            STZ   ROW
            STZ   COL
            BRA   :DONE
:T9         CMP   #$7F        ; Delete
            BNE   :T10
            JSR   BACKSPC
            BRA   :DONE
:T10        JSR   PRCHRC
            LDA   COL
            CMP   #79
            BNE   :S2
            STZ   COL
            LDA   ROW
            CMP   #23
            BEQ   :SCROLL
            INC   ROW
            BRA   :DONE
:S2         INC   COL
            BRA   :DONE
:SCROLL     JSR   SCROLL
            STZ   COL
            JSR   CLREOL
:DONE       RTS

* Scroll whole screen one line
SCROLL      LDA   #$00
:L1         PHA
            JSR   SCR1LINE
            PLA
            INC
            CMP   #23
            BNE   :L1
            RTS

* Copy line A+1 to line A
SCR1LINE    ASL               ; Dest addr->ZP1
            TAX
            LDA   SCNTAB,X
            STA   ZP1
            LDA   SCNTAB+1,X
            STA   ZP1+1
            INX               ; Source addr->ZP2
            INX
            LDA   SCNTAB,X
            STA   ZP2
            LDA   SCNTAB+1,X
            STA   ZP2+1
            LDY   #$00
:L1         LDA   (ZP2),Y
            STA   (ZP1),Y
            STA   $C002       ; Read main mem
            >>>   WRTMAIN
            LDA   (ZP2),Y
            STA   (ZP1),Y
            STA   $C003       ; Read aux mem
            >>>   WRTAUX
            INY
            CPY   #40
            BNE   :L1
            RTS

* Addresses of screen rows in PAGE2
SCNTAB      DW    $800,$880,$900,$980,$A00,$A80,$B00,$B80
            DW    $828,$8A8,$928,$9A8,$A28,$AA8,$B28,$BA8
            DW    $850,$8D0,$950,$9D0,$A50,$AD0,$B50,$BD0

