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
             LDX   #$83               ; Default KBD=Native, MODE=3
             STX   FX254VAR           ; b7-b4=default KBD map, b3-b0=default MODE
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
             JSR   PUTCHRC            ; Display edit cursor
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
             BMI   INKEY2             ; Remove cursor
INKEY1       LDA   CURSOR             ; Add cursor
             BIT   VDUSTATUS
             BVC   INKEY2
             LDA   CURSORCP
INKEY2       JSR   PUTCHRC            ; Toggle cursor
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
             JSR   PUTCHRC            ; Remove cursor
             JSR   COPYSWAP1          ; Swap cursor back
             LDA   COPYCHAR           ; Remove main cursor
INKEYOFF2    JSR   PUTCHRC            ; Remove cursor
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
* we don't know how long the new definition is and if
* it will fit into memory until after we've parsed it, so
* we either have to store it to a temp area or parse it
* twice.
*
* All this, and we need a structure that is reasonably coded,
* but with the priority to be easy for KEYREAD to extract
* from (as called more often), even if at expense of storing
* being more complex.
*
* Optimisations:
* BBC doesn't care if the new definition is valid, it removes
* the current definition before parsing, so a parse error
* results in the definition being cleared.
* eg *KEY 1 HELLO, *KEY 1 X gives Bad string and key 1=""
*
* BBC uses (simplified):
* SOFTBUF+key+0  -> start of definition
* SOFTBUF+key+1  -> after last byte of definition
* SOFTBUF+16     -> free space after end of last definition
*  definitions stored in order of creation
*
* Master uses:
* SOFTBUF+key    -> lo.start of definition
* SOFTBUF+key+17 -> hi.start of definition
* SOFTBUF+key+1  -> lo.after last byte definition
* SOFTBUF+key+18 -> hi.after last byte definition
* SOFTBUF+16/33  -> free space after last byte last definition
*  definitions stored in key order
*
* Initial development layout:
* 00..0F -> length of string 0..15
* 10...  -> strings in key order
* (len0+len1+...len15) => start of free space
*
STARKEY1     STA   FKEYNUM            ; Key number being defined
             JSR   KEYOPENGAP
             JSR   SKIPCOMMA
             SEC
             JSR   GSINIT             ; Initialise '*KEY-type string'
             LDX   KEYINS             ; Starting point to insert
STARKEYLP1   JSR   GSREAD
             BCS   STARKEYEND
             >>>   WRTMAIN            ; Write main memory
             STA   FKEYBUF,X          ; Store char of definition
             >>>   WRTAUX             ; Back to writing aux again
             INX
             CPX   MOVEDST            ; See if we are out of space
             BNE   STARKEYLP1
             LDX   FKEYNUM
             >>>   WRTMAIN            ; Write main memory
             STZ   FKEYLENS,X         ; Out of space. Set len=0
             >>>   WRTAUX             ; Back to writing aux again
             BRA   STARKEYCLS
STARKEYEND   TXA                      ; Last idx+1
             SEC                      ; Compute length
             SBC   KEYINS
             LDX   FKEYNUM
             >>>   WRTMAIN            ; Write main memory
             STA   FKEYLENS,X         ; Store length of new def
             >>>   WRTAUX             ; Back to writing aux again
STARKEYCLS   JSR   KEYCLSGAP
             RTS
FKEYNUM      DB    $00
KEYINS       DB    $00


* Open gap in FKEYBUF to allow new def to be inserted
* Moved defs for keys FKEYNUM+1..15 to top of FKEYBUF
* Preserves A,X,Y
KEYOPENGAP   PHA
             PHX
             PHY
             LDX   FKEYNUM            ; Key being defined
             JSR   KEYSUMLENS         ; Len of defs 0..X exclusive
             STA   KEYINS             ; Offset for insert
             LDX   FKEYNUM            ; Key being defined
             INX
             JSR   KEYSUMLENS         ; Len of defs 0..X exclusive
             STA   MOVESRC            ; Source offset for move
             LDX   #16                ; Sum keys 0..15 (ie: all)
             JSR   KEYSUMLENS         ; Sum them all
             SEC
             SBC   MOVESRC            ; Compute length to move
             STA   MOVELEN
             LDA   #$FF               ; Length of FKEYBUF
             SEC
             SBC   MOVELEN            ; Compute dest for move
             STA   MOVEDST            ; Dest offset for move
             JSR   MOVEKEYS           ; Open the gap
             PLY
             PLX
             PLA
             RTS
* After the gap is opened, there is freespace from MOVESRC to MOVEDST-1


* Close gap in FKEYBUF after def has been inserted
* Preserves A,X,Y
KEYCLSGAP    PHA
             PHX
             PHY
             LDA   #$FF               ; Length of FKEYBUF
             SEC
             SBC   MOVEDST            ; Previous dest, to calc length
             STA   MOVELEN            ; Length for move
             LDA   MOVEDST            ; Old dest ...
             STA   MOVESRC            ; ... is new source
             LDX   FKEYNUM            ; Key being defined
             INX
             JSR   KEYSUMLENS         ; Len of defs 0..X exclusive
             STA   MOVEDST            ; New dest
             JSR   MOVEKEYS           ; Close the gap
             PLY
             PLX
             PLA
             RTS


* Add lengths of *KEY definitions together
* On entry: X is the highest key num + 1 (sums 0..X-1)
* On return: Sum in A (exclusive of X)
* From *KEY0 to *KEYn where n is value in X
KEYSUMLENS   LDA   #$00               ; Clear sum
:LOOP        CPX   #$00
             BEQ   :DONE
             >>>   RDMAIN             ; Read main memory
             CLC
             ADC   FKEYLENS-1,X       ; Add lengths
             >>>   RDAUX              ; Read aux memory
             DEX
             BRA   :LOOP
:DONE        RTS
             

* Move key definitions within FKEYBUF
* Copies MOVELEN bytes from MOVSRC->MOVDST within FKEYBUF
MOVEKEYS     LDX   MOVESRC
             LDY   MOVEDST
:L1          LDA   MOVELEN
             BEQ   :DONE
             >>>   RDMAIN             ; Read main memory
             LDA   FKEYBUF,X
             >>>   RDAUX              ; Read aux memory
             >>>   WRTMAIN            ; Write main memory
             STA   FKEYBUF,Y
             >>>   WRTAUX             ; Write aux memory
             INX
             INY
             DEC   MOVELEN
             BRA   :L1
:DONE        RTS
MOVESRC      DB    $00                ; Source offset in FKEYBUF
MOVEDST      DB    $00                ; Dest offset in FKEYBUF
MOVELEN      DB    $00                ; # bytes remaining to move


* OSBYTE &12 - Clear soft keys
* ----------------------------
SOFTKEYCHK   LDA   FXSOFTOK
             BEQ   BYTE12OK           ; Soft keys ok, exit
BYTE12
*             LDX   #$FF
*             STX   FXSOFTOK           ; Soft keys being updated
*:L1          >>>   WRTMAIN            ; Zero the buffer (nice when debugging)
*             STZ   FKEYBUF,X
*             >>>   WRTAUX
*             DEX
*             BNE   :L1
             LDX   #15
             STX   FXSOFTOK           ; Soft keys being updated
             >>>   WRTMAIN            ; Short enough to page for whole loop
:L2          STZ   FKEYLENS,X         ; Zero the lengths
             DEX
             BNE   :L2
             >>>   WRTAUX
             STZ   FXSOFTOK           ; Soft keys updated
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
             TAX
             PHX
             JSR   KEYSUMLENS         ; Obtain starting offset
             STA   FXSOFTOFF		; SOFTKEYOFF
             PLX
             >>>   RDMAIN
             LDA   FKEYLENS,X         ; Obtain length of *KEY string
             >>>   RDAUX
             STA   FXSOFTLEN
             RTS

* Process cursor keys
KEYCURSOR    CMP   #$C9
             BEQ   KEYCOPY
             PHA
             LDA   OLDCHAR
             JSR   PUTCHRC            ; Remove cursor
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
             JSR   OUTCHARCP          ; Output it to restore and move cursor
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
* AppleL+digit  -> 80+x
* AppleR+digit  -> 90+x
* AppleLR+digit -> A0+x
* TAB           -> $C9
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
KBDREAD2     TAX                      ; X=raw keypress
*
* Set FXKBDSTATE to %x0CS0000 from Alt or Shift keys
             LDA   KBDAPPRGT          ; Right Apple/Alt pressed
             ASL   A
             LDA   KBDAPPLFT          ; Left Apple/Alt pressed
             ROR   A                  ; b7=Right, b6=Left
             AND   #$C0
             LSR   A
             LSR   A
             PHP                      ; Save EQ=no ALTs pressed
             BEQ   KBDREAD2A
             ADC   #$F0               ; Convert into fkey modifer
KBDREAD2A    STA   FXKBDSTATE
             BIT   VDUBANK
             BPL   KBDREAD5           ; Not IIgs
             LDA   KBDMOD             ; Get extended KBD state
             PLP
             PHP
             BNE   KBDREAD2B          ; ALTs pressed, skip
             PHA                      ; Save b4=Keypad
             ASL   A
             ASL   A
             ASL   A
             ASL   A                  ; b5=Ctrl, b4=Shift
             AND   #$30
             STA   FXKBDSTATE
             PLA
*
KBDREAD2B    AND   #$10
             BEQ   KBDREAD5           ; Not keypad
             PLP                      ; Drop NoALT
             TXA                      ; A=raw keypress
             BMI   KBDREADPAD         ; Translate keypad
             CMP   #$60
             BCC   KBDREADPAD
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

KBDREAD5     TXA                      ; A=raw keypress
             PLP
             BEQ   KBDNOALT           ; No ALTs pressed
*
KBDALT       CMP   #$40
             BCS   KBDCTRL            ; 'A'+ Alt+letter ->Control code
             CMP   #$30
             BCC   KBDCHKESC          ; <'0' Alt+nondigit -> keep
             CMP   #$3A
             BCS   KBDCHKESC          ; >'9' Alt+nondigit -> keep
             ORA   #$80               ; Alt+digit -> function key
*
KBDREAD6     BPL   KBDCHKESC          ; Not a top-bit key
KBDFUNC      AND   #$CF               ; Clear Ctrl+Shift bits
             ORA   FXKBDSTATE         ; Add in Ctrl+Shift
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

BYTE76       LDX   #$00               ; Update LEDs and return X=SHIFT
             RTS                      ; Not possible with Apple

