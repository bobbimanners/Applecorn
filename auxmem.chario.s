* AUXMEM.CHARIO.S
* (c) Bobbi 2021,2022 GPLv3
*
* AppleMOS Character I/O


* KERNEL/CHARIO.S
*****************
* Character read and write
*
* 14-Aug-2021 Flashing cursor and INKEY sync'd to frame rate
*             with VBLK. Ensured cursor turned on straight away.
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
* 15-Sep-2021 INKEY(0) tests once and returns immediately.
* 30-Nov-2021 With *FX4,<>0 TAB returns $09, allows eg VIEW to work.
* 15-Oct-2022 Replace calling KBDCHKESC with ESCPOLL, does translations, etc.
*             Fixed bug with cursor keys after *FX4,2. OSRDCH enables IRQs.
* 23-Oct-2022 Escape: BYTE7E needed to ESCPOLL, INKEYESC unbalanced stack.
* 03-Nov-2022 Escape: Fixed INKEY loop failing if entering with previous Escape,
*             combined with EscAck clearing keyboard.
* 06-Dec-2022 Moved *KEY into here.


* Hardware locations
KBDDATA      EQU   $C000             ; Read Keyboard data
KBDACK       EQU   $C010             ; Acknowledge keyboard data
KBDAPPLFT    EQU   $C061             ; Left Apple key
KBDAPPRGT    EQU   $C062             ; Right Apple key
IOVBLNK      EQU   $C019             ; VBLNK pulse

FLASHER      EQU   BYTEVARBASE+176   ; VSync counter for flashing cursor
FXEXEC       EQU   BYTEVARBASE+198
FXSPOOL      EQU   BYTEVARBASE+199

FXTABCHAR    EQU   BYTEVARBASE+219
FXESCCHAR    EQU   BYTEVARBASE+220
FXKEYBASE    EQU   BYTEVARBASE+221
FXESCON      EQU   BYTEVARBASE+229
FXESCEFFECT  EQU   BYTEVARBASE+230
FX200VAR     EQU   BYTEVARBASE+200
FXSOFTLEN    EQU   BYTEVARBASE+216
FXSOFTOK     EQU   BYTEVARBASE+244

FX254VAR     EQU   BYTEVARBASE+254
FX2VAR       EQU   BYTEVARBASE+$B1
FX3VAR       EQU   BYTEVARBASE+$EC
FX4VAR       EQU   BYTEVARBASE+$ED

KEYBUF       EQU   $400              ; *KEY buffer from $400-$7FF
                                     ; Beware of the screen holes!
KEYBUFFREE   EQU   KEYBUF + $20      ; Free space word

* *KEY <num> <GSTRANS string>
* ---------------------------
STARKEY     LDA   FXSOFTLEN
            BNE   ERRKEYUSED         ; Key being expanded
            JSR   SCANDEC
            CMP   #$10
            BCC   STARKEY1
ERRBADKEY   BRK
            DB    $FB
            ASC   'Bad key'
ERRKEYUSED  BRK
            DB    $FA
            ASC   'Key in use'
            BRK
STARKEY1    ASL   A                  ; Key num * 2
            PHA                      ; Preserve for later
            JSR   SKIPCOMMA
            LDA   KEYBUFFREE+0       ; Free space LS byte
            STA   OSTEXT+0
            PLX                      ; Recover key num * 2
            PHX
            STA   KEYBUF,X           ; Store LS byte start address
            LDA   KEYBUFFREE+1       ; Free space MS byte
            STA   OSTEXT+1
            PLX                      ; Recover key num * 2
            STA   KEYBUF+1,X         ; Store MS byte start address
:L1         LDA   (OSLPTR),Y         ; Read char from input
            STA   (OSTEXT)           ; Store in buffer
            PHA
            INY                      ; Advance source index
            JSR   INCKEYPTR          ; Advance dest pointer
            PLA
            CMP   #$0D               ; Carriage return?
            BNE   :L1
:S1         LDA   OSTEXT+0
            STA   KEYBUFFREE+0       ; Free space LS byte
            LDA   OSTEXT+1
            STA   KEYBUFFREE+1       ; Free space MS byte
            RTS


* Increment OSTEXT, skipping over screen holes
* Screen holes are $478-$47F, $4F8-$4FF
*                  $578-$57F, $5F8-$5FF
*                  $678-$67F, $6F8-$6FF
*                  $778-$77F, $7F8-$7FF
INCKEYPTR   LDA   OSTEXT+0           ; Least significant byte
            INC   A
            STA   OSTEXT+0
            AND   #$F8
            CMP   #$78               ; If $78 to $7F
            BEQ   :HOLE78
            CMP   #$F8               ; If $F8 to $FF
            BEQ   :HOLEF8
            RTS
:HOLE78     LDA   #$80
            STA   OSTEXT+0
            RTS
:HOLEF8     STZ   OSTEXT+0
            INC   OSTEXT+1
            RTS



* OSWRCH handler
****************
* Send a character to current output
* All registers preserved
*
WRCHHND      PHA
             PHX
             PHY
             PHA
* TO DO Check any output redirections
* TO DO Check any printer output
             JSR   OUTCHAR             ; Send to VDU driver
*  BCC WRCHHND3 ; VDU driver says skip printer
*  PLA          ; Get character back
*  PHA
*  JSR PRNCHAR  ; Send to printer
* WRCHHND3
*  Check FX3VAR
*  Bxx WRCHHND4 ; Spool disabled
             LDY   FXSPOOL             ; See if *SPOOL is in effect
             BEQ   WRCHHND4            ; No, skip sending to spool file
             PLA
             PHA
             JSR   OSBPUT              ; Write character to spool file
WRCHHND4     PLA                       ; Drop stacked character
             PLY                       ; Restore everything
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
DEFBYTELOW   EQU   219                 ; First default OSBYTE value
DEFBYTE      DB    $09,$1B             ; Default key codes
             DB    $C0,$D0,$E0,$F0     ; Default key expansion
             DB    $80,$90,$A0,$B0     ; Default key expansion
DEFBYTEEND

KBDINIT      LDX   #DEFBYTEEND-DEFBYTE-1
:KBDINITLP   LDA   DEFBYTE,X           ; Initialise KBD OSBYTE variables
             STA   BYTEVARBASE+DEFBYTELOW,X
             DEX
             BPL   :KBDINITLP
             LDX   #$C0
             STX   FX254VAR            ; b7-b4=default KBD map, b3-b0=default MODE
             BIT   SETV                ; Set V
             JSR   KBDTEST             ; Test if key being pressed
             BCS   :KBDINITOK          ; Return default MODE=0
             STA   KBDACK              ; Ack. keypress
             TAX                       ; Use keypress as default MODE
:KBDINITOK   TXA
             RTS

* OSRDCH/INKEY handler
**********************
* Read a character from current input
* All registers preserved except A, Carry
* Flashes a soft cursor while waiting for input
* *NB* OSRDCH returns with IRQs enabled, INKEY returns with IRQs preserved
*
RDCHHND      LDA   #$80                ; flag=wait forever
             PHY
             TAY
             BRA   INKEYGO             ; Wait forever for input

* XY<$8000 - wait for a keypress
INKEY        PHY                       ; Dummy PHY to balance RDCH
INKEYGO      CLI                       ; Enable IRQs
             PHX                       ; Save registers
             PHY
             BIT   VDUSTATUS           ; Enable editing cursor
             BVC   INKEYGO2            ; No editing cursor
             JSR   GETCHRC             ; Get character under cursor
             STA   COPYCHAR            ; Save char under edit cursor
             LDA   CURSORED
             JSR   PUTCHRC             ; Display edit cursor
             JSR   COPYSWAP1           ; Swap to copy cursor
INKEYGO2     JSR   GETCHRC             ; Get character under cursor
             STA   OLDCHAR
             BRA   INKEY1              ; Turn cursor on

INKEYLP      CLC
             LDA   #$01                ; Slow flash, every 32 frames
             BIT   VDUSTATUS
             BVC   INKEY0
             ASL   A                   ; Fast flash, every 16 frames
INKEY0       ADC   FLASHER
             STA   FLASHER
             AND   #15
             BNE   INKEY3              ; Not time to toggle yet
             LDA   OLDCHAR             ; Prepare to remove cursor
             BIT   FLASHER
             BMI   INKEY2              ; Remove cursor
INKEY1       LDA   CURSOR              ; Add cursor
             BIT   VDUSTATUS
             BVC   INKEY2
             LDA   CURSORCP
INKEY2       JSR   PUTCHRC             ; Toggle cursor
INKEY3       LDA   #$27                ; Prepare to return CHR$27 if Escape state
             CLC
             BIT   ESCFLAG             ; Check Escape state
             BMI   INKEYESC            ; Escape pending, return it with A=27
INKEY4       JSR   KEYREAD             ; Test for input, all can be trashed
             PLY
             BCC   INKEYOK             ; Char returned, return it
             BMI   INKEY6              ; Loop forever, skip countdown
             PLX
             BNE   INKEY5
             TYA
             BEQ   INKEYOUT            ; XY=0, timed out
             DEY                       ; 16-bit decrement
INKEY5       DEX
             PHX
INKEY6       PHY
*
* VBLK pulses at 50Hz/60Hz, toggles at 100Hz/120Hz
             LDX   IOVBLNK             ; Get initial VBLK state
INKEY8       BIT   KBDDATA
             BMI   INKEY4              ; Key pressed
             TXA
             EOR   IOVBLNK
             BPL   INKEY8              ; Wait for VBLK change
             BMI   INKEYLP             ; Loop back to key test

INKEYOUT     LDA   #$FF                ; Prepare to stack $FF
INKEYESC     PLY                       ; Drop stacked Y
INKEYOK      PHA                       ; Save key or timeout
             PHP                       ; Save CC=key, CS=timeout
             LDA   OLDCHAR             ; Prepare for main cursor
             BIT   VDUSTATUS
             BVC   INKEYOFF2           ; No editing cursor
             JSR   PUTCHRC             ; Remove cursor
             JSR   COPYSWAP1           ; Swap cursor back
             LDA   COPYCHAR            ; Remove main cursor
INKEYOFF2    JSR   PUTCHRC             ; Remove cursor
             PLP
             BCS   INKEYOK3            ; Timeout
             LDA   ESCFLAG             ; Keypress, test for Escape
             ASL   A                   ; Cy=Escape flag
             PLA                       ; Get char back
             PLX                       ; Restore X,Y for key pressed
INKEYOK3     PLY                       ; Or pop TimeOut
             RTS
* RDCH  Character read: CC, A=char, X=restored, Y=restored
* RDCH  Escape:         CS, A=char, X=restored, Y=restored
* INKEY Character read: CC, A=char, X=???, Y<$80
* INKEY Escape:         CS, A=char, X=???, Y<$80
* INKEY Timeout:        CS, A=???,  X=???, Y=$FF


BYTE81       TYA
             BMI   NEGINKEY            ; XY<0, scan for keypress
             JSR   INKEY               ; XY>=0, wait for keypress
* Character read: CC, A=char, X=???, Y<$80
* Escape:         CS, A=char, X=???, Y<$80
* Timeout:        CS, A=???,  X=???, Y=$FF
             TAX                       ; X=character returned
             TYA
             BMI   BYTE81DONE          ; Y=$FF, timeout
             LDY   #$00
             BCC   BYTE81DONE          ; CC, not Escape
             LDY   #$1B                ; Y=27
BYTE81DONE   RTS
* Returns: Y=$FF, X=???, CS  - timeout
*          Y=$1B, X=???, CS  - escape
*          Y=$00, X=char, CC - keypress


NEGINKEY     CPX   #$01
             LDX   #$00                ; Unimplemented
             BCS   NEGINKEY0
             JSR   NEGCALL             ; Read machine ID from mainmem
             LDX   #$2C
             TAY
             BEQ   NEGINKEY0           ;  $00 = Apple IIc  -> INKEY-256 = $2C
             LDX   #$2E
             AND   #$0F
             BEQ   NEGINKEY0           ;  $x0 = Apple IIe  -> INKEY-256 = $2E
             LDX   #$2A                ; else = Apple IIgs -> INKEY-256 = $2A
NEGINKEY0    LDY   #$00
NEGINKEY1    CLC
             RTS

NEGCALL      >>>   XF2MAIN,MACHRD      ; Try to read Machine ID


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
KEYREAD      LDY   FXEXEC               ; See if EXEC file is open
             BEQ   KEYREAD1             ; No, skip past
             JSR   OSBGET               ; Read character from file
             BCC   KEYREADOK            ; Not EOF, return it
             LDA   #$00                 ; EOF, close EXEC file
             STA   FXEXEC               ; Clear EXEC handle
             JSR   OSFIND               ; And close it
KEYREAD1
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
             JSR   KBDREAD             ; Fetch character from KBD "buffer"
             BCS   KEYREADOK           ; Nothing pending
             TAY                       ; Y=unmodified character
             BPL   KEYREADOK           ; Not top-bit key
             AND   #$CF                ; Drop Shift/Ctrl bits
             CMP   #$C9
             BCC   KEYSOFTY            ; Not cursor key
             LDX   FX4VAR
             BEQ   KEYCURSOR           ; *FX4,0 - editing keys
             CPY   #$C9
             CLV
             BEQ   KEYCOPYTAB          ; TAB key
             DEX
             BNE   KEYSOFTHI           ; Not *FX4,1 - soft key
             SBC   #$44                ; Return $88-$8B
KEYREADOK1   CLC
KEYREADOK    RTS

* Process soft key
KEYSOFTHI    LDX   FX254VAR
             CPX   #$C0
             BCC   KEYSOFTY
             TYA
             AND   #$BF
             TAY
KEYSOFTY     TYA                       ; Get key including Shift/Ctrl
             LSR   A
             LSR   A
             LSR   A
             LSR   A                   ; A=key DIV 16
             EOR   #$04                ; Offset into KEYBASE
             TAX
             LDA   FXKEYBASE-8,X
* TO DO:
*BEQ KEYNONE ; $00=ignored
*DEC A
*BEQ expandfunction
             CMP   #2                  ; *TEMP*
             BCC   KEYNONE             ; *TEMP*
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
             JSR   PUTCHRC             ; Remove cursor
             PLA
             JSR   COPYMOVE            ; Move copy cursor
             JSR   GETCHRC             ; Save char under cursor
             STA   OLDCHAR
KEYNONE      SEC
             RTS

KEYCOPY      BIT   VDUSTATUS
KEYCOPYTAB   LDA   FXTABCHAR           ; Prepare TAB if no copy cursor
             BVC   KEYREADOK1          ; No copy cursor, return TAB
             LDA   OLDCHAR             ; Get the char under cursor
             PHA
             JSR   OUTCHARCP           ; Output it to restore and move cursor
             JSR   GETCHRC             ; Save char under cursor
             STA   OLDCHAR
             PLA
             BNE   KEYREADOK1          ; Ok character
             SEC
             JMP   BEEP                ; Beep and return CS=No char


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
KBDREAD      CLV                       ; VC=return keypress
KBDTEST      LDA   KBDDATA             ; VS here to test for keypress
             EOR   #$80                ; Toggle bit 7
             CMP   #$80
             BCS   KBDDONE             ; No key pressed
             BVS   KBDDONE             ; VS=test for keypress
             STA   KBDACK              ; Ack. keypress
KBDREAD2     BIT   KBDAPPLFT
             BMI   KBDLALT             ; Left Apple pressed
             BIT   KBDAPPRGT
             BMI   KBDRALT             ; Right Apple pressed
             CMP   #$09
             BEQ   KBDTAB              ; TAB is dual action TAB/COPY
             CMP   #$08
             BCC   KBDCHKESC           ; <$08 not cursor key
             CMP   #$0C
             BCC   KBDCURSR            ; $08-$0B are cursor keys
             CMP   #$15
             BNE   KBDCHKESC           ; $15 is cursor key
*
KBDCUR15     LDA   #$0D                ; Convert RGT to $09
KBDTAB       SBC   #$04                ; Convert TAB to &C9
KBDCURSR     CLC
             ADC   #$C4                ; Cursor keys $C0+x
             BRA   KBDCHKESC

KBDRALT                                ; Right Apple key pressed
KBDLALT      CMP   #$40                ; Left Apple key pressed
             BCS   KBDCTRL
             CMP   #$30
             BCC   KBDCHKESC           ; <'0'
             CMP   #$3A
             BCS   KBDCHKESC           ; >'9'
KBDFUNC      AND   #$0F                ; Convert Apple-Num to function key
             ORA   #$80
KBDFUNC2     BIT   KBDAPPRGT
             BPL   KBDCHKESC           ; Left+Digit       -> $8x
             ORA   #$90                ; Right+Digit      -> $9x
             BIT   KBDAPPLFT
             BPL   KBDCHKESC
             EOR   #$30                ; Left+Right+Digit -> $Ax
             BRA   KBDCHKESC

KBDCTRL      AND   #$1F                ; Apple-Letter -> Ctrl-Letter
*
* Test for Escape character
KBDCHKESC    TAX                       ; X=keycode
             EOR   FXESCCHAR           ; Current ESCAPE char?
             ORA   FXESCON             ; Is ESCAPE an ASCII char?
             BNE   KBDNOESC            ; Not ESCAPE or ESCAPE=ASCII
             LDA   FX200VAR            ; Is ESCAPE ignored?
             LSR   A                   ; Check bit 0
             BCS   KBDDONE             ; ESCAPE completely ignored
             SEC
             ROR   ESCFLAG             ; Set Escape flag
KBDNOESC     TXA                       ; A=keycode
             CLC                       ; CLC=Ok
KBDDONE      RTS


* Poll the keyboard to update Escape state
* On exit, MI=Escape state pending
*          CC=key pressed, CS=no key pressed
*          A=character
*          X,Y=preserved
*
ESCPOLL      BIT   SETV                ; Set V
             JSR   KBDTEST             ; VS - test keyboard
             BCS   ESCPOLL9            ; No keypress pending
             PHX                       ; KBDREAD corrupts A,X
             JSR   KBDREAD2            ; Read key and check for Escape, returns CC
             PLX
ESCPOLL9     BIT   ESCFLAG             ; Return with Escape state
             RTS

* Process pending Escape state
BYTE7E       STA   KBDACK              ; Flush keyboard
             LDX   #$00                ; $7E = ack detection of ESC
             BIT   ESCFLAG
             BPL   BYTE7DOK            ; No Escape pending
             LDA   FXESCEFFECT         ; Process Escape effects
             BEQ   BYTE7E2
             CLI                       ; Allow IRQs while flushing
             STX   FXLINES             ; Clear scroll counter
             JSR   CMDEXEC0            ; Close any EXEC file
*             JSR   BUFFLUSHALL        ; Flush all buffers
BYTE7E2      LDX   #$FF                ; X=$FF, Escape was pending
BYTE7C       CLC                       ; &7C = clear escape condition
BYTE7D       ROR   ESCFLAG             ; $7D = set escape condition
BYTE7DOK     RTS

BYTE76       LDX   #$00                ; Update LEDs and return X=SHIFT
             RTS                       ; Not possible with Apple

