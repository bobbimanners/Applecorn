* AUXMEM.MISC.S
* (c) Bobbi 2021 GPLv3
*
* Misc functions and API entry block
* 02-Sep-2021 Written GSINIT/GSREAD
* 11-Sep-2021 PR16DEC uses OS workspace, added rest of default vectors/etc.


* OSBYTE $80 - ADVAL
************************************
* Read input device or buffer status

BYTE80      LDY   #$00           ; Prepare return=&00xx
            TXA                  ; X<0  - info about buffers
            BMI   ADVALBUF       ; X>=0 - read input devices
            CPX   #$7F
            BNE   ADVALNONE
ADVALWAIT   JSR   KBDREAD
            BCS   ADVALWAIT
            TAX
            BPL   ADVALOK1       ; &00xx for normal keys
            INY                  ; &01xx for function/edit keys
ADVALOK1    RTS
ADVALNONE   LDX   #$00           ; Input, just return 0
            RTS
ADVALBUF    INX
            BEQ   :ADVALKBD      ; Fake keyboard buffer
            INX
            BEQ   :ADVALOK       ; Serial input, return 0
            LDX   #$01           ; For outputs, return 1 char free
            RTS
:ADVALKBD   BIT   $C000          ; Test keyboard data/strobe
            BPL   :ADVALOK       ; No Strobe, return 0
            INX                  ; Strobe, return 1
:ADVALOK    RTS


******************
* Helper functions
******************

* Beep
*
* Sound measurement shows the tone formula is:
*   1.230 MHz
* ------------- = cycles
* 8 * frequency
*
* cycles = BEEPX*5+10
*
* So:
* BEEPX = (cycles-10)/5
* So:
* BEEPX = (  1.230 MHz        )
*         (------------- - 10 ) / 5
*         (8 * frequency      )

* BEEPX     EQU   #57        ; note=C5
BEEPX       EQU   #116           ; note=C4
BEEP        PHA
            PHX
            PHY
            LDY   #$00           ;       duration
:L1         LDX   #BEEPX         ; 2cy   pitch      2cy
*------------------------------------------------------
:L2         DEX                  ; 2cy      BEEPX * 2cy
            BNE   :L2            ; 3cy/2cy  (BEEPX-1) * 3cy + 1 * 2cy
*------------------------------------------------------
*                                   BEEPX*5-1cy
            LDA   $C030          ; 4cy        BEEPX*5+5
            DEY                  ; 2cy        BEEPX*5+7
            BNE   :L1            ; 3cy/2cy    BEEPX*5+10
            PLY                  ;
            PLX
            PLA
            RTS

* Print string pointed to by X,Y to the screen
OUTSTR      TXA

* Print string pointed to by A,Y to the screen
PRSTR       STA   OSTEXT+0       ;  String in A,Y
            STY   OSTEXT+1
:L1         LDA   (OSTEXT)       ; Ptr to string in OSTEXT
            BEQ   PRSTROK
            JSR   OSASCI
            INC   OSTEXT
            BNE   :L1
            INC   OSTEXT+1
            BRA   :L1
PRSTROK     RTS

* Print NL if not already at column 0
FORCENL     LDA   #$86
            JSR   OSBYTE
            TXA
            BEQ   PRSTROK
            JMP   OSNEWL

* Print XY in hex
OUT2HEX     TYA
            JSR   OUTHEX
            TAX                  ; Continue into OUTHEX

* Print hex byte in A
OUTHEX      PHA
            LSR
            LSR
            LSR
            LSR
            AND   #$0F
            JSR   PRNIB
            PLA
            AND   #$0F           ; Continue into PRNIB

* Print hex nibble in A
PRNIB       CMP   #$0A
            BCC   :S1
            CLC                  ; >= $0A
            ADC   #'A'-$0A
            JSR   OSWRCH
            RTS
:S1         ADC   #'0'           ; < $0A
            JMP   OSWRCH

* Print 16-bit value in XY in decimal
* beebwiki.mdfs.net/Number_output_in_6502_machine_code
OSNUM       EQU   OSTEXT+0
OSPAD       EQU   OSTEXT+4

PRDECXY     LDA   #' '
PRDECPAD    STA   OSPAD
            STX   OSNUM+0
            STY   OSNUM+1
:PRDEC16    LDY   #$08           ; Five digits (5-1)*2
:LP1        LDX   #$FF
            SEC
:LP2        LDA   OSNUM+0
            SBC   :TENS+0,Y
            STA   OSNUM+0
            LDA   OSNUM+1
            SBC   :TENS+1,Y
            STA   OSNUM+1
            INX
            BCS   :LP2
            LDA   OSNUM+0
            ADC   :TENS+0,Y
            STA   OSNUM+0
            LDA   OSNUM+1
            ADC   :TENS+1,Y
            STA   OSNUM+1
            TXA
            BNE   :DIGIT
            LDA   OSPAD
            BNE   :PRINT
            BEQ   :NEXT
:DIGIT      LDX   #'0'
            STX   OSPAD
            ORA   #'0'
:PRINT      JSR   OSWRCH
:NEXT       DEY
            DEY
            BPL   :LP1
            RTS
:TENS       DW    1
            DW    10
            DW    100
            DW    1000
            DW    10000


* GSINIT - Initialise for GSTRANS string parsing
************************************************
* On entry,
*  (OSLPTR),Y=>start of string (spaces will be skipped)
*  CLC = filename style parsing
*  SEC = *KEY style parsing
* On exit,
*  X = preserved
*  Y = prepared for future calls to GSREAD
*  EQ = end of line (nb: not "" null string)
*  NE = not end of line
*
* Very difficult to write this without it being a direct clone
* from the BBC MOS. ;)
*
GSINTGO     ROR   GSFLAG         ; CY initially into bit 7
            JSR   SKIPSPC        ; Skip any spaces
            INY                  ; Step past in case it's a quote
            CMP   #$22           ; Is it a quote?
            BEQ   GSINTGO1
            DEY                  ; Wasn't a quote, step back
            CLC                  ; Prepare CC=no leading quote
GSINTGO1    ROR   GSFLAG         ; Rotate 'leading-quote' into flags
            CMP   #$0D
            RTS                  ; Return EQ if end of line
* GSFLAG set to:
*  bit7: leading quote found
*  bit6: CC=filename CS=*KEY

* GSREAD - Read a character from a GSTRANS parsed string
********************************************************
* On entry,
*  (OSLPTR),Y=>current string pointer
* On exit,
*  A = parsed character
*  X = preserved
*  CS = end of string (space or <cr> or ")
*       Y =updated to start of next word or end of line
*       EQ=end of line after this string
*       NE=not end of line, more words follow
*  CC = not end of string
*       Y =updated for future calls to GSREAD
*       VS=7-bit control character, (char AND $7F)<$20
*       VC=not 7-bit control character (char AND $7F)>$1F
*       EQ= char=$00, NE= char>$00
*       PL= char<$80, MI= char>$7F
*
* No string present is checked for with:
*  JSR GSINIT:BEQ missingstring
*
* A null string is checked for with:
*  JSR GSINIT:JSR GSREAD:BCS nullstring
*
* A string is skipped with:
*  JSR GSINIT
* loop
*  JSR GSREAD:BCC loop
*
* A string is copied with:
*  JSR GSINIT
*  LDX #0
* loop
*  JSR GSREAD:BCS done
*  STA data,X
*  INX:BNE loop
* done
*
GSRDGO      LDA   #$00           ; Prepare to clear accumulator
GSREADLP    STA   GSCHAR         ; Update accumulator
            LDA   (OSLPTR),Y     ; Get current character
            CMP   #$0D           ; End of line?
            BNE   GSREAD2        ; No, check character
            BIT   GSFLAG
            BPL   GSREADEND      ; We aren't waiting for a closing quote
*                                ; End of line before closing quote
ERRBADSTR   BRK
            DB    $FD
            ASC   'Bad string'
            BRK

GSREAD2     CMP   #' '
            BCC   ERRBADSTR      ; Embedded control char
            BNE   GSREAD3        ; Not a space, process it
            BIT   GSFLAG         ; Can space terminate string?
            BMI   GSREADCHAR     ; We're waiting for a terminating quote
*                                ;  so return the space character
            BVC   GSREADEND      ; Space is a terminator, finish
GSREAD3     CMP   #$22           ; Is it a quote?
            BNE   GSREADESC      ; Not quote, check for escapes
            BIT   GSFLAG         ; Was there an opening quote?
            BPL   GSREADCHAR     ; Not waiting for a closing quote
            INY                  ; Waiting for quote, check next character
            LDA   (OSLPTR),Y
            CMP   #$22           ; Is it another quote?
            BEQ   GSREADCHAR     ; Quote-Quote, expand to single quote
* End of string
* Either closing quote, or a space seperator, or end of line
GSREADEND   JSR   SKIPSPC        ; Skip any spaces to next word
            SEC                  ; SEC=end of string
            RTS                  ; and (OSLPTR),Y=>next word or end of line
* CS=end of string
* EQ=end of line
* NE=not end of line, more words follow

GSREADESC   CMP   #$7C           ; Is it '|' escape character
            BNE   GSREADCHAR     ; No, return as character
            INY                  ; Step to next character
            LDA   (OSLPTR),Y
            CMP   #$7C
            BEQ   GSREADCHAR     ; bar-bar expands to bar
            CMP   #$22
            BEQ   GSREADCHAR     ; bar-quote expands to quote
            CMP   #'!'           ; Is it bar-pling?
            BNE   GSREAD5        ; No, check for bar-letter
            INY                  ; Step past it
            LDA   #$80           ; Set bit 7 in accumulator
            BNE   GSREADLP       ; Loop back to check next character(s)

GSREAD5     CMP   #'?'           ; Check for '?'
            BCC   ERRBADSTR      ; <'?', bad character
            BEQ   GSREADDEL      ; bar-query -> DEL
            AND   #$1F           ; Convert bar-letter to control code
            BIT   SETV           ; SEV=control character
            BVS   GSREADOK
GSREADDEL   LDA   #$7F
GSREADCHAR  CLV                  ; CLV=not control character
GSREADOK    INY                  ; Step to next character
            ORA   GSCHAR         ; Add in any bit 7 from |! prefix
            CLC                  ; CLC=not end of string
            RTS
* CC=not end of string
* VS=control character
* VC=not control character


* Read a byte from sideways ROM
RDROM       LDX   #$0F           ; Returns X=current ROM, Y=0, A=byte
            LDY   #$00           ; We haven't really got any ROMs
            LDA   ($F6),Y        ; so just read directly
EVENT       RTS

*EVENT       LDA   #<OSEVENM
*            LDY   #>OSEVENM
*            JMP   PRSTR
*OSEVENM     ASC   'OSEVEN.'
*            DB    $00


**********************************************************
* Interrupt Handlers, MOS redirection vectors etc.
**********************************************************

* Invoked from GSBRK in main memory. On IIgs only.
GSBRKAUX    >>>   IENTAUX        ; IENTAUX does not do CLI
* Continue into IRQBRKHDLR
* TO DO: Check, IENTAUX modifies X

* IRQ/BRK handler
IRQBRKHDLR  PHA
* Mustn't enable IRQs within the IRQ handler
* Do not use WRTMAIN/WRTAUX macros
            STA   $C004          ; Write to main memory
            STA   $45            ; $45=A for ProDOS IRQ handlers
            STA   $C005          ; Write to aux memory

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

:IRQ        >>>   XF2MAIN,A2IRQ  ; Bounce to Apple IRQ handler
IRQBRKRET
            >>>   IENTAUX        ; IENTAUX does not do CLI
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
            DW    FSCHND         ; $21E FSCV
            DW    NULLRTS        ; $220 EVENTV
            DW    NULLRTS        ; $222
            DW    NULLRTS        ; $224
            DW    NULLRTS        ; $226
            DW    NULLRTS        ; $228
            DW    NULLRTS        ; $22A
            DW    NULLRTS        ; $22C
            DW    NULLRTS        ; $22E
            DW    NULLRTS        ; $230 SPARE1V
            DW    NULLRTS        ; $232 SPARE2V
            DW    NULLRTS        ; $234 SPARE3V
ENDVEC

*
* Acorn MOS entry points at the top of RAM
* Copied from loaded code to high memory
*

* Base of API entries here in loaded code
MOSVEC
* Real base of API entries in real memory
MOSAPI      EQU   $FF95
            ORG   MOSAPI

* OPTIONAL ENTRIES
* ----------------
OSSERV      JMP   SERVICE        ; FF95 OSSERV
OSCOLD      JMP   NULLRTS        ; FF98 OSCOLD
OSPRSTR     JMP   OUTSTR         ; FF9B OSPRSTR
OSSCANDEC   JMP   SCANDEC        ; FF9E SCANDEC
OSSCANHEX   JMP   SCANHEX        ; FFA1 SCANHEX
OSFFA4      JMP   NULLRTS        ; FFA4 (DISKACC)
OSFFA7      JMP   NULLRTS        ; FFA7 (DISKCCP)
PRHEX       JMP   OUTHEX         ; FFAA PRHEX
PR2HEX      JMP   OUT2HEX        ; FFAD PR2HEX
OSFFB0      JMP   NULLRTS        ; FFB0 (USERINT)
OSWRRM      JMP   NULLRTS        ; FFB3 OSWRRM

* COMPULSARY ENTRIES
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
AUXBLK      ASC   '**ENDOFCODE**'
            DS    $200-13





















