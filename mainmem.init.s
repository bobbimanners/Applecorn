* MAINMEM.INIT.S
* (c) Bobbi 2021 GPLv3
*
* Initialization, interrupt handling and reset handling code
* that resides in main memory.

* Trampoline in main memory used by aux memory IRQ handler
* to invoke Apple II / ProDOS IRQs in main memory
A2IRQ       >>>   IENTMAIN          ; IENTMAIN does not do CLI
            JSR   A2IRQ2
            >>>   XF2AUX,IRQBRKRET
A2IRQ2      PHP                     ; Fake things to look like IRQ
            JMP   (A2IRQV)          ; Call Apple II ProDOS ISR

* BRK handler in main memory. Used on Apple IIgs only.
GSBRK       >>>   XF2AUX,GSBRKAUX

* Set prefix if not already set
SETPRFX     LDA   #GPFXCMD
            STA   :OPC7             ; Initialize cmd byte to $C7
:L1         JSR   MLI
:OPC7       DB    $00
            DW    GSPFXPL
            LDX   DRVBUF1           ; was $0300
            BNE   RTSINST
            LDA   $BF30
            STA   ONLNPL+1          ; Device number
            JSR   MLI
            DB    ONLNCMD
            DW    ONLNPL
            LDA   DRVBUF2           ; was $0301
            AND   #$0F
            TAX
            INX
            STX   DRVBUF1           ; was $0300
            LDA   #'/'
            STA   DRVBUF2           ; was $0301
            DEC   :OPC7
            BNE   :L1
RTSINST     RTS

* Disconnect /RAM ramdrive to avoid aux corruption
* Stolen from Beagle Bros Extra K
DISCONN     LDA   $BF98
            AND   #$30
            CMP   #$30
            BNE   :S1
            LDA   $BF26
            CMP   $BF10
            BNE   :S2
            LDA   $BF27
            CMP   $BF11
            BEQ   :S1
:S2         LDY   $BF31
:L1         LDA   $BF32,Y
            AND   #$F3
            CMP   #$B3
            BEQ   :S3
            DEY
            BPL   :L1
            BMI   :S1
:S3         LDA   $BF32,Y
            STA   DRVBUF2+1         ; was $0302
:L2         LDA   $BF33,Y
            STA   $BF32,Y
            BEQ   :S4
            INY
            BNE   :L2
:S4         LDA   $BF26
            STA   DRVBUF1           ; was $0300
            LDA   $BF27
            STA   DRVBUF2           ; was $0301
            LDA   $BF10
            STA   $BF26
            LDA   $BF11
            STA   $BF27
            DEC   $BF31
:S1         RTS

* Reset handler - invoked on Ctrl-Reset
* XFER to AUXMOS ($C000) in aux, AuxZP on, LC on
RESET       TSX
            STX   $0100
            LDA   $C058             ; AN0 off
            LDA   $C05A             ; AN1 off
            LDA   $C05D             ; AN2 on
            LDA   $C05F             ; AN3 on
            LDA   #$20              ; Turn off PAGE2 shadow on ROM3 GS
            TSB   $C035
            >>>   XF2AUX,AUXMOS
            RTS

















































