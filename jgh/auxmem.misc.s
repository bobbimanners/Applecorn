* MISC.S
********
* Misc functions and API entry block
*

* OSBYTE $80 - ADVAL
************************************
* Read input device or buffer status

BYTE80      LDY   #$00       ; Prepare return=&00xx
            TXA              ; X<0  - info about buffers
            BMI   :ADVALBUF  ; X>=0 - read input devices
*
* TEST CODE
            CPX   #$7F
            BNE   :ADVALNONE
ADVALWAIT   JSR   KBDREAD
            BCC   ADVALWAIT
            TAX
            RTS
* TEST CODE
*
:ADVALNONE  LDX   #$00       ; Input, just return 0
            RTS
:ADVALBUF   INX
            BEQ   :ADVALKBD  ; Fake keyboard buffer
            INX
            BEQ   :ADVALOK   ; Serial input, return 0
            LDX   #$01       ; For outputs, return 1 char free
            RTS
:ADVALKBD   BIT   $C000      ; Test keyboard data/strobe
            BPL   :ADVALOK   ; No Strobe, return 0
            INX              ; Strobe, return 1
:ADVALOK    RTS


******************
* Helper functions
******************

* Beep
BEEP        PHA
            PHX
            LDX   #$80
:L1         LDA   $C030
            JSR   DELAY
            INX
            BNE   :L1
            PLX
            PLA
            RTS

* Delay approx 1/100 sec
DELAY       PHX
            PHY
            LDX   #$00
:L1         INX                              ; 2
            LDY   #$00                       ; 2
:L2         INY                              ; 2
            CPY   #$00                       ; 2
            BNE   :L2                        ; 3 (taken)
            CPX   #$02                       ; 2
            BNE   :L1                        ; 3 (taken)
            PLY
            PLX
            RTS

* Print string pointed to by X,Y to the screen
OUTSTR      TXA

* Print string pointed to by A,Y to the screen
PRSTR       STA   OSTEXT+0                  ;  String in A,Y
            STY   OSTEXT+1
:L1         LDA   (OSTEXT)                  ; Ptr to string in ZP3
            BEQ   :S1
            JSR   OSASCI
            INC   OSTEXT
            BNE   :L1
            INC   OSTEXT+1
            BRA   :L1
:S1         RTS

* Print XY in hex
OUT2HEX     TYA
            JSR   OUTHEX
            TAX                             ; Continue into OUTHEX

* Print hex byte in A
OUTHEX      PHA
            LSR
            LSR
            LSR
            LSR
            AND   #$0F
            JSR   PRNIB
            PLA
            AND   #$0F                       ; Continue into PRNIB
;           JSR   PRNIB
;           RTS

* Print hex nibble in A
PRNIB       CMP   #$0A
            BCC   :S1
            CLC                              ; >= $0A
            ADC   #'A'-$0A
            JSR   OSWRCH
            RTS
:S1         ADC   #'0'                       ; < $0A
            JMP   OSWRCH


**********************************************************
* Interrupt Handlers, MOS redirection vectors etc.
**********************************************************

* IRQ/BRK handler
IRQBRKHDLR
            PHA
;            >>>   WRTMAIN
;            STA   $45                        ; A->$45 for ProDOS IRQ handlers
;            >>>   WRTAUX
; Mustn't enable IRQs within the IRQ handler
; Do this manually, as we have complete control at this point
            STA   $C004       ; Write to main memory
            STA   $45         ; Store A in $45 for ProDOS IRQ handlers
            STA   $C005       ; Write to aux memory
;
            TXA
            PHA
            CLD
            TSX
            LDA   $103,X                     ; Get PSW from stack
            AND   #$10
            BEQ   :IRQ                       ; IRQ
            SEC
            LDA   $0104,X
            SBC   #$01
            STA   FAULT
            LDA   $0105,X
            SBC   #$00
            STA   FAULT+1
            PLA
            TAX
            PLA
            CLI
            JMP   (BRKV)                     ; Pass on to BRK handler

:IRQ        >>>   XF2MAIN,A2IRQ              ; Bounce to Apple IRQ handler
IRQBRKRET
            PLA                              ; TODO: Pass on to IRQ1V
            TAX
            PLA
NULLRTI     RTI

PRERR       LDY   #$01
PRERRLP     LDA   (FAULT),Y
            BEQ   PRERR1
            JSR   OSWRCH
            INY
            BNE   PRERRLP
NULLRTS
PRERR1      RTS

MOSBRKHDLR  LDA   #<MSGBRK
            LDY   #>MSGBRK
            JSR   PRSTR
            JSR   PRERR
            JSR   OSNEWL
            JSR   OSNEWL
STOP        JMP   STOP                       ; Cannot return from a BRK

MSGBRK      DB    $0D
            ASC   "ERROR: "
            DB    $00

RDROM       LDA   #<OSRDRMM
            LDY   #>OSRDRMM
            JMP   PRSTR
OSRDRMM     ASC   'OSRDDRM.'
            DB    $00

EVENT       LDA   #<OSEVENM
            LDY   #>OSEVENM
            JMP   PRSTR
OSEVENM     ASC   'OSEVEN.'
            DB    $00

GSINTGO     LDA   #<OSINITM
            LDY   #>OSINITM
            JMP   PRSTR
OSINITM     ASC   'GSINITM.'
            DB    $00

GSRDGO      LDA   #<OSREADM
            LDY   #>OSREADM
            JMP   PRSTR
OSREADM     ASC   'GSREAD.'
            DB    $00


* Default page 2 contents
DEFVEC      DW    NULLRTS                    ; $200 USERV
            DW    MOSBRKHDLR                 ; $202 BRKV
            DW    NULLRTI                    ; $204 IRQ1V
            DW    NULLRTI                    ; $206 IRQ2V
            DW    CLIHND                     ; $208 CLIV
            DW    BYTEHND                    ; $20A BYTEV
            DW    WORDHND                    ; $20C WORDV
            DW    WRCHHND                    ; $20E WRCHV
            DW    RDCHHND                    ; $210 RDCHV
            DW    FILEHND                    ; $212 FILEV
            DW    ARGSHND                    ; $214 ARGSV
            DW    BGETHND                    ; $216 BGETV
            DW    BPUTHND                    ; $218 BPUTV
            DW    GBPBHND                    ; $21A GBPBV
            DW    FINDHND                    ; $21C FINDV
            DW    FSCHND                     ; $21E FSCV
ENDVEC

*
* Acorn MOS entry points at the top of RAM
* Copied from loaded code to high memory
*

MOSVEC                                       ; Base of API entries here in loaded code
MOSAPI      EQU   $FFB6                      ; Real base of API entries in real memory
            ORG   MOSAPI

* OPTIONAL ENTRIES
* ----------------
*OSSERV      JMP   NULLRTS          ; FF95 OSSERV
*OSCOLD      JMP   NULLRTS          ; FF98 OSCOLD
*OSPRSTR     JMP   OUTSTR           ; FF9B PRSTRG
*OSFF9E      JMP   NULLRTS          ; FF9E
*OSSCANHEX   JMP   RDHEX            ; FFA1 SCANHX
*OSFFA4      JMP   NULLRTS          ; FFA4
*OSFFA7      JMP   NULLRTS          ; FFA7
*PRHEX       JMP   OUTHEX           ; FFAA PRHEX
*PR2HEX      JMP   OUT2HEX          ; FFAD PR2HEX
*OSFFB0      JMP   NULLRTS          ; FFB0
*OSWRRM      JMP   NULLRTS          ; FFB3 OSWRRM

* COMPULSARY ENTRIES
* ------------------
VECSIZE     DB    ENDVEC-DEFVEC              ; FFB6 VECSIZE Size of vectors
VECBASE     DW    DEFVEC                     ; FFB7 VECBASE Base of default vectors
OSRDRM      JMP   RDROM                      ; FFB9 OSRDRM  Read byte from paged ROM
OSCHROUT    JMP   OUTCHAR                    ; FFBC CHROUT  Send char to VDU driver
OSEVEN      JMP   EVENT                      ; FFBF OSEVEN  Signal an event
GSINIT      JMP   GSINTGO                    ; FFC2 GSINIT  Init string reading
GSREAD      JMP   GSRDGO                     ; FFC5 GSREAD  Parse general string
NVWRCH      JMP   WRCHHND                    ; FFC8 NVWRCH  Nonvectored WRCH
NVRDCH      JMP   RDCHHND                    ; FFCB NVRDCH  Nonvectored RDCH
OSFIND      JMP   (FINDV)                    ; FFCE OSFIND
OSGBPB      JMP   (GBPBV)                    ; FFD1 OSGBPB
OSBPUT      JMP   (BPUTV)                    ; FFD4 OSBPUT
OSBGET      JMP   (BGETV)                    ; FFD7 OSBGET
OSARGS      JMP   (ARGSV)                    ; FFDA OSARGS
OSFILE      JMP   (FILEV)                    ; FFDD OSFILE
OSRDCH      JMP   (RDCHV)                    ; FFE0 OSRDCH
OSASCI      CMP   #$0D                       ; FFE3 OSASCI
            BNE   OSWRCH
OSNEWL      LDA   #$0A                       ; FFE7 OSNEWL
            JSR   OSWRCH
OSWRCR      LDA   #$0D                       ; FFEC OSWRCR
OSWRCH      JMP   (WRCHV)                    ; FFEE OSWRCH
OSWORD      JMP   (WORDV)                    ; FFF1 OSWORD
OSBYTE      JMP   (BYTEV)                    ; FFF4 OSBYTE
OSCLI       JMP   (CLIV)                     ; FFF7 OSCLI
NMIVEC      DW    NULLRTI                    ; FFFA NMIVEC
RSTVEC      DW    STOP                       ; FFFC RSTVEC
IRQVEC

* Assembler doesn't like running up to $FFFF, so we bodge a bit
MOSEND
            ORG   MOSEND-MOSAPI+MOSVEC
            DW    IRQBRKHDLR                 ; FFFE IRQVEC
MOSVEND

* Buffer for one 512 byte disk block in aux mem
AUXBLK      DS    $200

