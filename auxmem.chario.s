*********************************************************
* Kernel / Misc
*********************************************************

* KERNEL/CHARIO.S
*****************
* Character read and write
*

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
* All registers preserved except A, Carry
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


BYTE81      JSR   GETKEY      ; $81 = Read key with time lim
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

* KERNEL/KEYBOARD.S
*******************

KBDREAD
KEYPRESS    LDA   $C000
            TAY
            CMP   #$80
            BCC   KEYNONE     ; No key pressed
            AND   #$7F
            STA   $C010       ; Ack. keypress
            BIT   $C061
            BMI   KEYLALT     ; Left Apple pressed
            BIT   $C062
            BMI   KEYRALT     ; Right Apple pressed
            CMP   #$09
            BEQ   KEYTAB
            CMP   #$08
            BCC   KEYOK       ; <$08 not cursor key
            CMP   #$0C
            BCC   KEYCURSR
            CMP   #$15
            BEQ   KEYCUR15
KEYOK       SEC               ; SEC=Ok
KEYNONE     RTS

KEYTAB      LDA   #$C9
; If cursors active, COPY
; else TAB
            SEC
            RTS

KEYRALT                       ; Right Apple key pressed
KEYLALT     CMP   #$40        ; Left Apple key pressed
            BCS   KEYCTRL
            CMP   #$30
            BCC   KEYOK       ; <'0'
            CMP   #$3A
            BCS   KEYOK       ; >'9'
KEYFUNC     AND   #$0F        ; Convert Apple-Num to function key
            ORA   #$80
            BIT   $C062
            BPL   KEYFUNOK    ; Left+Digit       -> $8x
            ORA   #$90        ; Right+Digit      -> $9x
            BIT   $C061
            BPL   KEYFUNOK
            EOR   #$30        ; Left+Right+Digit -> $Ax
KEYFUNOK    SEC
            RTS
KEYCTRL     AND   #$1F        ; Apple-Letter -> Ctrl-Letter
            RTS

KEYCUR15
*         BIT   $C062
*         BPL   KEYCUR16 ; Right Apple not pressed
*         LDA   #$C9     ; Solid+Right -> COPY?
*         SEC
*         RTS
KEYCUR16    LDA   #$09        ; Convert RGT to $09
KEYCURSR    AND   #$03
            ORA   #$CC        ; Cursor keys $CC-$CF
            SEC               ; SEC=Ok
            RTS



