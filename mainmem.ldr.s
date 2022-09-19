* MAINMEM.LDR.S
* (c) Bobbi 2021 GPLv3
*
* Applecorn loader code.  Runs in main memory.
* 01-Oct-2021 Copies MOS code to whole $D000-$FFFF.
* 13-Nov-2021 LOADCODE uses absolute path to Applecorn directory.


* Loads Acorn ROM file (16KB) from disk and writes it
* to aux memory starting at $08000. Copies Applecorn MOS
* to aux memory starting at AUXMOS1 and jumps to it.
* (Note that the MOS code will copy itself to $D000.)

START       JSR   CROUT
            JSR   SETPRFX
            JSR   DISCONN

            LDA   #$20             ; PAGE2 shadow on ROM3 GS
            TRB   $C035

            JSR   ROMMENU
*            LDA   #>AUXADDR        ; Address in aux
*            LDX   #<AUXADDR
*            SEC                    ; Load into aux
*            JSR   LOADCODE         ; Load lang ROM

            LDA   #<:FDFILE
            STA   OPENPL+1
            LDA   #>:FDFILE
            STA   OPENPL+2
            LDA   #>FDRAWADDR      ; Address in main
            LDX   #<FDRAWADDR
            CLC                    ; Load into main
            JSR   LOADCODE

            LDA   #<:FNTFILE
            STA   OPENPL+1
            LDA   #>:FNTFILE
            STA   OPENPL+2
            LDA   #>FONTADDR       ; Address in main
            LDX   #<FONTADDR
            CLC                    ; Load into main
            JSR   LOADCODE

            LDA   #<MOSSHIM        ; Start address of MOS shim
            STA   A1L
            LDA   #>MOSSHIM
            STA   A1H

            LDA   #<MOSSHIM+$3000  ; End address of MOS shim
            STA   A2L
            LDA   #>MOSSHIM+$3000
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

            LDA   #<GSBRK          ; Set BRK vector in main mem
            STA   $3F0
            LDA   #>GSBRK
            STA   $3F0+1

            JSR   GFXINIT          ; Initialize FDraw graphics

            TSX                    ; Save SP at $0100 in aux
            STA   $C009            ; Write to AltZP
            STX   $0100
            STA   $C008            ; Write to main ZP
            >>>   XF2AUX,AUXMOS1

:FDFILE     STR   "FDRAW.FAST"     ; Filename for FDraw lib
:FNTFILE    STR   "FONT.DAT"       ; Filename for bitmap font

* Load image from file into memory
* On entry: OPENPL set up to point to leafname of file to load
*           Loads file from directory applecorn started from
*           Uses BLKBUF at loading buffer
*           Load address in A,X
*           Carry set->load to aux, carry clear->load to main
LOADCODE    PHP                    ; Save carry flag
            STA   :ADDRH           ; MSB of load address
            STX   :ADDRL           ; LSB of load address
            STZ   :BLOCKS

            LDX   #0
:LP1        LDA   CMDPATH+1,X      ; Copy Applecorn path to MOSFILE
            STA   MOSFILE2+1,X
            INX
            CPX   CMDPATH
            BCC   :LP1
:LP2        DEX
            LDA   MOSFILE2+1,X
            CMP   #'/'
            BNE   :LP2
            LDA   OPENPL+1
            STA   A1L
            LDA   OPENPL+2
            STA   A1H
            LDY   #1
            LDA   (A1L),Y
            CMP   #'/'
            BEQ   :L4              ; Already absolute path
:LP3        LDA   (A1L),Y
            STA   MOSFILE2+2,X
            INX
            INY
            TYA
            CMP   (A1L)
            BCC   :LP3
            BEQ   :LP3
            INX
            STX   MOSFILE2+0
            LDA   #<MOSFILE2       ; Point to absolute path
            STA   OPENPL+1
            LDA   #>MOSFILE2
            STA   OPENPL+2

:L4         JSR   OPENFILE         ; Open ROM file
            BCC   :S1
            PLP
            BCC   :L1A             ; Load to main, report error
            RTS                    ; Load to aux, return CS=Failed
:L1A        LDX   #$00
:L1B        LDA   :CANTOPEN,X      ; Part one of error msg
            BEQ   :S0
            JSR   COUT1
            INX
            BRA   :L1B
:S0         LDA   OPENPL+1         ; Print filename
            STA   A1L
            LDA   OPENPL+2
            STA   A1H
            LDY   #$00
            LDA   (A1L),Y
            STA   :LEN
:L1C        CPY   :LEN
            BEQ   :ERR1
            INY
            LDA   (A1L),Y
            JSR   COUT1
            BRA   :L1C
:ERR1       JSR   CROUT
            JSR   BELL
:SPIN       BRA   :SPIN
:S1         LDA   OPENPL+5         ; File reference number
            STA   READPL+1
:L2         PLP
            PHP
            BCS   :L2A             ; Loading to aux, skip dots
            LDA   #'.'+$80         ; Print progress dots
            JSR   COUT1
:L2A        JSR   RDFILE           ; Read file block by block
            BCS   :CLOSE           ; EOF (0 bytes left) or some error
            LDA   #<BLKBUF         ; Source start addr -> A1L,A1H
            STA   A1L
            LDA   #>BLKBUF
            STA   A1H
            LDA   #<BLKBUFEND      ; Source end addr -> A2L,A2H
            STA   A2L
            LDA   #>BLKBUFEND
            STA   A2H
            LDA   :ADDRL           ; Dest in aux -> A4L, A4H
            STA   A4L
            LDA   :ADDRH
            LDX   :BLOCKS
:L3         CPX   #$00
            BEQ   :S2
            INC
            INC
            DEX
            BRA   :L3
:S2         STA   A4H
            PLP                    ; Recover carry flag
            PHP
            BCS   :TOAUX
            JSR   MEMCPY           ; Destination in main mem
            BRA   :S3
:TOAUX      JSR   AUXMOVE          ; Carry already set (so to aux)
:S3         INC   :BLOCKS
            BRA   :L2
:CLOSE      LDA   OPENPL+5         ; File reference number
            STA   CLSPL+1
            JSR   CLSFILE
            JSR   CROUT
            PLP
            CLC                    ; CC=Ok
            RTS
:ADDRL      DB    $00              ; Destination address (LSB)
:ADDRH      DB    $00              ; Destination address (MSB)
:BLOCKS     DB    $00              ; Counter for blocks read
:LEN        DB    $00              ; Length of filename
:CANTOPEN   ASC   "Unable to open "
            DB    $00





















