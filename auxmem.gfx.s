* AUXMEM.GFX.S
* (c) Bobbi 2021 GPLv3
*
* Graphics operations

* Convert high-resolution screen coordinates
* from 1280x1024 to 280x192
CVTCOORD
* X-coordinate in VDUQ+5,+6   1280*7/32=280
            LDA   VDUQ+6        ; MSB of X-coord
            CMP   #$05          ; $500 is 1280
            BCS   :BIGX         ; Value >=1280
            STA   ZP1+1         ; X-coord -> ZP1 and ZP2
            STA   ZP2+1
            LDA   VDUQ+5
            STA   ZP1+0
            ASL   A             ; ZP2 *= 8
            ROL   ZP2+1
            ASL   A
            ROL   ZP2+1
            ASL   A
            ROL   ZP2+1
            SEC                 ; ZP2-ZP1->ZP2
            SBC   ZP1+0
            STA   ZP2+0
            LDA   ZP2+1
            SBC   ZP1+1
            LSR   A             ; ZP2 /= 32
            ROR   ZP2+0
            LSR   A
            ROR   ZP2+0
            LSR   A
            ROR   ZP2+0
            LSR   A
            ROR   ZP2+0
            LSR   A
            ROR   ZP2+0
            STA   VDUQ+6        ; ZP2 -> X-coord
            LDA   ZP2+0
            STA   VDUQ+5

* Y-coordinate in VDUQ+7,+8   1024*3/16=192
:YCOORD     LDA   VDUQ+8        ; MSB of Y-coord
            AND   #$FC
            BNE   :BIGY         ; Y>1023
            LDA   VDUQ+8        ; Y-coord -> ZP1
            STA   ZP1+1
            STA   ZP2+1
            LDA   VDUQ+7
            STA   ZP1+0
            ASL   A             ; ZP2 *= 2
            ROL   ZP2+1
            CLC                 ; ZP2+ZP1->ZP2
            ADC   ZP1+0
            STA   ZP2+0
            LDA   ZP2+1
            ADC   ZP1+1
            LSR   A             ; ZP2 /= 16
            ROR   ZP2+0
            LSR   A
            ROR   ZP2+0
            LSR   A
            ROR   ZP2+0
            LSR   A
            ROR   ZP2+0
            STZ   VDUQ+8        ; MSB always zero
            SEC
            LDA   #191          ; 191 - ZP2 -> Y-coord
            SBC   ZP2+0
            STA   VDUQ+7
            RTS
:BIGY       STZ   VDUQ+7        ; Y too large, row zero
            STZ   VDUQ+8
            RTS
:BIGX       LDA   #$17          ; X too large, use 279
            STA   VDUQ+5
            LDA   #$01
            STA   VDUQ+6
            BRA   :YCOORD

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

