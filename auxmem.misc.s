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
* 08-Oct-2022 ROMSEL doesn't call loader if already paged in.


* OSBYTE $80 - ADVAL
************************************
* Read input device or buffer status

BYTE80      LDY   #$00             ; Prepare return=&00xx
            TXA                    ; X<0  - info about buffers
            BMI   ADVALBUF         ; X>=0 - read input devices
            CPX   #$7F
            BNE   ADVALNONE
ADVALWAIT   JSR   KBDREAD
            BCS   ADVALWAIT
            TAX
            BPL   ADVALOK1         ; &00xx for normal keys
            INY                    ; &01xx for function/edit keys
ADVALOK1    RTS
ADVALNONE   LDX   #$00             ; Input, just return 0
            RTS
ADVALBUF    INX
            BEQ   :ADVALKBD        ; Fake keyboard buffer
            INX
            BEQ   :ADVALOK         ; Serial input, return 0
            LDX   #$01             ; For outputs, return 1 char free
            RTS
:ADVALKBD   BIT   KBDDATA          ; Test keyboard data/strobe
            BPL   :ADVALOK         ; No Strobe, return 0
            INX                    ; Strobe, return 1
:ADVALOK    RTS


* Beep
******
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

* BEEPX     EQU   #57              ; note=C5
BEEPX       EQU   #116             ; note=C4
BEEP        PHA
            PHX
            PHY
            LDY   #$00             ;       duration
:L1         LDX   #BEEPX           ; 2cy   pitch      2cy
*------------------------------------------------------
:L2         DEX                    ; 2cy      BEEPX * 2cy
            BNE   :L2              ; 3cy/2cy  (BEEPX-1) * 3cy + 1 * 2cy
*------------------------------------------------------
*                                   BEEPX*5-1cy
            LDA   SPKR             ; 4cy        BEEPX*5+5
            DEY                    ; 2cy        BEEPX*5+7
            BNE   :L1              ; 3cy/2cy    BEEPX*5+10
            PLY                    ;
            PLX
            PLA
PRSTROK     RTS


* OSPRSTR - Print string at XY
******************************
* On exit, X,Y preserved, A=$00
OUTSTR      TXA

* Print string pointed to by A,Y to the screen
PRSTR       STA   OSTEXT+0         ;  String in A,Y
            STY   OSTEXT+1
:L1         LDA   (OSTEXT)         ; Ptr to string in OSTEXT
            PHP                    ; Save EQ
            INC   OSTEXT
            BNE   :L2
            INC   OSTEXT+1
:L2         PLP                    ; Get EQ back
            BEQ   PRSTROK          ; End of string
            JSR   OSASCI
            BRA   :L1

* Print NL if not already at column 0
FORCENL     LDA   #$86
            JSR   OSBYTE
            TXA
            BEQ   PRSTROK
            JMP   OSNEWL

* PR2HEX - Print XY in hex
**************************
OUT2HEX     TYA
            JSR   OUTHEX
            TXA                    ; Continue into OUTHEX

* PR1HEX - Print hex byte in A
******************************
OUTHEX      PHA
            LSR
            LSR
            LSR
            LSR
            AND   #$0F
            JSR   PRNIB
            PLA
            AND   #$0F             ; Continue into PRNIB

* Print hex nibble in A
PRNIB       CMP   #$0A
            BCC   :S1
            CLC                    ; >= $0A
            ADC   #'A'-$0A
            JSR   OSWRCH
            RTS
:S1         ADC   #'0'             ; < $0A
            JMP   OSWRCH

* OSPRDEC - Print up to 32-bit decimal number
*********************************************
* See forum.6502.org/viewtopic.php?f=2&t=4894
* and groups.google.com/g/comp.sys.apple2/c/_y27d_TxDHA
*
* X=>four byte zero page locations
* Y= number of digits to pad to, 0 for no padding
*
PRINTDEC    STY   OSPAD            ; Number of padding+digits
            LDY   #0               ; Digit counter
PRDECDIGIT  LDA   #32              ; 32-bit divide
            STA   OSTEMP
            LDA   #0               ; Remainder=0
            CLV                    ; V=0 means div result = 0
PRDECDIV10  CMP   #10/2            ; Calculate OSNUM/10
            BCC   PRDEC10
            SBC   #10/2+$80        ; Remove digit & set V=1 to show div result > 0
            SEC                    ; Shift 1 into div result
PRDEC10     ROL   0,X              ; Shift /10 result into OSNUM
            ROL   1,X
            ROL   2,X
            ROL   3,X
            ROL   A                ; Shift bits of input into acc (input mod 10)
            DEC   OSTEMP
            BNE   PRDECDIV10       ; Continue 32-bit divide
            ORA   #48
            PHA                    ; Push low digit 0-9 to print
            INY
            BVS   PRDECDIGIT       ; If V=1, result of /10 was > 0 & do next digit
            LDA   #32
PRDECLP1    CPY   OSPAD
            BCS   PRDECLP2         ; Enough padding pushed
            PHA                    ; Push leading space characters
            INY
            BNE   PRDECLP1
PRDECLP2    PLA                    ; Pop character left to right
            JSR   OSWRCH           ; Print it
            DEY
            BNE   PRDECLP2
            RTS


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
GSINTGO     ROR   GSFLAG           ; CY initially into bit 7
            JSR   SKIPSPC          ; Skip any spaces
            INY                    ; Step past in case it's a quote
            CMP   #$22             ; Is it a quote?
            BEQ   GSINTGO1
            DEY                    ; Wasn't a quote, step back
            CLC                    ; Prepare CC=no leading quote
GSINTGO1    ROR   GSFLAG           ; Rotate 'leading-quote' into flags
            CMP   #$0D
            RTS                    ; Return EQ if end of line
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
GSRDGO      LDA   #$00             ; Prepare to clear accumulator
GSREADLP    STA   GSCHAR           ; Update accumulator
            LDA   (OSLPTR),Y       ; Get current character
            CMP   #$0D             ; End of line?
            BNE   GSREAD2          ; No, check character
            BIT   GSFLAG
            BPL   GSREADEND        ; We aren't waiting for a closing quote
*                                  ; End of line before closing quote
ERRBADSTR   BRK
            DB    $FD
            ASC   'Bad string'
            BRK

GSREAD2     CMP   #' '
            BCC   ERRBADSTR        ; Embedded control char
            BNE   GSREAD3          ; Not a space, process it
            BIT   GSFLAG           ; Can space terminate string?
            BMI   GSREADCHAR       ; We're waiting for a terminating quote
*                                  ;  so return the space character
            BVC   GSREADEND        ; Space is a terminator, finish
GSREAD3     CMP   #$22             ; Is it a quote?
            BNE   GSREADESC        ; Not quote, check for escapes
            BIT   GSFLAG           ; Was there an opening quote?
            BPL   GSREADCHAR       ; Not waiting for a closing quote
            INY                    ; Waiting for quote, check next character
            LDA   (OSLPTR),Y
            CMP   #$22             ; Is it another quote?
            BEQ   GSREADCHAR       ; Quote-Quote, expand to single quote
* End of string
* Either closing quote, or a space seperator, or end of line
GSREADEND   JSR   SKIPSPC          ; Skip any spaces to next word
            SEC                    ; SEC=end of string
            RTS                    ; and (OSLPTR),Y=>next word or end of line
* CS=end of string
* EQ=end of line
* NE=not end of line, more words follow

GSREADESC   CMP   #$7C             ; Is it '|' escape character
            BNE   GSREADCHAR       ; No, return as character
            INY                    ; Step to next character
            LDA   (OSLPTR),Y
            CMP   #$7C
            BEQ   GSREADCHAR       ; bar-bar expands to bar
            CMP   #$22
            BEQ   GSREADCHAR       ; bar-quote expands to quote
            CMP   #'!'             ; Is it bar-pling?
            BNE   GSREAD5          ; No, check for bar-letter
            INY                    ; Step past it
            LDA   #$80             ; Set bit 7 in accumulator
            BNE   GSREADLP         ; Loop back to check next character(s)

GSREAD5     CMP   #'?'             ; Check for '?'
            BCC   ERRBADSTR        ; <'?', bad character
            BEQ   GSREADDEL        ; bar-query -> DEL
            AND   #$1F             ; Convert bar-letter to control code
            BIT   SETV             ; SEV=control character
            BVS   GSREADOK
GSREADDEL   LDA   #$7F
GSREADCHAR  CLV                    ; CLV=not control character
GSREADOK    INY                    ; Step to next character
            ORA   GSCHAR           ; Add in any bit 7 from |! prefix
            CLC                    ; CLC=not end of string
            RTS
* CC=not end of string
* VS=control character
* VC=not control character


* OSRDROM - Read a byte from sideways ROM
*****************************************
* On entry, Y=ROM to read from
*           (ROMPTR)=>byte to read
* On exit,  A=byte read, X=current ROM, Y=$00
RDROM       LDA   ROMID
            PHA                    ; Save current ROM
            TYA
            TAX                    ; X=ROM to read from
            JSR   ROMSELECT        ; Page in the required ROM
            LDY   #$00             ; NOTE BBC sets Y=0, Master preserves
            LDA   (ROMPTR),Y       ; Read the byte
            PLX

* ROMSELECT - Select a sideways ROM
***********************************
* On entry, X=ROM to select
* On exit,  All registers must be preserved
*
ROMSELECT
* Insert code here for faking sideways ROMs by loading or otherwise
* fetching code to $8000. All registers must be preserved.
            PHP
            CPX   ROMID            ; Speed up by checking if
            BEQ   ROMSELOK         ; already paged in
            PHA
            PHX
            PHY
* LDA $FF
* JSR PR1HEX
            SEI
            TXA                    ; A=ROM to select
            >>>   XF2MAIN,SELECTROM
ROMSELDONE  >>>   ENTAUX
            PLY
            PLX
            PLA
            STX   ROMID            ; Set Current ROM number
ROMSELOK    PLP
            RTS

* Initialize ROMTAB according to user selection in menu
ROMINIT     STZ   MAXROM           ; One sideways ROM only
            >>>   RDMAIN           ; Read main mem
            LDA   USERSEL          ; *TO DO* Should be actual number of ROMs
            >>>   RDAUX            ; Read aux mem

            CMP   #6
            BNE   :X1
            INC   MAXROM
:X1         CMP   #7
            BNE   :X2
            STA   MAXROM
:X2         LDA   #$FF
            STA   ROMID            ; Ensure set to invalid value
EVENT       RTS


**********************************************************
* Interrupt Handlers, MOS redirection vectors etc.
**********************************************************

* Invoked from GSBRK in main memory. On IIgs only.
GSBRKAUX    >>>   IENTAUX          ; IENTAUX does not do CLI
* Continue into IRQBRKHDLR
* TO DO: Check, IENTAUX modifies X

* IRQ/BRK handler
*****************
IRQBRKHDLR  PHA
* Mustn't enable IRQs within the IRQ handler
* Do not use WRTMAIN/WRTAUX macros
            PHX
            CLD
            TSX
            LDA   $103,X           ; Get PSW from stack
            AND   #$10
            BEQ   :IRQ             ; IRQ
            SEC
            LDA   $0104,X
            SBC   #$01
            STA   FAULT+0          ; FAULT=>error block after BRK
            LDA   $0105,X
            SBC   #$00
            STA   FAULT+1
            LDA   ROMID            ; Get current ROM
            STA   BYTEVARBASE+$BA  ; Set ROM at last BRK
            STX   OSXREG           ; Pass stack pointer
            LDX   #$06             ; Service Call 6 = BRK occured
            JSR   SERVICEX
            LDX   BYTEVARBASE+$FC  ; Get current language
            JSR   ROMSELECT        ; Bring it into memory
            PLX
            PLA
            CLI
            JMP   (BRKV)           ; Pass on to BRK handler

:IRQ        PHY
            >>>   XF2MAIN,A2IRQ    ; Bounce to Apple IRQ handler
IRQBRKRET
            >>>   IENTAUX          ; IENTAUX does not do CLI

            PLY

*:S4                                ; TODO: Pass on to IRQ1V
            PLX
            PLA
NULLRTI     RTI

* Default BRK handler
*********************
MOSBRKHDLR  LDX   #<MSGBRK
            LDY   #>MSGBRK
            JSR   OSPRSTR
            JSR   PRERR
*            JSR   OSNEWL
*            JSR   OSNEWL
STOP        JMP   STOP             ; Cannot return from a BRK

MSGBRK      DB    $0D
            ASC   'ERROR: '
            DB    $00

PRERR       LDY   #$01
PRERRLP     LDA   (FAULT),Y
            BEQ   PRERR1
            JSR   OSWRCH
            INY
            BNE   PRERRLP
PRERR1
NULLRTS     RTS


* Default page 2 contents
*************************
DEFVEC      DW    NULLRTS          ; $200 USERV
            DW    MOSBRKHDLR       ; $202 BRKV
            DW    NULLRTI          ; $204 IRQ1V
            DW    NULLRTI          ; $206 IRQ2V
            DW    CLIHND           ; $208 CLIV
            DW    BYTEHND          ; $20A BYTEV
            DW    WORDHND          ; $20C WORDV
            DW    WRCHHND          ; $20E WRCHV
            DW    RDCHHND          ; $210 RDCHV
            DW    FILEHND          ; $212 FILEV
            DW    ARGSHND          ; $214 ARGSV
            DW    BGETHND          ; $216 BGETV
            DW    BPUTHND          ; $218 BPUTV
            DW    GBPBHND          ; $21A GBPBV
            DW    FINDHND          ; $21C FINDV
            DW    FSCHND           ; $21E FSCV
            DW    NULLRTS          ; $220 EVENTV
            DW    NULLRTS          ; $222
            DW    NULLRTS          ; $224
            DW    NULLRTS          ; $226
            DW    NULLRTS          ; $228
            DW    NULLRTS          ; $22A
            DW    NULLRTS          ; $22C
            DW    NULLRTS          ; $22E
            DW    NULLRTS          ; $230 SPARE1V
            DW    NULLRTS          ; $232 SPARE2V
            DW    NULLRTS          ; $234 SPARE3V
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
OSSERV      JMP   SERVICEX         ; FF95 OSSERV
OSCOLD      JMP   NULLRTS          ; FF98 OSCOLD
OSPRSTR     JMP   OUTSTR           ; FF9B OSPRSTR
OSSCANDEC   JMP   SCANDEC          ; FF9E SCANDEC
OSSCANHEX   JMP   SCANHEX          ; FFA1 SCANHEX
OSFFA4      JMP   NULLRTS          ; FFA4 (DISKACC)
OSFFA7      JMP   NULLRTS          ; FFA7 (DISKCCP)
PRHEX
PR1HEX      JMP   OUTHEX           ; FFAA PRHEX
PR2HEX      JMP   OUT2HEX          ; FFAD PR2HEX
OSFFB0      JMP   PRINTDEC         ; FFB0 (USERINT)
OSWRRM      JMP   NULLRTS          ; FFB3 OSWRRM

* COMPULSARY ENTRIES
* ------------------
VECSIZE     DB    ENDVEC-DEFVEC    ; FFB6 VECSIZE Size of vectors
VECBASE     DW    DEFVEC           ; FFB7 VECBASE Base of default vectors
OSRDRM      JMP   RDROM            ; FFB9 OSRDRM  Read byte from paged ROM
OSCHROUT    JMP   OUTCHAR          ; FFBC CHROUT  Send char to VDU driver
OSEVEN      JMP   EVENT            ; FFBF OSEVEN  Signal an event
GSINIT      JMP   GSINTGO          ; FFC2 GSINIT  Init string reading
GSREAD      JMP   GSRDGO           ; FFC5 GSREAD  Parse general string
NVWRCH      JMP   WRCHHND          ; FFC8 NVWRCH  Nonvectored WRCH
NVRDCH      JMP   RDCHHND          ; FFCB NVRDCH  Nonvectored RDCH
OSFIND      JMP   (FINDV)          ; FFCE OSFIND
OSGBPB      JMP   (GBPBV)          ; FFD1 OSGBPB
OSBPUT      JMP   (BPUTV)          ; FFD4 OSBPUT
OSBGET      JMP   (BGETV)          ; FFD7 OSBGET
OSARGS      JMP   (ARGSV)          ; FFDA OSARGS
OSFILE      JMP   (FILEV)          ; FFDD OSFILE
OSRDCH      JMP   (RDCHV)          ; FFE0 OSRDCH
OSASCI      CMP   #$0D             ; FFE3 OSASCI
            BNE   OSWRCH
OSNEWL      LDA   #$0A             ; FFE7 OSNEWL
            JSR   OSWRCH
OSWRCR      LDA   #$0D             ; FFEC OSWRCR
OSWRCH      JMP   (WRCHV)          ; FFEE OSWRCH
OSWORD      JMP   (WORDV)          ; FFF1 OSWORD
OSBYTE      JMP   (BYTEV)          ; FFF4 OSBYTE
OSCLI       JMP   (CLIV)           ; FFF7 OSCLI
NMIVEC      DW    NULLRTI          ; FFFA NMIVEC
RSTVEC      DW    STOP             ; FFFC RSTVEC
IRQVEC

* Assembler doesn't like running up to $FFFF, so we bodge a bit
MOSEND
            ORG   MOSEND-MOSAPI+MOSVEC
            DW    IRQBRKHDLR       ; FFFE IRQVEC
MOSVEND

*           ASC   '**ENDOFCODE**'

