* KERNEL/OSWOSB.S
*****************
* OSBYTE and OSWORD dispatch
*
* 15-Aug-2021 Added 'set variable' OSBYTEs 1-6


            XC             ; 65c02

*************************
* OSBYTE DISPATCH TABLE *
*************************

* * Non-zero default OSBYTE variables
* DEFBYTELOW  EQU  219              ; First default OSBYTE value
* DEFBYTE     DB   $09,$1B          ; Default key codes
*             DB   $01,$D0,$E0,$F0  ; Default key expansion
*             DB   $01,$80,$90,$00  ; Default key expansion
* DEFBYTEEND
* ^ moved to CHARIO.S

BYTEVARBASE EQU   $190            ; Base of OSBYTE variables

BYTWRDADDR  DW    BYTE00   ; OSBYTE   0 - Machine host
            DW    BYTE01   ; OSBYTE   1 - User flag
            DW    BYTE02   ; OSBYTE   2 - OSRDCH source
            DW    BYTE03   ; OSBYTE   3 - OSWRCH dest
            DW    BYTE04   ; OSBYTE   4 - Cursor keys
            DW    BYTE05   ; OSBYTE   5 - Printer destination
            DW    BYTE06   ; OSBYTE   6 - Printer ignore
BYTWRDLOW
BYTESZLO    EQU   BYTWRDLOW-BYTWRDADDR
BYTELOW     EQU   BYTESZLO/2-1          ; Maximum low OSBYTE
BYTEHIGH    EQU   $7C                   ; First high OSBYTE
            DW    BYTE7C   ; OSBYTE 124 - Clear Escape
            DW    BYTE7D   ; OSBYTE 125 - Set Escape
            DW    BYTE7E   ; OSBYTE 126 - Ack. Escape
            DW    BYTE7F   ; OSBYTE 127 - Read EOF
            DW    BYTE80   ; OSBYTE 128 - ADVAL           - MISC.s
            DW    BYTE81   ; OSBYTE 129 - INKEY           - CHARIO.s
            DW    BYTE82   ; OSBYTE 130 - Memory high word
            DW    BYTE83   ; OSBYTE 131 - MEMBOT
            DW    BYTE84   ; OSBYTE 132 - MEMTOP
            DW    BYTE85   ; OSBYTE 133 - MEMTOP for MODE
            DW    BYTE86   ; OSBYTE 134 - POS, VPOS       - VDU.s
            DW    BYTE87   ; OSBYTE 135 - Character, MODE - VDU.s
            DW    BYTE88   ; OSBYTE 136 - *CODE
            DW    BYTE89   ; OSBYTE 137 - *MOTOR
            DW    BYTE8A   ; OSBYTE 138 - Buffer insert
            DW    BYTE8B   ; OSBYTE 139 - *OPT
            DW    BYTE8C   ; OSBYTE 140 - *TAPE
            DW    BYTE8D   ; OSBYTE 141 - *ROM
            DW    BYTE8E   ; OSBYTE 142 - Enter language  - INIT.s
            DW    BYTE8F   ; OSBYTE 143 - Service call    - INIT.s
BYTWRDTOP
            DW    BYTEVAR  ; OSBYTE 166+ - Read/Write OSBYTE variable
* Maximum high OSBYTE
BYTESZHI    EQU   BYTWRDTOP-BYTWRDLOW
BYTEMAX     EQU   BYTESZHI/2+BYTEHIGH-1

*************************
* OSWORD DISPATCH TABLE *
*************************
OSWBASE     DW    WORD00   ; OSWORD  0 - Read input line
            DW    WORD01   ; OSWORD  1 - Read elapsed time
            DW    WORD02   ; OSWORD  2 - Write eleapsed time
            DW    WORD03   ; OSWORD  3 - Read interval timer
            DW    WORD04   ; OSWORD  4 - Write interval timer
            DW    WORD05   ; OSWORD  5 - Read I/O memory
            DW    WORD06   ; OSWORD  6 - Write I/O memory
*          DW    WORD07   ; OSWORD  7 - SOUND
*          DW    WORD08   ; OSWORD  8 - ENVELOPE
*          DW    WORD09   ; OSWORD  9 - POINT
*          DW    WORD0A   ; OSWORD 10 - Read character bitmap
*          DW    WORD0B   ; OSWORD 11 - Read palette
*          DW    WORD0C   ; OSWORD 12 - Write palette
*          DW    WORD0D   ; OSWORD 13 - Read coordinates
OSWEND
            DW    WORDE0   ; OSWORD &E0+ - User OSWORD

* Offset to start of OSWORD table
WORDSZOFF   EQU   OSWBASE-BYTWRDADDR
WORDOFF     EQU   WORDSZOFF/2
* Maximum OSWORD
WORDSZ      EQU   OSWEND-OSWBASE
WORDMAX     EQU   WORDSZ/2-1


************************
* OSWORD/OSBYTE dispatch
************************
* OSWORD:
* On entry, A=action
*           XY=>control block
* On exit,  A=preserved
*           X,Y,Cy trashed (except OSWORD 0)
*           control block updated
*
WORDHND     PHA
            PHP
            SEI
            STA   OSAREG          ; Store registers
            STX   OSCTRL+0        ; Point to control block
            STY   OSCTRL+1
            LDX   #$08            ; X=SERVWORD
            CMP   #$E0            ; User OSWORD
            BCS   WORDGO1
            CMP   #WORDMAX+1
            BCS   BYTWRDFAIL      ; Pass on to service call
            ADC   #WORDOFF
            BCC   BYTWRDCALL      ; Call OSWORD routine
WORDGO1     LDA   #WORDOFF+WORDMAX+1
            BCS   BYTWRDCALL      ; Call User OSWORD routine

* OSBYTE:
* On entry, A=action
*           X=first parameter
*           Y=second parameter if A>$7F
* On exit,  A=preserved
*           X=first returned result
*           Y=second returned result if A>$7F
*           Cy=any returned status if A>$7F
*
BYTEHND
* TEST code for VIEW
 CMP #$A0
 BNE BYTEHND0
 LDY #79 ; Read VDU variable $09,$0A
 LDX #23
 RTS
* TEST
BYTEHND0
            PHA
            PHP
            SEI
            STA   OSAREG          ; Store registers
            STX   OSXREG
            STY   OSYREG
            LDX   #$07            ; X=SERVBYTE
            CMP   #$A6
            BCS   BYTEGO1         ; OSBYTE &A6+
            CMP   #BYTEMAX+1
            BCS   BYTWRDFAIL      ; Pass on to service call
            CMP   #BYTEHIGH
            BCS   BYTEGO2         ; High OSBYTEs
            CMP   #BYTELOW+1
            BCS   BYTWRDFAIL      ; Pass on to service call
            STZ   OSYREG          ; Prepare Y=0 for low OSBYTEs
            BCC   BYTEGO3

BYTEGO1     LDA   #BYTEMAX+1          ; Index for BYTEVAR
BYTEGO2     SBC   #BYTEHIGH-BYTELOW-1 ; Reduce OSBYTE number
BYTEGO3     ORA   #$80                ; Will become CS=OSBYTE call

BYTWRDCALL  ASL   A               ; Index into dispatch table
            TAY                   ; Y=offset into dispatch table
*          BIT   FXNETCLAIM      ; Check Econet intercept flag
*          BPL   BYTWRDNONET     ; No intercept, skip past
*          TXA                   ; Set A=BYTE or WORD call
*          CLV                   ; Clear V
*          JSR   CALLNET         ; Call Econet with X=call type
*          BVS   BYTWRDEXIT      ; V now set, claimed by NETV

BYTWRDNONET LDA   BYTWRDADDR+1,Y  ; Get routine address
            STA   OSINTWS+1
            LDA   BYTWRDADDR+0,Y
            STA   OSINTWS+0
            LDA   OSAREG          ; Get A parameter back
            LDY   OSYREG          ; Get Y parameter back
            LDX   OSXREG          ; Get X parameter, set EQ from it
            BCS   BYTWRDGO        ; Skip if OSBYTE call
            LDY   #$00            ; OSWORD call, enter with Y=0
            LDA   (OSCTRL),Y      ; and A=first byte in control block
            SEC                   ; Enter routine with CS
BYTWRDGO    JSR   JMPADDR         ; Call the routine
* Routines are entered with:
*  A=OSBYTE call or first byte of OSWORD control block
*  X=X parameter
*  Y=OSBYTE Y parameter for A>$7F
*  Y=$00 for OSBYTE A<$80
*  Y=$00 for OSWORD so (OSCTRL),Y => first byte
*  Carry Set
*  EQ set from OSBYTE X or from OSWORD first byte
* X,Y,Cy from routine returned to caller

BYTWRDEXIT  ROR   A               ; Move Carry to A
            PLP                   ; Restore original flags
            ROL   A               ; Move Carry back to flags
            PLA                   ; Restore A
            CLV                   ; Clear V = Actioned
            RTS

BYTWRDFAIL
*          JSR   SERVICE         ; Offer to sideways ROMs
*          LDX   OSXREG          ; Get returned X
*          CMP   #$00
*          BEQ   BYTWRDEXIT      ; Claimed, return
            JSR   UNSUPBYTWRD     ; *DEBUG*
            LDX   #$FF            ; X=&FF if unclaimed
            PLP                   ; Restore IRQs
            PLA                   ; Restore A
            BIT   SETV            ; Set V = Not actioned
            RTS

SETV                              ; JMP() is $6C, bit 6 set to set V
* JMPADDR     JMP   (OSINTWS)
* Merlin doesn't like the above
JMPADDR     JMP   ($00FA)

* OSWORD &00 - Read a line of input
***********************************
* On entry, (OSCTRL)=>control block
*           Y=0, A=(OSCTRL)
* On exit,  Y=length of line, offset to <cr>
*           CC = Ok, CS = Escape
*

WORD00      IF MAXLEN-OSTEXT-2
            LDY   #$04
:WORD00LP1  LDA   (OSCTRL),Y      ; Copy MAXLEN, MINCH, MAXCH to workspace
            STA   MAXLEN-2,Y
            DEY
            CPY   #$02
            BCS   :WORD00LP1
:WORD00LP2  LDA   (OSCTRL),Y      ; (OSTEXT)=>line buffer
            STA   OSTEXT,Y
            DEY
            BPL   :WORD00LP2
            INY                   ; Initial line length = zero
            ELSE
            LDA   (OSCTRL),Y      ; Copy control block 
            STA   OSTEXT,Y        ; 0,1 => text
            INY                   ;  2  = MAXLEN 
            CPY   #$05            ;  3  = MINCHAR
            BCC   WORD00          ;  4  = MAXCHAR
            LDY   #$00            ; Initial line length = zero
            FIN
*          STY   FXLINES         ; Reset line counter
            CLI
            BEQ   :WORD00LP       ; Enter main loop

:WORD00BELL LDA   #$07            ; $07=BELL
            DEY                   ; Balance next INY
:WORD00NEXT INY                   ; Step to next character
:WORD00ECHO JSR   OSWRCH          ; Print character

:WORD00LP   JSR   OSRDCH
            BCS   :WORD00ESC      ; Escape
*          TAX                   ; Save character in X
*          LDA   FXVAR03         ; Get FX3 destination
*          ROR   A
*          ROR   A               ; Move bit 1 into Carry
*          TXA                   ; Get character back
*          BCS   :WORD00TEST     ; VDU disabled, ignore
*          LDX   FXVDUQLEN       ; Get length of VDU queue
*          BNE   :WORD00ECHO     ; Not zero, just print
:WORD00TEST CMP   #$7F            ; Delete
            BEQ   :WORD00DEL
            CMP   #$08            ; If KBD has no DELETE key
            BNE   :WORD00CHAR
            LDA   #$7F
:WORD00DEL  CPY   #$00
            BEQ   :WORD00LP       ; Nothing to delete
            DEY                   ; Back up one character
            BCS   :WORD00ECHO     ; Loop back to print DEL
:WORD00CHAR CMP   #$15            ; Ctrl-U
            BNE   :WORD00INS      ; No, insert character
            LDA   #$7F            ; Delete character
            INY                   ; Balance first DEY
:WORD00ALL  DEY                   ; Back up one character
            BEQ   :WORD00LP       ; Beginning of line
            JSR   OSWRCH          ; Print DELETE
            JMP   :WORD00ALL      ; Loop to delete all
:WORD00INS  STA   (OSTEXT),Y      ; Store the character
            CMP   #$0D
            BEQ   :WORD00CR       ; CR - Done
            CPY   MAXLEN
            BCS   :WORD00BELL     ; Too long, beep
            CMP   MINCHAR
            BCC   :WORD00ECHO     ; <MINCHAR, don't step to next
            CMP   MAXCHAR
            BCC   :WORD00NEXT     ; <MAXCHAR, step to next
            BEQ   :WORD00NEXT     ; =MAXCHAR, step to next
            BCS   :WORD00ECHO     ; >MAXCHAR, don't step to next

:WORD00CR   JSR   OSNEWL
*          JSR   CALLNET         ; Call Econet Vector, A=13
:WORD00ESC  LDA   ESCFLAG         ; Get Escape flag
            ROL   A               ; Carry=Escape state
            RTS

* OSWORD &01 - Read elapsed time
* OSWORD &02 - Write elapsed time
* OSWORD &03 - Read countdown timer
* OSWORD &04 - Write countdown timer
************************************
* On entry, (OSCTRL)=>control block
*           Y=0

WORD01      TYA              ; Dummy, just return zero
:WORD01LP   STA   (OSCTRL),Y
            INY
            CPY   #$05
            BCC   :WORD01LP
WORD04
WORD03
WORD02      RTS              ; Dummy, do nothing

* OSWORD &05 - Read I/O memory
* OSWORD &06 - Write I/O memory
***********************************
* On entry, (OSCTRL)+0 address
*           (OSCTRL)+4 byte read or written
*           Y=0, A=(OSCTRL)

WORD05      JSR   GETADDR    ; Point to address, set X and Y
* TO DO: test (OSCTRL)+2/3 to select memory
            LDA   (OSINTWS)  ; Get byte
            STA   (OSCTRL),Y ; Store it
            RTS
WORD06      JSR   GETADDR    ; Point to address, set X and Y
            LDA   (OSCTRL),Y ; Get byte
* TO DO: test (OSCTRL)+2/3 to select memory
            STA   (OSINTWS)  ; Store it
            RTS
GETADDR     STA   OSINTWS+0  ; (OSINTWS)=>byte to read/write
            INY
            LDA   (OSCTRL),Y
            STA   OSINTWS+1
            LDY   #$04       ; Point Y to data byte
            RTS

* OSBYTE routines
*****************

BYTE00      LDX   #$0A       ; $00 = identify Host
            RTS

BYTE88      LDA   #$01       ; $88 = *CODE
WORDE0      JMP   (USERV)    ; OSWORD &E0+

* Low OSBYTE converted into Set Variable
BYTE02      LDA   #$F7       ; -> &B1
;
BYTE09                       ; -> &C2
BYTE0A                       ; -> &C3
BYTE0B                       ; -> &C4
BYTE0C      ADC   #$C9       ; -> &C5
;
BYTE01                       ; -> &F1
BYTE05                       ; -> &F5
BYTE06      ADC   #$07       ; -> &F6
;
BYTE03                       ; -> &EC
BYTE04      ADC   #$E8       ; -> &ED
;
* Read/Write OSBYTE variable
BYTEVAR     TAY                   ; offset to variable
            LDA   BYTEVARBASE+0,Y
            TAX                   ; X=old value
            AND   OSYREG
            EOR   OSXREG
            STA   BYTEVARBASE+0,Y ; update variable
            LDA   BYTEVARBASE+1,Y
            TAY                   ; Y=next value
* Unimplemented
BYTE89 ; *MOTOR
BYTE8A ; Buffer insert
BYTE8C ; *TAPE
BYTE8D ; *ROM
            RTS

* Memory layout
BYTE82                       ; $82 = read high order address
*      LDY   #$00
*      LDX   #$00            ; $0000 for language processor
* Should return $0000, but BCPL and Lisp try to move up to $F800
* overwriting Apple II stuff
            LDY   #$FF       ; $FFFF for I/O processor
            LDX   #$FF
            RTS

BYTE83      LDY   #$0E       ; $83 = read bottom of user mem
            LDX   #$00       ; $0E00
            RTS

BYTE85                       ; $85 = top user mem for mode
BYTE84      LDY   #$80       ; $84 = read top of user mem
            LDX   #$00
            RTS

* Move to keyboard stuff
************************
BYTE7E      LDX   #$00       ; $7E = ack detection of ESC
            BIT   ESCFLAG
            BPL   BYTE7DOK   ; No Escape pending
* TO DO: process escape effects
            DEX              ; X=$FF, Escape was pending
BYTE7C      CLC              ; &7C = clear escape condition
BYTE7D      ROR   ESCFLAG    ; $7D = set escape condition
BYTE7DOK    RTS

* Passed on to filing system
BYTE8B      LDA   #$00       ; &00 -> &00 - *OPT
BYTE7F      AND   #$01       ; &7F -> &01 - EOF
            JMP   (FSCV)     ; Hand over to filing system


* TO DO: Move this to AUXMEM.INIT.S
***********************************

* OSBYTE $8E - Enter language ROM
*
BYTE8E      PHP              ; Save CLC=RESET, SEC=Not RESET
            LDA   #$00
            STA   FAULT+0
            LDA   #$80
            STA   FAULT+1
            LDY   #$09
            JSR   PRERRLP    ; Print ROM name with PRERR to set
            STY   FAULT+0    ;  FAULT pointing to version string
            JSR   OSNEWL
            JSR   OSNEWL
            PLP              ; Get entry type back
            LDA   #$01
            JMP   AUXADDR

* OSBYTE $8F - Issue service call
* X=service call, Y=parameter
*
BYTE8F      TXA
SERVICE     LDX   #$0F
            BIT   $8006
            BPL   :SERVSKIP  ; No service entry
            JSR   $8003      ; Call service entry
            TAX
            BEQ   :SERVDONE
:SERVSKIP   LDX   #$FF
:SERVDONE   RTS


* Test/Debug code
UNSUPBYTWRD
            LDA   #<OSBYTEM
            LDY   #>OSBYTEM
            CPX   #7
            BEQ   UNSUPGO
            LDA   #<OSWORDM
            LDY   #>OSWORDM
UNSUPGO     JSR   PRSTR
            LDA   OSAREG
            JSR   OUTHEX
;            LDA   #$2C
;            LDA   OSXREG
;            JSR   OUTHEX
;            LDA   #$2C
;            LDA   OSYREG
;            JSR   OUTHEX
            LDA   #<OSBM2
            LDY   #>OSBM2
            JSR   PRSTR
;            JSR   OSRDCH
            LDA   OSAREG
            RTS

OSBYTEM     ASC   'OSBYTE($'
            DB    $00
OSWORDM     ASC   'OSWORD($'
            DB    $00
OSBM2       ASC   ').'
            DB    $00

