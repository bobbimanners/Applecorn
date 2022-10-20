* AUXMEM.AUDIO.S
* (c) Bobbi 2022 GPLv3
*
* Applecorn audio code
*

* OSWORD &07 - Make a sound
* On entry: (OSCTRL),Y points to eight byte parameter block (2 bytes each for
*           channel, amplitude, pitch, duration)
WORD07      INY
            LDA   (OSCTRL),Y                 ; Get channel system bits
            DEY
            CMP   #$20                       ; Sound system is %000xxxxx:xxxxxxxx
            BCS   :RTS                       ; *TO DO* Should pass to service call
            LDA   (OSCTRL),Y                 ; Get channel number/flush byte
            ORA   #$04                       ; Convert to buffer number 4-7
            AND   #$0F                       ; Mask off flush nybble
            PHA                              ; Stash
            LDA   (OSCTRL),Y                 ; Get channel number/flush byte
            AND   #$F0                       ; Mask off channel number nybble
            BEQ   :WAITLOOP                  ; If no flush, skip
            PLX                              ; Buffer num -> X
            PHX
            PHY
            BIT   :RTS                       ; Set V, means flush buffer
            JSR   CNPHND                     ; Go flush buffer
            PLY
:WAITLOOP   LDA   $C000                      ; See if key pressed
            BPL   :NOKEY
            EOR   #$80
            JSR   KBDCHKESC                  ; Was Escape pressed?
            BIT   ESCFLAG
*                                            ; *TO DO* Replace above with JSR ESCPOLL
            BMI   :ESCAPE                    ; If so, bail!
:NOKEY      PLX                              ; Buffer num -> X
            PHX
            CLV                              ; Ask to count buffer
            SEC                              ; Ask for space remaining
            JSR   CNPHND                     ; Go count it
            CPX   #3                         ; Less than 4 bytes remaining?
            BMI   :WAITLOOP
            PLX                              ; Buffer num -> X
            INY                              ; Point to channel num MSB
            LDA   (OSCTRL),Y
            JSR   INSHND                     ; Insert into queue X
            INY                              ; Point to amplitude LSB
            LDA   (OSCTRL),Y
            JSR   INSHND                     ; Insert into queue X
            INY                              ; Point to amplitude MSB
            INY                              ; Point to pitch LSB
            LDA   (OSCTRL),Y
            JSR   INSHND                     ; Insert into queue X
            INY                              ; Point to pitch MSB
            INY                              ; Point to duration LSB
            LDA   (OSCTRL),Y
            JSR   INSHND                     ; Insert into queue X
:RTS        RTS
:ESCAPE     PLX                              ; Fix up stack
            STA   $C010                      ; Ack keypress
            RTS


* OSWORD &08 - Envelope
* On entry: (OSCTRL),Y points to 14 byte parameter block
* Supports 4 envelopes for now, could be extended for more
WORD08      LDA   (OSCTRL),Y                 ; Get envelope number
            DEC   A                          ; Make it zero-based
            CMP   #$03                       ; Check in range
            BPL   :RTS                       ; Ignore if out of range
            TAX
            LDA   #$00
:L0         CPX   #$00                       ; Calculate EnvNum * 13
            BEQ   :S1                        ; Faster to do n*12+n to get n*13
            CLC
            ADC   #13
            DEX
            BRA   :L0
:S1         TAX                              ; Dest offset in X
            INY                              ; Skip over env number parm
:L1         LDA   (OSCTRL),Y                 ; Copy CB to mainmem
            >>>   WRTMAIN
            STA   ENVBUF0,X
            >>>   WRTAUX
            INY
            INX
            CPY   #14
            BNE   :L1
:RTS        RTS


* Insert value into buffer (INSV)
* On entry: A is value, X is buffer number.
* On exit: A, X, Y preserved. C clear on success.
* Stub that calls into main memory
INSHND      PHA                              ; Preserve all regs
            PHX
            PHY
            PHX                              ; X->Y for transfer
            PLY
            >>>   XF2MAIN,MAININS
INSHNDRET   >>>   ENTAUX
            PHA                              ; A->Flags after transfer
            PLP
            PLY                              ; Recover all regs
            PLX
            PLA
            RTS


* Count space in buffer or purge buffer (CNPV)
* On entry: X is buffer number. V set means purge, V clear means count.
*           C set means space left, C clear means entries used
* On exit: For purge, X & Y are preserved.
*          For count, value in X (Y=0).
*          A undef.  V,C flags preserved.
* Stub that calls into main memory
CNPHND      PHP
            PHX
            PHY
            PHP                              ; Flags->A for transfer
            PLA
            PHX                              ; X->Y for transfer
            PLY
            >>>   XF2MAIN,MAINCNP
CNPHNDRET1  >>>   ENTAUX                     ; Return after count
            PHY                              ; Y->X after transfer
            PLX
            PLY                              ; Discard stacked Y
            PLY                              ; Discard stacked X
            LDY   #$00                       ; Y=0 for count
            PLP
            RTS
CNPHNDRET2  >>>   ENTAUX                     ; Return after purge
            PLY                              ; Recover X,Y and flags
            PLX
            PLP
            RTS

