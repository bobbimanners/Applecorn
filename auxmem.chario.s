* AUXMEM.CHARIO.S
* (c) Bobbi 2021 GPLv3
*
* AppleMOS Character I/O

* KERNEL/CHARIO.S
*****************
* Character read and write
*
* 14-Aug-2021 Flashing cursor and INKEY sync'd to frame rate
*             with VBLK. Ensured cursor turned on straightaway.
* 15-Aug-2021 Cursor keys move copy cursor, copy reads char.
*             Copy cursor not visible yet.
* 16-Aug-2021 Copy cursor and Edit cursor visible.
* 17-Aug-2021 OSBYTE 4 for cursors, OSBYTE 221-228 for topbit
*             keys.
* 21-Aug-2021 FIXED: If screen scrolls, copy cursor ends on
*             wrong line.
*             FIXED: KBDREAD has several paths that don't
*             test ESCHAR.
*             FIXED: INKEY doesn't restore cursor on timeout.
*             The three separate cursors can be set seperately.
* 02-Sep-2021 INKEY-256 tests Apple IIe vs IIc.
* 05-Sep-2021 KBDINIT returns startup value to pass to VDUINT.
* 09-Sep-2021 Moved keyboard OSBYTEs to here.
* 12-Sep-2021 COPY calls new VDU entry point.


OLDCHAR      EQU   OSKBD1                    ; *TEMP*  ; character under cursor

** Moved to AUXMEM.MOSEQU.S for Merlin-8/-16
*COPYCHAR EQU OSKBD2 ; *TEMP*  ; character under copy cursor

FLASHER      EQU   BYTEVARBASE+193           ; flash counter for cursor

FXEXEC       EQU   BYTEVARBASE+198
FXSPOOL      EQU   BYTEVARBASE+199

FXTABCHAR    EQU   BYTEVARBASE+219
FXESCCHAR    EQU   BYTEVARBASE+220
FXKEYBASE    EQU   BYTEVARBASE+221
FXESCON      EQU   BYTEVARBASE+229
FXESCEFFECT  EQU   BYTEVARBASE+230
FX200VAR     EQU   BYTEVARBASE+200
FX254VAR     EQU   BYTEVARBASE+254
FX2VAR       EQU   BYTEVARBASE+$B1
FX3VAR       EQU   BYTEVARBASE+$EC
FX4VAR       EQU   BYTEVARBASE+$ED


* OSWRCH handler
****************
* Send a character to current output
* All registers preserved
*
WRCHHND      PHA
             PHX
             PHY
* TO DO Check any output redirections
* TO DO Check any spool output
*  LDY FXSPOOL
*  BEQ WRCHHND1
*  JSR OSBPUT
* WRCHHND1
*
             JSR   OUTCHAR
* TO DO Check any printer output
*  BCC WRCHHND2
*  TSX
*  LDA $103,X
*  JSR PRNCHAR
* WRCHHND2
             PLY
             PLX
             PLA
             RTS


* Character Input
*****************
* Default keyboard OSBYTE variables
*DEFBYTELOW  EQU  219              ; First default OSBYTE value
*DEFBYTE     DB   $09,$1B          ; Default key codes
*            DB   $01,$D0,$E0,$F0  ; Default key expansion
*            DB   $01,$80,$90,$00  ; Default key expansion
*DEFBYTEEND

* TEMP as no *KEY
* Default keyboard OSBYTE variables
DEFBYTELOW   EQU   219                       ; First default OSBYTE value
DEFBYTE      DB    $09,$1B                   ; Default key codes
             DB    $C0,$D0,$E0,$F0           ; Default key expansion
             DB    $80,$90,$A0,$B0           ; Default key expansion
DEFBYTEEND

KBDINIT      LDX   #DEFBYTEEND-DEFBYTE-1
:KBDINITLP   LDA   DEFBYTE,X                 ; Initialise KBD OSBYTE variables
             STA   BYTEVARBASE+DEFBYTELOW,X
             DEX
             BPL   :KBDINITLP
             LDX   #$C0
             STX   FX254VAR                  ; b7-b4=default KBD map, b3-b0=default MODE
             BIT   SETV
             JSR   KBDTEST
             BCS   :KBDINITOK                ; Return default MODE=0
             STA   $C010                     ; Ack. keypress
             TAX                             ; Use keypress as default MODE
:KBDINITOK   TXA
             RTS

* OSRDCH/INKEY handler
**********************
* Read a character from current input
* All registers preserved except A, Carry
* Flashes a fake cursor while waiting for input
*
RDCHHND      LDA   #$80                      ; flag=wait forever
             PHY
             TAY
             BRA   INKEYGO                   ; Wait forever for input

* XY<$8000 - wait for a keypress
INKEY        PHY                             ; Dummy PHY to balance RDCH
INKEYGO      PHX                             ; Save registers
             PHY
             BIT   VDUSTATUS                 ; Enable editing cursor
             BVC   INKEYGO2                  ; No editing cursor
             JSR   GETCHRC                   ; Get character under cursor
             STA   COPYCHAR                  ; Save char under edit cursor
             LDA   CURSORED
             JSR   PUTCHRC                   ; Display edit cursor
             JSR   COPYSWAP1                 ; Swap to copy cursor
INKEYGO2     JSR   GETCHRC                   ; Get character under cursor
             STA   OLDCHAR
             CLI
             BRA   INKEY1                    ; Turn cursor on
*
INKEYLP1     PHX
INKEYLP2     PHY
INKEYLP      CLC
             LDA   #$01                      ; Slow flash, every 32 frames
             BIT   VDUSTATUS
             BVC   INKEY0
             ASL   A                         ; Fast flash, every 16 frames
INKEY0       ADC   FLASHER
             STA   FLASHER
             AND   #15
             BNE   INKEY3                    ; Not time to toggle yet
             LDA   OLDCHAR                   ; Prepare to remove cursor
             BIT   FLASHER
             BMI   INKEY2                    ; Remove cursor
INKEY1       LDA   CURSOR                    ; Add cursor
             BIT   VDUSTATUS
             BVC   INKEY2
             LDA   CURSORCP
INKEY2       JSR   PUTCHRC                   ; Toggle cursor
INKEY3       LDA   ESCFLAG
             BMI   INKEYOK                   ; Escape pending, return it
INKEY4       JSR   KEYREAD                   ; Test for input, all can be trashed
             BCC   INKEYOK                   ; Char returned, return it
*
* VBLK pulses at 50Hz, changes at 100Hz
* (60Hz in US, will need tweeking)
             LDX   $C019                     ; Get initial VBLK state
INKEY5       BIT   $C000
             BMI   INKEY4                    ; Key pressed
             TXA
             EOR   $C019
             BPL   INKEY5                    ; Wait for VBLK change
*
             PLY
             BMI   INKEYLP2                  ; Loop forever
             PLX
             TXA
             BNE   INKEYDEC                  ; Decrement XY
             DEY
INKEYDEC     DEX
             BNE   INKEYLP1                  ; Not 0, loop back
             TYA
             BNE   INKEYLP1                  ; Not 0, loop back
             PHY
             JSR   INKEYOFF                  ; Restore cursors
             PLY
             DEY                             ; Y=$FF
             TYA                             ; A=$FF
             PLX                             ; Drop dummy PHY
             SEC
             RTS
* Timeout: CS, AY=$FFFF, becomes XY=$FFFF

INKEYOK      PHA
             JSR   INKEYOFF                  ; Restore cursors
INKEYOK2     PLA
             PLY                             ; <$80=INKEY or $80=RDCH
             PLX                             ; Restore X
             PLY                             ; <$80=INKEY or restore=RDCH
             PHA                             ; Save char for a mo
             LDA   ESCFLAG
             ASL   A                         ; Cy=Escape flag
             PLA                             ; Get char back
             RTS
* Character read: CC, A=char, X=???, Y<$80
* Escape:         CS, A=??  , X=???, Y<$80

INKEYOFF     LDA   OLDCHAR                   ; Remove editing cursor
             BIT   VDUSTATUS
             BVC   INKEYOFF2                 ; No editing cursor
             JSR   PUTCHRC                   ; Remove cursor
             JSR   COPYSWAP1                 ; Swap cursor back
             LDA   COPYCHAR                  ; Remove edit cursor
INKEYOFF2    JMP   PUTCHRC

BYTE81       TYA
             BMI   NEGINKEY                  ; XY<0, scan for keypress
             JSR   INKEY                     ; XY>=0, wait for keypress
*  Y=$FF, A=FF,   X=??, CS - timeout
*  Y<$80, A=esc,  X=??, CS - escape
*  Y<$80, A=char, X=??, CC - character read
             TAX                             ; X=character returned
             TYA
             BMI   BYTE81DONE                ; Y=$FF, timeout
             LDY   #$00
             BCC   BYTE81DONE                ; CC, not Escape
             LDY   #$1B                      ; Y=27
BYTE81DONE   RTS
* Returns: Y=$FF, X=$FF, CS  - timeout
*          Y=$1B, X=???, CS  - escape
*          Y=$00, X=char, CC - keypress


NEGINKEY     CPX   #$01
             LDX   #$00                      ; Unimplemented
             BCS   NEGINKEY0

             JSR   NEGCALL                   ; Read machine ID from aux
             LDX   #$2C
             TAY
             BEQ   NEGINKEY0                 ;  $00 = Apple IIc -> INKEY-256 = $2C
             LDX   #$2E
             AND   #$0F
             BEQ   NEGINKEY0                 ;  $x0 = Apple IIe -> INKEY-256 = $2E
             LDX   #$2A                      ; else = Apple IIgs INKEY-256 = $2A
NEGINKEY0    LDY   #$00
             CLC
             RTS

NEGCALL      >>>   XF2MAIN,MACHRD            ; Try to read Machine ID


* KERNEL/KEYBOARD.S
*******************

* KEYREAD
************************
* Test for and read from input,
* expanding keyboard special keys
*
* On exit, CS=no keypress
*          CC=keypress
*          A =keycode, X,Y=corrupted
KEYREAD
* TO DO: check *EXEC source
*  LDY FXEXEC
*  BEQ KEYREAD1
*  JSR OSBGET
*  BCC KEYREADOK
*  LDA #0
*  STA FXVAREXEC
*  JSR OSFIND
* KEYREAD1
*
* TO DO: expand current soft key
*  LDA SOFTKEYLEN
*  BEQ KEYREAD2
*  LDX SOFTKEYOFF
*  LDA SOFTKEYS,X
*  INC SOFTKEYOFF
*  DEC SOFTKEYLEN
*  CLC
*  RTS
* KEYREAD2
*
             JSR   KBDREAD                   ; Fetch character from KBD "buffer"
             BCS   KEYREADOK                 ; Nothing pending
*
             TAY
             BPL   KEYREADOK                 ; Not top-bit key
             AND   #$CF
             CMP   #$C9
             BCC   KEYSOFT                   ; Not cursor key
             LDX   FX4VAR
             BEQ   KEYCURSOR                 ; *FX4,0 - editing keys
             DEX
             BNE   KEYSOFT1                  ; Not *FX4,1 - soft key
             LDY   FXTABCHAR
             CMP   #$C9
             BEQ   KEYREADOKY                ; TAB key
             SBC   #$44                      ; Return $88-$8B
             TAY
KEYREADOKY   TYA
KEYREADOK1   CLC
KEYREADOK    RTS
*
* Process soft key
KEYSOFT1     LDX   FX254VAR
             CPX   #$C0
             BCC   KEYSOFT
             AND   #$BF
             TAY
KEYSOFT      TYA
             LSR   A
             LSR   A
             LSR   A
             LSR   A                         ; A=key DIV 16
             EOR   #$04                      ; Offset into KEYBASE
             TAX
             LDA   FXKEYBASE-8,X
* TO DO:
*BEQ KEYNONE ; $00=ignored
*DEC A
*BEQ expandfunction
             CMP   #2                        ; *TEMP*
             BCC   KEYNONE                   ; *TEMP*
             TYA
             AND   #$0F
             CLC
             ADC   FXKEYBASE-8,X
             CLC
             RTS

* Process cursor keys
KEYCURSOR    CMP   #$C9
             BEQ   KEYCOPY
             PHA
             LDA   OLDCHAR
             JSR   PUTCHRC                   ; Remove cursor
             PLA
             JSR   COPYMOVE                  ; Move copy cursor
             JSR   GETCHRC                   ; Save char under cursor
             STA   OLDCHAR
KEYNONE      SEC
             RTS

KEYCOPY      LDA   FXTABCHAR                 ; Prepare TAB if no copy cursor
             BIT   VDUSTATUS
             BVC   KEYREADOK1                ; No copy cursor, return TAB
             LDA   OLDCHAR                   ; Get the char under cursor
             PHA
             JSR   OUTCHARCP                 ; Output it to restore and move cursor
             JSR   GETCHRC                   ; Save char under cursor
             STA   OLDCHAR
             PLA
             BNE   KEYREADOK1                ; Ok character
             SEC
             JMP   BEEP                      ; Beep and return CS=No char


* KBDREAD
************************
* Test for and fetch key from keyboard
*
* On exit, CS=no keypress
*          CC=keypress
*          A =keycode, X=corrupted
* Apple+Letter -> Ctrl+Letter
* Apple+Digits -> 80+x, 90+x, A0+x
* TAB          -> $C9
* Cursors      -> $CC-$CF
*
KBDREAD      CLV                             ; VC=return keypress
KBDTEST      LDA   $C000                     ; VS here to test for keypress
             EOR   #$80                      ; Toggle bit 7
             CMP   #$80
             BCS   KBDDONE                   ; No key pressed
             BVS   KBDDONE                   ; VS=test for keypress
             STA   $C010                     ; Ack. keypress
             BIT   $C061
             BMI   KBDLALT                   ; Left Apple pressed
             BIT   $C062
             BMI   KBDRALT                   ; Right Apple pressed
             CMP   #$09
             BEQ   KBDTAB                    ; TAB is dual action TAB/COPY
             CMP   #$08
             BCC   KBDCHKESC                 ; <$08 not cursor key
             CMP   #$0C
             BCC   KBDCURSR                  ; $08-$0B are cursor keys
             CMP   #$15
             BNE   KBDCHKESC                 ; $15 is cursor key
*
KBDCUR15     LDA   #$0D                      ; Convert RGT to $09
KBDTAB       SBC   #$04                      ; Convert TAB to &C9
KBDCURSR     CLC
             ADC   #$C4                      ; Cursor keys $C0+x
             BRA   KBDCHKESC

KBDRALT                                      ; Right Apple key pressed
KBDLALT      CMP   #$40                      ; Left Apple key pressed
             BCS   KBDCTRL
             CMP   #$30
             BCC   KBDCHKESC                 ; <'0'
             CMP   #$3A
             BCS   KBDCHKESC                 ; >'9'
KBDFUNC      AND   #$0F                      ; Convert Apple-Num to function key
             ORA   #$80
             BIT   $C062
             BPL   KBDCHKESC                 ; Left+Digit       -> $8x
             ORA   #$90                      ; Right+Digit      -> $9x
             BIT   $C061
             BPL   KBDCHKESC
             EOR   #$30                      ; Left+Right+Digit -> $Ax
             BRA   KBDCHKESC

KBDCTRL      AND   #$1F                      ; Apple-Letter -> Ctrl-Letter
*
* Test for Escape key
KBDCHKESC    TAX                             ; X=keycode
             EOR   FXESCCHAR                 ; Current ESCAPE char?
             ORA   FXESCON                   ; Is ESCAPE an ASCII char?
             BNE   KBDNOESC                  ; Not ESCAPE or ESCAPE=ASCII
             LDA   FX200VAR                  ; Is ESCAPE ignored?
             LSR   A                         ; Check bit 0
             BCS   KBDDONE                   ; ESCAPE completely ignored
             SEC
             ROR   ESCFLAG                   ; Set Escape flag
KBDNOESC     TXA                             ; A=keycode
             CLC                             ; CLC=Ok
KBDDONE      RTS

* Process pending Escape state
BYTE7E       LDX   #$00                      ; $7E = ack detection of ESC
             BIT   ESCFLAG
             BPL   BYTE7DOK                  ; No Escape pending
             LDA   FXESCEFFECT               ; Process Escape effects
             BEQ   BYTE7E2
             CLI                             ; Allow IRQs while flushing
             STA   FXLINES                   ; Clear scroll counter
*             JSR   STAREXEC0      ; Close any EXEC file
*             JSR   FLUSHALL       ; Flush all buffers
BYTE7E2      LDX   #$FF                      ; X=$FF, Escape was pending
BYTE7C       CLC                             ; &7C = clear escape condition
BYTE7D       ROR   ESCFLAG                   ; $7D = set escape condition
BYTE7DOK     RTS

BYTE76       LDX   #$00                      ; Update LEDs and return X=SHIFT
             RTS                             ; Not possible with Apple

