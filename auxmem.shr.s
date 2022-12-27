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
              DB    $00, $0F               ; RED
              DB    $F0, $00               ; GREEN
              DB    $F0, $0F               ; YELLOW
              DB    $0F, $00               ; BLUE
              DB    $0F, $0F               ; MAGENTA
              DB    $FF, $00               ; CYAN
              DB    $FF, $0F               ; WHITE
              DB    $44, $04               ; Dark grey
              DB    $00, $07               ; RED (dim)
              DB    $70, $00               ; GREEN (dim)
              DB    $70, $07               ; YELLOW (dim)
              DB    $07, $00               ; BLUE (dim)
              DB    $07, $07               ; MAGENTA (dim)
              DB    $77, $00               ; CYAN (dim)
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

******************************************************************************
* Data in bank $E1
******************************************************************************

SHRFONTXPLD   EQU   $A000                  ; Explode SHR font to $E1:A000

* Used for long writes
SHRCOLMASKL   EQU   $E1B000                ; Colour mask foreground (word)
SHRBGMASKL    EQU   $E1B002                ; Colour mask background (word)

* Used for reads via data bank reg
SHRCOLMASK    EQU   $B000                  ; Colour mask foreground (word)
SHRBGMASK     EQU   $B002                  ; Colour mask background (word)

******************************************************************************

SHRBGMASKA    DW    $0000                  ; Keep a copy in aux mem too


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
* On entry: A contains row of font data
SHRCHAR320    PHY                          ; Preserve Y
              LDY   #$00                   ; Dest byte index
:L0           STZ   ZP2
              LDX   #$00                   ; Source bit index
:L1           ASL                          ; MS bit -> C
              PHP                          ; Preserve C
              ROL   ZP2                    ; C -> LS bit
              PLP                          ; Recover C
              PHP
              ROL   ZP2                    ; C -> LS bit
              PLP                          ; Recover C
              PHP
              ROL   ZP2                    ; C -> LS bit
              PLP                          ; Recover C
              ROL   ZP2                    ; C -> LS bit
              INX
              CPX   #$02                   ; Processed two bits of font?
              BNE   :L1
              PHA                          ; Preserve partially shifted font
              LDA   ZP2
              STA   [VDUADDR],Y
              PLA                          ; Recover partially shifted font
              INY
              CPY   #$04                   ; Done 4 bytes?
              BNE   :L0
              PLY                          ; Recover Y
              RTS


* Draw one pixel row of font in 640 mode
* 2 bytes per char, 2 bits per pixel
* On entry: A contains row of font data
SHRCHAR640    PHY                          ; Preserve Y
              LDY   #$00                   ; Dest byte index
:L0           STZ   ZP2
              LDX   #$00                   ; Source bit index
:L1           ASL                          ; MS bit -> C
              PHP                          ; Preserve C
              ROL   ZP2                    ; C -> LS bit
              PLP                          ; Recover C
              ROL   ZP2                    ; C -> LS bit
              INX
              CPX   #$04
              BNE   :L1
              PHA                          ; Preserve partially shifted font
              LDA   ZP2
              STA   [VDUADDR],Y
              PLA                          ; Recover partially shifted font
              INY
              CPY   #$02                   ; Done 2 bytes?
              BNE   :L0
              PLY                          ; Recover Y
              RTS


* Write character to SHR screen
* On entry: A - character to write
SHRPRCHAR     LDX   VDUPIXELS              ; Pixels per byte
              CPX   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :S1
              JMP   SHRPRCH320
:S1           JMP   SHRPRCH640


* Write character to SHR screen in 320 pixel mode
SHRPRCH320    SEC
              SBC   #32
              STA   VDUADDR2+0             ; A*32 -> VDUADDR2
              STZ   VDUADDR2+1
              ASL   VDUADDR2+0
              ROL   VDUADDR2+1
              ASL   VDUADDR2+0
              ROL   VDUADDR2+1
              ASL   VDUADDR2+0
              ROL   VDUADDR2+1
              ASL   VDUADDR2+0
              ROL   VDUADDR2+1
              ASL   VDUADDR2+0
              ROL   VDUADDR2+1
              CLC                          ; SHRFONTXPLD+A*32 -> VDUADDR2
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

              PHP                          ; Disable interrupts
              SEI
              PHB                          ; Save data bank
              LDA   VDUBANK2               ; Push font Bank onto stack
              PHA
              PLB                          ; Set data bank to font bank
              CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              LDY   VDUADDR2               ; Font src ptr
              LDX   VDUADDR                ; SHR dst ptr
              LDA   !$000000,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E10000,X              ; Write 2 bytes to screen
              LDA   !$000002,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E10002,X              ; Write 2 bytes to screen
              LDA   !$000004,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E100A0,X              ; Write 2 bytes to screen
              LDA   !$000006,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E100A2,X              ; Write 2 bytes to screen
              LDA   !$000008,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E10140,X              ; Write 2 bytes to screen
              LDA   !$00000A,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E10142,X              ; Write 2 bytes to screen
              LDA   !$00000C,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E101E0,X              ; Write 2 bytes to screen
              LDA   !$00000E,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E101E2,X              ; Write 2 bytes to screen
              LDA   !$000010,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E10280,X              ; Write 2 bytes to screen
              LDA   !$000012,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E10282,X              ; Write 2 bytes to screen
              LDA   !$000014,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E10320,X              ; Write 2 bytes to screen
              LDA   !$000016,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E10322,X              ; Write 2 bytes to screen
              LDA   !$000018,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E103C0,X              ; Write 2 bytes to screen
              LDA   !$00001A,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E103C2,X              ; Write 2 bytes to screen
              LDA   !$00001C,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E10460,X              ; Write 2 bytes to screen
              LDA   !$00001E,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E10462,X              ; Write 2 bytes to screen
              PLB                          ; Recover data bank
              SEC                          ; Back to emulation mode
              XCE
              MX    %11                    ; Tell Merlin
              PLP                          ; Normal service resumed
              RTS


* Write character to SHR screen in 640 pixel mode
SHRPRCH640    SEC
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

              PHP                          ; Disable interrupts
              SEI
              PHB                          ; Save data bank
              LDA   VDUBANK2               ; Push font Bank onto stack
              PHA
              PLB                          ; Set data bank to font bank
              CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              LDY   VDUADDR2               ; Font src ptr
              LDX   VDUADDR                ; SHR dst ptr
              LDA   !$000000,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E10000,X              ; Write 2 bytes to screen
              LDA   !$000002,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E100A0,X              ; Write 2 bytes to screen
              LDA   !$000004,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E10140,X              ; Write 2 bytes to screen
              LDA   !$000006,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E101E0,X              ; Write 2 bytes to screen
              LDA   !$000008,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E10280,X              ; Write 2 bytes to screen
              LDA   !$00000A,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E10320,X              ; Write 2 bytes to screen
              LDA   !$00000C,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E103C0,X              ; Write 2 bytes to screen
              LDA   !$00000E,Y             ; Read 2 bytes of exploded font
              JSR   SHRCOLWORD
              STAL  $E10460,X              ; Write 2 bytes to screen
              PLB                          ; Recover data bank
              SEC                          ; Back to emulation mode
              XCE
              MX    %11                    ; Tell Merlin
              PLP                          ; Normal service resumed
              RTS


* Apply colour masks to 16 bit word of character data
* Called in 6816 native mode, 16 bit
              MX    %00                    ; Tell Merlin 16 bit M & X
SHRCOLWORD
              PHA                          ; Keep A
              AND   SHRCOLMASK             ; Mask to set foreground colour
              STA   ZP1                    ; Keep foreground
              PLA                          ; Get original A back
              EOR   #$FFFF                 ; Invert bits
              AND   SHRBGMASK              ; Apply background colour mask
              EOR   ZP1                    ; Combine with foreground
              RTS
              MX    %11


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
SHRSCR1LINE   PHY
              PHX
              STA   VDUADDR+1              ; Screen line -> MSB
              STZ   VDUADDR+0              ; Zero LSB
              PHP                          ; Disable interrupts
              SEI
              CLC                          ; Enter native mode
              XCE
              PHB                          ; Preserve data bank
              REP   #$31                   ; M,X 16 bit, carry clear
              MX    %00                    ; Tell Merlin
              LDA   VDUADDR                ; Screen line to scroll
              ASL                          ; Mult 4
              ASL
              ADC   VDUADDR                ; Mult 5
              STA   VDUADDR                ; VDUADDR = line * $500
              LDA   TXTWINLFT              ; Left margin
              ASL                          ; 2 bytes / char
              LDY   VDUPIXELS              ; Pixels per byte
              CPY   #$02                   ; 2 pixels per byte in 320 mode
              BNE   :S1
              ASL                          ; 4 bytes / char
:S1           AND   #$00ff                 ; Mask to get 8 bit result
              ADC   VDUADDR                ; Add to beginning of line addr
              STA   VDUADDR                ; VDUADDR = start position
              SEP   #$21                   ; M 8 bit, X 16 bit, carry set
              MX    %10                    ; Tell Merlin
              LDA   TXTWINRGT              ; Compute width ..
              SBC   TXTWINLFT              ; .. right minus left
              REP   #$31                   ; M,X 16 bit, carry clear
              MX    %00                    ; Tell Merlin
              ASL                          ; 2 bytes / char
              LDY   VDUPIXELS              ; Pixels per byte
              CPY   #$02                   ; 2 pixels per byte in 320 mode
              BNE   :S2
              ASL                          ; 4 bytes / char
:S2           AND   #$00ff                 ; Mask to get 8 bit result
              ADC   VDUADDR                ; Add to start position
              TAX                          ; Will use as index
              PEA   #$e1e1                 ; Set databank to $E1
              PLB
              PLB
:LOOP1        LDA   $2500,x                ; 2 bytes, row 0
              STA   $2000,x
              LDA   $25a0,x                ; row 1
              STA   $20a0,x
              LDA   $2640,x                ; row 2
              STA   $2140,x
              LDA   $26e0,x                ; row 3
              STA   $21e0,x
              LDA   $2780,x                ; row 4
              STA   $2280,x
              LDA   $2820,x                ; row 5
              STA   $2320,x
              LDA   $28c0,x                ; row 6
              STA   $23c0,x
              LDA   $2960,x                ; row 7
              STA   $2460,x
              DEX                          ; Update index
              DEX
              BMI   :DONE                  ; Jump out if odd->-ve
              CPX   VDUADDR                ; Compare with start addr
              BCS   :LOOP1                 ; Bytes left? Go again
:DONE         PLB                          ; Recover data bank
              SEC                          ; Back to emulation mode
              XCE
              PLP                          ; Recover flags + regs
              PLX
              PLY
              RTS


* Reverse scroll one line
* Copy text line A to line A+1
* TODO: Implement this
SHRRSCR1LINE
              RTS


* Clear from current location to EOL
SHRCLREOL     JSR   SHRCHARADDR
              STZ   VDUADDR+0              ; Addr of start of line
              LDA   #$08                   ; Eight rows of pixels
              STA   :CTR
              INC   TXTWINRGT
:L0           LDA   VDUTEXTX
              TAX
              ASL                          ; 2 bytes / char
              TAY
:L1           CPX   TXTWINRGT
              BCS   :S1
              LDA   SHRBGMASKA
              STA   [VDUADDR],Y
              INY
              STA   [VDUADDR],Y
              INY
              LDA   VDUPIXELS              ; Pixels per byte
              CMP   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :S2
              LDA   SHRBGMASKA
              STA   [VDUADDR],Y
              INY
              STA   [VDUADDR],Y
              INY
:S2           INX
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
SHRSETTCOL    PHA
              LDX   VDUPIXELS              ; Pixels per byte
              CPX   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :MODE0
              AND   #$80
              BEQ   :FORE320
              PLA
              AND   #$0F
              TAX
              LDA   :MASKS320,X            ; Lookup mask in table
              STAL  SHRBGMASKL             ; Set colour mask (BG)
              STAL  SHRBGMASKL+1
              STA   SHRBGMASKA
              RTS
:FORE320      PLA
              AND   #$0F
              TAX
              LDA   :MASKS320,X            ; Lookup mask in table
              STAL  SHRCOLMASKL            ; Set colour mask (FG)
              STAL  SHRCOLMASKL+1
              RTS
:MODE0        AND   #$80
              BEQ   :FORE640
              PLA
              AND   #$03
              TAX
              LDA   :MASKS640,X            ; Lookup mask in table
              STAL  SHRBGMASKL             ; Set colour mask (BG)
              STAL  SHRBGMASKL+1
              STA   SHRBGMASKA
              RTS
:FORE640      PLA
              AND   #$03
              TAX
              LDA   :MASKS640,X            ; Lookup mask in table
              STAL  SHRCOLMASKL            ; Set colour mask (FG)
              STAL  SHRCOLMASKL+1
              RTS
:MASKS640     DB    %00000000
              DB    %01010101
              DB    %10101010
              DB    %11111111
:MASKS320     DB    $00
              DB    $11
              DB    $22
              DB    $33
              DB    $44
              DB    $55
              DB    $66
              DB    $77
              DB    $88
              DB    $99
              DB    $AA
              DB    $BB
              DB    $CC
              DB    $DD
              DB    $EE
              DB    $FF


