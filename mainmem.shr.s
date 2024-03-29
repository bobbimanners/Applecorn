* MAINMEM.SHR.S
* (c) Bobbi 2022 GPLv3
*
* Routines for drawing bitmapped text and graphics in SHR mode
* on Apple IIGS (640x200 4 colour, or 320x200 16 colour.)
*
* This code is in main memory only to save space in aux LC.
*

******************************************************************************
* Data in bank $E1
******************************************************************************

SHRFONTXPLD   EQU   $A000                  ; Explode SHR font to $E1:A000

******************************************************************************

* 21 bytes of persistent storage, also accessed by mainmem code
* TODO: Move to SHRZP maybe
SHRPIXELS     DB    $00                    ; Main memory copy of VDUPIXELS
SHRVDUQ       DS    16                     ; Main memory copy of VDUQ
SHRGFXFGMASK  DB    $00                    ; Foreground colour mask
SHRGFXFGMSK2  DB    $00                    ; Copy of foreground colour mask
SHRGFXBGMASK  DB    $00                    ; Background colour mask
SHRGFXACTION  DB    $00                    ; GCOL action for point plotting

* These are all persistent locals (14 bytes of ZP)
SHRXPIXEL     EQU   SHRZP+0                ; Prev point in screen coords (word)
SHRYPIXEL     EQU   SHRZP+2                ; Prev point in screen coords (word)
SHRWINLFT     EQU   SHRZP+4                ; Gfx win - left (0-639) (word)
SHRWINRGT     EQU   SHRZP+6                ; Gfx win - right (0-639) (word)
SHRWINTOP     EQU   SHRZP+8                ; Gfx win - top (0-199) (word)
SHRWINBTM     EQU   SHRZP+10               ; Gfx win - bottom (0-199) (word)


* Colours in the following order.
* For 16 colour modes ...
* BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE, ...
* For 4 colour modes ...
* BLACK, RED, YELLOW, WHITE

*                    GB   0R
PALETTE320    DB    $00, $00               ; BLACK
              DB    $00, $0F               ; RED
              DB    $F0, $00               ; GREEN
              DB    $F0, $0F               ; YELLOW
              DB    $0F, $00               ; BLUE
              DB    $0F, $0F               ; MAGENTA
              DB    $FF, $00               ; CYAN
              DB    $FF, $0F               ; WHITE
              DB    $44, $04               ; Dark grey
              DB    $88, $0F               ; RED (light)
              DB    $F8, $08               ; GREEN (light)
              DB    $F8, $0F               ; YELLOW (light)
              DB    $8F, $08               ; BLUE (light)
              DB    $8F, $0F               ; MAGENTA (light)
              DB    $FF, $08               ; CYAN (light)
              DB    $AA, $0A               ; Light grey

PALETTE640    DB    $00, $00               ; BLACK
              DB    $00, $0F               ; RED
              DB    $F0, $0F               ; YELLOW
              DB    $FF, $0F               ; WHITE
              DB    $00, $00               ; BLACK
              DB    $00, $0F               ; RED
              DB    $F0, $0F               ; YELLOW
              DB    $F8, $0F               ; WHITE
              DB    $00, $00               ; BLACK
              DB    $00, $0F               ; RED
              DB    $F0, $0F               ; YELLOW
              DB    $FF, $0F               ; WHITE
              DB    $00, $00               ; BLACK
              DB    $00, $0F               ; RED
              DB    $F0, $0F               ; YELLOW
              DB    $FF, $0F               ; WHITE


* Explode font to generate SHRFONTXPLD table
* This is 2 bytes x 8 rows for each character in 640 mode
* or      4 bytes x 8 rows for each character in 320 mode
SHRXPLDFONT   >>>   ENTMAIN
              LDA   #<SHRFONTXPLD          ; Use A3L/H to point to ..
              STA   A3L                    ; .. start of table to write
              LDA   #>SHRFONTXPLD
              STA   A3H
              LDA   #$E1                   ; Memory bank $E1
              STA   A4L
              LDA   #32                    ; First char number
:L1           JSR   SHRXPLDCHAR            ; Explode char A
              INC   A
              CMP   #128                   ; 96 chars in FONT8
              BNE   :L1
              JSR   SHRCLR24               ; Clear row 24
              >>>   XF2AUX,SHRV22RET


* Explode one character to location pointed to by A3L
* On entry: A - character to explode
SHRXPLDCHAR   PHA
              SEC
              SBC   #32
              STA   A1L                    ; A*8 -> A1L/H
              STZ   A1H
              ASL   A1L
              ROL   A1H
              ASL   A1L
              ROL   A1H
              ASL   A1L
              ROL   A1H
              CLC                          ; FONT8+A*8 -> A1L/H
              LDA   A1L
              ADC   #<FONT8
              STA   A1L
              LDA   A1H
              ADC   #>FONT8
              STA   A1H
              LDY   #$00                   ; First row of char
:L1           LDA   (A1L),Y                ; Load row of font
              JSR   SHRXPLDROW
              INY                          ; Next row of font
              CPY   #$08                   ; Last row?
              BNE   :L1
              PLA
              RTS


* Explode one pixel row of user defined graphics char
SHRUSERCHAR   >>>   ENTMAIN
              LDA   #<SHRFONTXPLD          ; Use A3L/H to point to ..
              STA   A3L                    ; .. start of table to write
              LDA   #>SHRFONTXPLD
              STA   A3H
              LDA   #$E1                   ; Bank $E1
              STA   A4L

              LDA   SHRVDUQ+0              ; Character number
              CMP   #32                    ; < 32? Then bail out
              BCC   :DONE
              SEC                          ; Otherwise, subtract 32
              SBC   #32
              TAY

              LDA   #16                    ; Bytes/char in 640 mode              
              LDX   SHRPIXELS              ; Pixels per byte
              CPX   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :S0
              LDA   #32                    ; Bytes/char in 320 mode
:S0           STA   :INCREMENT

:L0           CPY   #$00
              BEQ   :S1
              CLC
              LDA   A3L
              ADC   :INCREMENT
              STA   A3L
              LDA   A3H
              ADC   #$00
              STA   A3H
              DEY
              BRA   :L0

:S1           LDY   #$00
:L1           LDA   SHRVDUQ+1,Y            ; Row of pixels
              JSR   SHRXPLDROW
              INY
              CPY   #$08                   ; Last row?
              BNE   :L1
:DONE         >>>   XF2AUX,VDUXXRET
:INCREMENT    DB    $00


* Explode one row of pixels. Used by SHRXPLDCHAR & SHRUSERCHAR
* On entry: A contains row of font data
SHRXPLDROW    LDX   SHRPIXELS              ; Pixels per byte
              CPX   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :S1
              JSR   SHRCHAR320
              BRA   :S2
:S1           JSR   SHRCHAR640
:S2           LDX   SHRPIXELS              ; Pixels per byte
              CPX   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :S3
              CLC                          ; 320 mode: add 4 to A3L
              LDA   A3L
              ADC   #$04
              STA   A3L
              LDA   A3H
              ADC   #$00
              STA   A3H
              BRA   :S4
:S3           CLC                          ; 640 mode: add 2 to A3L
              LDA   A3L
              ADC   #$02
              STA   A3L
              LDA   A3H
              ADC   #$00
              STA   A3H
:S4           RTS


* Clear text row 24 (0-based index)
SHRCLR24      CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              LDX   #$00
              LDA   #$00
:L1           STAL  $E19800,X
              INX
              INX
              CPX   #$0500
              BNE   :L1
              SEC                          ; 65816 emulation mode
              XCE
              MX    %11                    ; Tell Merlin
              RTS


* Explode one pixel row of font in 320 mode
* 4 bytes per char, 4 bits per pixel
* On entry: A contains row of font data
SHRCHAR320    PHY                          ; Preserve Y
              LDY   #$00                   ; Dest byte index
:L0           STZ   A2L
              LDX   #$00                   ; Source bit index
:L1           ASL                          ; MS bit -> C
              PHP                          ; Preserve C
              ROL   A2L                    ; C -> LS bit
              PLP                          ; Recover C
              PHP
              ROL   A2L                    ; C -> LS bit
              PLP                          ; Recover C
              PHP
              ROL   A2L                    ; C -> LS bit
              PLP                          ; Recover C
              ROL   A2L                    ; C -> LS bit
              INX
              CPX   #$02                   ; Processed two bits of font?
              BNE   :L1
              PHA                          ; Preserve partially shifted font
              LDA   A2L
              STA   [A3L],Y
              PLA                          ; Recover partially shifted font
              INY
              CPY   #$04                   ; Done 4 bytes?
              BNE   :L0
              PLY                          ; Recover Y
              RTS


* Explode one pixel row of font in 640 mode
* 2 bytes per char, 2 bits per pixel
* On entry: A contains row of font data
SHRCHAR640    PHY                          ; Preserve Y
              LDY   #$00                   ; Dest byte index
:L0           STZ   A2L
              LDX   #$00                   ; Source bit index
:L1           ASL                          ; MS bit -> C
              PHP                          ; Preserve C
              ROL   A2L                    ; C -> LS bit
              PLP                          ; Recover C
              ROL   A2L                    ; C -> LS bit
              INX
              CPX   #$04
              BNE   :L1
              PHA                          ; Preserve partially shifted font
              LDA   A2L
              STA   [A3L],Y
              PLA                          ; Recover partially shifted font
              INY
              CPY   #$02                   ; Done 2 bytes?
              BNE   :L0
              PLY                          ; Recover Y
              RTS


* Handle plotting & unplotting cursors
* On entry: character in A, flags in Y
*           pointer to screen address in SHRVDUQ+0..1
SHRCURSM      >>>   ENTMAIN
              PHY                          ; Preserve flags
              PHA                          ; Preserve character
              LDA   SHRVDUQ+0              ; Copy pointer to A3L/H
              STA   A3L
              LDA   SHRVDUQ+1
              STA   A3H
              LDA   #$E1                   ; Bank $E1
              STA   A4L
              LDA   SHRPIXELS              ; Pixels per byte
              CMP   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :MODE0
              LDA   #$04                   ; 4 bytes in 320 mode
              LDX   #$71                   ; White/red
              BRA   :S1
:MODE0        LDA   #$02                   ; 2 bytes in 640 mode
              LDX   #%11011101             ; White/red/white/red
:S1           STA   :BYTES                 ; Bytes per char
              STX   :CURSBYTE
              LDA   A3L                    ; LSB
              CLC
              ADC   #<$460                 ; $460 is seven rows
              STA   A3L
              LDA   A3H                    ; MSB
              ADC   #>$460                 ; $460 is seven rows
              STA   A3H
              LDY   #$00
              LDX   #$00
              PLA                          ; Recover character
              PLP                          ; Recover flags
              BVC   :S2                    ; VC: Write cursor
              INX                          ; Advance to 2nd half of :SAVEBYTES
              INX
              INX
              INX
:S2           BCC   :CURSOROFF             ; CC: Remove cursor
:CURSORON
              LDAL  [A3L],Y                ; See if cursor shown
              CMP   :CURSBYTE
              BEQ   :DONE                  ; Cursor shown already, skip
:L1           LDAL  [A3L],Y
              STA   :SAVEBYTES,X           ; Preserve bytes under cursor
              LDA   :CURSBYTE              ; Byte of cursor data
              STAL  [A3L],Y
              INX
              INY
              CPY   :BYTES
              BNE   :L1
              >>>   XF2AUX,SHRCURSRET
:CURSOROFF
              LDAL  [A3L],Y                ; See if cursor shown
              CMP   :CURSBYTE
              BNE   :DONE                  ; Cursor not shown, skip
:L2           LDA   :SAVEBYTES,X           ; Restore bytes under cursor
              STAL  [A3L],Y
              INX
              INY
              CPY   :BYTES
              BNE   :L2
:DONE         >>>   XF2AUX,SHRCURSRET
:BYTES        DB    $00                    ; 2 for 640-mode, 4 for 320-mode
:CURSBYTE     DB    $00                    ; Cursor byte for mode
:SAVEBYTES    DS    8                      ; Bytes under cursors


* VDU5 plot char at graphics cursor position
SHRVDU5CH     >>>   ENTMAIN
              CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin

              AND   #$00FF
              STA   A1L                    ; A*16 -> A1L/H
              ASL   A1L
              ASL   A1L
              ASL   A1L
              ASL   A1L

              LDA   SHRPIXELS              ; Pixels per byte
              AND   #$00FF
              CMP   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :MODE0
              LDA   #$04                   ; 4 bytes per row in MODE 1
              ASL   A1L                    ; A*32 -> A1L/H in MODE 1
              BRA   :S0
:MODE0        LDA   #$02                   ; 2 bytes per row in MODE 0
:S0           STA   :BYTES

              CLC                          ; Add SHRFONTXPLD to A1L/H
              LDA   A1L
              ADC   #SHRFONTXPLD
              STA   A1L

              LDA   SHRYPIXEL              ; y coordinate
              SEC
              SBC   #8                     ; Height of this row
              CMP   SHRWINBTM
              BMI   :NEWPAGE
              LDA   SHRYPIXEL
              CMP   SHRWINTOP
              BEQ   :S1
              BPL   :NEWPAGE
:S1           LDA   SHRXPIXEL              ; x coordinate
              CMP   SHRWINLFT
              BMI   :NEWPAGE
              CMP   SHRWINRGT
              BEQ   :S2
              BPL   :NEWPAGE
              BRA   :S2
:NEWPAGE      LDA   SHRWINTOP
              STA   SHRYPIXEL
              LDA   SHRWINLFT
              STA   SHRXPIXEL

:S2           SEP   #$30                   ; 8 bit M & X
              MX    %11                    ; Tell Merlin
              LDX   SHRYPIXEL              ; Screen row (Y-coord)
              LDA   SHRROWSL,X             ; Look up addr (LS byte)
              STA   A3L                    ; Stash in A3L
              LDA   SHRROWSH,X             ; Look up addr (MS byte)
              STA   A3H                    ; Stash in A3H
              LDA   #$E1                   ; Bank $E1
              STA   A4L
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin

              LDX   SHRXPIXEL              ; Screen col (X-coord)
              STX   A2L
              LSR   A2L                    ; Divide by 2

              LDA   SHRPIXELS
              AND   #$00FF
              CMP   #$02
              BEQ   :M1                    ; MODE 1
              LSR   A2L                    ; Divide by 2 again
:M1           LDX   A1L                    ; Index into exploded font
              STZ   :ROWCTR
:L0           
              PHX
              LDY   #$00
              STZ   :PIXBUF+2              ; Clear bytes 3,4 of shift buf
              STZ   :PIXBUF+4              ; Clear bytes 5,6 of shift buf
:LOOP         LDAL  $E10000,X              ; Read a word of exploded font
              STA   :PIXBUF,Y              ; Store word to shift buffer
              INX
              INX
              INY
              INY
              CPY   :BYTES
              BNE   :LOOP
              LDA   SHRXPIXEL
              JSR   SHRSHIFT               ; Shift :PIXBUF to the right
              LDY   A2L                    ; Index into row of pixels
              STZ   :COLCTR
              LDX   #$00
              INC   :BYTES
:L1           LDA   :PIXBUF,X              ; Read word of exploded font
              PHX
              SEP   #$30                   ; 8 bit M & X
              MX    %11                    ; Tell Merlin
              JSR   SHRPLOTBYTE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              PLX
              INX                          ; Next byte of font
              INY                          ; Next byte on screen
              INC   :COLCTR
              LDA   :COLCTR
              CMP   :BYTES                 ; Bytes per row 
              BNE   :L1
              DEC   :BYTES

              PLA                          ; Restore saved X -> A
              CLC                          ; Add bytes per row
              ADC   :BYTES
              TAX                          ; Back to X

              LDA   A3L                    ; Increment A3L/H to next row
              CLC
              ADC   #$A0
              STA   A3L
              LDA   A3H
              ADC   #$00
              STA   A3H
              INC   :ROWCTR
              LDA   :ROWCTR
              CMP   #$08                   ; 8 rows
              BNE   :L0
:DONE         SEC                          ; 65816 emulation mode
              XCE
              MX    %11                    ; Tell Merlin
              >>>   XF2AUX,SHRPRCH320RET
* Zero page
:COLCTR       EQU   TMPZP+0
:ROWCTR       EQU   TMPZP+2
:BYTES        EQU   TMPZP+4                ; Bytes per char row
:PIXBUF       EQU   TMPZP+6                ; Shift buffer (6 bytes)


* Shifts one character row of pixels to the right
* Called in 65816 native mode, 16 bit M & X
* On entry: A - x-coordinate of char
SHRSHIFT      MX    %00                    ; Tell merlin we are 16 bit M&X
              PHA
              LDA   SHRPIXELS              ; Pixels per byte
              AND   #$00FF
              CMP   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :MODE0
              PLA
              AND   #$0001                 ; Bits to shift in MODE 1
              ASL
              PHA
:MODE0        PLA
              AND   #$0003                 ; Bits to shift in MODE 0
              PHA

              LDA   :PIXBUF                ; Put bytes in big-endian order
              XBA
              STA   :PIXBUF
              LDA   :PIXBUF+2
              XBA
              STA   :PIXBUF+2
              LDA   :PIXBUF+4
              XBA
              STA   :PIXBUF+4

              PLA
:L1           CMP   #$0000
              BEQ   :S1
              LSR   :PIXBUF                ; Shift :PIXBUF to the right 1 bit
              ROR   :PIXBUF+2
              ROR   :PIXBUF+4
              LSR   :PIXBUF                ; Shift right again
              ROR   :PIXBUF+2
              ROR   :PIXBUF+4
              DEC   A
              BRA   :L1

:S1           LDA   :PIXBUF                ; Put bytes back in little-endian
              XBA
              STA   :PIXBUF
              LDA   :PIXBUF+2
              XBA
              STA   :PIXBUF+2
              LDA   :PIXBUF+4
              XBA
              STA   :PIXBUF+4
              RTS
              MX    %11


* Handle cursor left in VDU5 mode
SHRVDU08      >>>   ENTMAIN
              CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              LDA   SHRXPIXEL
              SEC
              SBC   #$08                   ; Move to previous column
              CMP   SHRWINLFT
              BMI   :PREVLINE              ; x-pos < SHRWINLFT
              STA   SHRXPIXEL
              BRA   :DONE
:PREVLINE     LDA   SHRYPIXEL
              CLC                          ; Add 8 rows (go up)
              ADC   #$08
              CMP   SHRWINTOP
              BCS   :HOME                  ; y-pos >= SHRWINTOP
              STA   SHRYPIXEL
              LDA   SHRWINRGT
              SEC
              SBC   #$07
              STA   SHRXPIXEL
              BRA   :DONE
:HOME         LDA   SHRWINTOP
              STA   SHRYPIXEL
              LDA   SHRWINLFT
              STA   SHRXPIXEL
:DONE         SEC                          ; 65816 emulation mode
              XCE
              MX    %11                    ; Tell Merlin
              >>>   XF2AUX,VDUXXRET


* Handle cursor right in VDU5 mode
SHRVDU09      >>>   ENTMAIN
              CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              LDA   SHRXPIXEL
              CLC
              ADC   #$08                   ; Advance to next column
              CMP   SHRWINRGT
              BCS   :NEWLINE               ; x-pos >= SHRWINRGT
              STA   SHRXPIXEL
              BRA   :DONE
:NEWLINE      LDA   SHRWINLFT
              STA   SHRXPIXEL
              JSR   SHRVDU5LF
:DONE         SEC                          ; 65816 emulation mode
              XCE
              MX    %11                    ; Tell Merlin
              >>>   XF2AUX,VDUXXRET


* Handle cursor down / linefeed in VDU5 mode
SHRVDU10      >>>   ENTMAIN
              CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              JSR   SHRVDU5LF
:DONE         SEC                          ; 65816 emulation mode
              XCE
              MX    %11                    ; Tell Merlin
              >>>   XF2AUX,VDUXXRET


* Handle cursor up in VDU5 mode
SHRVDU11      >>>   ENTMAIN
              CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              LDA   SHRYPIXEL
              CLC
              ADC   #$08                   ; Height of row of text
              CMP   SHRWINTOP
              BCS   :TOP                   ; y-pos >= SHRWINTOP
              STA   SHRYPIXEL
              BRA   :DONE
:TOP          LDA   SHRWINTOP
              STA   SHRYPIXEL
:DONE         SEC                          ; 65816 emulation mode
              XCE
              MX    %11                    ; Tell Merlin
              >>>   XF2AUX,VDUXXRET


* Handle linefeed in VDU5 mode - does the actual work
* Called in 65816 native mode, 16 bit M & X
SHRVDU5LF     MX    %00                    ; Tell Merlin
              LDA   SHRYPIXEL
              SEC
              SBC   #16                    ; Height of this+next row
              CMP   SHRWINBTM
              BCC   :NEWPAGE               ; Less than 16 rows left
              LDA   SHRYPIXEL
              SEC
              SBC   #$08
              STA   SHRYPIXEL
              BRA   :DONE
:NEWPAGE      LDA   SHRWINTOP
              STA   SHRYPIXEL
:DONE         RTS
              MX    %11                    ; 8 bit again


* Handle carriage return in VDU5 mode
SHRVDU13      >>>   ENTMAIN
              CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              LDA   SHRWINLFT
              STA   SHRXPIXEL
:DONE         SEC                          ; 65816 emulation mode
              XCE
              MX    %11                    ; Tell Merlin
              >>>   XF2AUX,VDUXXRET


* Handle erasing char for VDU127 in VDU5 mode
* Called after SHRVDU08 has already backspaced cursor
SHRVDU127     >>>   ENTMAIN
              LDX   SHRYPIXEL              ; Screen row (Y-coord)
              LDA   SHRROWSL,X             ; Look up addr (LS byte)
              STA   A3L                    ; Stash in A3L
              LDA   SHRROWSH,X             ; Look up addr (MS byte)
              STA   A3H                    ; Stash in A3H
              LDA   #$E1                   ; Bank $E1
              STA   A4L
              LDX   SHRPIXELS
              CPX   #$02
              BNE   :MODE0
              CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              LDA   SHRXPIXEL              ; Screen col (X-coord)
              LSR   A                      ; Divide by 2
              BRA   :MODE1
:MODE0        CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              LDA   SHRXPIXEL              ; Screen col (X-coord)
              LSR   A                      ; Divide by 2
              LSR   A                      ; Divide by 4
              TAY
              LDX   #$00
              SEP   #$30                   ; 8 bit M & X
              MX    %11                    ; Tell Merlin
:L1           LDA   SHRGFXBGMASK
              STAL  [A3L],Y
              INY
              STAL  [A3L],Y
              DEY
              JSR   SHRNXTROWM             ; Advance A3L/H to next pixel row
              INX
              CPX   #$08                   ; Erased all 8 rows?
              BNE   :L1
              BRA   :DONE
:MODE1        MX    %00                    ; Tell Merlin it's 16 bit M&X
              TAY
              LDX   #$00
              SEP   #$30                   ; 8 bit M & X
              MX    %11                    ; Tell Merlin
:L2           LDA   SHRGFXBGMASK
              STAL  [A3L],Y
              INY
              STAL  [A3L],Y
              INY
              STAL  [A3L],Y
              INY
              STAL  [A3L],Y
              DEY
              DEY
              DEY
              JSR   SHRNXTROWM             ; Advance A3L/H to next pixel row
              INX
              CPX   #$08                   ; Erased all 8 rows?
              BNE   :L2
:DONE         SEC                          ; 65816 emulation mode
              XCE
              >>>   XF2AUX,VDUXXRET

* Advance A3L/H to next pixel row on screen
SHRNXTROWM    LDA   A3L                    ; Advance A3L/H to next row
              CLC
              ADC   #160
              STA   A3L
              LDA   A3H
              ADC   #$00
              STA   A3H
              RTS


* Plot actions: PLOT k,x,y
* k is in SHRVDUQ+4
* x is in SHRVDUQ+5,SHRVDUQ+6
* y is in SHRVDUQ+7,SHRVDUQ+8
*
* Plot actions:
*  $00+x - move/draw lines     Where x: 0 - Move relative
*  $40+x - plot point                   1 - Draw relative FG
* [$50+x - fill triangle]               2 - Draw relative Inv FG
* [$60+x - fill rectangle]              3 - Draw relative BG
* [$90+x - draw circle]                 4 - Move absolute
* [$98+x - fill circle]                 5 - Draw abs FG
*                                       6 - Draw abs Inv FG
*                                       7 - Draw abs BG
* Note: abs/rel handled in auxmem.vdu.s
* TODO: No triangle filling or other fancy ops yet
SHRPLOT       >>>   ENTMAIN
              >>>   SHRCOORD               ; Convert coordinates
              LDA   A1L                    ; Preserve converted x
              PHA
              LDA   A1H
              PHA
              LDA   A2L                    ; Preserve converted y
              PHA
              LDA   A2H
              PHA
              LDA   SHRVDUQ+4              ; k
              AND   #$03
              CMP   #$00                   ; Bits 0,1 clear -> just move
              BEQ   :S2
              JSR   SHRPLOTCOL             ; Handle colour selection
              LDA   SHRVDUQ+4              ; k
              AND   #$F0                   ; Keep MS nybble
              CMP   #$00                   ; Move or draw line
              BNE   :S1
              JSR   SHRLINE
              BRA   :S2
:S1           CMP   #$40                   ; Plot point
              BNE   :BAIL                  ; Other? Bail out

              CLC                          ; 65816 native mode
              XCE
              SEP   #$30                   ; 8 bit M & X
              MX    %11                    ; Tell Merlin
              JSR   SHRPOINT
              SEC                          ; 65816 emulation mode
              XCE
              MX    %11                    ; Tell Merlin

              BRA   :S2
:S2           PLA                          ; Store prev pt in screen coords
              STA   SHRYPIXEL+1
              PLA
              STA   SHRYPIXEL+0
              PLA
              STA   SHRXPIXEL+1
              PLA
              STA   SHRXPIXEL+0
:DONE         >>>   XF2AUX,GFXPLOTRET
:BAIL         PLA
              PLA
              PLA
              PLA
              LDA   SHRGFXFGMSK2           ; Restore original FG colour
              STA   SHRGFXFGMASK
              BRA   :DONE


* Handle colour selection for PLOT
SHRPLOTCOL    LDA   SHRGFXFGMASK           ; Preserve FG colour
              STA   SHRGFXFGMSK2
              LDA   SHRVDUQ+4              ; k
              AND   #$03
              CMP   #$02                   ; Inverse fFG
              BNE   :S1
              LDA   SHRGFXFGMASK           ; Load FG mask
              EOR   #$FF                   ; Negate / invert
              INC   A
              STA   SHRGFXFGMASK           ; Overwrite GF mask
              BRA   :DONE
:S1           CMP   #$03                   ; BG
              BNE   :DONE
              LDA   SHRGFXBGMASK           ; Load BG mask
              STA   SHRGFXFGMASK           ; Overwrite FG mask
:DONE         RTS


* Plot a point
* Called in 65816 native mode, 8 bit M & X
* On entry: A1L/H x-coordinate, A2L/H y-coordinate
SHRPOINT      REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              LDA   A2L                    ; y coordinate
              CMP   SHRWINBTM
              BMI   :OUT
              CMP   SHRWINTOP
              BEQ   :S1
              BPL   :OUT
:S1           LDA   A1L                    ; x coordinate
              CMP   SHRWINLFT
              BMI   :OUT
              CMP   SHRWINRGT
              BEQ   SHRPOINT2
              BPL   :OUT
              BRA   SHRPOINT2
:OUT          SEP   #$30                   ; 8 bit M & X
              MX    %11                    ; Tell Merlin
              RTS
SHRPOINT2     SEP   #$30                   ; 8 bit M & X
              MX    %11                    ; Tell Merlin

              LDX   A2L                    ; Screen row (Y-coord)
              LDA   SHRROWSL,X             ; Look up addr (LS byte)
              STA   A3L                    ; Stash in A3L
              LDA   SHRROWSH,X             ; Look up addr (MS byte)
              STA   A3H                    ; Stash in A3H
              LDA   #$E1                   ; Bank $E1
              STA   A4L

              LDX   A1L                    ; Store X-coord for later
              LSR   A1H                    ; Divide by 2
              ROR   A1L

              LDA   SHRPIXELS              ; Pixels per byte
              CMP   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :MODE0

              LDY   A1L                    ; Index into row of pixels
              TXA
              AND   #$01                   ; Keep LSB bit only
              TAX                          ; Index into :BITS320

              LDA   :BITS320,X             ; Get bit pattern for pixel to set
              BRA   SHRPLOTBYTE
              
:MODE0        LSR   A1H                    ; Divide X-coord by 2 again
              ROR   A1L
              LDY   A1L                    ; Index into row of pixels
              TXA
              AND   #$03                   ; Keep LSB two bits only
              TAX                          ; Index into :BITS640

              LDA   :BITS640,X             ; Get bit pattern for pixel to set

SHRPLOTBYTE   PHA
              LDA   SHRGFXACTION           ; GCOL action
              AND   #$0007                 ; Avoid table overflows
              ASL
              TAX
              PLA                          ; Recover bit pattern
              JMP   (:PLOTTBL, X)          ; Jump using jump table

:BITS320      DB    %11110000              ; Bit patterns for pixel ..
              DB    %00001111              ; .. within byte
:BITS640      DB    %11000000              ; Bit patterns for pixel ..
              DB    %00110000              ; .. within byte
              DB    %00001100
              DB    %00000011
:PLOTTBL      DW    SHRPLOTSET             ; Jump table for GCOL actions
              DW    SHRPLOTOR
              DW    SHRPLOTAND
              DW    SHRPLOTXOR
              DW    SHRPLOTNOT
              DW    SHRPLOTNOP
              DW    SHRPLOTCLR
              DW    SHRPLOTNOP


* Plot the specified colour (GCOL action 0)
* Pixel bit pattern in A
SHRPLOTSET    TAX                          ; Keep copy of bit pattern
              EOR   #$FF                   ; Invert bits
              AND   [A3L],Y                ; Load existing byte, clearing pixel
              STA   A1L
              TXA                          ; Get bit pattern back
              AND   SHRGFXFGMASK           ; Mask to set colour
              ORA   A1L                    ; OR into existing byte
              STA   [A3L],Y                ; Write to screen
              RTS


* OR with colour on screen (GCOL action 1)
* Pixel bit pattern in A
SHRPLOTOR     AND   SHRGFXFGMASK           ; Mask to set colour
              ORA   [A3L],Y                ; OR into existing byte
              STA   [A3L],Y                ; Write to screen
              RTS


* AND with colour on screen (GCOL action 2)
* Pixel bit pattern in A
SHRPLOTAND    TAX                          ; Keep copy of bit pattern
              AND   [A3L],Y                ; Mask bits to work on
              STA   A1L
              TXA                          ; Get bit pattern back
              AND   SHRGFXFGMASK           ; Mask to set colour
              AND   A1L                    ; AND with screen data
              STA   A1L
              TXA                          ; Get bit pattern back
              EOR   #$FF                   ; Invert
              AND   [A3L],Y                ; Mask remaining bits
              ORA   A1L                    ; Combine
              STA   [A3L],Y                ; Write to screen
              RTS


* XOR with colour on screen (GCOL action 3)
* Pixel bit pattern in A
SHRPLOTXOR    AND   SHRGFXFGMASK           ; Mask to set colour
              EOR   [A3L],Y                ; EOR into existing byte
              STA   [A3L],Y                ; Write to screen
              RTS


* NOT colour on screen (GCOL action 4)
* Pixel bit pattern in A
SHRPLOTNOT    TAX                          ; Keep copy of bit pattern
              STX   A1L
              LDA   [A3L],Y                ; Load existing byte
              EOR   #$FF                   ; Negate / invert existing byte
              AND   A1L                    ; Mask with bit pattern
              STA   A1L
              TXA                          ; Get bit pattern back
              EOR   #$FF                   ; Invert bits
              AND   [A3L],Y                ; Mask remaining bits
              ORA   A1L                    ; Combine
              STA   [A3L],Y                ; Write to screen
              RTS


* NO-OP (GCOL action 5)
* Pixel bit pattern in A
SHRPLOTNOP    RTS


* Clear (GCOL action 6)
* Pixel bit pattern in A, and also at top of stack
SHRPLOTCLR    EOR   #$FF                   ; Invert bits
              AND   [A3L],Y                ; Load existing byte, clearing pixel
              STA   [A3L],Y                ; Write to screen
              RTS


* Bresenham line drawing algorithm, entry point
* x0 is in SHRXPIXEL+0,SHRPIXEL+1
* y0 is in SHRYPIXEL
* x1 in A1L,A1H
* y1 in A2L
* Called in emulation mode.
* Uses TMPZP+0,+1
SHRLINE       LDA   A2L                    ; y1
              SEC
              SBC   SHRYPIXEL              ; Subtract y0
              BPL   :S1                    ; Skip if +ve
              EOR   #$FF                   ; Negate if -ve
              INC   A
:S1           STA   TMPZP+0                ; abs(y1 - y0)
              STZ   TMPZP+1                ; Pad to 16 bit
              CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              LDA   A1L                    ; Load x1 (A1L,A1H)
              SEC
              SBC   SHRXPIXEL              ; Subtract x0
              BPL   :S2                    ; Skip if +ve
              EOR   #$FFFF                 ; Negate if -ve
              INC   A
:S2           CMP   TMPZP                  ; Cmp abs(x1 - x0) w/ abs(y1 - y0)
              BCC   :YDOM                  ; abs(x1 - x0) < abs(y1 - y0)

:XDOM         LDA   SHRXPIXEL              ; x0
              CMP   A1L                    ; x1
              BPL   :X1                    ; x0 >= x1
              JMP   SHRLINELO              ; x0 < x1
:X1           JSR   SHRLINESWAP            ; Swap parms
              JMP   SHRLINELO

:YDOM         LDA   SHRYPIXEL              ; y0
              CMP   A2L                    ; y1
              BPL   :Y1                    ; y0 >= y1
              JMP   SHRLINEHI              ; y0 < y1
:Y1           JSR   SHRLINESWAP            ; Swap parms
              JMP   SHRLINEHI


* Swap (x0, y0) and (x1, y1)
* Called in 65816 native mode, 16 bit M &X
* Uses TMPZP+0,+1
SHRLINESWAP   LDA   SHRXPIXEL              ; x0
              STA   TMPZP
              LDA   A1L                    ; x1
              STA   SHRXPIXEL
              LDA   TMPZP
              STA   A1L
              LDA   SHRYPIXEL              ; y0
              STA   TMPZP
              LDA   A2L                    ; y1
              STA   SHRYPIXEL
              LDA   TMPZP
              STA   A2L
              RTS


* Plot x-dominant line (shallow gradient)
* Called in 65816 native mode, 16 bit M & X. Returns in emulation mode.
SHRLINELO     MX    %00                    ; Tell merlin 16 bit M & X
              LDA   A1L                    ; x1
              STA   :LIM                   ; We re-use A1L/H later
              SEC
              SBC   SHRXPIXEL              ; Subtract x0
              STA   :DX
              LDA   A2L                    ; y1
              SEC
              SBC   SHRYPIXEL              ; Subtract y0
              STA   :DY
              LDA   #$0001
              STA   :YI                    ; yi = 1

              LDA   :DY
              BPL   :S1                    ; Skip if dy = 0
              LDA   #$FFFF
              STA   :YI                    ; yi = -1
              EOR   :DY                    ; Negate dy
              INC   A
              STA   :DY                    ; dy = -dy

:S1           TAY                          ; dy
              ASL                          ; 2 * dy
              STA   :DY                    ; DY now (2 * dy)
              SEC
              SBC   :DX                    ; (2 * dy) - dx
              STA   :D                     ; D = (2 * dy) - dx
              LDA   SHRYPIXEL              ; y0
              STA   A2L                    ; y = y0 (re-using A2L/H)
              TYA
              SEC
              SBC   :DX
              ASL
              STA   :DX                    ; DX now (2 * (dy - dx)

              LDX   SHRXPIXEL              ; x = x0
:L1           STX   A1L                    ; Store x-coord for SHRPOINT
              PHX
              SEP   #$30                   ; 8 bit M & X
              MX    %11                    ; Tell Merlin
              JSR   SHRPOINT               ; x in A1L/H, y in A2L
              REP   #$31                   ; 16 bit M & X, CLC
              MX    %00                    ; Tell Merlin
              PLX
              LDA   :D
              BMI   :S2                    ; D < 0
              ADC   :DX
              STA   :D                     ; D = D + (2 * (dy - dx))
              LDA   A2L                    ; y
              CLC                          ; (Required)
              ADC   :YI
              STA   A2L                    ; y = y + yi
              BRA   :S3
:S2         ; CLC                          ; Already CC
              ADC   :DY
              STA   :D                     ; D = D + 2 * dy
:S3           INX
              CPX   :LIM                   ; Compare with x1
              BCC   :L1

              SEC                          ; 65816 emulation mode
              XCE
              MX    %11                    ; Tell Merlin
              RTS
* Zero page
:DX           EQU   TMPZP+0                ; dx initially, then (2 * (dy - dx))
:DY           EQU   TMPZP+2                ; dy initially, then (2 * dy)
:YI           EQU   TMPZP+4                ; +1 or -1
:D            EQU   TMPZP+6                ; D
:LIM          EQU   TMPZP+8                ; x1 gets stashed here


* Plot y-dominant line (steep gradient)
* Called in 65816 native mode, 16 bit M & X. Returns in emulation mode.
SHRLINEHI     MX    %00                    ; Tell Merlin 16 bit M & X
              LDA   A1L                    ; x1
              SEC
              SBC   SHRXPIXEL              ; Subtract x0
              STA   :DX
              LDA   A2L                    ; y1
              STA   :LIM                   ; We re-use A1L/H later
              SEC
              SBC   SHRYPIXEL              ; Subtract y0
              STA   :DY
              LDA   #$0001
              STA   :XI                    ; xi = 1

              LDA   :DX
              BPL   :S1                    ; Skip if dx = 0
              LDA   #$FFFF
              STA   :XI                    ; xi = -1
              EOR   :DX                    ; Negate dx
              INC   A
              STA   :DX                    ; dx = -dx

:S1           TAX                          ; dx
              ASL                          ; 2 * dx
              STA   :DX                    ; DX now (2 * dx)
              SEC
              SBC   :DY                    ; (2 * dx) - dy
              STA   :D                     ; D = (2 * dx) - dy
              LDA   SHRXPIXEL              ; x0
              STA   :X                     ; x = x0
              TXA
              SEC
              SBC   :DY
              ASL
              STA   :DY                    ; DY now (2 * (dx - dy)

              LDX   SHRYPIXEL              ; y = y0
:L1           LDA   :X
              STA   A1L                    ; Store x-coord for SHRPOINT
              STX   A2L                    ; Store y-coord for SHRPOINT
              PHX
              SEP   #$30                   ; 8 bit M & X
              MX    %11                    ; Tell Merlin
              JSR   SHRPOINT               ; x in A1L/H, y in A2L
              REP   #$31                   ; 16 bit M & X, CLC
              MX    %00                    ; Tell Merlin
              PLX
              LDA   :D
              BMI   :S2                    ; D < 0
              ADC   :DY
              STA   :D                     ; D = D + (2 * (dx - dy))
              LDA   :X                     ; x
              CLC                          ; (Required)
              ADC   :XI
              STA   :X                     ; x = x + xi
              BRA   :S3
:S2         ; CLC                          ; Already CC
              ADC   :DX
              STA   :D                     ; D = D + 2 * dx
:S3           INX
              CPX   :LIM                   ; Compare with y1
              BCC   :L1

              SEC                          ; 65816 emulation mode
              XCE
              MX    %11                    ; Tell Merlin
*              PLP                          ; Resume normal service
              RTS
* Zero page
:X            EQU   TMPZP+0
:DX           EQU   TMPZP+2                ; dx initially, then (2 * dx)
:DY           EQU   TMPZP+4                ; dy initially, then (2 * (dx - dy)))
:XI           EQU   TMPZP+6                ; +1 or -1
:D            EQU   TMPZP+8                ; D
:LIM          EQU   TMPZP+10               ; x1 gets stashed here


* Macro to convert high-resolution screen coordinates
* from 1280x1024 to 640x200 or 320x200
* On return: X-coordinate in A1L/H, Y-coordinate in A2L (A2H=0)
SHRCOORD      MAC
              CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin

* X-coordinate in SHRVDUQ+5,+6   1280/2=640 or 1280/4=320
              LDA   SHRVDUQ+5
              ASL                          ; Sign bit -> C
              ROR   SHRVDUQ+5              ; Signed divide /2

              LDA   SHRPIXELS              ; Pixels per byte
              AND   #$00FF                 ; Mask
              CMP   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   SHRCOORDM0
              LDA   SHRVDUQ+5
              ASL                          ; Sign bit -> C
              ROR   SHRVDUQ+5              ; Signed divide /2
SHRCOORDM0    LDA   SHRVDUQ+5
              STA   A1L                    ; Result in A1L/H

* Y-coordinate in SHRVDUQ+7,+8   1024*25/128=200
              LDA   SHRVDUQ+7
              BMI   SHRCOORDNEG
              ASL                          ; *2
              ADC   SHRVDUQ+7              ; *3
              ASL                          ; *6
              ASL                          ; *12
              ASL                          ; *24
              ADC   SHRVDUQ+7              ; *25

* Clever speedup trick thanks to Kent Dickey @ A2Infinitum
* now we have valid data in acc[15:7], and we want to shift right 7 bits to
* get acc[8:0] as the valid bits.  If we left shift one bit and xba,
* we get acc[7:0] in the proper bits, so we just have to bring the bit we
* just shifted out back
* See: https://apple2infinitum.slack.com/archives/CA8AT5886/p1628877444215300
* for code on how to shift left 7 bits

              ASL                          ;
              AND   #$FF00                 ; Mask bits
              ADC   #0                     ; Add in carry (9th bit)
              XBA                          ; Clever trick: fewer shifts
              STA   A2L                    ; Into A2L/H
        
              SEC                          ; Back to emulation mode
              XCE
              MX    %11                    ; Tell Merlin
              BRA   SHRCOORDEND

SHRCOORDNEG   MX    %00                    ; Tell Merlin we are 16 bit
              EOR   #$FFFF                 ; Negate
              INC   A
              ASL                          ; *2
              ADC   SHRVDUQ+7              ; *3
              ASL                          ; *6
              ASL                          ; *12
              ASL                          ; *24
              ADC   SHRVDUQ+7              ; *25

* Clever speedup trick thanks to Kent Dickey @ A2Infinitum
* now we have valid data in acc[15:7], and we want to shift right 7 bits to
* get acc[8:0] as the valid bits.  If we left shift one bit and xba,
* we get acc[7:0] in the proper bits, so we just have to bring the bit we
* just shifted out back
* See: https://apple2infinitum.slack.com/archives/CA8AT5886/p1628877444215300
* for code on how to shift left 7 bits

              ASL                          ;
              AND   #$FF00                 ; Mask bits
              ADC   #0                     ; Add in carry (9th bit)
              XBA                          ; Clever trick: fewer shifts
              EOR   #$FFFF                 ; Negate
              INC   A
              STA   A2L                    ; Into A2L/H
        
              SEC                          ; Back to emulation mode
              XCE
              MX    %11                    ; Tell Merlin
*              PLP                          ; Normal service resumed
SHRCOORDEND   EOM


* Another coordinate transform, used by VDU25
* Same as SHRCOORD above, except it is entered in native, 16 bit M & X mode
* Assumes positive coordinates.
* On entry: X is offset into SHRVDUQ to find coordinate
* On return: Coverted coordinats in A1L/H, A2L/H
SHRCOORD2     MX    $00                    ; Tell Merlin it's 16 bit

* X-coordinate in SHRVDUQ+5,+6   1280/2=640
              LSR   SHRVDUQ,X              ; Unsigned divide /2
              LDA   SHRPIXELS              ; Pixels per byte
              AND   #$00FF                 ; Mask
              CMP   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   SHRCOORD2M0
              LSR   SHRVDUQ,X              ; Unsigned divide /2 again
SHRCOORD2M0   LDA   SHRVDUQ,X
              STA   A1L                    ; Result in A1L/H

* Y-coordinate in SHRVDUQ+7,+8   1024*25/128=200
              LDA   SHRVDUQ+2,X
              ASL                          ; *2
              ADC   SHRVDUQ+2,X            ; *3
              ASL                          ; *6
              ASL                          ; *12
              ASL                          ; *24
              ADC   SHRVDUQ+2,X            ; *25

              ASL                          ;
              AND   #$FF00                 ; Mask bits
              ADC   #0                     ; Add in carry (9th bit)
              XBA                          ; Clever trick: fewer shifts
              STA   A2L                    ; Into A2L/H
              RTS


              MX    %11                    ; Following code is 8 bit again


* Clear the graphics window
SHRVDU16      >>>   ENTMAIN
              CLC                          ; 816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              INC   SHRWINTOP
              INC   SHRWINRGT
              LDX   SHRWINBTM

              LDA   SHRPIXELS
              AND   #$00FF
              CMP   #$02
              BNE   :M0                    ; MODE0

              LDA   SHRWINLFT
              LSR   A                      ; Divide left by 2
              INC   A                      ; Treat left column specially
              STA   :LEFTLIM
              LDA   SHRWINRGT
              LSR   A                      ; Divide right by 2
              STA   :RIGHTLIM
              BRA   :S0

:M0           LDA   SHRWINLFT
              LSR   A                      ; Divide left by 4
              LSR   A
              INC   A                      ; Treat left column specially
              STA   :LEFTLIM
              LDA   SHRWINRGT
              LSR   A                      ; Divide right by 4
              LSR   A
              STA   :RIGHTLIM
              BRA   :S0

:S0           SEP   #$30                   ; 8 bit M & X
              MX    %11                    ; Tell Merlin
:L1           LDY   :LEFTLIM
              LDA   SHRROWSL,X             ; Look up addr (LS byte)
              STA   A3L                    ; Stash in A3L
              LDA   SHRROWSH,X             ; Look up addr (MS byte)
              STA   A3H                    ; Stash in A3H
              LDA   #$E1                   ; Bank $E1
              STA   A4L

              LDA   SHRGFXBGMASK
:L2           CPY   :RIGHTLIM
              BCS   :S1
              STA   [A3L],Y
              INY
              CPY   :RIGHTLIM
              BRA   :L2

:S1           INX
              CPX   SHRWINTOP
              BNE   :L1

              LDA   SHRPIXELS
              CMP   #$02
              BNE   :MODE0

              LDA   SHRWINRGT
              AND   #$01
              TAX
              LDA   :RIGHT320,X            ; Bits to set
              JSR   SHRVDU16V              ; Handle right edge

              LDY   :LEFTLIM
              DEY                          ; Handle leftmost byte
              LDA   SHRWINLFT
              AND   #$01
              TAX
              LDA   :LEFT320,X             ; Bits to set
              JSR   SHRVDU16V              ; Handle left edge
              BRA   :DONE

:MODE0        LDA   SHRWINRGT
              AND   #$03
              TAX
              LDA   :RIGHT640,X            ; Bits to set
              JSR   SHRVDU16V              ; Handle right edge

              LDY   :LEFTLIM
              DEY                          ; Handle leftmost byte
              LDA   SHRWINLFT
              AND   #$03
              TAX
              LDA   :LEFT640,X             ; Bits to set
              JSR   SHRVDU16V              ; Handle left edge

:DONE         REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              DEC   SHRWINTOP
              DEC   SHRWINRGT

              SEC                          ; Back to 6502 emu mode
              XCE
              MX    %11                    ; Tell Merlin
              >>>   XF2AUX,SHRCLRRET
:LEFT320      DB    %11111111
              DB    %00001111
:LEFT640      DB    %11111111
              DB    %00111111
              DB    %00001111
              DB    %00000011
:RIGHT320     DB    %00000000
              DB    %11110000
:RIGHT640     DB    %00000000
              DB    %11000000
              DB    %11110000
              DB    %11111100
* Zero page
:LEFTLIM      EQU   TMPZP+0                ; 2 bytes of ZP
:RIGHTLIM     EQU   TMPZP+2                ; 2 bytes of ZP


* Helper routine to draw vertical lines
* Draw line from A1L,SHRWINBTM to A1L,SHRWINBTM in BG colour
* Called in 65816 native mode, 8 bit M & X
* On entry: Y - byte offset into row, A - bit pattern to set
SHRVDU16V     PHA
              LDX   SHRWINBTM
:L1           LDA   SHRROWSL,X             ; Look up addr (LS byte)
              STA   A3L                    ; Stash in A3L
              LDA   SHRROWSH,X             ; Look up addr (MS byte)
              STA   A3H                    ; Stash in A3H
              LDA   #$E1                   ; Bank $E1
              STA   A4L

              PLA
              PHA
              EOR   #$FF                   ; Invert bits
              AND   [A3L],Y                ; Load existing byte, clearing pixel
              STA   A1L
              PLA
              PHA
              AND   SHRGFXBGMASK           ; Mask to set colour
              ORA   A1L                    ; OR into existing byte
              STA   [A3L],Y                ; Write to screen

              INX
              CPX   SHRWINTOP
              BNE   :L1
              PLA
              RTS


* Validate graphics window parms & store if okay
* First 8 bytes of SHRVDUQ: left, bottom, right, top
SHRVDU24      >>>   ENTMAIN
              CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              LDA   SHRVDUQ+4              ; Right
              CMP   SHRVDUQ+0              ; Left
              BCC   :BAD                   ; right<left
              CMP   #1280                  ; width
              BCS   :BAD                   ; right>=width
              LDA   SHRVDUQ+6              ; Top
              CMP   SHRVDUQ+2              ; Bottom
              BCC   :BAD                   ; top<bottom
              CMP   #1024                  ; height
              BCS   :BAD                   ; top>=height
             
              LDX   #$00                   ; Start of SHRVDUQ 
              JSR   SHRCOORD2              ; Convert left, bottom
              LDA   A1L                    ; left converted
              STA   SHRWINLFT
              LDA   A2L                    ; bottom converted
              STA   SHRWINBTM
              LDX   #$04                   ; 4 byte offset
              JSR   SHRCOORD2              ; Convert right, top
              LDA   A1L                    ; right converted
              STA   SHRWINRGT
              LDA   A2L                    ; top converted
              STA   SHRWINTOP

              SEC                          ; 65816 emulation mode
              XCE
              >>>   XF2AUX,VDU24RET
:BAD          SEC                          ; 65816 emulation mode
              XCE
              >>>   XF2AUX,VDUXXRET


* Reset graphics window
* Initialize other locals (called on MODE)
SHRVDU26      >>>   ENTMAIN

              STZ   SHRWINLFT+0            ; Graphics window
              STZ   SHRWINLFT+1
              STZ   SHRWINBTM+0
              STZ   SHRWINBTM+1
              LDY   SHRPIXELS
              CPY   #$02
              BNE   :MODE0
              LDA   #<319
              STA   SHRWINRGT+0
              LDA   #>319
              STA   SHRWINRGT+1
              BRA   :S1
:MODE0        LDA   #<639
              STA   SHRWINRGT+0
              LDA   #>639
              STA   SHRWINRGT+1
:S1           LDA   #<199
              STA   SHRWINTOP+0
              LDA   #>199
              STA   SHRWINTOP+1

              STZ   SHRXPIXEL+0            ; Other locals
              STZ   SHRXPIXEL+1
              STZ   SHRYPIXEL+0
              STZ   SHRYPIXEL+1

              >>>   XF2AUX,VDU26RET


* Set up default palette
SHRDEFPALM    >>>   ENTMAIN
              LDY   #00                    ; Palette offset for 320 mode
              LDA   SHRPIXELS              ; Pixels per byte
              CMP   #$02                   ; 2 is 320-mode (MODE 1)
              BEQ   :S1
              LDY   #32                    ; Palette offset for 640 mode
:S1           LDX   #$00
:L1           LDA   PALETTE320,Y           ; Offset in Y computed above
              STAL  $E19E00,X              ; Palettes begin at $9E00 in $E1
              INX
              INY
              CPX   #32                    ; 32 bytes in palette
              BNE   :L1
              >>>   XF2AUX,SHRDEFPALRET


* Assign a 'physical' colour from the 16 colour palette to a
* 'logical' colour for the current mode
* On entry: A=logical colour, Y=physical colour
SHRPALCHANGE  >>>   ENTMAIN
              TAX
              TYA
              AND   #%00011110             ; Has already been shifted
              TAY
              LDA   SHRPIXELS              ; Pixels per byte
              CMP   #$02                   ; 2 is 320-mode (MODE 1)
              BEQ   :MODE320
              TXA
              AND   #%00000110             ; Has already been shifted
              TAX
              LDA   PALETTE320,Y           ; Byte 1 of physical colour
              STAL  $E19E00,X              ; Store in logical slot (4 copies)
              STAL  $E19E00+8,X
              STAL  $E19E00+16,X
              STAL  $E19E00+24,X
              LDA   PALETTE320+1,Y         ; Byte 2 of physical colour
              STAL  $E19E00+1,X            ; Store in logical slot (4 copies)
              STAL  $E19E00+9,X
              STAL  $E19E00+17,X
              STAL  $E19E00+25,X
              BRA   :DONE
:MODE320      TXA
              AND   #%00011110             ; Has already been shifted
              TAX
              LDA   PALETTE320,Y           ; Byte 1 of physical colour
              STAL  $E19E00,X              ; Store in logical slot
              LDA   PALETTE320+1,Y         ; Byte 2 of physical colour
              STAL  $E19E00+1,X            ; Store in logical slot
:DONE         >>>   XF2AUX,VDUXXRET 


* Assign a custom RGB colour to a 'logical' colour
* On entry: A=GB components, Y=R component, SHRVDUQ=logical colour
SHRPALCUSTOM  >>>   ENTMAIN
              LDX   SHRVDUQ
              PHA                          ; Preserve GB components
              LDA   SHRPIXELS              ; Pixels per byte
              CMP   #$02                   ; 2 is 320-mode (MODE 1)
              BEQ   :MODE320
              TXA
              AND   #%00000110             ; Has already been shifted
              TAX
              PLA                          ; Recover GB components
              STAL  $E19E00,X              ; Store in logical slot (4 copies)
              STAL  $E19E00+8,X
              STAL  $E19E00+16,X
              STAL  $E19E00+24,X
              TYA                          ; R component
              STAL  $E19E00+1,X            ; Store in logical slot (4 copies)
              STAL  $E19E00+9,X
              STAL  $E19E00+17,X
              STAL  $E19E00+25,X
              BRA   :DONE
:MODE320      TXA
              AND   #%00011110             ; Has already been shifted
              TAX
              PLA                          ; Recover GB components
              STAL  $E19E00,X              ; Store in logical slot
              TYA                          ; R component
              STAL  $E19E00+1,X            ; Store in logical slot
:DONE         >>>   XF2AUX,VDUXXRET 
              

* Table of addresses of SHR rows (in reverse order)
SHRROWSL      DB    <$9c60
              DB    <$9bc0
              DB    <$9b20
              DB    <$9a80
              DB    <$99e0
              DB    <$9940
              DB    <$98a0
              DB    <$9800
              DB    <$9760
              DB    <$96c0
              DB    <$9620
              DB    <$9580
              DB    <$94e0
              DB    <$9440
              DB    <$93a0
              DB    <$9300
              DB    <$9260
              DB    <$91c0
              DB    <$9120
              DB    <$9080
              DB    <$8fe0
              DB    <$8f40
              DB    <$8ea0
              DB    <$8e00
              DB    <$8d60
              DB    <$8cc0
              DB    <$8c20
              DB    <$8b80
              DB    <$8ae0
              DB    <$8a40
              DB    <$89a0
              DB    <$8900
              DB    <$8860
              DB    <$87c0
              DB    <$8720
              DB    <$8680
              DB    <$85e0
              DB    <$8540
              DB    <$84a0
              DB    <$8400
              DB    <$8360
              DB    <$82c0
              DB    <$8220
              DB    <$8180
              DB    <$80e0
              DB    <$8040
              DB    <$7fa0
              DB    <$7f00
              DB    <$7e60
              DB    <$7dc0
              DB    <$7d20
              DB    <$7c80
              DB    <$7be0
              DB    <$7b40
              DB    <$7aa0
              DB    <$7a00
              DB    <$7960
              DB    <$78c0
              DB    <$7820
              DB    <$7780
              DB    <$76e0
              DB    <$7640
              DB    <$75a0
              DB    <$7500
              DB    <$7460
              DB    <$73c0
              DB    <$7320
              DB    <$7280
              DB    <$71e0
              DB    <$7140
              DB    <$70a0
              DB    <$7000
              DB    <$6f60
              DB    <$6ec0
              DB    <$6e20
              DB    <$6d80
              DB    <$6ce0
              DB    <$6c40
              DB    <$6ba0
              DB    <$6b00
              DB    <$6a60
              DB    <$69c0
              DB    <$6920
              DB    <$6880
              DB    <$67e0
              DB    <$6740
              DB    <$66a0
              DB    <$6600
              DB    <$6560
              DB    <$64c0
              DB    <$6420
              DB    <$6380
              DB    <$62e0
              DB    <$6240
              DB    <$61a0
              DB    <$6100
              DB    <$6060
              DB    <$5fc0
              DB    <$5f20
              DB    <$5e80
              DB    <$5de0
              DB    <$5d40
              DB    <$5ca0
              DB    <$5c00
              DB    <$5b60
              DB    <$5ac0
              DB    <$5a20
              DB    <$5980
              DB    <$58e0
              DB    <$5840
              DB    <$57a0
              DB    <$5700
              DB    <$5660
              DB    <$55c0
              DB    <$5520
              DB    <$5480
              DB    <$53e0
              DB    <$5340
              DB    <$52a0
              DB    <$5200
              DB    <$5160
              DB    <$50c0
              DB    <$5020
              DB    <$4f80
              DB    <$4ee0
              DB    <$4e40
              DB    <$4da0
              DB    <$4d00
              DB    <$4c60
              DB    <$4bc0
              DB    <$4b20
              DB    <$4a80
              DB    <$49e0
              DB    <$4940
              DB    <$48a0
              DB    <$4800
              DB    <$4760
              DB    <$46c0
              DB    <$4620
              DB    <$4580
              DB    <$44e0
              DB    <$4440
              DB    <$43a0
              DB    <$4300
              DB    <$4260
              DB    <$41c0
              DB    <$4120
              DB    <$4080
              DB    <$3fe0
              DB    <$3f40
              DB    <$3ea0
              DB    <$3e00
              DB    <$3d60
              DB    <$3cc0
              DB    <$3c20
              DB    <$3b80
              DB    <$3ae0
              DB    <$3a40
              DB    <$39a0
              DB    <$3900
              DB    <$3860
              DB    <$37c0
              DB    <$3720
              DB    <$3680
              DB    <$35e0
              DB    <$3540
              DB    <$34a0
              DB    <$3400
              DB    <$3360
              DB    <$32c0
              DB    <$3220
              DB    <$3180
              DB    <$30e0
              DB    <$3040
              DB    <$2fa0
              DB    <$2f00
              DB    <$2e60
              DB    <$2dc0
              DB    <$2d20
              DB    <$2c80
              DB    <$2be0
              DB    <$2b40
              DB    <$2aa0
              DB    <$2a00
              DB    <$2960
              DB    <$28c0
              DB    <$2820
              DB    <$2780
              DB    <$26e0
              DB    <$2640
              DB    <$25a0
              DB    <$2500
              DB    <$2460
              DB    <$23c0
              DB    <$2320
              DB    <$2280
              DB    <$21e0
              DB    <$2140
              DB    <$20a0
              DB    <$2000

SHRROWSH      DB    >$9c60
              DB    >$9bc0
              DB    >$9b20
              DB    >$9a80
              DB    >$99e0
              DB    >$9940
              DB    >$98a0
              DB    >$9800
              DB    >$9760
              DB    >$96c0
              DB    >$9620
              DB    >$9580
              DB    >$94e0
              DB    >$9440
              DB    >$93a0
              DB    >$9300
              DB    >$9260
              DB    >$91c0
              DB    >$9120
              DB    >$9080
              DB    >$8fe0
              DB    >$8f40
              DB    >$8ea0
              DB    >$8e00
              DB    >$8d60
              DB    >$8cc0
              DB    >$8c20
              DB    >$8b80
              DB    >$8ae0
              DB    >$8a40
              DB    >$89a0
              DB    >$8900
              DB    >$8860
              DB    >$87c0
              DB    >$8720
              DB    >$8680
              DB    >$85e0
              DB    >$8540
              DB    >$84a0
              DB    >$8400
              DB    >$8360
              DB    >$82c0
              DB    >$8220
              DB    >$8180
              DB    >$80e0
              DB    >$8040
              DB    >$7fa0
              DB    >$7f00
              DB    >$7e60
              DB    >$7dc0
              DB    >$7d20
              DB    >$7c80
              DB    >$7be0
              DB    >$7b40
              DB    >$7aa0
              DB    >$7a00
              DB    >$7960
              DB    >$78c0
              DB    >$7820
              DB    >$7780
              DB    >$76e0
              DB    >$7640
              DB    >$75a0
              DB    >$7500
              DB    >$7460
              DB    >$73c0
              DB    >$7320
              DB    >$7280
              DB    >$71e0
              DB    >$7140
              DB    >$70a0
              DB    >$7000
              DB    >$6f60
              DB    >$6ec0
              DB    >$6e20
              DB    >$6d80
              DB    >$6ce0
              DB    >$6c40
              DB    >$6ba0
              DB    >$6b00
              DB    >$6a60
              DB    >$69c0
              DB    >$6920
              DB    >$6880
              DB    >$67e0
              DB    >$6740
              DB    >$66a0
              DB    >$6600
              DB    >$6560
              DB    >$64c0
              DB    >$6420
              DB    >$6380
              DB    >$62e0
              DB    >$6240
              DB    >$61a0
              DB    >$6100
              DB    >$6060
              DB    >$5fc0
              DB    >$5f20
              DB    >$5e80
              DB    >$5de0
              DB    >$5d40
              DB    >$5ca0
              DB    >$5c00
              DB    >$5b60
              DB    >$5ac0
              DB    >$5a20
              DB    >$5980
              DB    >$58e0
              DB    >$5840
              DB    >$57a0
              DB    >$5700
              DB    >$5660
              DB    >$55c0
              DB    >$5520
              DB    >$5480
              DB    >$53e0
              DB    >$5340
              DB    >$52a0
              DB    >$5200
              DB    >$5160
              DB    >$50c0
              DB    >$5020
              DB    >$4f80
              DB    >$4ee0
              DB    >$4e40
              DB    >$4da0
              DB    >$4d00
              DB    >$4c60
              DB    >$4bc0
              DB    >$4b20
              DB    >$4a80
              DB    >$49e0
              DB    >$4940
              DB    >$48a0
              DB    >$4800
              DB    >$4760
              DB    >$46c0
              DB    >$4620
              DB    >$4580
              DB    >$44e0
              DB    >$4440
              DB    >$43a0
              DB    >$4300
              DB    >$4260
              DB    >$41c0
              DB    >$4120
              DB    >$4080
              DB    >$3fe0
              DB    >$3f40
              DB    >$3ea0
              DB    >$3e00
              DB    >$3d60
              DB    >$3cc0
              DB    >$3c20
              DB    >$3b80
              DB    >$3ae0
              DB    >$3a40
              DB    >$39a0
              DB    >$3900
              DB    >$3860
              DB    >$37c0
              DB    >$3720
              DB    >$3680
              DB    >$35e0
              DB    >$3540
              DB    >$34a0
              DB    >$3400
              DB    >$3360
              DB    >$32c0
              DB    >$3220
              DB    >$3180
              DB    >$30e0
              DB    >$3040
              DB    >$2fa0
              DB    >$2f00
              DB    >$2e60
              DB    >$2dc0
              DB    >$2d20
              DB    >$2c80
              DB    >$2be0
              DB    >$2b40
              DB    >$2aa0
              DB    >$2a00
              DB    >$2960
              DB    >$28c0
              DB    >$2820
              DB    >$2780
              DB    >$26e0
              DB    >$2640
              DB    >$25a0
              DB    >$2500
              DB    >$2460
              DB    >$23c0
              DB    >$2320
              DB    >$2280
              DB    >$21e0
              DB    >$2140
              DB    >$20a0
              DB    >$2000


