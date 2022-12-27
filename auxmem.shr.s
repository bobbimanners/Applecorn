* AUXMEM.SHR.S
* (c) Bobbi 2022 GPLv3
*
* Routines for drawing bitmapped text and graphics in SHR mode
* on Apple IIGS (640x200 4 colour, or 320x200 16 colour.)
*

SCB320        EQU   $00                    ; SCB for 320 mode
SCB640        EQU   $80                    ; SCB for 640 mode


* Colours in the following order.
* For 16 colour modes ...
* BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE, ...
* For 4 colour modes ...
* BLACK, RED, YELLOW, WHITE

PALETTE320    DB    $00, $00               ; BLACK
              DB    $00, $08               ; RED
              DB    $80, $00               ; GREEN
              DB    $80, $08               ; YELLOW
              DB    $08, $00               ; BLUE
              DB    $08, $08               ; MAGENTA
              DB    $88, $00               ; CYAN
              DB    $88, $08               ; WHITE
              DB    $00, $00               ; BLACK
              DB    $00, $08               ; RED
              DB    $80, $00               ; GREEN
              DB    $80, $08               ; YELLOW
              DB    $08, $00               ; BLUE
              DB    $08, $08               ; MAGENTA
              DB    $88, $00               ; CYAN
              DB    $88, $08               ; WHITE

PALETTE640    DB    $00, $00               ; BLACK
              DB    $00, $08               ; RED
              DB    $80, $08               ; YELLOW
              DB    $88, $08               ; WHITE
              DB    $00, $00               ; BLACK
              DB    $00, $08               ; RED
              DB    $80, $08               ; YELLOW
              DB    $88, $08               ; WHITE
              DB    $00, $00               ; BLACK
              DB    $00, $08               ; RED
              DB    $80, $08               ; YELLOW
              DB    $88, $08               ; WHITE
              DB    $00, $00               ; BLACK
              DB    $00, $08               ; RED
              DB    $80, $08               ; YELLOW
              DB    $88, $08               ; WHITE

SHRCOLMASK    DB    $00                    ; Colour mask foreground
SHRBGMASK     DB    $00                    ; Colour mask background


* Addresses of start of text rows in SHR
* LS byte is always zero
* Add $A0 to get to next row of pixels
SHRTAB        DB    $20                    ; Text row 0
              DB    $25                    ; Text row 1
              DB    $2a                    ; Text row 2
              DB    $2f                    ; Text row 3
              DB    $34                    ; Text row 4
              DB    $39                    ; Text row 5
              DB    $3e                    ; Text row 6
              DB    $43                    ; Text row 7
              DB    $48                    ; Text row 8
              DB    $4d                    ; Text row 9
              DB    $52                    ; Text row 10
              DB    $57                    ; Text row 11
              DB    $5c                    ; Text row 12
              DB    $61                    ; Text row 13
              DB    $66                    ; Text row 14
              DB    $6b                    ; Text row 15
              DB    $70                    ; Text row 16
              DB    $75                    ; Text row 17
              DB    $7a                    ; Text row 18
              DB    $7f                    ; Text row 19
              DB    $84                    ; Text row 20
              DB    $89                    ; Text row 21
              DB    $8e                    ; Text row 22
              DB    $93                    ; Text row 23


* Enable SHR mode
SHRVDU22      LDA   #$18                   ; Inhibit SHR & aux HGR shadowing
              TSB   SHADOW
              LDA   #$80                   ; Most significant bit
              TSB   NEWVIDEO               ; Enable SHR mode
              LDA   VDUPIXELS              ; Pixels per byte
              CMP   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :MODE0
              LDA   #SCB320                ; SCB for 320-mode
              LDY   #00                    ; Palette offset
              STZ   CLR80VID               ; 40 column text mode
              BRA   :S1
:MODE0        LDA   #SCB640                ; SCB for 640-mode
              LDY   #32                    ; Palette offset
              STZ   SET80VID               ; 80 column text mode
:S1           LDX   #$00
:L1           STAL  $E19D00,X              ; SCBs begin at $9D00 in $E1
              INX
              CPX   #200                   ; 200 lines so 200 SCBs
              BNE   :L1
              LDX   #$00
:L2           LDA   PALETTE320,Y           ; Offset in Y computed above
              STAL  $E19E00,X              ; Palettes begin at $9E00 in $E1
              INX
              INY
              CPX   #32                    ; 32 bytes in palette
              BNE   :L2
              JSR   SHRXPLDFONT            ; Explode font -> SHRFONTXPLD table
              JSR   VDU12                  ; Clear text and SHR screen
              RTS


SHRFONTXPLD   EQU   $A000                  ; Explode SHR font to $E1:A000


* Explode font to generate SHRFONTXPLD table
* This is 2 bytes x 8 rows for each character in 640 mode
* or      4 bytes x 8 rows for each character in 320 mode
SHRXPLDFONT   LDA   #<SHRFONTXPLD          ; Use VDUADDR to point to ..
              STA   VDUADDR+0              ; .. start of table to write
              LDA   #>SHRFONTXPLD
              STA   VDUADDR+1
              LDA   #$E1
              STA   VDUBANK
              LDA   #32                    ; First char number
:L1           JSR   SHRXPLDCHAR            ; Explode char A
              INC   A
              CMP   #128                   ; 96 chars in FONT8
              BNE   :L1
              RTS


* Explode one character to location pointed to by VDUADDR
* On entry: A - character to explode
SHRXPLDCHAR   PHA
              SEC
              SBC   #32
              STA   ZP1+0                  ; A*8 -> ZP1
              STZ   ZP1+1
              ASL   ZP1+0
              ROL   ZP1+1
              ASL   ZP1+0
              ROL   ZP1+1
              ASL   ZP1+0
              ROL   ZP1+1
              CLC                          ; FONT8+A*8 -> ZP1
              LDA   ZP1+0
              ADC   #<FONT8
              STA   ZP1+0
              LDA   ZP1+1
              ADC   #>FONT8
              STA   ZP1+1
              LDY   #$00                   ; First row of char
:L1           >>>   RDMAIN
              LDA   (ZP1),Y                ; Load row of font
              >>>   RDAUX
              LDX   VDUPIXELS              ; Pixels per byte
              CPX   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :S1
              JSR   SHRCHAR320
              BRA   :S2
:S1           JSR   SHRCHAR640
:S2           LDX   VDUPIXELS              ; Pixels per byte
              CPX   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :S3
              CLC                          ; 320 mode: add 4 to VDUADDR
              LDA   VDUADDR+0
              ADC   #$04
              STA   VDUADDR+0
              LDA   VDUADDR+1
              ADC   #$00
              STA   VDUADDR+1
              BRA   :S4
:S3           CLC                          ; 640 mode: add 2 to VDUADDR
              LDA   VDUADDR+0
              ADC   #$02
              STA   VDUADDR+0
              LDA   VDUADDR+1
              ADC   #$00
              STA   VDUADDR+1
:S4           INY                          ; Next row of font
              CPY   #$08                   ; Last row?
              BNE   :L1
              PLA
              RTS


* Draw one pixel row of font in 320 mode
* 4 bytes per char, 4 bits per pixel
* TODO: Implement this
SHRCHAR320    PHY
              LDA   #$FF
              LDY   #$00
              STA   [VDUADDR],Y
              INY
              STA   [VDUADDR],Y
              INY
              STA   [VDUADDR],Y
              INY
              STA   [VDUADDR],Y
              PLY
              RTS


* Draw one pixel row of font in 640 mode
* 2 bytes per char, 2 bits per pixel
SHRCHAR640    PHY
              STZ   ZP2
              LDX   #$00                   ; Source bit index
:L1           ASL                          ; MS bit -> C
              PHP                          ; Preserve C
              ROL   ZP2                    ; C -> LS bit
              PLP                          ; Recover C
              ROL   ZP2                    ; C -> LS bit
              INX
              CPX   #$04
              BNE   :L1
              PHA
              LDA   ZP2
              STA   [VDUADDR]
              PLA
              STZ   ZP2
              LDX   #$00
:L2           ASL                          ; MS bit -> C
              PHP                          ; Preserve C
              ROL   ZP2                    ; C -> LS bit
              PLP                          ; Recover C
              ROL   ZP2                    ; C -> LS bit
              INX
              CPX   #$04
              BNE   :L2
              LDA   ZP2
              LDY   #$01
              STA   [VDUADDR],Y
              PLY
              RTS


* Write character to SHR screen
* On entry: A - character to write
* TODO: This is for 640 mode only at the moment
SHRPRCHAR     SEC
              SBC   #32
              STA   VDUADDR2+0             ; A*16 -> VDUADDR2
              STZ   VDUADDR2+1
              ASL   VDUADDR2+0
              ROL   VDUADDR2+1
              ASL   VDUADDR2+0
              ROL   VDUADDR2+1
              ASL   VDUADDR2+0
              ROL   VDUADDR2+1
              ASL   VDUADDR2+0
              ROL   VDUADDR2+1
              CLC                          ; SHRFONTXPLD+A*16 -> VDUADDR2
              LDA   VDUADDR2+0
              ADC   #<SHRFONTXPLD
              STA   VDUADDR2+0
              LDA   VDUADDR2+1
              ADC   #>SHRFONTXPLD
              STA   VDUADDR2+1
              LDA   #$E1
              STA   VDUBANK2
              JSR   SHRCHARADDR            ; Screen addr in VDUADDR

* 65816 code contributed by John Brooks follows ...

              PHB                          ; Save data bank
              LDA   VDUADDR2+2             ; Push font Bank onto stack
              PHA
              PLB                          ; Set data bank to font bank
              CLC
              XCE
              REP   #$30
              LDY   VDUADDR2               ; Font src ptr
              LDX   VDUADDR                ; SHR dst ptr
SrcFont       =     $000000
DstShr        =     $E10000
              LUP   8
              LDA   !SrcFont,Y
              STAL  DstShr,X   
SrcFont       =     SrcFont+2
DstShr        =     DstShr+160
              --^           
              PLB
              SEC
              XCE
              MX    %11
              RTS


* Apply colour masks to byte of character data
SHRCOLBYTE    PHA                          ; Keep A
              AND   SHRCOLMASK             ; Mask to set foreground colour
              STA   ZP1                    ; Keep foreground
              PLA                          ; Get original A back
              EOR   #$FF                   ; Invert bits
              AND   SHRBGMASK              ; Apply background colour mask
              EOR   ZP1                    ; Combine with foreground
              RTS


* Calculate character address in SHR screen memory
* This is the address of the first pixel row of the char
* Add $00A0 for each subsequent row
SHRCHARADDR   LDY   VDUTEXTY
              LDA   SHRTAB,Y               ; MSB
              STA   VDUADDR+1
              LDA   VDUTEXTX
              ASL                          ; Mult x 2 (4 pixels/byte)
              LDY   VDUPIXELS              ; Pixels per byte
              CPY   #$02                   ; 2 pixels per byte in 320 mode
              BNE   :S1
              ASL                          ; Mult x 2 (2 pixels/byte)
:S1           STA   VDUADDR+0              ; LSB of address
              LDA   #$E1                   ; Bank $E1
              STA   VDUBANK
              RTS
* (VDUADDR)=>character address, X=preserved


* Advance VDUADDR to the next row of pixels
SHRNEXTROW    LDA   VDUADDR+0              ; Add 160 to VDUADDR
              CLC
              ADC   #160
              STA   VDUADDR+0
              LDA   VDUADDR+1
              ADC   #$00
              STA   VDUADDR+1
              RTS


* Forwards scroll one line
* Copy text line A+1 to line A
* Note: Code for this courtesy Kent Dickey
* TODO: This is only for 640 mode at present
SHRSCR1LINE
; acc=line to scroll (0-24)
; nead to calc acc * $500.  Could use a table, but this is about as fast
        phy
	phx
	sta	VDUADDR+1
	stz	VDUADDR
	php
	sei
	clc
	xce
        phb
	rep	#$31                    ; M,X 16 bit, carry clear
        MX      %00                     ; Tell Merlin
	lda	VDUADDR
	asl
	asl
	adc	VDUADDR
	sta	VDUADDR			;; VDUADDR = line * $500
	lda	TXTWINLFT
	asl
	and	#$00ff
	adc	VDUADDR
	sta	VDUADDR			; VDUADDR = Minimum position
	sep	#$21			; M 8 bit, X 16 bit, carry set
        MX      %10                     ; Tell Merlin
	lda	TXTWINRGT
	sbc	TXTWINLFT
	rep	#$31                    ; M,X 16 bit, carry clear
        MX      %00                     ; Tell Merlin
	asl
	and	#$00ff
	adc	VDUADDR
	tax
	pea	#$e1e1
	plb
	plb
:loop1
	lda	$2500,x			;; 2 bytes, row 0
	sta	$2000,x
	lda	$25a0,x			; row 1
	sta	$20a0,x
	lda	$2640,x			; row 2
	sta	$2140,x
	lda	$26e0,x			; row 3
	sta	$21e0,x
	lda	$2780,x			; row 4
	sta	$2280,x
	lda	$2820,x			; row 5
	sta	$2320,x
	lda	$28c0,x			; row 6
	sta	$23c0,x
	lda	$2960,x			; row 7
	sta	$2460,x
	dex
	dex
	bmi	:done
	cpx	VDUADDR
	bcs	:loop1
:done
        plb
	sec
	xce
	plp
	plx
	ply
	rts


* Reverse scroll one line
* Copy text line A to line A+1
* TODO: Implement this
SHRRSCR1LINE
              RTS


* Clear from current location to EOL
* TODO: This is only for 640 mode at present
SHRCLREOL     JSR   SHRCHARADDR
              STZ   VDUADDR+0              ; Addr of start of line
              LDA   #$08                   ; Eight rows of pixels
              STA   :CTR
              INC   TXTWINRGT
:L0           LDA   VDUTEXTX
              TAX
              ASL                          ; 2 bytes / char
              TAY
              LDA   SHRBGMASK
:L1           CPX   TXTWINRGT
              BCS   :S1
              STA   [VDUADDR],Y
              INY
              STA   [VDUADDR],Y
              INY
              INX
              BRA   :L1
:S1           JSR   SHRNEXTROW
              DEC   :CTR
              BNE   :L0
              DEC   TXTWINRGT
              RTS
:CTR          DB    $00


* VDU16 (CLG) clears the whole SHR screen right now
SHRCLEAR      PHP                          ; Disable interrupts
              SEI
              CLC                          ; 816 native mode
              XCE
              REP   #$10                   ; 16 bit index
              MX    %10                    ; Tell Merlin
              LDX   #$0000
              LDA   #$00
:L1           STAL  $E12000,X              ; SHR screen @ E1:2000
              INX
              CPX   #$7D00
              BNE   :L1
              SEP   #$10                   ; Back to 8 bit index
              MX    %11                    ; Tell Merlin
              SEC                          ; Back to 6502 emu mode
              XCE
              PLP                          ; Normal service resumed
              RTS


* Set text colour
* A=txt colour
* TODO: Need to add support for 320 mode also
SHRSETTCOL    PHA
              AND   #$80
              BEQ   :FOREGND
              PLA
              AND   #$03
              TAX
              LDA   :MASKS640,X            ; Lookup mask in table
              STA   SHRBGMASK              ; Set colour mask (BG)
              RTS
:FOREGND      PLA
              AND   #$03
              TAX
              LDA   :MASKS640,X            ; Lookup mask in table
              STA   SHRCOLMASK             ; Set colour mask (FG)
              RTS
:MASKS640     DB    %00000000
              DB    %01010101
              DB    %10101010
              DB    %11111111


