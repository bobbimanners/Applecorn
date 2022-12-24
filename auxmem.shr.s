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

* Enable SHR mode
SHRVDU22      JSR   VDU12                  ; Clear text and SHR screen
              LDA   #$80                   ; Most significant bit
              TSB   NEWVIDEO               ; Enable SHR mode
              LDA   VDUPIXELS              ; Pixels per byte
              CMP   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :MODE0
              LDA   #SCB320                ; SCB for 320-mode
              LDY   #00                    ; Palette offset
              BRA   :S1
:MODE0        LDA   #SCB640                ; SCB for 640-mode
              LDY   #32                    ; Palette offset
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
              RTS


* Write character to SHR screen
* On entry: A - character to write
SHRPRCHAR     SEC
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
              JSR   SHRCHARADDR            ; Addr in VDUADDR
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
:S2           LDA   VDUADDR+0              ; Add 160 to VDUADDR
              CLC
              ADC   #160
              STA   VDUADDR+0
              LDA   VDUADDR+1
              ADC   #$00
              STA   VDUADDR+1
              INY                          ; Next row of font
              CPY   #$08                   ; Last row?
              BNE   :L1
              RTS


* Draw one pixel row of font in 320 mode
* 4 bytes per char, 4 bits per pixel
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
              STZ   :TEMP
              LDX   #$00                   ; Source bit index
:L1           ASL                          ; MS bit -> C
              PHP                          ; Preserve C
              ROL  :TEMP                   ; C -> LS bit
              PLP                          ; Recover C
              ROL  :TEMP                   ; C -> LS bit
              INX
              CPX  #$04
              BNE  :L1
              PHA
              LDA  :TEMP
 AND #%10101010
              STA  [VDUADDR]
              PLA
              STZ  :TEMP
              LDX  #$00
:L2           ASL                          ; MS bit -> C
              PHP                          ; Preserve C
              ROL  :TEMP                   ; C -> LS bit
              PLP                          ; Recover C
              ROL  :TEMP                   ; C -> LS bit
              INX
              CPX  #$04
              BNE  :L2
              LDA  :TEMP
              LDY  #$01
 AND #%10101010
              STA  [VDUADDR],Y
              PLY
              RTS
:TEMP         DB   $00


* Calculate character address in SHR screen memory
* This is the address of the first pixel row of the char
* Add $00A0 for each subsequent row
SHRCHARADDR   LDA   #$20                   ; MSB starts at $20
              LDY   VDUTEXTY
:L1           CPY   #$00
              BEQ   :S1
              CLC
              ADC   #05                    ; Each char row is $500
              DEY
              BRA   :L1
:S1           STA   VDUADDR+1              ; MSB of address
              LDA   VDUTEXTX
              ASL                          ; Mult x 2 (4 pixels/byte)
              LDY   VDUPIXELS              ; Pixels per byte
              CPY   #$02                   ; 2 pixels per byte in 320 mode
              BNE   :S2
              ASL                          ; Mult x 2 (2 pixels/byte)
:S2           STA   VDUADDR+0              ; LSB of address
              LDA   #$E1                   ; Bank $E1
              STA   VDUBANK
              RTS
* (VDUADDR)=>character address, X=preserved


* Forwards scroll one line
SHRSCR1LINE
              RTS


* Reverse scroll one line
SHRRSCR1LINE
              RTS


* Clear from current location to EOL
SHRCLREOL
              RTS


* VDU16 (CLG) clears the whole SHR screen right now
SHRCLEAR      PHP                          ; Disable interrupts
              SEI
              CLC                          ; 816 native mode
              XCE
              REP  #$10                    ; 16 bit index
              MX   %10                     ; Tell Merlin
              LDX  #$0000
              LDA  #$00
:L1           STAL $E12000,X               ; SHR screen @ E1:2000
              INX
              CPX  #$7D00
              BNE  :L1
              SEP  #$10                    ; Back to 8 bit index
              MX   %11                     ; Tell Merlin
              SEC                          ; Back to 6502 emu mode
              XCE
              PLP                          ; Normal service resumed
              RTS


