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

SHRPIXELS     DB    $00                    ; Main memory copy of VDUPIXELS
SHRVDUQ       DS    16                     ; Main memory copy of VDUQ
SHRGFXFGMASK  DB    $00                    ; Foreground colour mask
SHRGFXFGMSK2  DB    $00                    ; Copy of foreground colour mask
SHRGFXBGMASK  DB    $00                    ; Background colour mask
SHRGFXACTION  DB    $00                    ; GCOL action for point plotting
SHRXPIXEL     DW    $0000                  ; Previous point in screen coords
SHRYPIXEL     DW    $0000                  ; Previous point in screen coords
SHRTMPWRD     DW    $0000                  ; Temp scratch space



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
              >>>   XF2AUX,SHRV22RET
              RTS


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
:DONE         >>>   XF2AUX,VDU23RET
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
              JSR   SHRCOORD               ; Convert coordinates
              LDA   A1L                    ; Preserve converted x
              PHA
              LDA   A1H
              PHA
              LDA   A2L                    ; Preserve converted y
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
              JSR   SHRPOINT
              BRA   :S2
:S2           PLA                          ; Store prev pt in screen coords
              STA   SHRYPIXEL+0
              STZ   SHRYPIXEL+1
              PLA
              STA   SHRXPIXEL+1
              PLA
              STA   SHRXPIXEL+0
:DONE         >>>   XF2AUX,GFXPLOTRET
:BAIL         PLA
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
* Called in emulation mode or 8 bit native mode
SHRPOINT      LDX   A2L                    ; Screen row (Y-coord)
              LDA   SHRROWSL,X             ; Look up addr (LS byte)
              STA   A3L                    ; Stash in A3L
              LDA   SHRROWSH,X             ; Look up addr (MS byte)
              STA   A3H                    ; Stash in A3H
              LDA   #$E1                   ; Bank $E1
              STA   A4L

              LDX   A1L                    ; Store X-coord for later
              LSR   A1H                    ; Divide by 4
              ROR   A1L
              LSR   A1H
              ROR   A1L
              LDY   A1L                    ; Index into row of pixels

              LDA   SHRPIXELS              ; Pixels per byte
              CMP   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :MODE0

              TXA
              LSR
              AND   #$01                   ; Keep LSB bit only
              TAX                          ; Index into :BITS320

              LDA   :BITS320,X             ; Get bit pattern for pixel to set
              BRA   :DOPLOT
              
:MODE0        TXA
              AND   #$03                   ; Keep LSB two bits only
              TAX                          ; Index into :BITS640

              LDA   :BITS640,X             ; Get bit pattern for pixel to set
:DOPLOT       PHA

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
SHRLINE       LDA   A2L                    ; y1
              SEC
              SBC   SHRYPIXEL              ; Subtract y0
              BPL   :S1                    ; Skip if +ve
              EOR   #$FF                   ; Negate if -ve
              INC   A
:S1           STA   SHRTMPWRD+0            ; abs(y1 - y0)
              STZ   SHRTMPWRD+1            ; Pad to 16 bit
              PHP                          ; Disable interrupts
              SEI
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
:S2           CMP   SHRTMPWRD              ; Cmp abs(x1 - x0) w/ abs(y1 - y0)
              BCC   :YDOM                  ; abs(x1 - x0) < abs(y1 - y0)

:XDOM         LDA   SHRXPIXEL              ; x0
              CMP   A1L                    ; x1
              BCS   :X1                    ; x0 >= x1
              JMP   SHRLINELO              ; x0 < x1
:X1           JSR   SHRLINESWAP            ; Swap parms
              JMP   SHRLINELO

:YDOM         LDA   SHRYPIXEL              ; y0
              CMP   A2L                    ; y1
              BCS   :Y1                    ; y0 >= y1
              JMP   SHRLINEHI              ; y0 < y1
:Y1           JSR   SHRLINESWAP            ; Swap parms
              JMP   SHRLINEHI


* Swap (x0, y0) and (x1, y1)
* Called in 16 bit 65816 native mode
SHRLINESWAP   LDA   SHRXPIXEL              ; x0
              STA   SHRTMPWRD
              LDA   A1L                    ; x1
              STA   SHRXPIXEL
              LDA   SHRTMPWRD
              STA   A1L
              LDA   SHRYPIXEL              ; y0
              STA   SHRTMPWRD
              LDA   A2L                    ; y1
              STA   SHRYPIXEL
              LDA   SHRTMPWRD
              STA   A2L
              RTS


* Plot x-dominant line (shallow gradient)
* Called in 16 bit 65816 native mode. Returns in emulation mode.
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
              EOR   #$FFFF                 ; Negate dy
              INC   A
              STA   :DY                    ; dy = -dy
              LDA   #$FFFF
              STA   :YI                    ; yi = -1
:S1           LDA   :DY                    ; dy
              ASL                          ; 2 * dy
              SEC
              SBC   :DX                    ; (2 * dy) - dx
              STA   :D                     ; D = (2 * dy) - dx
              LDA   SHRYPIXEL              ; y0
              STA   A2L                    ; y = y0 (re-using A2L/H)
              LDA   :DY
              SEC
              SBC   :DX
              ASL
              STA   :DX                    ; DX now (2 * (dy - dx)
              LDA   :DY
              ASL
              STA   :DY                    ; DY now (2 * dy)
              LDX   SHRXPIXEL              ; x = x0
:L1           STX   A1L                    ; Store x-coord for SHRPOINT
              PHX
              SEP   #$30                   ; 8 bit M & X
              MX    %11                    ; Tell Merlin
              JSR   SHRPOINT               ; x in A1L/H, y in A2L
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              PLX
              LDA   :D
              BMI   :S2                    ; D < 0
              CLC
              ADC   :DX
              STA   :D                     ; D = D + (2 * (dy - dx))
              LDA   A2L                    ; y
              CLC
              ADC   :YI
              STA   A2L                    ; y = y + yi
              BRA   :S3
:S2           CLC
              ADC   :DY
              STA   :D                     ; D = D + 2 * dy
:S3           INX
              CPX   :LIM                   ; Compare with x1
              BNE   :L1

              SEC                          ; 65816 emulation mode
              XCE
              MX    %11                    ; Tell Merlin
              PLP                          ; Resume normal service
              RTS
:DX           DW    $0000                  ; dx initially, then (2 * (dy - dx))
:DY           DW    $0000                  ; dy initially, then (2 * dy)
:YI           DW    $0000                  ; +1 or -1
:D            DW    $0000                  ; D
:LIM          DW    $0000                  ; x1 gets stashed here


* Plot y-dominant line (steep gradient)
* Called in 16 bit 65816 native mode. Returns in emulation mode.
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
              EOR   #$FFFF                 ; Negate dx
              INC   A
              STA   :DX                    ; dx = -dx
              LDA   #$FFFF
              STA   :XI                    ; xi = -1
:S1           LDA   :DX                    ; dx
              ASL                          ; 2 * dx
              SEC
              SBC   :DY                    ; (2 * dx) - dy
              STA   :D                     ; D = (2 * dx) - dy
              LDA   SHRXPIXEL              ; x0
              STA   :X                     ; x = x0
              LDA   :DX
              SEC
              SBC   :DY
              ASL
              STA   :DY                    ; DY now (2 * (dx - dy)
              LDA   :DX
              ASL
              STA   :DX                    ; DX now (2 * dx)
              LDX   SHRYPIXEL              ; y = y0
:L1           LDA   :X
              STA   A1L                    ; Store x-coord for SHRPOINT
              STX   A2L                    ; Store y-coord for SHRPOINT
              PHX
              SEP   #$30                   ; 8 bit M & X
              MX    %11                    ; Tell Merlin
              JSR   SHRPOINT               ; x in A1L/H, y in A2L
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              PLX
              LDA   :D
              BMI   :S2                    ; D < 0
              CLC
              ADC   :DY
              STA   :D                     ; D = D + (2 * (dx - dy))
              LDA   :X                     ; x
              CLC
              ADC   :XI
              STA   :X                     ; x = x + xi
              BRA   :S3
:S2           CLC
              ADC   :DX
              STA   :D                     ; D = D + 2 * dx
:S3           INX
              CPX   :LIM                   ; Compare with y1
              BNE   :L1

              SEC                          ; 65816 emulation mode
              XCE
              MX    %11                    ; Tell Merlin
              PLP                          ; Resume normal service
              RTS
:X            DW    $0000
:DX           DW    $0000                  ; dx initially, then (2 * dx)
:DY           DW    $0000                  ; dy initially, then (2 * (dy - dx)))
:XI           DW    $0000                  ; +1 or -1
:D            DW    $0000                  ; D
:LIM          DW    $0000                  ; x1 gets stashed here


* Convert high-resolution screen coordinates
* from 1280x1024 to 640x200 or 320x200
* On return: X-coordinate in A1L/H, Y-coordinate in A2L (A2H=0)
SHRCOORD      PHP                          ; Disable interrupts
              SEI
              CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin

* X-coordinate in SHRVDUQ+5,+6   1280/2=640
              LDA   SHRVDUQ+5
              LSR                          ; /2
              STA   A1L                    ; Result in A1L/H

* Y-coordinate in SHRVDUQ+7,+8   1024*25/128=200
:Y            LDA   SHRVDUQ+7
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
              XBA                          ; Clever trick: fewer shifts
              STA   A2L                    ; Into A2L/H
        
              SEC                          ; Back to emulation mode
              XCE
              MX    %11                    ; Tell Merlin
              PLP                          ; Normal service resumed
              RTS


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

