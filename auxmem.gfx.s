* AUXMEM.GFX.S
* (c) Bobbi 2021 GPLv3
*
* Graphics operations

* Convert high-resolution screen coordinates
* from 1280x1024 to 280x192
CVTCOORD
* X-coordinate in VDUQ+5,+6   1280/4*7/8=280
            LDA   VDUQ+5         ; X-coord -> ZP1 and ZP2
            STA   ZP1+0
            STA   ZP2+0
            LDA   VDUQ+6
            STA   ZP1+1
            STA   ZP2+1
            CLC                  ; ZP1 divide by 2 (0-639 now)
            ROR   ZP1+1
            ROR   ZP1+0
            CLC                  ; ZP1 divide by 2 (0-319 now)
            ROR   ZP1+1
            ROR   ZP1+0
            CLC                  ; ZP1+ZP2->ZP2
            LDA   ZP1+0
            ADC   ZP2+0
            STA   ZP2+0
            LDA   ZP1+1
            ADC   ZP2+1
            STA   ZP2+1
            CLC                  ; ZP1+ZP2->ZP2
            LDA   ZP1+0
            ADC   ZP2+0
            STA   ZP2+0
            LDA   ZP1+1
            ADC   ZP2+1
            STA   ZP2+1
            CLC                  ; ZP1+ZP2->ZP2
            LDA   ZP1+0
            ADC   ZP2+0
            STA   ZP2+0
            LDA   ZP1+1
            ADC   ZP2+1
            STA   ZP2+1
            CLC                  ; ZP2 divide by 2
            ROR   ZP2+1
            ROR   ZP2+0
            CLC                  ; ZP2 divide by 2
            ROR   ZP2+1
            ROR   ZP2+0
            CLC                  ; ZP2 divide by 2
            ROR   ZP2+1
            ROR   ZP2+0
            LDA   ZP2+0
            STA   VDUQ+5
            LDA   ZP2+1
            STA   VDUQ+6

* Y-coordinate in VDUQ+7,+8   1024/4*3/4=192
            LDA   VDUQ+7         ; Y-coord -> ZP1
            STA   ZP1+0
            LDA   VDUQ+8
            STA   ZP1+1
            CLC                  ; ZP1 divide by 2 (0-512 now)
            ROR   ZP1+1
            ROR   ZP1+0
            CLC                  ; ZP1 divide by 2 (0-256 now)
            ROR   ZP1+1
            ROR   ZP1+0
            LDA   ZP1+0          ; Copy ZP1->ZP2
            STA   ZP2+0
            LDA   ZP1+1
            STA   ZP2+1
            CLC                  ; ZP1+ZP2->ZP2
            LDA   ZP1+0
            ADC   ZP2+0
            STA   ZP2+0
            LDA   ZP1+1
            ADC   ZP2+1
            STA   ZP2+1
            CLC                  ; ZP1+ZP2->ZP2
            LDA   ZP1+0
            ADC   ZP2+0
            STA   ZP2+0
            LDA   ZP1+1
            ADC   ZP2+1
            STA   ZP2+1
            CLC                  ; ZP2 divide by 2
            ROR   ZP2+1
            ROR   ZP2+0
            CLC                  ; ZP2 divide by 2
            ROR   ZP2+1
            ROR   ZP2+0
            LDA   ZP2+0
            STA   VDUQ+7
            LDA   ZP2+1
            STA   VDUQ+8

            RTS

* Add coordinates to XPIXEL, YPIXEL
RELCOORD    CLC
            LDA   XPIXEL+0
            ADC   VDUQ+5
            STA   VDUQ+5
            LDA   XPIXEL+1
            ADC   VDUQ+6
            STA   VDUQ+6
            CLC
            LDA   YPIXEL
            ADC   VDUQ+7
            STA   VDUQ+7
            RTS

