* MAINMEM.INIT.S
* (c) Bobbi 2021 GPLv3
*
* Initialization, interrupt handling and reset handling code
* that resides in main memory.

* 14-Nov-2021 If started from CSD, gets prefix to CMDBUF.


* Trampoline in main memory used by aux memory IRQ handler
* to invoke Apple II / ProDOS IRQs in main memory
A2IRQ        >>>   IENTMAIN          ; IENTMAIN does not do CLI
             JSR   A2IRQ2
             >>>   XF2AUX,IRQBRKRET
A2IRQ2       PHP                     ; Fake things to look like IRQ
             JMP   (A2IRQV)          ; Call Apple II ProDOS ISR

* BRK handler in main memory. Used on Apple IIgs only.
GSBRK        >>>   XF2AUX,GSBRKAUX

** Set prefix if not already set
*SETPRFX      LDA   #GPFXCMD
*             STA   :OPC7             ; Initialize cmd byte to $C7
*:L1          JSR   MLI
*:OPC7        DB    $00
*             DW    GSPFXPL
*             LDX   DRVBUF1           ; was $0300
*             BNE   RTSINST
*             LDA   DEVNUM
*             STA   ONLNPL+1          ; Device number
*             JSR   MLI
*             DB    ONLNCMD
*             DW    ONLNPL
*             LDA   DRVBUF2           ; was $0301
*             AND   #$0F
*             TAX
*             INX
*             STX   DRVBUF1           ; was $0300
*             LDA   #'/'
*             STA   DRVBUF2           ; was $0301
*             DEC   :OPC7
*             BNE   :L1
*RTSINST      LDA   CMDPATH
*             BEQ   :GETPFX           ; CMDPATH empty
*             LDA   CMDPATH+1
*             CMP   #'/'
*             BEQ   :GETPFXDONE       ; CMDPATH already absolute path
*:GETPFX      JSR   MLI
*             DB    $C7               ; Get Prefix
*             DW    :GETADDR
*:GETPFXDONE  RTS
*:GETADDR     HEX   01                ; One parameter
*             DW    CMDPATH           ; Get prefix to CMDPATH
*
*
** Disconnect /RAM ramdrive to avoid aux corruption
** Stolen from Beagle Bros Extra K
*DISCONN      LDA   MACHID
*             AND   #$30
*             CMP   #$30
*             BNE   :S1
*             LDA   DEVADR32
*             CMP   DEVADR01
*             BNE   :S2
*             LDA   DEVADR32+1
*             CMP   DEVADR01+1
*             BEQ   :S1
*:S2          LDY   DEVCNT
*:L1          LDA   DEVLST,Y
*             AND   #$F3
*             CMP   #$B3
*             BEQ   :S3
*             DEY
*             BPL   :L1
*             BMI   :S1
*:S3          LDA   DEVLST,Y
*             STA   DRVBUF2+1         ; was $0302
*:L2          LDA   DEVLST+1,Y
*             STA   DEVLST,Y
*             BEQ   :S4
*             INY
*             BNE   :L2
*:S4          LDA   DEVADR32
*             STA   DRVBUF1           ; was $0300
*             LDA   DEVADR32+1
*             STA   DRVBUF2           ; was $0301
*             LDA   DEVADR01
*             STA   DEVADR32
*             LDA   DEVADR01+1
*             STA   DEVADR32+1
*             DEC   DEVCNT
*:S1          RTS
*
* Reset handler - invoked on Ctrl-Reset
* XFER to AUXMOS ($D000) in aux, AuxZP on, LC on
RESET        TSX
             STX   $0100
             LDA   AN0OFF            ; AN0 off
             LDA   AN1OFF            ; AN1 off
             LDA   AN2ON             ; AN2 on
             LDA   AN3ON             ; AN3 on
             >>>   XF2AUX,AUXMOS
             RTS



