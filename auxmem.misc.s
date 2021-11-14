* AUXMEM.MISC.S
* (c) Bobbi 2021 GPLv3
*
* Misc functions and API entry block
* 02-Sep-2021 Written GSINIT/GSREAD
* 11-Sep-2021 PR16DEC uses OS workspace, added rest of default vectors/etc.
* 20-Sep-2021 Updated PRDECIMAL routine, prints up to 32 bits.
* 25-Oct-2021 Initial pseudo-sideways ROM selection code.
* 26-Oct-2021 Corrected entry parameters to OSRDRM.
* 03-Nov-2021 Temp'y fix, if can't find SROM, ignores it.
* 13-Nov-2021 ROMSELECT calls mainmem to load ROM.


* OSBYTE $80 - ADVAL
************************************
* Read input device or buffer status

BYTE80      LDY   #$00               ; Prepare return=&00xx
            TXA                      ; X<0  - info about buffers
            BMI   ADVALBUF           ; X>=0 - read input devices
            CPX   #$7F
            BNE   ADVALNONE
ADVALWAIT   JSR   KBDREAD
            BCS   ADVALWAIT
            TAX
            BPL   ADVALOK1           ; &00xx for normal keys
            INY                      ; &01xx for function/edit keys
ADVALOK1    RTS
ADVALNONE   LDX   #$00               ; Input, just return 0
            RTS
ADVALBUF    INX
            BEQ   :ADVALKBD          ; Fake keyboard buffer
            INX
            BEQ   :ADVALOK           ; Serial input, return 0
            LDX   #$01               ; For outputs, return 1 char free
            RTS
:ADVALKBD   BIT   $C000              ; Test keyboard data/strobe
            BPL   :ADVALOK           ; No Strobe, return 0
            INX                      ; Strobe, return 1
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
BEEPX       EQU   #116               ; note=C4
BEEP        PHA
            PHX
            PHY
            LDY   #$00               ;       duration
:L1         LDX   #BEEPX             ; 2cy   pitch      2cy
*------------------------------------------------------
:L2         DEX                      ; 2cy      BEEPX * 2cy
            BNE   :L2                ; 3cy/2cy  (BEEPX-1) * 3cy + 1 * 2cy
*------------------------------------------------------
*                                   BEEPX*5-1cy
            LDA   $C030              ; 4cy        BEEPX*5+5
            DEY                      ; 2cy        BEEPX*5+7
            BNE   :L1                ; 3cy/2cy    BEEPX*5+10
            PLY                      ;
            PLX
            PLA
            RTS


* Print string pointed to by X,Y to the screen
OUTSTR      TXA

* Print string pointed to by A,Y to the screen
PRSTR       STA   OSTEXT+0           ;  String in A,Y
            STY   OSTEXT+1
:L1         LDA   (OSTEXT)           ; Ptr to string in OSTEXT
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
            TXA                      ; Continue into OUTHEX

* Print hex byte in A
OUTHEX      PHA
            LSR
            LSR
            LSR
            LSR
            AND   #$0F
            JSR   PRNIB
            PLA
            AND   #$0F               ; Continue into PRNIB

* Print hex nibble in A
PRNIB       CMP   #$0A
            BCC   :S1
            CLC                      ; >= $0A
            ADC   #'A'-$0A
            JSR   OSWRCH
            RTS
:S1         ADC   #'0'               ; < $0A
            JMP   OSWRCH

* TEMP ENTRY *
* Print 16-bit value in XY in decimal
OSNUM       EQU   OSTEXT+0
OSPAD       EQU   OSTEXT+4
*PRDECXY
*PRDECPAD    STX   OSNUM+0
*            STY   OSNUM+1
*            STZ   OSNUM+2
*            STZ   OSNUM+3
*:PRDEC16    LDY   #$05       ; 5 digits
*            LDX   #OSNUM     ; number stored in OSNUM

* Print up to 32-bit decimal number
* See forum.6502.org/viewtopic.php?f=2&t=4894
* and groups.google.com/g/comp.sys.apple2/c/_y27d_TxDHA
*
* X=>four byte zero page locations
* Y= number of digits to pad to, 0 for no padding
*
PRINTDEC    sty   OSPAD              ; Number of padding+digits
            ldy   #0                 ; Digit counter
PRDECDIGIT  lda   #32                ; 32-bit divide
            sta   OSTEMP
            lda   #0                 ; Remainder=0
            clv                      ; V=0 means div result = 0
PRDECDIV10  cmp   #10/2              ; Calculate OSNUM/10
            bcc   PRDEC10
            sbc   #10/2+$80          ; Remove digit & set V=1 to show div result > 0
            sec                      ; Shift 1 into div result
PRDEC10     rol   0,x                ; Shift /10 result into OSNUM
            rol   1,x
            rol   2,x
            rol   3,x
            rol   a                  ; Shift bits of input into acc (input mod 10)
            dec   OSTEMP
            bne   PRDECDIV10         ; Continue 32-bit divide
            ora   #48
            pha                      ; Push low digit 0-9 to print
            iny
            bvs   PRDECDIGIT         ; If V=1, result of /10 was > 0 & do next digit
            lda   #32
PRDECLP1    cpy   OSPAD
            bcs   PRDECLP2           ; Enough padding pushed
            pha                      ; Push leading space characters
            iny
            bne   PRDECLP1
PRDECLP2    pla                      ; Pop character left to right
            jsr   OSWRCH             ; Print it
            dey
            bne   PRDECLP2
            rts


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
GSINTGO     ROR   GSFLAG             ; CY initially into bit 7
            JSR   SKIPSPC            ; Skip any spaces
            INY                      ; Step past in case it's a quote
            CMP   #$22               ; Is it a quote?
            BEQ   GSINTGO1
            DEY                      ; Wasn't a quote, step back
            CLC                      ; Prepare CC=no leading quote
GSINTGO1    ROR   GSFLAG             ; Rotate 'leading-quote' into flags
            CMP   #$0D
            RTS                      ; Return EQ if end of line
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
GSRDGO      LDA   #$00               ; Prepare to clear accumulator
GSREADLP    STA   GSCHAR             ; Update accumulator
            LDA   (OSLPTR),Y         ; Get current character
            CMP   #$0D               ; End of line?
            BNE   GSREAD2            ; No, check character
            BIT   GSFLAG
            BPL   GSREADEND          ; We aren't waiting for a closing quote
*                                ; End of line before closing quote
ERRBADSTR   BRK
            DB    $FD
            ASC   'Bad string'
            BRK

GSREAD2     CMP   #' '
            BCC   ERRBADSTR          ; Embedded control char
            BNE   GSREAD3            ; Not a space, process it
            BIT   GSFLAG             ; Can space terminate string?
            BMI   GSREADCHAR         ; We're waiting for a terminating quote
*                                ;  so return the space character
            BVC   GSREADEND          ; Space is a terminator, finish
GSREAD3     CMP   #$22               ; Is it a quote?
            BNE   GSREADESC          ; Not quote, check for escapes
            BIT   GSFLAG             ; Was there an opening quote?
            BPL   GSREADCHAR         ; Not waiting for a closing quote
            INY                      ; Waiting for quote, check next character
            LDA   (OSLPTR),Y
            CMP   #$22               ; Is it another quote?
            BEQ   GSREADCHAR         ; Quote-Quote, expand to single quote
* End of string
* Either closing quote, or a space seperator, or end of line
GSREADEND   JSR   SKIPSPC            ; Skip any spaces to next word
            SEC                      ; SEC=end of string
            RTS                      ; and (OSLPTR),Y=>next word or end of line
* CS=end of string
* EQ=end of line
* NE=not end of line, more words follow

GSREADESC   CMP   #$7C               ; Is it '|' escape character
            BNE   GSREADCHAR         ; No, return as character
            INY                      ; Step to next character
            LDA   (OSLPTR),Y
            CMP   #$7C
            BEQ   GSREADCHAR         ; bar-bar expands to bar
            CMP   #$22
            BEQ   GSREADCHAR         ; bar-quote expands to quote
            CMP   #'!'               ; Is it bar-pling?
            BNE   GSREAD5            ; No, check for bar-letter
            INY                      ; Step past it
            LDA   #$80               ; Set bit 7 in accumulator
            BNE   GSREADLP           ; Loop back to check next character(s)

GSREAD5     CMP   #'?'               ; Check for '?'
            BCC   ERRBADSTR          ; <'?', bad character
            BEQ   GSREADDEL          ; bar-query -> DEL
            AND   #$1F               ; Convert bar-letter to control code
            BIT   SETV               ; SEV=control character
            BVS   GSREADOK
GSREADDEL   LDA   #$7F
GSREADCHAR  CLV                      ; CLV=not control character
GSREADOK    INY                      ; Step to next character
            ORA   GSCHAR             ; Add in any bit 7 from |! prefix
            CLC                      ; CLC=not end of string
            RTS
* CC=not end of string
* VS=control character
* VC=not control character


* Read a byte from sideways ROM
* On entry, Y=ROM to read from
* On exit,  A=byte read, X=current ROM, Y=$00
RDROM       LDA   $F4
            PHA                      ; Save current ROM
            TYA
            TAX                      ; X=ROM to read from
            JSR   ROMSELECT          ; Page in the required ROM
            LDY   #$00
            LDA   ($F6),Y            ; Read the byte
            PLX

* Select a sideways ROM
* X=ROM to select
* All registers must be preserved
ROMSELECT
* Insert code here for faking sideways ROMs by loading or otherwise
* fetching code to $8000. All registers must be preserved.
:ROMSEL     PHP
            PHA
            PHX
            PHY
            SEI
            TXA                      ; A=ROM to select
            >>>   XF2MAIN,SELECTROM
ROMSELDONE  >>>   ENTAUX
            PLY
            PLX
            PLA
            PLP
:ROMSELOK   STX   $F4                ; Set Current ROM number
            RTS


ROMXX
*            CPX   $F8
*            BEQ   :ROMSELOK        ; Already selected
*
** Insert code here for faking sideways ROMs by loading or otherwise
** fetching code to $8000. All registers must be preserved.
*            CPX   MAXROM
*            BEQ   :ROMSEL
*            BCS   :ROMSELOK        ; Out of range, ignore
*:ROMSEL     PHA
*            PHX
*            PHY
*
*            LDA   OSLPTR+0
*            PHA
*            LDA   OSLPTR+1
*            PHA
*
*            TXA
*            ASL   A
*            TAX
*            LDA   ROMTAB+0,X       ; LSB of pointer to name
*            STA   OSFILECB+0
*            LDA   ROMTAB+1,X       ; MSB of pointer to name
*            STA   OSFILECB+1
*
*            LDX   #<OSFILECB
*            LDY   #>OSFILECB
*            LDA   #$05             ; Means 'INFO'
*            JSR   OSFILE
*            CMP   #$01
*            BNE   :ROMNOTFND       ; File not found
*
*            STZ   OSFILECB+2       ; Dest address $8000
*            LDA   #$80
*            STA   OSFILECB+3
*            STZ   OSFILECB+4
*            STZ   OSFILECB+5
*            STZ   OSFILECB+6       ; Load to specified address
*            LDX   #<OSFILECB
*            LDY   #>OSFILECB
*            LDA   #$FF             ; Means 'LOAD'
*            JSR   OSFILE
*:ROMNOTFND
*            PLA
*            STA   OSLPTR+1
*            PLA
*            STA   OSLPTR+0
*            PLY
*            PLX
*            PLA
*            STX   $F8              ; Set ROM loaded
*:ROMSELOK   STX   $F4              ; Set Current ROM number
EVENT       RTS

*BASICROM    ASC   'BASIC2.ROM'
*            DB    $0D,$00
*
*COMALROM    ASC   'COMAL.ROM'
*            DB    $0D,$00
*
*LISPROM     ASC   'LISP501.ROM'
*            DB    $0D,$00
*
*FORTHROM    ASC   'FORTH103.ROM'
*            DB    $0D,$00
*
*PROLOGROM   ASC   'MPROLOG310.ROM'
*            DB    $0D,$00
*
*BCPLROM     ASC   'BCPL7.0.ROM'
*            DB    $0D,$00
*
*PASCROM1    ASC   'PASC.1.10.1.ROM'
*            DB    $0D,$00
*
*PASCROM2    ASC   'PASC.1.10.2.ROM'
*            DB    $0D,$00
*

* Initialize ROMTAB according to user selection in menu
ROMINIT     STZ   MAXROM             ; One sideways ROM only
            STA   $C002              ; Read main mem
            LDA   USERSEL
            STA   $C003              ; Read aux mem

            CMP   #6
            BNE   :X1
            INC   MAXROM
:X1         CMP   #7
            BNE   :X2
            STA   MAXROM
:X2         RTS

*            ASL                    ; x2
*            CLC
*            ADC   #<ROMS
*            STA   OSLPTR+0
*            LDA   #>ROMS
*            ADC   #$00
*            STA   OSLPTR+1
*            LDY   #$00
*            LDA   (OSLPTR),Y
*            STA   ROMTAB+0
*            INY
*            LDA   (OSLPTR),Y
*            STA   ROMTAB+1
*            STA   $C002            ; Read main mem
*            LDA   USERSEL
*            STA   $C003            ; Read aux mem
*            CMP   #6               ; Menu entry 7 has two ROMs
*            BNE   :S1
*            LDA   #<PASCROM2
*            STA   ROMTAB+2
*            LDA   #>PASCROM2
*            STA   ROMTAB+3
*            INC   MAXROM           ; Two ROMs
*            BRA   :DONE
*:S1         CMP   #7               ; Menu entry 8
*            BNE   :DONE
*            LDA   #<PASCROM1
*            STA   ROMTAB+0
*            LDA   #>PASCROM1
*            STA   ROMTAB+1
*            LDA   #<PASCROM2
*            STA   ROMTAB+2
*            LDA   #>PASCROM2
*            STA   ROMTAB+3
*            LDA   #<LISPROM
*            STA   ROMTAB+4
*            LDA   #>LISPROM
*            STA   ROMTAB+5
*            LDA   #<FORTHROM
*            STA   ROMTAB+6
*            LDA   #>FORTHROM
*            STA   ROMTAB+7
*            LDA   #<PROLOGROM
*            STA   ROMTAB+8
*            LDA   #>PROLOGROM
*            STA   ROMTAB+9
*            LDA   #<BCPLROM
*            STA   ROMTAB+10
*            LDA   #>BCPLROM
*            STA   ROMTAB+11
*            LDA   #<COMALROM
*            STA   ROMTAB+12
*            LDA   #>COMALROM
*            STA   ROMTAB+13
*            LDA   #<BASICROM
*            STA   ROMTAB+14
*            LDA   #>BASICROM
*            STA   ROMTAB+15
*            LDA   #7               ; 8 sideways ROMs
*            STA   MAXROM
*:DONE       LDA   #$FF
*            STA   $F8              ; Force ROM to load
*            RTS
*
** Active sideways ROMs
*ROMTAB      DW    $0000            ; ROM0
*            DW    $0000            ; ROM1
*            DW    $0000            ; ROM2
*            DW    $0000            ; ROM3
*            DW    $0000            ; ROM4
*            DW    $0000            ; ROM5
*            DW    $0000            ; ROM6
*            DW    $0000            ; ROM7
*            DW    $0000            ; ROM8
*            DW    $0000            ; ROM9
*            DW    $0000            ; ROMA
*            DW    $0000            ; ROMB
*            DW    $0000            ; ROMC
*            DW    $0000            ; ROMD
*            DW    $0000            ; ROME
*            DW    $0000            ; ROMF
*
** ROM filenames in same order as in the menu
** ROMMENU copies these to ROMTAB upon user selection
*ROMS        DW    BASICROM
*            DW    COMALROM
*            DW    LISPROM
*            DW    FORTHROM
*            DW    PROLOGROM
*            DW    BCPLROM
*            DW    PASCROM1
*            DW    PASCROM2

*EVENT       LDA   #<OSEVENM
*            LDY   #>OSEVENM
*            JMP   PRSTR
*OSEVENM     ASC   'OSEVEN.'
*            DB    $00


**********************************************************
* Interrupt Handlers, MOS redirection vectors etc.
**********************************************************

* Invoked from GSBRK in main memory. On IIgs only.
GSBRKAUX    >>>   IENTAUX            ; IENTAUX does not do CLI
* Continue into IRQBRKHDLR
* TO DO: Check, IENTAUX modifies X

* IRQ/BRK handler
IRQBRKHDLR  PHA
* Mustn't enable IRQs within the IRQ handler
* Do not use WRTMAIN/WRTAUX macros
            STA   $C004              ; Write to main memory
            STA   $45                ; $45=A for ProDOS IRQ handlers
            STA   $C005              ; Write to aux memory

            TXA
            PHA
            CLD
            TSX
            LDA   $103,X             ; Get PSW from stack
            AND   #$10
            BEQ   :IRQ               ; IRQ
            SEC
            LDA   $0104,X
            SBC   #$01
            STA   FAULT+0            ; FAULT=>error block after BRK
            LDA   $0105,X
            SBC   #$00
            STA   FAULT+1

            LDA   $F4                ; Get current ROM
            STA   BYTEVARBASE+$BA    ; Set ROM at last BRK
            STX   OSXREG             ; Pass stack pointer
            LDA   #$06               ; Service Call 6 = BRK occured
            JSR   SERVICE
            LDX   BYTEVARBASE+$FC    ; Get current language
            JSR   ROMSELECT          ; Bring it into memory

            PLA
            TAX
            PLA
            CLI
            JMP   (BRKV)             ; Pass on to BRK handler

:IRQ        >>>   XF2MAIN,A2IRQ      ; Bounce to Apple IRQ handler
IRQBRKRET
            >>>   IENTAUX            ; IENTAUX does not do CLI
            PLA                      ; TODO: Pass on to IRQ1V
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
STOP        JMP   STOP               ; Cannot return from a BRK

MSGBRK      DB    $0D
            ASC   'ERROR: '
            DB    $00


* Default page 2 contents
DEFVEC      DW    NULLRTS            ; $200 USERV
            DW    MOSBRKHDLR         ; $202 BRKV
            DW    NULLRTI            ; $204 IRQ1V
            DW    NULLRTI            ; $206 IRQ2V
            DW    CLIHND             ; $208 CLIV
            DW    BYTEHND            ; $20A BYTEV
            DW    WORDHND            ; $20C WORDV
            DW    WRCHHND            ; $20E WRCHV
            DW    RDCHHND            ; $210 RDCHV
            DW    FILEHND            ; $212 FILEV
            DW    ARGSHND            ; $214 ARGSV
            DW    BGETHND            ; $216 BGETV
            DW    BPUTHND            ; $218 BPUTV
            DW    GBPBHND            ; $21A GBPBV
            DW    FINDHND            ; $21C FINDV
            DW    FSCHND             ; $21E FSCV
            DW    NULLRTS            ; $220 EVENTV
            DW    NULLRTS            ; $222
            DW    NULLRTS            ; $224
            DW    NULLRTS            ; $226
            DW    NULLRTS            ; $228
            DW    NULLRTS            ; $22A
            DW    NULLRTS            ; $22C
            DW    NULLRTS            ; $22E
            DW    NULLRTS            ; $230 SPARE1V
            DW    NULLRTS            ; $232 SPARE2V
            DW    NULLRTS            ; $234 SPARE3V
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
OSSERV      JMP   SERVICE            ; FF95 OSSERV
OSCOLD      JMP   NULLRTS            ; FF98 OSCOLD
OSPRSTR     JMP   OUTSTR             ; FF9B OSPRSTR
OSSCANDEC   JMP   SCANDEC            ; FF9E SCANDEC
OSSCANHEX   JMP   SCANHEX            ; FFA1 SCANHEX
OSFFA4      JMP   NULLRTS            ; FFA4 (DISKACC)
OSFFA7      JMP   NULLRTS            ; FFA7 (DISKCCP)
PRHEX       JMP   OUTHEX             ; FFAA PRHEX
PR2HEX      JMP   OUT2HEX            ; FFAD PR2HEX
OSFFB0      JMP   PRINTDEC           ; FFB0 (USERINT)
OSWRRM      JMP   NULLRTS            ; FFB3 OSWRRM

* COMPULSARY ENTRIES
* ------------------
VECSIZE     DB    ENDVEC-DEFVEC      ; FFB6 VECSIZE Size of vectors
VECBASE     DW    DEFVEC             ; FFB7 VECBASE Base of default vectors
OSRDRM      JMP   RDROM              ; FFB9 OSRDRM  Read byte from paged ROM
OSCHROUT    JMP   OUTCHAR            ; FFBC CHROUT  Send char to VDU driver
OSEVEN      JMP   EVENT              ; FFBF OSEVEN  Signal an event
GSINIT      JMP   GSINTGO            ; FFC2 GSINIT  Init string reading
GSREAD      JMP   GSRDGO             ; FFC5 GSREAD  Parse general string
NVWRCH      JMP   WRCHHND            ; FFC8 NVWRCH  Nonvectored WRCH
NVRDCH      JMP   RDCHHND            ; FFCB NVRDCH  Nonvectored RDCH
OSFIND      JMP   (FINDV)            ; FFCE OSFIND
OSGBPB      JMP   (GBPBV)            ; FFD1 OSGBPB
OSBPUT      JMP   (BPUTV)            ; FFD4 OSBPUT
OSBGET      JMP   (BGETV)            ; FFD7 OSBGET
OSARGS      JMP   (ARGSV)            ; FFDA OSARGS
OSFILE      JMP   (FILEV)            ; FFDD OSFILE
OSRDCH      JMP   (RDCHV)            ; FFE0 OSRDCH
OSASCI      CMP   #$0D               ; FFE3 OSASCI
            BNE   OSWRCH
OSNEWL      LDA   #$0A               ; FFE7 OSNEWL
            JSR   OSWRCH
OSWRCR      LDA   #$0D               ; FFEC OSWRCR
OSWRCH      JMP   (WRCHV)            ; FFEE OSWRCH
OSWORD      JMP   (WORDV)            ; FFF1 OSWORD
OSBYTE      JMP   (BYTEV)            ; FFF4 OSBYTE
OSCLI       JMP   (CLIV)             ; FFF7 OSCLI
NMIVEC      DW    NULLRTI            ; FFFA NMIVEC
RSTVEC      DW    STOP               ; FFFC RSTVEC
IRQVEC

* Assembler doesn't like running up to $FFFF, so we bodge a bit
MOSEND
            ORG   MOSEND-MOSAPI+MOSVEC
            DW    IRQBRKHDLR         ; FFFE IRQVEC
MOSVEND

* Buffer for one 512 byte disk block in aux mem
AUXBLK      ASC   '**ENDOFCODE**'
            DS    $200-13







