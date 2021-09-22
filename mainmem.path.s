* MAINMEM.PATH.S
* (c) Bobbi 2021 GPLv3
*
* Code for handling Applecorn paths and converting them to
* ProDOS paths.  Runs in main memory.

* Preprocess path in MOSFILE, handles:
* 1) ':sd' type slot and drive prefix (s,d are digits)
* 2) '.' or '@' for current working directory
* 3) '..' or '^' for parent directory
* Carry set on error, clear otherwise
PREPATH     LDX   MOSFILE      ; Length
            BNE   :S1
            JMP   :EXIT        ; If zero length
:S1         LDA   MOSFILE+1    ; 1st char of pathname
            CMP   #':'
            BNE   :NOTCOLN     ; Not colon
            CPX   #$03         ; Length >= 3?
            BCS   :S2
            JMP   :ERR         ; If not
:S2         LDA   MOSFILE+3    ; Drive
            SEC
            SBC   #'1'
            TAX
            LDA   MOSFILE+2    ; Slot
            SEC
            SBC   #'0'
            JSR   DRV2PFX      ; Slot/drv->pfx in PREFIX
            JSR   DEL1CHAR     ; Delete ':' from MOSFILE
            JSR   DEL1CHAR     ; Delete slot from MOSFILE
            JSR   DEL1CHAR     ; Delete drive from MOSFILE
            LDA   MOSFILE      ; Is there more?
            BEQ   :APPEND      ; Only ':sd'
            CMP   #$02         ; Length >= 2
            BCC   :ERR         ; If not
            LDA   MOSFILE+1    ; 1st char of filename
            CMP   #'/'
            BNE   :ERR
            JSR   DEL1CHAR     ; Delete '/' from MOSFILE
            BRA   :APPEND
:NOTCOLN    JSR   GETPREF      ; Current pfx -> PREFIX
:REENTER    LDA   MOSFILE+1    ; First char of dirname
            CMP   #'@'         ; '@' means current working dir
            BEQ   :CWD
            CMP   #'^'         ; '^' means parent dir
            BEQ   :CARET
            CMP   #'/'         ; Absolute path
            BEQ   :EXIT        ; Nothing to do
            CMP   #'.'         ; ...
            BEQ   :UPDIR1
            BRA   :APPEND
:UPDIR1     LDA   MOSFILE      ; Length
            CMP   #$01
            BEQ   :CWD         ; '.' on its own
            LDA   MOSFILE+2
            CMP   #'.'         ; '..'
            BEQ   :DOTDOT
            CMP   #'/'         ; './'
            BEQ   :CWD
            BRA   :ERR
:DOTDOT     JSR   DEL1CHAR     ; Delete first char of MOSFILE
:CARET      JSR   PARENT       ; Parent dir -> PREFIX
:CWD        JSR   DEL1CHAR     ; Delete first char of MOSFILE
            LDA   MOSFILE      ; Is there more?
            BEQ   :APPEND      ; No more
            CMP   #$02         ; Len at least two?
            BCC   :ERR         ; Too short!
            LDA   MOSFILE+1    ; What is next char?
            CMP   #'/'         ; Is it slash?
            BNE   :ERR         ; Nope!
            JSR   DEL1CHAR     ; Delete '/' from MOSFILE
            BRA   :REENTER     ; Go again!
:APPEND     JSR   APFXMF       ; Append MOSFILE->PREFIX
            JSR   PFXtoMF      ; Copy back to MOSFILE
:EXIT       JSR   DIGCONV      ; Handle initial digits
            CLC
            RTS
:ERR        SEC
            RTS

* Convert path in PREFIX by removing leaf dir to leave
* parent directory. If already at top, return unchanged.
PARENT      LDX   PREFIX       ; Length of string
            BEQ   :EXIT        ; Prefix len zero
            DEX                ; Ignore trailing '/'
:L1         LDA   PREFIX,X
            CMP   #'/'
            BEQ   :FOUND
            DEX
            CPX   #$01
            BNE   :L1
            BRA   :EXIT        ; No slash found
:FOUND      STX   PREFIX       ; Truncate string
:EXIT       RTS

* Convert slot/drive to prefix
* Expect slot number (1..7) in A, drive (0..1) in X
* Puts prefix (or empty string) in PREFIX
DRV2PFX     CLC                ; Cy=0 A=00000sss
            ROR   A            ;    s   000000ss
            ROR   A            ;    s   s000000s
            ROR   A            ;    s   ss000000
            ROR   A            ;    0   sss00000
            CPX   #1           ;    d   sss00000
            ROR   A            ;    0   dsss0000

            STA   ONLNPL+1     ; Device number
            JSR   MLI          ; Call ON_LINE
            DB    ONLNCMD
            DW    ONLNPL       ; Buffer set to DRVBUF2 (was $301)
            LDA   DRVBUF2      ; Slot/Drive/Length
            AND   #$0F         ; Mask to get length
            TAX
            INC                ; Plus '/' at each end
            INC
            STA   PREFIX       ; Store length
            LDA   #'/'
            STA   PREFIX+1
            STA   PREFIX+2,X
:L1         CPX   #$00         ; Copy -> PREFIX
            BEQ   :EXIT
            LDA   DRVBUF2,X
            STA   PREFIX+1,X
            DEX
            BRA   :L1
:EXIT       RTS

* Delete first char of MOSFILE
DEL1CHAR    LDX   MOSFILE      ; Length
            BEQ   :EXIT        ; Nothing to delete
            LDY   #$02         ; Second char
:L1         CPY   MOSFILE
            BEQ   :S2          ; If Y=MOSFILE okay
            BCS   :S1          ; If Y>MOSFILE done
:S2         LDA   MOSFILE,Y
            STA   MOSFILE-1,Y
            INY
            BRA   :L1
:S1         DEC   MOSFILE
:EXIT       RTS

* Append MOSFILE to PREFIX
APFXMF      LDY   PREFIX       ; Length of PREFIX
            LDX   #$00         ; Index into MOSFILE
:L1         CPX   MOSFILE      ; Length of MOSFILE
            BEQ   :DONE
            LDA   MOSFILE+1,X
            STA   PREFIX+1,Y
            INX
            INY
            BRA   :L1
:DONE       STY   PREFIX       ; Update length PREFIX
            RTS

* Scan pathname in MOSFILE converting files/dirs
* starting with digit by adding 'N' before.
DIGCONV     LDY   #$01         ; First char
:L1         CPY   MOSFILE      ; String length
            BEQ   :KEEPON      ; Last char
            BCS   :DONE        ; Y>MOSFILE
:KEEPON     LDA   MOSFILE,Y    ; Load char
            JSR   ISDIGIT      ; Is it a digit?
            BCC   :NOINS       ; No .. skip
            CPY   #$01         ; First char?
            BEQ   :INS         ; First char is digit
            LDA   MOSFILE-1,Y  ; Prev char
            CMP   #'/'         ; Slash
            BEQ   :INS         ; Slash followed by digit
            BRA   :NOINS       ; Otherwise leave it alone
:INS        LDA   #'N'         ; Char to insert
            JSR   INSMF        ; Insert it
            INY
:NOINS      INY                ; Next char
            BRA   :L1
:DONE       RTS

* Is char in A a digit? Set carry if so
ISDIGIT     CMP   #'9'+1
            BCS   :NOTDIG
            CMP   #'0'
            BCC   :NOTDIG
            SEC
            RTS
:NOTDIG     CLC
            RTS

* Insert char in A into MOSFILE at posn Y
* Preserves regs
INSMF       PHA                ; Preserve char
            STY   :INSIDX      ; Stash index for later
            LDY   MOSFILE      ; String length
            INY                ; Start with Y=len+1
:L1         CPY   :INSIDX      ; Back to ins point?
            BEQ   :S1          ; Yes, done moving
            LDA   MOSFILE-1,Y  ; Move one char
            STA   MOSFILE,Y
            DEY
            BRA   :L1
:S1         PLA                ; Char to insert
            STA   MOSFILE,Y    ; Insert it
            INC   MOSFILE      ; One char longer
            RTS
:INSIDX     DB    $00

* Copy Pascal-style string
* Source in A1L/A1H, dest in A4L/A4H
STRCPY      LDY   #$00
            LDA   (A1L),Y      ; Length of source
            STA   (A4L),Y      ; Copy length byte
            TAY
:L1         CPY   #$00
            BEQ   :DONE
            LDA   (A1L),Y
            STA   (A4L),Y
            DEY
            BRA   :L1
:DONE       RTS

* Copy MOSFILE to MFTEMP
MFtoTMP     LDA   #<MOSFILE
            STA   A1L
            LDA   #>MOSFILE
            STA   A1H
            LDA   #<MFTEMP
            STA   A4L
            LDA   #>MFTEMP
            STA   A4H
            JSR   STRCPY
            RTS

* Copy MFTEMP to MOSFILE
TMPtoMF     LDA   #<MFTEMP
            STA   A1L
            LDA   #>MFTEMP
            STA   A1H
            LDA   #<MOSFILE
            STA   A4L
            LDA   #>MOSFILE
            STA   A4H
            JSR   STRCPY
            RTS

* Copy MFTEMP to MOSFILE2
TMPtoMF2    LDA   #<MFTEMP
            STA   A1L
            LDA   #>MFTEMP
            STA   A1H
            LDA   #<MOSFILE2
            STA   A4L
            LDA   #>MOSFILE2
            STA   A4H
            JSR   STRCPY
            RTS

* Copy MOSFILE to MOSFILE2
COPYMF12    LDA   #<MOSFILE
            STA   A1L
            LDA   #>MOSFILE
            STA   A1H
            LDA   #<MOSFILE2
            STA   A4L
            LDA   #>MOSFILE2
            STA   A4H
            JSR   STRCPY
            RTS

* Copy MOSFILE2 to MOSFILE
COPYMF21    LDA   #<MOSFILE2
            STA   A1L
            LDA   #>MOSFILE2
            STA   A1H
            LDA   #<MOSFILE
            STA   A4L
            LDA   #>MOSFILE
            STA   A4H
            JSR   STRCPY
            RTS

* Copy PREFIX to MOSFILE
PFXtoMF     LDA   #<PREFIX
            STA   A1L
            LDA   #>PREFIX
            STA   A1H
            LDA   #<MOSFILE
            STA   A4L
            LDA   #>MOSFILE
            STA   A4H
            JSR   STRCPY
            RTS

MFTEMP      DS    65           ; Temp copy of MOSFILE
PREFIX      DS    65           ; Buffer for ProDOS prefix























