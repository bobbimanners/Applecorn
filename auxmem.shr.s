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

* Pixel masks for colours in 640 mode
SHRCMASK640   DB    %00000000
              DB    %01010101
              DB    %10101010
              DB    %11111111

* Pixel masks for colours in 320 mode
SHRCMASK320   DB    $00
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
              STZ   CLR80VID               ; 40 column text mode
              BRA   :S1
:MODE0        LDA   #SCB640                ; SCB for 640-mode
              STZ   SET80VID               ; 80 column text mode
:S1           LDX   #$00
:L1           STAL  $E19D00,X              ; SCBs begin at $9D00 in $E1
              INX
              CPX   #200                   ; 200 lines so 200 SCBs
              BNE   :L1
              JSR   SHRDEFPAL              ; Default palette
              >>>   XF2MAIN,SHRXPLDFONT    ; Explode font -> SHRFONTXPLD table
SHRV22RET     >>>   ENTAUX
              JSR   VDU12                  ; Clear text and SHR screen
              RTS

******************************************************************************
* Data in bank $E1
******************************************************************************

* Used for long writes
SHRCOLMASKL   EQU   $E1B000                ; Colour mask foreground (word)
SHRBGMASKL    EQU   $E1B002                ; Colour mask background (word)

* Used for reads via data bank reg
SHRCOLMASK    EQU   $B000                  ; Colour mask foreground (word)
SHRBGMASK     EQU   $B002                  ; Colour mask background (word)

******************************************************************************

SHRBGMASKA    DW    $0000                  ; Keep a copy in aux mem too


* Write character to SHR screen
* On entry: A - character to write
SHRPRCHAR     LDX   VDUPIXELS              ; Pixels per byte
              CPX   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :S1
              JMP   SHRPRCH320
:S1           JMP   SHRPRCH640


* Plot or unplot a cursor on SHR screen
* On entry: A - character to plot, CS show cursor/CC remove cursor
SHRCURSOR     PHP                          ; Preserve flags
              PHA                          ; Preserve character
              LDA   VDUSTATUS              ; If VDU5 mode, bail
              AND   #$20
              BNE   :BAIL
              LDA   VDUPIXELS              ; Pixels per byte
              CMP   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :MODE0
              LDA   #$04                   ; 4 bytes in 320 mode
              LDX   #$71                   ; White/red
              BRA   :S1
:MODE0        LDA   #$02                   ; 2 bytes in 640 mode
              LDX   #%11011101             ; White/red/white/red
:S1           STA   :BYTES                 ; Bytes per char
              STX   :CURSBYTE
              LDA   #$E1
              STA   VDUBANK2
              JSR   SHRCHARADDR            ; Screen addr in VDUADDR
              LDA   VDUADDR+0              ; LSB
              CLC
              ADC   #<$460                 ; $460 is seven rows
              STA   VDUADDR+0
              LDA   VDUADDR+1              ; MSB
              ADC   #>$460                 ; $460 is seven rows
              STA   VDUADDR+1
              LDY   #$00
              PLA                          ; Recover character
              PLP                          ; Recover flags
              BCC   :CURSOROFF
:CURSORON
              LDA   [VDUADDR],Y            ; See if cursor shown
              CMP   :CURSBYTE
              BEQ   :DONE
              LDX   :CURSBYTE
:L1           LDAL  [VDUADDR],Y
              STA   :SAVEBYTES,Y           ; Preserve bytes under cursor
              TXA                          ; Byte of cursor data
              STAL  [VDUADDR],Y
              INY
              CPY   :BYTES
              BNE   :L1
              RTS
:CURSOROFF
              LDA   [VDUADDR],Y            ; See if cursor shown
              CMP   :CURSBYTE
              BNE   :DONE
:L2           LDA   :SAVEBYTES,Y           ; Restore bytes under cursor
              STAL  [VDUADDR],Y
              INY
              CPY   :BYTES
              BNE   :L2
:DONE         RTS
:BAIL         PLA                          ; Fix stack
              PLA
              RTS
:BYTES        DB    $00                    ; 2 for 640-mode, 4 for 320-mode
:CURSBYTE     DB    $00                    ; Cursor byte for mode
:SAVEBYTES    DS    4                      ; Bytes under cursor


* Write character to SHR screen in 320 pixel mode
SHRPRCH320    SEC
              SBC   #32
              TAX

              LDA   VDUSTATUS
              AND   #$20                   ; Bit 5 text@gfx cursor
              BEQ   SHRPRCH320V4           ; VDU 4
              TXA
              >>>   XF2MAIN,SHRVDU5CH      ; VDU5
SHRPRCH320RET >>>   ENTAUX
              RTS

SHRPRCH320V4  TXA
              PHP                          ; Disable interrupts
              SEI
              CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              AND   #$00FF
              STA   VDUADDR2               ; A*32 -> VDUADDR2
              ASL   VDUADDR2
              ASL   VDUADDR2
              ASL   VDUADDR2
              ASL   VDUADDR2
              ASL   VDUADDR2
              CLC                          ; SHRFONTXPLD+A*32 -> VDUADDR2
              LDA   VDUADDR2
              ADC   #SHRFONTXPLD
              STA   VDUADDR2
              SEP   #$30                   ; 8 bit M & X
              MX    %11                    ; Tell Merlin
              LDA   #$E1
              STA   VDUBANK2
              JSR   SHRCHARADDR            ; Screen addr in VDUADDR

* 65816 code contributed by John Brooks follows ...

              PHB                          ; Save data bank
              LDA   VDUBANK2               ; Push font Bank onto stack
              PHA
              PLB                          ; Set data bank to font bank
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
              TAX

              LDA   VDUSTATUS
              AND   #$20                   ; Bit 5 text@gfx cursor
              BEQ   SHRPRCH640V4           ; VDU 4
              TXA
              >>>   XF2MAIN,SHRVDU5CH      ; VDU5
* (Returns via SHRPRCH320RET)

SHRPRCH640V4  TXA
              PHP                          ; Disable interrupts
              SEI
              CLC                          ; 65816 native mode
              XCE
              REP   #$30                   ; 16 bit M & X
              MX    %00                    ; Tell Merlin
              AND   #$00FF
              STA   VDUADDR2               ; A*16 -> VDUADDR2
              ASL   VDUADDR2
              ASL   VDUADDR2
              ASL   VDUADDR2
              ASL   VDUADDR2
              CLC                          ; SHRFONTXPLD+A*16 -> VDUADDR2
              LDA   VDUADDR2
              ADC   #SHRFONTXPLD
              STA   VDUADDR2
              SEP   #$30                   ; 8 bit M & X
              MX    %11                    ; Tell Merlin
              LDA   #$E1
              STA   VDUBANK2
              JSR   SHRCHARADDR            ; Screen addr in VDUADDR

* 65816 code contributed by John Brooks follows ...

              PHB                          ; Save data bank
              LDA   VDUBANK2               ; Push font Bank onto stack
              PHA
              PLB                          ; Set data bank to font bank
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
* Called in 65816 native mode, 16 bit
SHRCOLWORD    MX    %00                    ; Tell Merlin 16 bit M & X
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
              LDY   VDUPIXELS              ; Pixels per byte
              CPY   #$02                   ; 2 pixels per byte in 320 mode
              BNE   :S1
              ASL                          ; Double TXTWINLFT
:S1           ASL                          ; 2 bytes / char
              AND   #$00ff                 ; Mask to get 8 bit result
              ADC   VDUADDR                ; Add to beginning of line addr
              STA   VDUADDR                ; VDUADDR = start position
              SEP   #$21                   ; M 8 bit, X 16 bit, carry set
              MX    %10                    ; Tell Merlin
              LDA   TXTWINRGT              ; Compute width ..
              SBC   TXTWINLFT              ; .. right minus left
              LDY   VDUPIXELS              ; Pixels per byte
              CPY   #$02                   ; 2 pixels per byte in 320 mode
              BNE   :S2
              ASL                          ; Double the width for 320
              INC   A                      ; Plus one
:S2           REP   #$31                   ; M,X 16 bit, carry clear
              MX    %00                    ; Tell Merlin
              ASL                          ; 2 bytes / char
              AND   #$00ff                 ; Mask to get 8 bit result
              ADC   VDUADDR                ; Add to start position
              TAX                          ; Will use as index
              PEA   #$E1E1                 ; Set databank to $E1
              PLB
              PLB
:LOOP1        LDA   $2500,X                ; 2 bytes, row 0
              STA   $2000,X
              LDA   $25A0,X                ; row 1
              STA   $20A0,X
              LDA   $2640,X                ; row 2
              STA   $2140,X
              LDA   $26E0,X                ; row 3
              STA   $21E0,X
              LDA   $2780,X                ; row 4
              STA   $2280,X
              LDA   $2820,X                ; row 5
              STA   $2320,X
              LDA   $28C0,X                ; row 6
              STA   $23C0,X
              LDA   $2960,X                ; row 7
              STA   $2460,X
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
SHRRSCR1LINE  PHY
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
              LDY   VDUPIXELS              ; Pixels per byte
              CPY   #$02                   ; 2 pixels per byte in 320 mode
              BNE   :S1
              ASL                          ; Double TXTWINLFT
:S1           ASL                          ; 2 bytes / char
              AND   #$00ff                 ; Mask to get 8 bit result
              ADC   VDUADDR                ; Add to beginning of line addr
              STA   VDUADDR                ; VDUADDR = start position
              SEP   #$21                   ; M 8 bit, X 16 bit, carry set
              MX    %10                    ; Tell Merlin
              LDA   TXTWINRGT              ; Compute width ..
              SBC   TXTWINLFT              ; .. right minus left
              LDY   VDUPIXELS              ; Pixels per byte
              CPY   #$02                   ; 2 pixels per byte in 320 mode
              BNE   :S2
              ASL                          ; Double the width for 320
              INC   A                      ; Plus one
:S2           REP   #$31                   ; M,X 16 bit, carry clear
              MX    %00                    ; Tell Merlin
              ASL                          ; 2 bytes / char
              AND   #$00ff                 ; Mask to get 8 bit result
              ADC   VDUADDR                ; Add to start position
              TAX                          ; Will use as index
              PEA   #$E1E1                 ; Set databank to $E1
              PLB
              PLB
:LOOP1        LDA   $2000,X                ; 2 bytes, row 0
              STA   $2500,X
              LDA   $20A0,X                ; row 1
              STA   $25A0,X
              LDA   $2140,X                ; row 2
              STA   $2640,X
              LDA   $21E0,X                ; row 3
              STA   $26E0,X
              LDA   $2280,X                ; row 4
              STA   $2780,X
              LDA   $2320,X                ; row 5
              STA   $2820,X
              LDA   $23C0,X                ; row 6
              STA   $28C0,X
              LDA   $2460,X                ; row 7
              STA   $2960,X
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


* Clear from current location to EOL
SHRCLREOL     JSR   SHRCHARADDR
              STZ   VDUADDR+0              ; Addr of start of line
              LDA   #$08                   ; Eight rows of pixels
              STA   :CTR
              INC   TXTWINRGT
:L0           LDA   VDUTEXTX
              TAX
              ASL                          ; 2 bytes / char
              LDY   VDUPIXELS              ; Pixels per byte
              CPY   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :S0
              ASL                          ; 4 bytes / char
:S0           TAY
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


* VDU16 (CLG) clears the graphics window
SHRCLEAR      >>>   XF2MAIN,SHRVDU16
SHRCLRRET     >>>   ENTAUX
              RTS


* Set text colour
* A=text colour
SHRSETTCOL    PHA
              LDX   VDUPIXELS              ; Pixels per byte
              CPX   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :MODE0
              AND   #$80
              BEQ   :FORE320
              PLA
              AND   #$0F
              TAX
              LDA   SHRCMASK320,X          ; Lookup mask in table
              STAL  SHRBGMASKL             ; Set colour mask (BG)
              STAL  SHRBGMASKL+1
              STA   SHRBGMASKA
              RTS
:FORE320      PLA
              AND   #$0F
              TAX
              LDA   SHRCMASK320,X          ; Lookup mask in table
              STAL  SHRCOLMASKL            ; Set colour mask (FG)
              STAL  SHRCOLMASKL+1
              RTS
:MODE0        AND   #$80
              BEQ   :FORE640
              PLA
              AND   #$03
              TAX
              LDA   SHRCMASK640,X          ; Lookup mask in table
              STAL  SHRBGMASKL             ; Set colour mask (BG)
              STAL  SHRBGMASKL+1
              STA   SHRBGMASKA
              RTS
:FORE640      PLA
              AND   #$03
              TAX
              LDA   SHRCMASK640,X          ; Lookup mask in table
              STAL  SHRCOLMASKL            ; Set colour mask (FG)
              STAL  SHRCOLMASKL+1
              RTS


* Set graphics colour
* A=gfx colour, X=gcol action
* GCOL actions:
*  0 = SET pixel
*  1 = ORA with pixel
*  2 = AND with pixel
*  3 = XOR with pixel
*  4 = NOT pixel
*  5 = NUL no change to pixel
*  6 = CLR clear pixel to background
*  7 = UND undefined
SHRSETGCOL    PHA
              LDY   VDUPIXELS              ; Pixels per byte
              CPY   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :MODE0
              AND   #$80
              BEQ   :FORE320
              PLA
              AND   #$0F
              TAY
              LDA   SHRCMASK320,Y          ; Lookup mask in table
              >>>   WRTMAIN
              STA   SHRGFXBGMASK
              >>>   WRTAUX
              RTS
:FORE320      PLA
              AND   #$0F
              TAY
              LDA   SHRCMASK320,Y          ; Lookup mask in table
              >>>   WRTMAIN
              STA   SHRGFXFGMASK
              STX   SHRGFXACTION
              >>>   WRTAUX
              RTS
:MODE0        AND   #$80
              BEQ   :FORE640
              PLA
              AND   #$03
              TAY
              LDA   SHRCMASK640,Y          ; Lookup mask in table
              >>>   WRTMAIN
              STA   SHRGFXBGMASK
              >>>   WRTAUX
              RTS
:FORE640      PLA
              AND   #$03
              TAY
              LDA   SHRCMASK640,Y          ; Lookup mask in table
              >>>   WRTMAIN
              STA   SHRGFXFGMASK
              STX   SHRGFXACTION
              >>>   WRTAUX
              RTS

* Set up default palette
SHRDEFPAL     LDY   #00                    ; Palette offset for 320 mode
              LDA   VDUPIXELS              ; Pixels per byte
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
              RTS


* Assign a 'physical' colour from the 16 colour palette to a
* 'logical' colour for the current mode
* On entry: X=logical colour, Y=physical colour
SHRPALCHANGE  TYA
              AND   #%00011110             ; Has already been shifted
              TAY
              LDA   VDUPIXELS              ; Pixels per byte
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
              RTS
:MODE320      TXA
              AND   #%00011110             ; Has already been shifted
              TAX
              LDA   PALETTE320,Y           ; Byte 1 of physical colour
              STAL  $E19E00,X              ; Store in logical slot
              LDA   PALETTE320+1,Y         ; Byte 2 of physical colour
              STAL  $E19E00+1,X            ; Store in logical slot
              RTS


* Assign a custom RGB colour to a 'logical' colour
* On entry: X=logical colour, A=GB components, Y=R component
SHRPALCUSTOM  PHA                          ; Preserve GB components
              LDA   VDUPIXELS              ; Pixels per byte
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
              RTS
:MODE320      TXA
              AND   #%00011110             ; Has already been shifted
              TAX
              PLA                          ; Recover GB components
              STAL  $E19E00,X              ; Store in logical slot
              TYA                          ; R component
              STAL  $E19E00+1,X            ; Store in logical slot
              RTS

