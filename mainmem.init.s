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



