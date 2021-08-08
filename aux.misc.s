*********************************************************
* Kernel / Misc
*********************************************************

* OSWRCH handler
* All registers preserved
WRCHHND     PHA
            PHX
            PHY
* TODO Check any output redirections
* TODO Check any spool output
            JSR   OUTCHAR
* TODO Check any printer output
            PLY
            PLX
            PLA
            RTS

* OSRDCH handler
* All registers preserved except A, carry
* Read a character from the keyboard
RDCHHND     PHX
            PHY
            JSR   GETCHRC
            STA   OLDCHAR
:L1         LDA   CURS+1      ; Skip unless CURS=$8000
            CMP   #$80
            BNE   :S1
            LDA   CURS
            BNE   :S1
            STZ   CURS
            STZ   CURS+1
            LDA   CSTATE
            ROR
            BCS   :S2
            LDA   #'_'
            BRA   :S3
:S2         LDA   OLDCHAR
:S3         JSR   PRCHRC
            INC   CSTATE
:S1         INC   CURS
            BNE   :S4
            INC   CURS+1
:S4         LDA   $C000       ; Keyboard data/strobe
            BPL   :L1
            LDA   OLDCHAR     ; Erase cursor
            JSR   PRCHRC
            LDA   $C000
            AND   #$7F
            STA   $C010       ; Clear strobe
            PLY
            PLX
            CMP   #$1B        ; Escape pressed?
            BNE   :S5
            SEC               ; Return CS
            ROR   ESCFLAG
            SEC
            RTS
:S5         CLC
            RTS
CURS        DW    $0000       ; Counter
CSTATE      DB    $00         ; Cursor on or off
OLDCHAR     DB    $00         ; Char under cursor

* Performs OSBYTE $80 function
* Read ADC channel or get buffer status
OSBYTE80    CPX   #$00        ; X=0 Last ADC channel
            BNE   :S1
            LDX   #$00        ; Fire button
            LDY   #$00        ; ADC never converted
            RTS
:S1         BMI   :S2
            LDX   #$00        ; X +ve, ADC value
            LDY   #$00
            RTS
:S2         CPX   #$FF        ; X $FF = keyboard buf
            BEQ   :INPUT
            CPX   #$FE        ; X $FE = RS423 i/p buf
            BEQ   :INPUT
            LDX   #$FF        ; Spaced remaining in o/p
            RTS
:INPUT      LDX   #$00        ; Nothing in input buf
            RTS

* Performs OSBYTE $81 INKEY$ function
* X,Y has time limit
* On exit, CC, Y=$00, X=key - key pressed
*          CS, Y=$FF        - timeout
*          CS, Y=$1B        - escape
GETKEY      TYA
            BMI   NEGKEY      ; Negative INKEY
:L1         CPX   #$00
            BEQ   :S1
            LDA   $C000       ; Keyb data/strobe
            AND   #$80
            BNE   :GOTKEY
            JSR   DELAY       ; 1/100 sec
            DEX
            BRA   :L1
:S1         CPY   #$00
            BEQ   :S2
            DEY
            LDX   #$FF
            BRA   :L1
:S2         LDA   $C000       ; Keyb data/strobe
            AND   #$80
            BNE   :GOTKEY
            LDY   #$FF        ; No key, time expired
            SEC
            RTS
:GOTKEY     LDA   $C000       ; Fetch char
            AND   #$7F
            STA   $C010       ; Clear strobe
            CMP   #27         ; Escape
            BEQ   :ESC
            TAX
            LDY   #$00
            CLC
            RTS
:ESC        ROR   ESCFLAG
            LDY   #27         ; Escape
            SEC
            RTS
NEGKEY      LDX   #$00        ; Unimplemented
            LDY   #$00
            RTS

***********************************************************
* Helper functions
***********************************************************

* Beep
BEEP        PHA
            PHX
            LDX   #$80
:L1         LDA   $C030
            JSR   DELAY
            INX
            BNE   :L1
            PLX
            PLA
            RTS

* Delay approx 1/100 sec
DELAY       PHX
            PHY
            LDX   #$00
:L1         INX               ; 2
            LDY   #$00        ; 2
:L2         INY               ; 2
            CPY   #$00        ; 2
            BNE   :L2         ; 3 (taken)
            CPX   #$02        ; 2
            BNE   :L1         ; 3 (taken)
            PLY
            PLX
            RTS

* Print string pointed to by X,Y to the screen
OUTSTR      TXA

* Print string pointed to by A,Y to the screen
PRSTR       STA   OSTEXT+0    ;  String in A,Y
            STY   OSTEXT+1
:L1         LDA   (OSTEXT)    ; Ptr to string in OSTEXT
            BEQ   :S1
            JSR   OSASCI
            INC   OSTEXT
            BNE   :L1
            INC   OSTEXT+1
            BRA   :L1
:S1         RTS

* Print XY in hex
OUT2HEX     TYA
            JSR   OUTHEX
            TAX               ; Continue into OUTHEX

* Print hex byte in A
OUTHEX      PHA
            LSR
            LSR
            LSR
            LSR
            AND   #$0F
            JSR   PRNIB
            PLA
            AND   #$0F        ; Continue into PRNIB

* Print hex nibble in A
PRNIB       CMP   #$0A
            BCC   :S1
            CLC               ; >= $0A
            ADC   #'A'-$0A
            JSR   OSWRCH
            RTS
:S1         ADC   #'0'        ; < $0A
            JMP   OSWRCH

