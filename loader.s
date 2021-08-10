* LOADER.S
* (c) Bobbi 2021 GPLv3
*
* Applecorn loader code

* Loads Acorn ROM file (16KB) from disk and writes it
* to aux memory starting at $08000. Copies Applecorn MOS
* to aux memory starting at AUXMOS1 and jumps to it.
* (Note that the MOS code will relocate itself to $D000.)
START       STZ   :BLOCKS
            LDX   #$00
:L1         LDA   HELLO,X          ; Signon message
            BEQ   :S1
            JSR   COUT1
            INX
            BRA   :L1
:S1         JSR   CROUT
            JSR   SETPRFX
            JSR   DISCONN

            STA   $C009            ; Alt ZP on
            STZ   $9F              ; WARMSTRT - set cold!
            STA   $C008            ; Alt ZP off

            LDA   #<ROMFILE
            STA   OPENPL+1
            LDA   #>ROMFILE
            STA   OPENPL+2
            JSR   OPENFILE         ; Open ROM file
            BCC   :S2
            LDX   #$00
:L2         LDA   CANTOPEN,X
            BEQ   :ER1
            JSR   COUT1
            INX
            BRA   :L2
            BRA   :S2
:ER1        JSR   CROUT
            JSR   BELL
            RTS

:S2         LDA   OPENPL+5         ; File reference number
            STA   READPL+1

:L3         LDA   #'.'+$80         ; Read file block by block
            JSR   COUT1
            JSR   RDFILE
            BCS   :S3              ; EOF (0 bytes left) or some error

            LDA   #<BLKBUF         ; Source start addr -> A1L,A1H
            STA   A1L
            LDA   #>BLKBUF
            STA   A1H

            LDA   #<BLKBUFEND      ; Source end addr -> A2L,A2H
            STA   A2L
            LDA   #>BLKBUFEND
            STA   A2H

            LDA   #<AUXADDR        ; Dest in aux -> A4L, A4H
            STA   A4L
            LDA   #>AUXADDR
            LDX   :BLOCKS
:L4         CPX   #$00
            BEQ   :S25
            INC
            INC
            DEX
            BRA   :L4
:S25        STA   A4H

            SEC                    ; Copy Main -> Aux
            JSR   AUXMOVE

            INC   :BLOCKS
            BRA   :L3

:S3         LDA   OPENPL+5         ; File reference number
            STA   CLSPL+1
            JSR   CLSFILE

            LDA   #<MOSSHIM        ; Start address of MOS shim
            STA   A1L
            LDA   #>MOSSHIM
            STA   A1H

            LDA   #<MOSSHIM+$1000  ; End address of MOS shim
            STA   A2L
            LDA   #>MOSSHIM+$1000
            STA   A2H

            LDA   #<AUXMOS1        ; To AUXMOS1 in aux memory
            STA   A4L
            LDA   #>AUXMOS1
            STA   A4H

            SEC                    ; Copy MOS from Main->Aux
            JSR   AUXMOVE

            LDA   #<RESET          ; Set reset vector->RESET
            STA   RSTV
            LDA   #>RESET
            STA   RSTV+1
            EOR   #$A5             ; Checksum
            STA   RSTV+2

            TSX                    ; Save SP at $0100
            STX   $0100
            >>>   XF2AUX,AUXMOS1

:BLOCKS     DB    0                ; Counter for blocks read



