* AUXMEM.BYTWRD.S
* (c) Bobbi 2021 GPLv3
*
* Applecorn OSBYTE and OSWORD handlers
*
* 15-Aug-2021 Added 'set variable' OSBYTEs 1-6.
* 02-Sep-2021 OSWORD 5 can read from Main Memory ROM.
* 04-Sep-2021 Extended VDU table to add $75 and $A0 for VDU driver.
* 09-Sep-2021 Moved keyboard and VDU OSBYTEs to Keyboard and VDU.


             XC                           ; 65c02

*************************
* OSBYTE DISPATCH TABLE *
*************************
BYTWRDADDR   DW    BYTE00                 ; OSBYTE   0 - Machine host    - INIT.s
             DW    BYTE01                 ; OSBYTE   1 - User flag
             DW    BYTE02                 ; OSBYTE   2 - OSRDCH source
             DW    BYTE03                 ; OSBYTE   3 - OSWRCH dest
             DW    BYTE04                 ; OSBYTE   4 - Cursor keys
             DW    BYTE05                 ; OSBYTE   5 - Printer destination
             DW    BYTE06                 ; OSBYTE   6 - Printer ignore
             DW    BYTENULL               ; OSBYTE   7 - Serial Rx Speed
             DW    BYTENULL               ; OSBYTE   8 - Serial Tx Speed
             DW    BYTENULL               ; OSBYTE   9 - Flash period space
             DW    BYTENULL               ; OSBYTE  10 - Flash period mark
             DW    BYTENULL               ; OSBYTE  11 - Autorepeat delay
             DW    BYTENULL               ; OSBYTE  12 - Autorepeat repeat
             DW    BYTENULL               ; OSBYTE  13 - Disable event
             DW    BYTENULL               ; OSBYTE  14 - Enable event
             DW    BYTENULL               ; OSBYTE  15 - Flush buffer
BYTWRDLOW
BYTESZLO     EQU   BYTWRDLOW-BYTWRDADDR
BYTELOW      EQU   BYTESZLO/2-1           ; Maximum low OSBYTE
BYTEHIGH     EQU   $75                    ; First high OSBYTE
             DW    BYTE75                 ; OSBYTE 117 - Read VDU status - VDU.s
             DW    BYTE76                 ; OSBYTE 118 - Update kbd LEDs - CHARIO.s
             DW    BYTENULL               ; OSBYTE 119
             DW    BYTENULL               ; OSBYTE 120
             DW    BYTENULL               ; OSBYTE 121
             DW    BYTENULL               ; OSBYTE 122
             DW    BYTENULL               ; OSBYTE 123
             DW    BYTE7C                 ; OSBYTE 124 - Clear Escape    - CHARIO.s
             DW    BYTE7D                 ; OSBYTE 125 - Set Escape      - CHARIO.s
             DW    BYTE7E                 ; OSBYTE 126 - Ack. Escape     - CHARIO.s
             DW    BYTE7F                 ; OSBYTE 127 - Read EOF
             DW    BYTE80                 ; OSBYTE 128 - ADVAL           - MISC.s
             DW    BYTE81                 ; OSBYTE 129 - INKEY           - CHARIO.s
             DW    BYTE82                 ; OSBYTE 130 - Memory high word
             DW    BYTE83                 ; OSBYTE 131 - MEMBOT
             DW    BYTE84                 ; OSBYTE 132 - MEMTOP
             DW    BYTE85                 ; OSBYTE 133 - MEMTOP for MODE
             DW    BYTE86                 ; OSBYTE 134 - POS, VPOS       - VDU.s
             DW    BYTE87                 ; OSBYTE 135 - Character, MODE - VDU.s
             DW    BYTE88                 ; OSBYTE 136 - *CODE
             DW    BYTENULL               ; OSBYTE 137 - *MOTOR
             DW    BYTENULL               ; OSBYTE 138 - Buffer insert
             DW    BYTE8B                 ; OSBYTE 139 - *OPT
             DW    BYTENULL               ; OSBYTE 140 - *TAPE
             DW    BYTENULL               ; OSBYTE 141 - *ROM
             DW    BYTE8E                 ; OSBYTE 142 - Enter language  - INIT.s
             DW    BYTE8F                 ; OSBYTE 143 - Service call    - INIT.s
             DW    BYTENULL               ; OSBYTE 144
             DW    BYTENULL               ; OSBYTE 145
             DW    BYTENULL               ; OSBYTE 146
             DW    BYTENULL               ; OSBYTE 147
             DW    BYTENULL               ; OSBYTE 148
             DW    BYTENULL               ; OSBYTE 149
             DW    BYTENULL               ; OSBYTE 150
             DW    BYTENULL               ; OSBYTE 151
             DW    BYTENULL               ; OSBYTE 152
             DW    BYTENULL               ; OSBYTE 153
             DW    BYTENULL               ; OSBYTE 154
             DW    BYTENULL               ; OSBYTE 155
             DW    BYTENULL               ; OSBYTE 156
             DW    BYTENULL               ; OSBYTE 157
             DW    BYTENULL               ; OSBYTE 158
             DW    BYTENULL               ; OSBYTE 159
             DW    BYTEA0                 ; OSBYTE 160 - Read VDU variable - VDU.s
BYTWRDTOP
             DW    BYTEVAR                ; OSBYTE 166+ - Read/Write OSBYTE variable
* Maximum high OSBYTE
BYTESZHI     EQU   BYTWRDTOP-BYTWRDLOW
BYTEMAX      EQU   BYTESZHI/2+BYTEHIGH-1

*************************
* OSWORD DISPATCH TABLE *
*************************
OSWBASE      DW    WORD00                 ; OSWORD  0 - Read input line
             DW    WORD01                 ; OSWORD  1 - Read elapsed time
             DW    WORD02                 ; OSWORD  2 - Write eleapsed time
             DW    WORD03                 ; OSWORD  3 - Read interval timer
             DW    WORD04                 ; OSWORD  4 - Write interval timer
             DW    WORD05                 ; OSWORD  5 - Read I/O memory
             DW    WORD06                 ; OSWORD  6 - Write I/O memory
*          DW    WORD07   ; OSWORD  7 - SOUND
*          DW    WORD08   ; OSWORD  8 - ENVELOPE
*          DW    WORD09   ; OSWORD  9 - POINT
*          DW    WORD0A   ; OSWORD 10 - Read character bitmap
*          DW    WORD0B   ; OSWORD 11 - Read palette
*          DW    WORD0C   ; OSWORD 12 - Write palette
*          DW    WORD0D   ; OSWORD 13 - Read coordinates
OSWEND
             DW    WORDE0                 ; OSWORD &E0+ - User OSWORD

* Offset to start of OSWORD table
WORDSZOFF    EQU   OSWBASE-BYTWRDADDR
WORDOFF      EQU   WORDSZOFF/2
* Maximum OSWORD
WORDSZ       EQU   OSWEND-OSWBASE
WORDMAX      EQU   WORDSZ/2-1


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
WORDHND      PHA
             PHP
             SEI
             STA   OSAREG                 ; Store registers
             STX   OSCTRL+0               ; Point to control block
             STY   OSCTRL+1
             LDX   #$08                   ; X=SERVWORD
             CMP   #$E0                   ; User OSWORD
             BCS   WORDGO1
             CMP   #WORDMAX+1
             BCS   BYTWRDFAIL             ; Pass on to service call
             ADC   #WORDOFF
             BCC   BYTWRDCALL             ; Call OSWORD routine
WORDGO1      LDA   #WORDOFF+WORDMAX+1
             BCS   BYTWRDCALL             ; Call User OSWORD routine

* OSBYTE:
* On entry, A=action
*           X=first parameter
*           Y=second parameter if A>$7F
* On exit,  A=preserved
*           X=first returned result
*           Y=second returned result if A>$7F
*           Cy=any returned status if A>$7F
*
BYTEHND      PHA
             PHP
             SEI
             STA   OSAREG                 ; Store registers
             STX   OSXREG
             STY   OSYREG
             LDX   #$07                   ; X=SERVBYTE
             CMP   #$A6
             BCS   BYTEGO1                ; OSBYTE &A6+
             CMP   #BYTEMAX+1
             BCS   BYTWRDFAIL             ; Pass on to service call
             CMP   #BYTEHIGH
             BCS   BYTEGO2                ; High OSBYTEs
             CMP   #BYTELOW+1
             BCS   BYTWRDFAIL             ; Pass on to service call
             STZ   OSYREG                 ; Prepare Y=0 for low OSBYTEs
             BCC   BYTEGO3

BYTEGO1      LDA   #BYTEMAX+1             ; Index for BYTEVAR
BYTEGO2      SBC   #BYTEHIGH-BYTELOW-1    ; Reduce OSBYTE number
BYTEGO3      ORA   #$80                   ; Will become CS=OSBYTE call

BYTWRDCALL   ASL   A                      ; Index into dispatch table
             TAY                          ; Y=offset into dispatch table
*          BIT   FXNETCLAIM      ; Check Econet intercept flag
*          BPL   BYTWRDNONET     ; No intercept, skip past
*          TXA                   ; Set A=BYTE or WORD call
*          CLV                   ; Clear V
*          JSR   CALLNET         ; Call Econet with X=call type
*          BVS   BYTWRDEXIT      ; V now set, claimed by NETV

BYTWRDNONET  LDA   BYTWRDADDR+1,Y         ; Get routine address
             STA   OSINTWS+1
             LDA   BYTWRDADDR+0,Y
             STA   OSINTWS+0
             LDA   OSAREG                 ; Get A parameter back
             LDY   OSYREG                 ; Get Y parameter back
             LDX   OSXREG                 ; Get X parameter, set EQ from it
             BCS   BYTWRDGO               ; Skip if OSBYTE call
             LDY   #$00                   ; OSWORD call, enter with Y=0
             LDA   (OSCTRL),Y             ; and A=first byte in control block
             SEC                          ; Enter routine with CS
BYTWRDGO     JSR   JMPADDR                ; Call the routine
* Routines are entered with:
*  A=OSBYTE call or first byte of OSWORD control block
*  X=X parameter
*  Y=OSBYTE Y parameter for A>$7F
*  Y=$00 for OSBYTE A<$80
*  Y=$00 for OSWORD so (OSCTRL),Y => first byte
*  Carry Set
*  EQ set from OSBYTE X or from OSWORD first byte
* X,Y,Cy from routine returned to caller

BYTWRDEXIT   ROR   A                      ; Move Carry to A
             PLP                          ; Restore original flags and IRQs
             ROL   A                      ; Move Carry back to flags
             PLA                          ; Restore A
             CLV                          ; Clear V = Actioned
BYTENULL     RTS

BYTWRDFAIL   PHX                          ; *DEBUG*
             JSR   SERVICEX               ; Offer to sideways ROMs as service X
             LDX   OSXREG                 ; Get returned X, returned Y is in Y
             CMP   #$01
             PLA                          ; *DEBUG*
             BCC   BYTWRDEXIT             ; Claimed, return
             BIT   $E0                    ; *DEBUG*
             BVC   BYTEFAIL1              ; Debug turned off
             JSR   UNSUPBYTWRD            ; *DEBUG*
BYTEFAIL1    LDX   #$FF                   ; X=&FF if unclaimed
             PLP                          ; Restore original flags and IRQs
             PLA                          ; Restore A
             BIT   SETV                   ; Set V = Not actioned
             RTS

SETV                                      ; JMP() is $6C, bit 6 set to set V
* JMPADDR     JMP   (OSINTWS)
* Merlin doesn't like the above
JMPADDR      JMP   ($00FA)

* OSWORD &00 - Read a line of input
***********************************
* On entry, (OSCTRL)=>control block
*           Y=0, A=(OSCTRL)
* On exit,  Y=length of line, offset to <cr>
*           CC = Ok, CS = Escape
*

WORD00       IF    MAXLEN-OSTEXT-2
             LDY   #$04
:WORD00LP1   LDA   (OSCTRL),Y             ; Copy MAXLEN, MINCH, MAXCH to workspace
             STA   MAXLEN-2,Y
             DEY
             CPY   #$02
             BCS   :WORD00LP1
:WORD00LP2   LDA   (OSCTRL),Y             ; (OSTEXT)=>line buffer
             STA   OSTEXT,Y
             DEY
             BPL   :WORD00LP2
             INY                          ; Initial line length = zero
             ELSE
             LDY   #$04                   ; Copy control block
:WORD00LP3   LDA   (OSCTRL),Y             ; 0,1 => text
             STA   OSTEXT,Y               ;  2  = MAXLEN
             DEY                          ;  3  = MINCHAR
             BPL   :WORD00LP3             ;  4  = MAXCHAR
             INY                          ; Initial line length = zero
             FIN
*             STY   FXLINES                ; Reset line counter
             CLI
             BEQ   :WORD00LP              ; Enter main loop

:WORD00BELL  LDA   #$07                   ; $07=BELL
             DEY                          ; Balance next INY
:WORD00NEXT  INY                          ; Step to next character
:WORD00ECHO  JSR   OSWRCH                 ; Print character

:WORD00LP    JSR   OSRDCH
             BCS   :WORD00ESC             ; Escape
*          TAX                   ; Save character in X
*          LDA   FXVAR03         ; Get FX3 destination
*          ROR   A
*          ROR   A               ; Move bit 1 into Carry
*          TXA                   ; Get character back
*          BCS   :WORD00TEST     ; VDU disabled, ignore
             LDX   FXVDUQLEN              ; Get length of VDU queue
             BNE   :WORD00ECHO            ; Not zero, just print
:WORD00TEST  CMP   #$7F                   ; Delete
             BEQ   :WORD00DEL
             CMP   #$08                   ; If KBD has no DELETE key
             BNE   :WORD00CHAR
             LDA   #$7F
:WORD00DEL   CPY   #$00
             BEQ   :WORD00LP              ; Nothing to delete
             DEY                          ; Back up one character
             BCS   :WORD00ECHO            ; Loop back to print DEL
:WORD00CHAR  CMP   #$15                   ; Ctrl-U
             BNE   :WORD00INS             ; No, insert character
             LDA   #$7F                   ; Delete character
             INY                          ; Balance first DEY
:WORD00ALL   DEY                          ; Back up one character
             BEQ   :WORD00LP              ; Beginning of line
             JSR   OSWRCH                 ; Print DELETE
             JMP   :WORD00ALL             ; Loop to delete all
:WORD00INS   STA   (OSTEXT),Y             ; Store the character
             CMP   #$0D
             BEQ   :WORD00CR              ; CR - Done
             CPY   MAXLEN
             BCS   :WORD00BELL            ; Too long, beep
             CMP   MINCHAR
             BCC   :WORD00ECHO            ; <MINCHAR, don't step to next
             CMP   MAXCHAR
             BCC   :WORD00NEXT            ; <MAXCHAR, step to next
             BEQ   :WORD00NEXT            ; =MAXCHAR, step to next
             BCS   :WORD00ECHO            ; >MAXCHAR, don't step to next

:WORD00CR    JSR   OSNEWL
*          JSR   CALLNET         ; Call Econet Vector, A=13
:WORD00ESC   LDA   ESCFLAG                ; Get Escape flag
             ROL   A                      ; Carry=Escape state
             RTS


* OSWORD &01 - Read elapsed time
* OSWORD &02 - Write elapsed time
* OSWORD &03 - Read countdown timer
* OSWORD &04 - Write countdown timer
************************************
* On entry, (OSCTRL)=>control block
*           Y=0

WORD01       TYA                          ; Dummy, just return zero
:WORD01LP    STA   (OSCTRL),Y
             INY
             CPY   #$05
             BCC   :WORD01LP
WORD04
WORD03
WORD02       RTS                          ; Dummy, do nothing

* OSWORD &05 - Read I/O memory
* OSWORD &06 - Write I/O memory
***********************************
* On entry, (OSCTRL)+0 address
*           (OSCTRL)+4 byte read or written
*           Y=0, A=(OSCTRL)
* IRQs are disabled, so we don't have to preserve IRQ state
*
WORD05       JSR   GETADDR                ; Point to address, set Y=>data
             BNE   WORD05A
             JSR   WORD05IO
             LDY   #$04
             STA   (OSCTRL),Y             ; Store it
WORD05RET    RTS

WORD05IO     LDA   OSINTWS+0              ; X CORRUPTED BY XF2MAIN
             LDY   OSINTWS+1
WORD05IO1    >>>   XF2MAIN,MAINRDMEM

* <8000xxxx language memory
*  ????xxxx main memory RAM paged in via STA $C002
*  ????xxxx main memory ROM paged in via XFER

             STA   $C002                  ; Switch to main memory
WORD05A      LDA   (OSINTWS)              ; Get byte
             STA   $C003                  ; Back to aux memory
             STA   (OSCTRL),Y             ; Store it
             RTS

WORD06       JSR   GETADDR                ; Point to address, set Y=>data
             PHP
             LDA   (OSCTRL),Y             ; Get byte
             PLP
             BNE   WORD06A
             STA   $C004                  ; Switch to main memory
WORD06A      STA   (OSINTWS)              ; Store it
             STA   $C005                  ; Back to aux memory
             RTS

GETADDR      STA   OSINTWS+0              ; (OSINTWS)=>byte to read/write
             INY
             LDA   (OSCTRL),Y
             STA   OSINTWS+1
             INY
             INY
             LDA   (OSCTRL),Y             ; Get address high byte
             INY                          ; Point Y to data byte
             CMP   #$80                   ; *TO DO* Needs an appropriate value
             RTS


* OSBYTE routines
*****************

BYTE88       LDA   #$01                   ; $88 = *CODE
WORDE0       JMP   (USERV)                ; OSWORD &E0+

* Low OSBYTE converted into Set Variable
BYTE02       LDA   #$F7                   ; -> &B1
*
BYTE09                                    ; -> &C2
BYTE0A                                    ; -> &C3
BYTE0B                                    ; -> &C4
BYTE0C       ADC   #$C9                   ; -> &C5
*
BYTE01                                    ; -> &F1
BYTE05                                    ; -> &F5
BYTE06       ADC   #$07                   ; -> &F6
*
BYTE03                                    ; -> &EC
BYTE04       ADC   #$E8                   ; -> &ED
*
* Read/Write OSBYTE variable
BYTEVAR      TAY                          ; offset to variable
             LDA   BYTEVARBASE+0,Y
             TAX                          ; X=old value
             AND   OSYREG
             EOR   OSXREG
             STA   BYTEVARBASE+0,Y        ; update variable
             LDA   BYTEVARBASE+1,Y
             TAY                          ; Y=next value
             RTS

* Memory layout
BYTE82                                    ; $82 = read high order address
* Should return $0000, but BCPL, Lisp and View try to move
* up to $F800 overwriting Apple II stuff
             LDY   #$FF                   ; $FFFF for I/O processor
             LDX   #$FF
             RTS

BYTE83       LDY   #$0E                   ; $83 = read bottom of user mem
             LDX   #$00                   ; $0E00
             RTS

BYTE85                                    ; $85 = top user mem for mode
BYTE84       LDY   #$80                   ; $84 = read top of user mem
             LDX   #$00
             RTS

* Passed on to filing system
BYTE8B       CPX   #$FF                   ; *DEBUG*
             BNE   BYTE8BA                ; *DEBUG*
             STY   $E0                    ; *DEBUG*
             RTS                          ; *DEBUG*
BYTE8BA      LDA   #$00                   ; &00 -> &00 - *OPT
BYTE7F       AND   #$01                   ; &7F -> &01 - EOF
CALLFSCV     JMP   (FSCV)                 ; Hand over to filing system


* Test/Debug code
UNSUPBYTWRD  TAX
             LDA   #<OSBYTEM
             LDY   #>OSBYTEM
             CPX   #7
             BEQ   UNSUPGO
             LDA   #<OSWORDM
             LDY   #>OSWORDM
UNSUPGO      JSR   PRSTR
             LDA   OSAREG
             JSR   OUTHEX
*            LDA   #$2C
*            LDA   OSXREG
*            JSR   OUTHEX
*            LDA   #$2C
*            LDA   OSYREG
*            JSR   OUTHEX
             LDA   #<OSBM2
             LDY   #>OSBM2
             JSR   PRSTR
*            JSR   OSRDCH
             LDA   OSAREG
             RTS

OSBYTEM      ASC   'OSBYTE($'
             DB    $00
OSWORDM      ASC   'OSWORD($'
             DB    $00
OSBM2        ASC   ').'
             DB    $00






