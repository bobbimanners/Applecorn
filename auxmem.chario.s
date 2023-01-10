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
* 12-Dec-2022 Test code to write *KEY data to mainmem.
* 24-Dec-2022 Minor bit of tidying.
* 26-Dec-2022 Integrated ADB extended keyboard keys.
* 27-Dec-2022 Bobbi's keyboard uses $60+n extended keys.
* 30-Dec-2022 Optimised *KEY, US KBD Alt-Ctrl-2, Alt-Ctrl-6 -> f2/f6.
* 03-Jan-2023 Wrote BYTE76 to return CTRL/SHIFT state for text pausing.
* 07-Jan-2023 Updated KBDREAD to use BYTE76.


* Hardware locations
KBDDATA      EQU   $C000              ; Read Keyboard data
KBDACK       EQU   $C010              ; Acknowledge keyboard data
KBDAPPLFT    EQU   $C061              ; Left Apple key
KBDAPPRGT    EQU   $C062              ; Right Apple key
KBDMOD       EQU   $C025              ; AppleIIgs modifier keys
IOVBLNK      EQU   $C019              ; VBLNK pulse

FLASHER      EQU   BYTEVARBASE+176    ; VSync counter for flashing cursor
FXEXEC       EQU   BYTEVARBASE+198    ; *EXEC handle
FXSPOOL      EQU   BYTEVARBASE+199    ; *SPOOL handle

FXKBDSTATE   EQU   BYTEVARBASE+202    ; Keyboard modifier state
FXTABCHAR    EQU   BYTEVARBASE+219    ; Char for TAB key to return
FXESCCHAR    EQU   BYTEVARBASE+220    ; Char to match as Escape key
FXKEYBASE    EQU   BYTEVARBASE+221    ; Base of char &80+ translations
FXKEYPADBASE EQU   BYTEVARBASE+238    ; Base of keypad keys
FXESCON      EQU   BYTEVARBASE+229    ; Escape key is ASC or ESC
FXESCEFFECT  EQU   BYTEVARBASE+230    ; Actions when Escape acknowledged
FX200VAR     EQU   BYTEVARBASE+200    ; Completely ignore CHR$(escape)
FX254VAR     EQU   BYTEVARBASE+254    ; Keyboard map

FXSOFTLEN    EQU   BYTEVARBASE+216    ; Length of current soft key
FXSOFTOFF    EQU   BYTEVARBASE+233    ; Offset to current soft key
FXSOFTOK     EQU   BYTEVARBASE+244    ; Soft keys not unstable

FX2VAR       EQU   BYTEVARBASE+$B1    ; Input stream
FX3VAR       EQU   BYTEVARBASE+$EC    ; Output streams
FX4VAR       EQU   BYTEVARBASE+$ED    ; Cursor key state

* FKEYLENS   defined in mainmem.misc.s ; Length of soft key definitions
* FKEYBUF    defined in mainmem.misc.s ; Base of soft key definitions


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
             JSR   OUTCHAR            ; Send to VDU driver
*  BCC WRCHHND3 ; VDU driver says skip printer
*  PLA          ; Get character back
*  PHA
*  JSR PRNCHAR  ; Send to printer
* WRCHHND3
*  Check FX3VAR
*  Bxx WRCHHND4 ; Spool disabled
             LDY   FXSPOOL            ; See if *SPOOL is in effect
             BEQ   WRCHHND4           ; No, skip sending to spool file
             PLA
             PHA
             JSR   OSBPUT             ; Write character to spool file
WRCHHND4     PLA                      ; Drop stacked character
             PLY                      ; Restore everything
             PLX
             PLA
             RTS


* Character Input
*****************
* Default keyboard OSBYTE variables
DEFBYTELOW  EQU  219              ; First default OSBYTE value
DEFBYTE     DB   $09,$1B          ; Default key codes
            DB   $01,$D0,$E0,$F0  ; Default key expansion
            DB   $01,$80,$90,$00  ; Default key expansion
DEFBYTEEND

KBDINIT      LDX   #DEFBYTEEND-DEFBYTE-1
:KBDINITLP   LDA   DEFBYTE,X          ; Initialise KBD OSBYTE variables
             STA   BYTEVARBASE+DEFBYTELOW,X
             DEX
             BPL   :KBDINITLP
             LDA   #$80               ; Keypad keys are function keys
             STA   FXKEYPADBASE
             JSR   SOFTKEYCHK         ; Clear soft keys
             LDX   #$C3               ; Default KBD=RISC OS, MODE=3
             STX   FX254VAR           ; b7-b4=default KBD map, b3-b0=default MODE
*             LDX   #$03               ; Default MODE=3 (map already <$C0 by startup)
             BIT   SETV               ; Set V
             JSR   KBDTEST            ; Test if key being pressed
             BCS   :KBDINITOK         ; Return default MODE
             STA   KBDACK             ; Ack. keypress
             TAX                      ; Use keypress as default MODE
:KBDINITOK   TXA
             RTS

* OSRDCH/INKEY handler
**********************
* Read a character from current input
* All registers preserved except A, Carry
* Flashes a soft cursor while waiting for input
* *NB* OSRDCH returns with IRQs enabled, INKEY returns with IRQs preserved
*
RDCHHND      LDA   #$80               ; flag=wait forever
             PHY
             TAY
             BRA   INKEYGO            ; Wait forever for input

* XY<$8000 - wait for a keypress
INKEY        PHY                      ; Dummy PHY to balance RDCH
INKEYGO      CLI                      ; Enable IRQs
             PHX                      ; Save registers
             PHY
             BIT   VDUSTATUS          ; Enable editing cursor
             BVC   INKEYGO2           ; No editing cursor
             JSR   GETCHRC            ; Get character under cursor
             STA   COPYCHAR           ; Save char under edit cursor
             LDA   CURSORED
             JSR   SHOWCURSOR         ; Display edit cursor [ON]
             JSR   COPYSWAP1          ; Swap to copy cursor
INKEYGO2     JSR   GETCHRC            ; Get character under cursor
             STA   OLDCHAR
             BRA   INKEY1             ; Turn cursor on

INKEYLP      CLC
             LDA   #$01               ; Slow flash, every 32 frames
             BIT   VDUSTATUS
             BVC   INKEY0
             ASL   A                  ; Fast flash, every 16 frames
INKEY0       ADC   FLASHER
             STA   FLASHER
             AND   #15
             BNE   INKEY3             ; Not time to toggle yet
             LDA   OLDCHAR            ; Prepare to remove cursor
             BIT   FLASHER
             BPL   INKEY1             ; Do not remove cursor
             JSR   REMCURSOR          ; Cursor off [OFF]
             BRA   INKEY3
INKEY1       LDA   CURSOR             ; Add cursor
             BIT   VDUSTATUS
             BVC   INKEY2
             LDA   CURSORCP
INKEY2       JSR   SHOWCURSOR         ; Cursor on [ON]
INKEY3       LDA   #$27               ; Prepare to return CHR$27 if Escape state
             CLC
             BIT   ESCFLAG            ; Check Escape state
             BMI   INKEYESC           ; Escape pending, return it with A=27
INKEY4       JSR   KEYREAD            ; Test for input, all can be trashed
             PLY
             BCC   INKEYOK            ; Char returned, return it
             BMI   INKEY6             ; Loop forever, skip countdown
             PLX
             BNE   INKEY5
             TYA
             BEQ   INKEYOUT           ; XY=0, timed out
             DEY                      ; 16-bit decrement
INKEY5       DEX
             PHX
INKEY6       PHY
*
* VBLK pulses at 50Hz/60Hz, toggles at 100Hz/120Hz
             LDX   IOVBLNK            ; Get initial VBLK state
INKEY8       BIT   KBDDATA
             BMI   INKEY4             ; Key pressed
             TXA
             EOR   IOVBLNK
             BPL   INKEY8             ; Wait for VBLK change
             BMI   INKEYLP            ; Loop back to key test

INKEYOUT     LDA   #$FF               ; Prepare to stack $FF
INKEYESC     PLY                      ; Drop stacked Y
INKEYOK      PHA                      ; Save key or timeout
             PHP                      ; Save CC=key, CS=timeout
             LDA   OLDCHAR            ; Prepare for main cursor
             BIT   VDUSTATUS
             BVC   INKEYOFF2          ; No editing cursor
             JSR   REMCURSOR          ; Remove cursor [OFF]
             JSR   COPYSWAP1          ; Swap cursor back
             LDA   COPYCHAR           ; Remove main cursor
INKEYOFF2    JSR   REMCURSOR          ; Remove cursor [OFF]
             PLP
             BCS   INKEYOK3           ; Timeout
             LDA   ESCFLAG            ; Keypress, test for Escape
             ASL   A                  ; Cy=Escape flag
             PLA                      ; Get char back
             PLX                      ; Restore X,Y for key pressed
INKEYOK3     PLY                      ; Or pop TimeOut
             RTS
* RDCH  Character read: CC, A=char, X=restored, Y=restored
* RDCH  Escape:         CS, A=char, X=restored, Y=restored
* INKEY Character read: CC, A=char, X=???, Y<$80
* INKEY Escape:         CS, A=char, X=???, Y<$80
* INKEY Timeout:        CS, A=???,  X=???, Y=$FF


BYTE81       TYA
             BMI   NEGINKEY           ; XY<0, scan for keypress
             JSR   INKEY              ; XY>=0, wait for keypress
* Character read: CC, A=char, X=???, Y<$80
* Escape:         CS, A=char, X=???, Y<$80
* Timeout:        CS, A=???,  X=???, Y=$FF
             TAX                      ; X=character returned
             TYA
             BMI   BYTE81DONE         ; Y=$FF, timeout
             LDY   #$00
             BCC   BYTE81DONE         ; CC, not Escape
             LDY   #$1B               ; Y=27
BYTE81DONE   RTS
* Returns: Y=$FF, X=???, CS  - timeout
*          Y=$1B, X=???, CS  - escape
*          Y=$00, X=char, CC - keypress


NEGINKEY     CPX   #$01
             LDX   #$00               ; Unimplemented
             BCS   NEGINKEY0
             JSR   NEGCALL            ; Read machine ID from mainmem
             LDX   #$2C
             TAY
             BEQ   NEGINKEY0          ;  $00 = Apple IIc  -> INKEY-256 = $2C
             LDX   #$2E
             AND   #$0F
             BEQ   NEGINKEY0          ;  $x0 = Apple IIe  -> INKEY-256 = $2E
             LDX   #$2A               ; else = Apple IIgs -> INKEY-256 = $2A
NEGINKEY0    LDY   #$00
NEGINKEY1    CLC
             RTS

NEGCALL      >>>   XF2MAIN,MACHRD     ; Try to read Machine ID


* KERNEL/KEYBOARD.S
*******************


* SOFT KEY PROCESSING
* ===================
OSDECNUM     EQU   OSTEMP

* *SHOW (<num>)
* -------------
STARSHOW     RTS

* *KEY <num> <GSTRANS string>
* ---------------------------
STARKEY      LDA   FXSOFTLEN
             BNE   ERRKEYUSED         ; Key being expanded
             JSR   SCANDEC
             CMP   #$10
             BCC   STARKEY1
ERRBADKEY    BRK
             DB    $FB
             ASC   'Bad key'
ERRKEYUSED   BRK
             DB    $FA
             ASC   'Key in use'
             BRK
*
* A slightly fiddly procedure, as we need to check the new
* definition is valid before we insert it, we can't bomb
* out halfway through inserting a string, and we mustn't
* have mainmem paged in while parsing the string as the
* string might be "underneath" the memory we've paged in,
* we don't know how long the new definition is and if it
* will fit into memory until after we've parsed it, so we
* either have to store it to a temp area or parse it twice.
*
* All this, and we need a structure that is reasonably coded,
* but with the priority to be easy for KEYREAD to extract
* from (as called more often), even if at expense of storing
* being more complex.
*
* Soft key definition layout:
* FKEYLENS+n - length of key n
* FKEYBUF+n  - start of key n where x=SUM(len(0)...len(n-1))
*
* SCANDEC stores number in OSDECNUM, so we can keep it there
* We also have OSKBDx variables available for shuffling code
* NB: OSKBD1, OSKBD2 also hold copy cursor state
*
STARKEY1     INC   FXSOFTOK           ; Soft keys unstable
             PHY                      ; Y=>command line
*
             PHP                      ; Read/write main memory
             SEI                      ; MACRO-ise this
             STA   WRMAINRAM
             STA   RDMAINRAM
*
             JSR   KEYOFFLEN          ; X=offset, A=length, CLC
             STX   OSKBD1             ; OSKBD1=offset to old definition
             STA   OSKBD2             ; OSKBD2=old length
             ADC   OSKBD1             ; A=offset to next definition
             TAY
* Remove old definition
:LOOP        LDA   FKEYBUF,Y          ; Get byte from next string
             STA   FKEYBUF,X          ; Move it down over this string
             INX
             INY
             BNE   :LOOP
             LDX   OSDECNUM
             STZ   FKEYLENS,X         ; Length=0
             LDA   #17
             JSR   KEYOFFLEN          ; X=offset to free space
*
             STA   RDCARDRAM          ; Read/write aux memory
             STA   WRCARDRAM          ; MACRO-ise this
             PLP
*
             STX   OSKBD2
             PLY
             JSR   SKIPCOMMA
             SEC
             JSR   GSINIT             ; Initialise '*KEY-type string'
STARKEYLP1   JSR   GSREAD
             BCS   STARKEYEND
             >>>   WRTMAIN            ; Write main memory
             STA   FKEYBUF,X          ; Store char of definition
             >>>   WRTAUX             ; Back to writing aux again
             INX
             BNE   STARKEYLP1
STARKEYERR   JMP   ERRBADSTR          ; String too long
* Should this be ERRBADKEY?

STARKEYEND   BNE   STARKEYERR         ; Badly terminated
* X=offset to end of new definition
* OSDECNUM=key number
* OSKBD1=offset to insertion point
* OSKBD2=start of new string, holding position
*
             TXA                      ; SEC from above
             SBC   OSKBD2             ; A=length of new definition
             BEQ   STARKEYDONE        ; Zero length, all done
             LDX   OSDECNUM
*
             PHP                      ; Read/write main memory
             SEI                      ; MACRO-ise this
             STA   WRMAINRAM
             STA   RDMAINRAM
*
             STA   FKEYLENS,X         ; Set new length
*
* A=length of new string
* X=key number
* OSKBD1=offset to insertion point
* OSKBD2=offset to free space, holding new string
*
             TAX
             LDA   OSKBD2
             SEC
             SBC   OSKBD1
             TAY                      ; Y=length between insertion point and free space
             BEQ   STARKEYNONE        ; Nothing to move, all done
             STX   OSKBD1             ; OSKBD1=length of new string
             LDX   OSKBD2             ; X=offset to free space, holding new string
*
* Insert new string
STARKEYLP2   PHY
             PHX
             LDA   FKEYBUF,X          ; Shuffle strings up
             PHA
STARKEYLP4   DEX
             LDA   FKEYBUF,X
             STA   FKEYBUF+1,X
             DEY
             BNE   STARKEYLP4
             PLA
             STA   FKEYBUF,X          ; Insert new string
             PLX
             INX
             PLY
             DEC   OSKBD1             ; Loop for length of new string
             BNE   STARKEYLP2
STARKEYNONE
*
             STA   RDCARDRAM          ; Read/write aux memory
             STA   WRCARDRAM          ; MACRO-ise this
             PLP
*
STARKEYDONE  STZ   FXSOFTOK           ; Soft keys are stable
             RTS

* Get offset and length of key in X
* Add lengths of previous definitions together
* Assumes mainmen is paged in by caller
* On entry: A=key number
* On exit   X=offset to definition start
*           A=length of definition
*           CC always
KEYOFFLEN   TAX
            LDA   FKEYLENS,X          ; Get length of this key
            PHA
            LDA   #0
            CLC                       ; CLC for addition
            BCC   :ADDUP
:KEYLOOP    ADC   FKEYLENS,X          ; Add length of previous key
:ADDUP      DEX                       ; Step to previous key
            BPL   :KEYLOOP            ; Do until key 0 added
            TAX                       ; Return X=offset
            PLA                       ; Return A=length
            RTS

* OSBYTE &12 - Clear soft keys
* ----------------------------
SOFTKEYCHK   LDA   FXSOFTOK
             BEQ   BYTE12OK           ; Soft keys ok, exit
BYTE12       LDX   #15
             STX   FXSOFTOK           ; Soft keys being updated
             >>>   WRTMAIN            ; Short enough to page for whole loop
:L2          STZ   FKEYLENS,X         ; Zero the lengths
             DEX
             BNE   :L2
             >>>   WRTAUX
             STZ   FXSOFTOK           ; Soft keys stable
BYTE12OK     RTS


* KEYREAD
************************
* Test for and read from input,
* expanding keyboard special keys
*
* On exit, CS=no keypress
*          CC=keypress
*          A =keycode, X,Y=corrupted
KEYREAD      LDY   FXEXEC             ; See if EXEC file is open
             BEQ   KEYREAD1           ; No, skip past
             JSR   OSBGET             ; Read character from file
             BCC   KEYREADOK          ; Not EOF, return it
             LDA   #$00               ; EOF, close EXEC file
             STA   FXEXEC             ; Clear EXEC handle
             JSR   OSFIND             ; And close it
KEYREAD1     LDA   FXSOFTLEN          ; Soft key active?
             BEQ   KEYREAD2           ; No, skip past
             LDX   FXSOFTOFF          ; Get offset to current character
             >>>   RDMAIN
             LDA   FKEYBUF,X          ; Get it from mainmem
             >>>   RDAUX
             INC   FXSOFTOFF          ; Inc. offset
             DEC   FXSOFTLEN          ; Dec. counter
             CLC
             RTS

KEYREAD2     JSR   KBDREAD            ; Fetch character from KBD "buffer"
             BCS   KEYREADOK          ; Nothing pending
             TAY                      ; Y=unmodified character
             BPL   KEYREADOK          ; Not top-bit key
             AND   #$CF               ; Drop Shift/Ctrl bits
             CMP   #$C9
             BCC   KEYSOFTHI          ; Not cursor key
*             BCC   KEYSOFTY           ; Not cursor key
             LDX   FX4VAR
             BEQ   KEYCURSOR          ; *FX4,0 - editing keys
             CPY   #$C9
             CLV
             BEQ   KEYCOPYTAB         ; TAB key
             DEX
             BNE   KEYSOFTHI          ; Not *FX4,1 - soft key
             SBC   #$44               ; Return $88-$8B
KEYREADOK1   CLC
KEYREADOK    RTS

* Process soft key
KEYSOFTHI    LDX   FX254VAR
             CPX   #$C0
             BCC   KEYSOFTY
             TYA
             EOR   #$40               ; Toggle keyboard map
*             AND   #$BF
             TAY
KEYSOFTY     TYA                      ; Get key including Shift/Ctrl
             LSR   A
             LSR   A
             LSR   A
             LSR   A                  ; A=key DIV 16
             EOR   #$04               ; Offset into KEYBASE
             TAX
             LDA   FXKEYBASE-8,X
             BEQ   KEYNONE            ; Value 0 means 'ignore key'
             DEC   A
             BEQ   KEYEXPAND          ; Value 1 means 'expand key'
             TYA
             AND   #$0F
             CLC
             ADC   FXKEYBASE-8,X
             CLC
             RTS

* Expand soft key
* On entry: Y=key code ($Xn where n is soft key number)
KEYEXPAND    TYA
             AND   #$0F               ; Obtain soft key number
             >>>   RDMAIN
             JSR   KEYOFFLEN          ; Get offset and length of key
             >>>   RDAUX
             STX   FXSOFTOFF
             STA   FXSOFTLEN
             BRA   KEYREAD1           ; Go back and start fetching

* Process cursor keys
KEYCURSOR    CMP   #$C9
             BEQ   KEYCOPY
             PHA
             LDA   OLDCHAR
             JSR   REMCURSOR          ; Remove cursor [OFF]
             PLA
             JSR   COPYMOVE           ; Move copy cursor
             JSR   GETCHRC            ; Save char under cursor
             STA   OLDCHAR
KEYNONE      SEC
KBDDONE2     RTS

KEYCOPY      BIT   VDUSTATUS
KEYCOPYTAB   LDA   FXTABCHAR          ; Prepare TAB if no copy cursor
             BVC   KEYREADOK1         ; No copy cursor, return TAB
             LDA   OLDCHAR            ; Get the char under cursor
             PHA
             JSR   PUTCOPYCURS        ; Output it to restore and move cursor [OFF]
             JSR   GETCHRC            ; Save char under cursor
             STA   OLDCHAR
             PLA
             BNE   KEYREADOK1         ; Ok character
             SEC
             JMP   BEEP               ; Beep and return CS=No char


* KBDREAD
************************
* Test for and fetch key from keyboard
* Updated for ADB keyboards
*
* On exit, CS=no keypress
*          CC=keypress
*          A =keycode, X=corrupted
* Apple+Letter  -> Ctrl+Letter
* AppleL+digit  -> 80+x                  fkey -> 80+x
* AppleR+digit  -> 90+x            Shift+fkey -> 90+x
* AppleLR+digit -> A0+x             Ctrl+fkey -> A0+x
* TAB           -> $C9        Shift+Ctrl+fkey -> B0+x
* Cursors       -> $CC-$CF
* Keypad        -> PADBASE+key
*
KBDREAD      CLV                      ; VC=return keypress
KBDTEST      LDA   KBDDATA            ; VS here to test for keypress
             EOR   #$80               ; Toggle bit 7
             CMP   #$80
             BCS   KBDDONE2           ; No key pressed
             BVS   KBDDONE2           ; VS=test for keypress
             STA   KBDACK             ; Ack. keypress
KBDREAD2
             PHA
             JSR   BYTE76A            ; Check keyboard modifiers
             BVC   KBDREAD5           ; Not keypad
             PLA                      ; Get raw keycode back

*             TAX                      ; X=raw keypress
** NB: BYTE76A corrupts X
** Set FXKBDSTATE to %x0CS0000 from Alt or Shift keys
*             LDA   KBDAPPRGT          ; Right Apple/Alt pressed
*             ASL   A
*             LDA   KBDAPPLFT          ; Left Apple/Alt pressed
*             ROR   A                  ; b7=Right, b6=Left
*             AND   #$C0
*             LSR   A
*             LSR   A
*             PHP                      ; Save EQ=no ALTs pressed
*             BEQ   KBDREAD2A
*             ADC   #$F0               ; Convert into fkey modifer
*KBDREAD2A    STA   FXKBDSTATE
*             BIT   VDUBANK
*             BPL   KBDREAD5           ; Not IIgs
*             LDA   KBDMOD             ; Get extended KBD state
*             PLP
*             PHP
*             BNE   KBDREAD2B          ; ALTs pressed, skip
*             PHA                      ; Save b4=Keypad
*             ASL   A
*             ASL   A
*             ASL   A
*             ASL   A                  ; b5=Ctrl, b4=Shift
*             AND   #$30
*             STA   FXKBDSTATE
*             PLA
**
*KBDREAD2B    AND   #$10
*             BEQ   KBDREAD5           ; Not keypad
*             PLP                      ; Drop NoALT
*             TXA                      ; A=raw keypress

             BMI   KBDREADPAD         ; Translate keypad
             CMP   #$60
             BCC   KBDREADPAD
             TAX
             LDA   KBDADBKEYS-$60,X   ; Translate $60-$7E keys
             BRA   KBDREAD6

KBDREADPAD   LDX   FXKEYPADBASE
             BEQ   KBDCHKESC          ; $00=use unchanged
             BPL   KBDREAD4           ; Keypad not function keys
             CMP   #$20
             BCC   KBDCHKESC          ; Don't translate control chars
             CMP   #$3D
             BNE   KBDREAD3           ; Special case for KP'='
             DEC   A
KBDREAD3     ORA   #$30               ; Ensure $30-$3F
KBDREAD4     SEC
             SBC   #$30               ; Convert to offset from $30
             CLC
             ADC   FXKEYPADBASE       ; Add to keypad base
             BRA   KBDREAD6

* Special-case checks
KBDREADX2    LDA   #$1A               ; Alt-Ctrl-2 -> f2
KBDREADX6    EOR   #$98               ; Alt-Ctrl-6 -> f6
             BNE   KBDFUNC

KBDREAD5
             LSR   A
             LSR   A                  ; Cy=ALTs pressed
             PLA                      ; A=raw keypress
             BCC   KBDNOALT           ; No ALTs pressed

*             TXA                      ; A=raw keypress
*             PLP
*             BEQ   KBDNOALT           ; No ALTs pressed

*
KBDALT
*             TXA
             BEQ   KBDREADX2          ; RAlt-2
             CMP   #$1E
             BEQ   KBDREADX6          ; RAlt-6
             CMP   #$40
             BCS   KBDCTRL            ; 'A'+ Alt+letter ->Control code
             CMP   #$30
             BCC   KBDCHKESC          ; <'0' Alt+nondigit -> keep
             CMP   #$3A
             BCS   KBDCHKESC          ; >'9' Alt+nondigit -> keep
             ORA   #$80               ; Alt+digit -> function key
*
KBDREAD6     BPL   KBDCHKESC          ; Not a top-bit key
KBDFUNC      AND   #$CF               ; Clear Ctrl+Shift bits
*             ORA   FXKBDSTATE         ; Add in Ctrl+Shift
             ORA   OSKBD3             ; Add in Ctrl+Shift
*
* Test for Escape character
KBDCHKESC    TAX                      ; X=processed keycode
             EOR   FXESCCHAR          ; Current ESCAPE char?
             ORA   FXESCON            ; Is ESCAPE an ASCII char?
             BNE   KBDNOESC           ; Not ESCAPE or ESCAPE=ASCII
             LDA   FX200VAR           ; Is ESCAPE ignored?
             LSR   A                  ; Check bit 0
             BCS   KBDDONE            ; ESCAPE completely ignored
             SEC
             ROR   ESCFLAG            ; Set Escape flag
KBDNOESC     TXA                      ; A=keycode
             CLC                      ; CLC=Ok
KBDDONE      RTS

* Moved here to reduce BRx ranges
KBDCTRL      AND   #$1F               ; Apple-Letter -> Ctrl-Letter
             BRA KBDCHKESC
 
KBDNOALT     CMP   #$09
             BEQ   KBDTAB             ; TAB is dual action TAB/COPY
             CMP   #$08
             BCC   KBDCHKESC          ; <$08 not cursor key
             CMP   #$0C
             BCC   KBDCURSR           ; $08-$0B are cursor keys
             CMP   #$15
             BNE   KBDCHKESC          ; $15 is cursor key
KBDCUR15     LDA   #$0D               ; Convert RGT to $09
KBDTAB       SBC   #$04               ; Convert TAB to &C9
KBDCURSR     CLC
             ADC   #$C4               ; Cursor keys $C0+x
             BRA   KBDFUNC

KBDADBKEYS   DB    $85,$86,$87,$83,$88,$89,$80,$8B
             DB    $80,$8D,$80,$8E,$80,$8A,$80,$8C
             DB    $80,$8F,$C6,$C8,$CB,$C7,$84,$87
             DB    $82,$CA,$81,$CC,$CD,$CE,$C4,$7F

* Poll the keyboard to update Escape state
* On exit, MI=Escape state pending
*          CC=key pressed, CS=no key pressed
*          A=character
*          X,Y=preserved
*
ESCPOLL      BIT   SETV               ; Set V
             JSR   KBDTEST            ; VS - test keyboard
             BCS   ESCPOLL9           ; No keypress pending
             PHX                      ; KBDREAD corrupts A,X
             JSR   KBDREAD2           ; Read key and check for Escape, returns CC
             PLX
ESCPOLL9     BIT   ESCFLAG            ; Return with Escape state
             RTS

* Process pending Escape state
BYTE7E       STA   KBDACK             ; Flush keyboard
             LDX   #$00               ; $7E = ack detection of ESC
             BIT   ESCFLAG
             BPL   BYTE7DOK           ; No Escape pending
             LDA   FXESCEFFECT        ; Process Escape effects
             BEQ   BYTE7E2
             CLI                      ; Allow IRQs while flushing
             STX   FXLINES            ; Clear scroll counter
             STX   FXSOFTLEN          ; Cancel soft key expansion
             JSR   CMDEXEC0           ; Close any EXEC file
*             JSR   BUFFLUSHALL       ; Flush all buffers (this should do FXSOFTLEN)
BYTE7E2      LDX   #$FF               ; X=$FF, Escape was pending
BYTE7C       CLC                      ; &7C = clear escape condition
BYTE7D       ROR   ESCFLAG            ; $7D = set escape condition
BYTE7DOK     RTS

* Update KBDSTATE and return state of SHIFT and CTRL keys
* Returns A=X=      =%SxxxxEAx
*         Flags     =C=Ctrl, M=Shift, V=Extended key
*         OSKBD3    =%00CS0000
*         FXKBDSTATE=%CSxxxxEA C=Ctrl, S=Shift, E=Extended, A=Apple
BYTE76       JSR   ESCPOLL
             CLC
             BMI   BYTE76X            ; Escape pending, return M=Shift, C=None
BYTE76A      LDA   KBDAPPRGT          ; Right Apple/Alt pressed
             ASL   A
             LDA   KBDAPPLFT          ; Left Apple/Alt pressed
             ROR   A                  ; b7=Right, b6=Left
             AND   #$C0
             PHP                      ; Save EQ=no ALTs pressed
             BEQ   BYTE76C
             ADC   #$C1               ; Convert into fkey modifer, b0=1
BYTE76C      STA   OSKBD3
             BIT   VDUBANK
             BPL   BYTE76E            ; Not IIgs
             LDA   KBDMOD             ; Get extended KBD state
             ROR   A
             ROR   A
             ROR   A                  ; b7=Ctrl, b6=Shift, b1=Extended
             AND   #$C2
             PLP
             BEQ   BYTE76D
             AND   #$02               ; ALTs pressed, just keep Extend
BYTE76D      ORA   OSKBD3
             STA   OSKBD3             ; Update with Ctrl/Shift/Extend
             PHP                      ; Balance stack
BYTE76E      PLP                      ; Drop flags, NE=either ALT pressed
             LSR   OSKBD3             ; Adjust for soft key modifier
             LSR   OSKBD3             ; b5=Ctrl, b4=Shift, Cy=Extend
             CLV                      ; CLV=Not Extend
             BCC   BYTE76F
             BIT   SETV               ; SEV=Extend
BYTE76F      LSR   A                  ; Test ALT bit in bit 0
             BCC   BYTE76G
             ORA   #$20
BYTE76G      ROL   A                  ; Put bit 0 back
             STA   FXKBDSTATE
             ASL   A                  ; C=Ctrl, M=Shift
             TAX                      ; X.b7=Shift
BYTE76X      RTS

* Call BYTE76 to get state of SHIFT/CTRL to pause/restore scrolling
* Left and Right Apple keys simulate SHIFT/CTRL when no KBDMOD register
* Returns: M   =SHIFT or one APPLE key pressed
*          C   =CTRL pressed
*          M+C =SHIFT+CTRL pressed or both APPLE keys pressed
* Escape will abort and return MI+CC to simulate SHIFT to continue
*
* Scrolling can pause with:
* LOOP:
* JSR BYTE76
* BPL EXIT ; SHIFT not pressed
* BCS LOOP ; SHIFT+CTRL pressed
* EXIT:
* 
* Paged mode can be released with:
* LOOP:
* JSR BYTE76
* BPL LOOP ; SHIFT not pressed
*
