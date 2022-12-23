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
              DB    $80, $08               ; YELLOW
              DB    $00, $00               ; BLACK
              DB    $00, $08               ; RED
              DB    $80, $00               ; GREEN
              DB    $80, $08               ; YELLOW
              DB    $08, $00               ; BLUE
              DB    $08, $08               ; MAGENTA
              DB    $88, $00               ; CYAN
              DB    $80, $08               ; YELLOW
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
              LDA   #$E1                   ; SHR memory bank
              STA   VDUBANK
              LDA   VDUPIXELS              ; Pixels per byte
              CMP   #$02                   ; 2 is 320-mode (MODE 1)
              BNE   :MODE0
              LDA   SCB320                 ; SCB for 320-mode
              LDY   #00                    ; Palette offset
              BRA   :S1
:MODE0        LDA   SCB640                 ; SCB for 640-mode
              LDY   #32                    ; Palette offset
:S1           LDX   #$00
:L1           STAL  $E19D00,X              ; SCBs begin at $9D00 in $E1
              INX
              CPX   #200                   ; 200 lines so 200 SCBs
              BNE   :L1
              LDX   #$00
:L2           LDA   PALETTE320,Y           ; Offset n Y computed above
              STAL  $E119E00,X             ; Palettes begin at $9E00 in $E1
              INX
              INY
              CPX   #16                    ; 16 colours in palette
              BNE   :L2
              RTS


* Write character to SHR screen
SHRPRCHAR
              RTS


* Calculate character address in SHR screen memory
SHRCHARADDR
              RTS


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
SHRCLEAR      CLC                          ; 816 native mode
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
              RTS


