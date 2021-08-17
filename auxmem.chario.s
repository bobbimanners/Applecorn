*********************************************************
* Kernel / Character I/O
*********************************************************

* KERNEL/CHARIO.S
*****************
* Character read and write
*
* 14-Aug-2021 Flashing cursor and INKEY sync'd to frame rate
*             with VBLK. Ensured cursor turned on straight away.
* 15-Aug-2021 Cursor keys move copy cursor, copy reads char.
*             Copy cursor not visible yet.
* 16-Aug-2021 Copy cursor and Edit cursor visible.


* TEMP:
FLASHER     EQU   $290
CURSOR      EQU   $291
OLDCHAR     EQU   $292
COPYCHAR    EQU   $293

FXTABCHAR   EQU   BYTEVARBASE+219
FXESCCHAR   EQU   BYTEVARBASE+220
FXESCON     EQU   BYTEVARBASE+229
FX2VAR      EQU   BYTEVARBASE+$B1
FX3VAR      EQU   BYTEVARBASE+$EC
FX4VAR      EQU   BYTEVARBASE+$ED


* OSWRCH handler
****************
* Send a character to current output
* All registers preserved
*
WRCHHND     PHA
            PHX
            PHY
* TO DO Check any output redirections
* TO DO Check any spool output
            JSR   OUTCHAR
* TO DO Check any printer output
            PLY
            PLX
            PLA
            RTS

* OSRDCH/INKEY handler
**********************
* Read a character from current input
* All registers preserved except A, Carry
* Flashes a fake cursor while waiting for input
*
RDCHHND     LDA   #$80             ; flag=wait forever
            PHY
            TAY
* TEST
            LDA   CURSOR
            BNE   INKEYGO
            LDA   #'_'
            STA   CURSOR
            LDA   #$1B
            STA   FXESCCHAR
* TEST
            BRA   INKEYGO          ; Wait forever for input

; XY<$8000 - wait for a keypress
INKEY       PHY                    ; Dummy PHY to balance RDCH
INKEYGO     PHX                    ; Save registers
            PHY
            JSR   GETCHRC          ; Get character under cursor
            STA   OLDCHAR
* This can be optimised
            BIT   VDUSTATUS
            BVC   INKEYGO2         ; No editing cursor
            STA   COPYCHAR         ; Save char under edit cursor
            LDA   #$A0
            JSR   PUTCHRC          ; Display edit cursor
            JSR   COPYSWAP1        ; Swap to copy cursor
            JSR   GETCHRC          ; Get character under copy cursor
            STA   OLDCHAR
*
INKEYGO2    CLI
            BRA   INKEY1           ; Turn cursor on
;
INKEYLP1    PHX
INKEYLP2    PHY
INKEYLP     CLC
            LDA   #$01             ; Slow flash, every 32 frames
            BIT   VDUSTATUS
            BVC   INKEY0
            ASL   A                ; Fast flash, every 16 frames
INKEY0      ADC   FLASHER
            STA   FLASHER
            AND   #15
            BNE   INKEY3           ; Not time to toggle yet
            LDA   OLDCHAR          ; Prepare to remove cursor
            BIT   FLASHER
            BMI   INKEY2           ; Remove cursor
INKEY1      LDA   CURSOR           ; Add cursor
INKEY2      JSR   PUTCHRC          ; Toggle cursor
INKEY3      LDA   ESCFLAG
            BMI   INKEYOK          ; Escape pending, return it
INKEY4      JSR   KEYREAD          ; Test for input, all can be trashed
            BCC   INKEYOK          ; Char returned, return it
;
* VBLK pulses at 50Hz, changes at 100Hz
* (60Hz in US, will need tweeking)
            LDX   $C019            ; Get initial VBLK state
INKEY5      BIT   $C000
            BMI   INKEY4           ; Key pressed
            TXA
            EOR   $C019
            BPL   INKEY5           ; Wait for VBLK change
;
            PLY
            BMI   INKEYLP2         ; Loop forever
            PLX
            TXA
            BNE   INKEYDEC         ; Decrement XY
            DEY
INKEYDEC    DEX
            BNE   INKEYLP1         ; Not 0, loop back
            TYA
            BNE   INKEYLP1         ; Not 0, loop back
            DEY                    ; Y=$FF
            TYA                    ; A=$FF
            PLX                    ; Drop dummy PHY
            RTS                    ; CS from above
; Timeout: CS, AY=$FFFF, becomes XY=$FFFF

INKEYOK     PHA
* This can be optimised
            BIT   VDUSTATUS
            BVC   INKEYOK2         ; No editing cursor
            LDA   OLDCHAR
            JSR   PUTCHRC          ; Remove copy cursor
            JSR   COPYSWAP1        ; Swap cursor back
            LDA   COPYCHAR
            BRA   INKEYOK3         ; Restore char under edit cursor
*
INKEYOK2    LDA   OLDCHAR          ;  and swap cursor back
INKEYOK3    JSR   PUTCHRC          ; Remove edit cursor
            PLA
            PLY                    ; <$80=INKEY or $80=RDCH
            PLX                    ; Restore X
            PLY                    ; <$80=INKEY or restore=RDCH
            PHA                    ; Save char for a mo
            LDA   ESCFLAG
            ASL   A                ; Cy=Escape flag
            PLA                    ; Get char back
            RTS
; Character read: CC, A=char, X=???, Y<$80
; Escape:         CS, A=??  , X=???, Y<$80


BYTE81      TYA
            BMI   NEGINKEY         ; XY<0, scan for keypress
            JSR   INKEY            ; XY>=0, wait for keypress
*  Y=$FF, A=FF,   X=??, CS - timeout
*  Y<$80, A=esc,  X=??, CS - escape
*  Y<$80, A=char, X=??, CC - character read
            TAX                    ; X=character returned
            TYA
            BMI   BYTE81DONE       ; Y=$FF, timeout
            LDY   #$00
            BCC   BYTE81DONE       ; CC, not Escape
            LDY   #$1B             ; Y=27
BYTE81DONE  RTS
* Returns: Y=$FF, X=$FF, CS  - timeout
*          Y=$1B, X=???, CS  - escape
*          Y=$00, X=char, CC - keypress

NEGINKEY    LDX   #$00             ; Unimplemented
            LDY   #$00
            CLC
            RTS


* KERNEL/KEYBOARD.S
*******************

* KEYREAD
*************************
* Test for and read from input,
* expanding keyboard special keys
*
* On exit, CS=no keypress
*          CC=keypress
*          A =keycode, X=corrupted
KEYREAD
* TO DO: check *EXEC source
* TO DO: expand current soft key
            JSR   KBDREAD          ; Fetch character from KBD "buffer"
            BCS   KEYREADOK        ; Nothing pending
* TO DO: process new soft keys
*
* Process cursor keys
* TO DO: check FX4VAR
KEYCURSOR   CMP   #$C9
            BEQ   KEYCOPY
            CMP   #$CC
            BCC   KEYREADOK        ; Not cursor key
            PHA
            LDA   OLDCHAR
            JSR   PUTCHRC          ; Remove cursor
            PLA
            JSR   COPYMOVE         ; Move copy cursor
            JSR   GETCHRC          ; Save char under cursor
            STA   OLDCHAR
            SEC
KEYREADOK   RTS

KEYCOPY     LDA   FXTABCHAR        ; Prepare TAB if no copy cursor
            BIT   VDUSTATUS
            BVC   KEYREADOK        ; No copy cursor, return TAB
            LDA   OLDCHAR          ; Get the char under cursor
            PHA
            JSR   OUTCHARGO        ; Output it to restore and move cursor
            JSR   GETCHRC          ; Save char under cursor
            STA   OLDCHAR
            PLA
            BNE   KEYCOPYOK        ; Ok character
            SEC
            JMP   BEEP             ; Beep and return CS=No char
KEYCOPYOK   CLC
            RTS                    ; Return the character


* KBDREAD
*************************
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
KBDREAD     CLV                    ; VC=return keypress
KBDTEST     LDA   $C000            ; VS here to test for keypress
            EOR   #$80             ; Toggle bit 7
            CMP   #$80
            BCS   KBDDONE          ; No key pressed
            BVS   KBDDONE          ; VS=test for keypress
            STA   $C010            ; Ack. keypress
            BIT   $C061
            BMI   KBDLALT          ; Left Apple pressed
            BIT   $C062
            BMI   KBDRALT          ; Right Apple pressed
            CMP   #$09
            BEQ   KBDTAB           ; 
            CMP   #$08
            BCC   KBDESC           ; <$08 not cursor key
            CMP   #$0C
            BCC   KBDCURSR
            CMP   #$15
            BEQ   KBDCUR15
* Test for Escape key
KBDESC      CMP   FXESCCHAR        ; Current ESCAPE char?
*           CMP   #27        ; TEMP
            BNE   KBDNOESC         ; No
            LDX   FXESCON          ; Is ESCAPE enabled?
            BNE   KBDNOESC         ; No
            ROR   ESCFLAG          ; Set Escape flag
KBDNOESC    CLC                    ; CLC=Ok
KBDDONE     RTS

KBDRALT                            ; Right Apple key pressed
KBDLALT     CMP   #$40             ; Left Apple key pressed
            BCS   KBDCTRL
            CMP   #$30
            BCC   KBDFUNOK         ; <'0'
            CMP   #$3A
            BCS   KBDOK            ; >'9'
KBDFUNC     AND   #$0F             ; Convert Apple-Num to function key
            ORA   #$80
            BIT   $C062
            BPL   KBDFUNOK         ; Left+Digit       -> $8x
            ORA   #$90             ; Right+Digit      -> $9x
            BIT   $C061
            BPL   KBDFUNOK
            EOR   #$30             ; Left+Right+Digit -> $Ax
KBDFUNOK    RTS
KBDCTRL     AND   #$1F             ; Apple-Letter -> Ctrl-Letter
KBDOK       CLC
            RTS

KBDTAB      LDA   #$11             ; Convert TAB to $C9, expanded later
KBDCUR15    SBC   #$0C             ; Convert RGT to $09
KBDCURSR    CLC
            ADC   #$C4             ; Cursor keys $CC-$CF
            RTS                    ; CLC=Ok set earlier



