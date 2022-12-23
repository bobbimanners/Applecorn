* AUXMEM.SHR.S
* (c) Bobbi 2022 GPLv3
*
* Routines for drawing bitmapped text and graphics in SHR mode
* on Apple IIGS (640x200 4 colour, or 320x200 16 colour.)
*

SCB320        EQU   $00                    ; SCB for 320 mode
SCB640        EQU   $80                    ; SCB for 640 mode

* Enable SHR mode
SHRVDU22      JSR   VDU12                  ; Clear text and HGR screen
              LDA   #$80                   ; Most significant bit
              TSB   NEWVIDEO               ; Enable SHR mode
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
SHRCLEAR
              RTS


