**********************************************************
* Interrupt Handlers, MOS redirection vectors etc.
**********************************************************

* IRQ/BRK handler
IRQBRKHDLR
            PHA
            >>>   WRTMAIN
            STA   $45            ; A->$45 for ProDOS IRQ handlers
            >>>   WRTAUX
            TXA
            PHA
            CLD
            TSX
            LDA   $103,X         ; Get PSW from stack
            AND   #$10
            BEQ   :IRQ           ; IRQ
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
            JMP   (BRKV)         ; Pass on to BRK handler

:IRQ        >>>   XF2MAIN,A2IRQ
IRQBRKRET
            PLA                  ; TODO: Pass on to IRQ1V
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
STOP        JMP   STOP           ; Cannot return from a BRK

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
DEFVEC      DW    NULLRTS        ; $200 USERV
            DW    MOSBRKHDLR     ; $202 BRKV
            DW    NULLRTI        ; $204 IRQ1V
            DW    NULLRTI        ; $206 IRQ2V
            DW    CLIHND         ; $208 CLIV
            DW    BYTEHND        ; $20A BYTEV
            DW    WORDHND        ; $20C WORDV
            DW    WRCHHND        ; $20E WRCHV
            DW    RDCHHND        ; $210 RDCHV
            DW    FILEHND        ; $212 FILEV
            DW    ARGSHND        ; $214 ARGSV
            DW    BGETHND        ; $216 BGETV
            DW    BPUTHND        ; $218 BPUTV
            DW    GBPBHND        ; $21A GBPBV
            DW    FINDHND        ; $21C FINDV
            DW    NULLRTS        ; $21E FSCV
ENDVEC

*
* Acorn MOS entry points at the top of RAM
* Copied from loaded code to high memory
*

MOSVEC                           ; Base of API entries here in loaded code
MOSAPI      EQU   $FFB6          ; Real base of API entries in real memory
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

* COMPULSORY ENTRIES
* ------------------
VECSIZE     DB    ENDVEC-DEFVEC  ; FFB6 VECSIZE Size of vectors
VECBASE     DW    DEFVEC         ; FFB7 VECBASE Base of default vectors
OSRDRM      JMP   RDROM          ; FFB9 OSRDRM  Read byte from paged ROM
OSCHROUT    JMP   OUTCHAR        ; FFBC CHROUT  Send char to VDU driver
OSEVEN      JMP   EVENT          ; FFBF OSEVEN  Signal an event
GSINIT      JMP   GSINTGO        ; FFC2 GSINIT  Init string reading
GSREAD      JMP   GSRDGO         ; FFC5 GSREAD  Parse general string
NVWRCH      JMP   WRCHHND        ; FFC8 NVWRCH  Nonvectored WRCH
NVRDCH      JMP   RDCHHND        ; FFCB NVRDCH  Nonvectored RDCH
OSFIND      JMP   (FINDV)        ; FFCE OSFIND
OSGBPB      JMP   (GBPBV)        ; FFD1 OSGBPB
OSBPUT      JMP   (BPUTV)        ; FFD4 OSBPUT
OSBGET      JMP   (BGETV)        ; FFD7 OSBGET
OSARGS      JMP   (ARGSV)        ; FFDA OSARGS
OSFILE      JMP   (FILEV)        ; FFDD OSFILE
OSRDCH      JMP   (RDCHV)        ; FFE0 OSRDCH
OSASCI      CMP   #$0D           ; FFE3 OSASCI
            BNE   OSWRCH
OSNEWL      LDA   #$0A           ; FFE7 OSNEWL
            JSR   OSWRCH
OSWRCR      LDA   #$0D           ; FFEC OSWRCR
OSWRCH      JMP   (WRCHV)        ; FFEE OSWRCH
OSWORD      JMP   (WORDV)        ; FFF1 OSWORD
OSBYTE      JMP   (BYTEV)        ; FFF4 OSBYTE
OSCLI       JMP   (CLIV)         ; FFF7 OSCLI
NMIVEC      DW    NULLRTI        ; FFFA NMIVEC
RSTVEC      DW    STOP           ; FFFC RSTVEC
IRQVEC

* Assembler doesn't like running up to $FFFF, so we bodge a bit
MOSEND
            ORG   MOSEND-MOSAPI+MOSVEC
            DW    IRQBRKHDLR     ; FFFE IRQVEC
MOSVEND

* Buffer for one 512 byte disk block in aux mem
AUXBLK      DS    $200

