* AUXMEM.OSCLI.S
* (c) BOBBI 2021-2022 GPLv3
*
* Handle OSCLI system calls

* 22-Aug-2021 Uses dispatch table
*             Prepares parameters and hands on to API call
* 24-Aug-2021 Combined *LOAD and *SAVE, full address parsing.
* 02-Sep-2021 *LOAD/*SAVE now uses GSTRANS.
* 12-Sep-2021 *HELP uses subject lookup, *HELP MOS, *HELP HOSTFS.
* 25-Oct-2021 Implemented *BASIC.
* 07-Oct-2022 *CLOSE is a host command, fixed *EXEC.
* 08-Oct-2022 Rewrote *TYPE, *DUMP, *SPOOL, shares code with *EXEC.
*             Sorted command table, added *HELP FILE.
*             Optimised CLILOOK dispatcher.
* 05-Nov-2022 Added ROM, TAPE, TV to command table -> OSBYTE calls.
* 06-Nov-2022 Rewrote *BUILD, avoids using code memory.
*             Moved *KEY into CHARIO.S
* 15-Dec-2022 Added *REMOVE. LDY #0 was missing in CLIUNKNOWN.


* COMMAND TABLE
***************
* Table structure is: { string, byte OR $80, destword-1 } $FF
* Commands are entered with A=command byte with b7=1
*                          b6=0 - Enter with XY=>parameters
*                          b6=1 - Enter with LPTR,Y=>parameters
*                          EQ=no parameter
*                          CS=normal entry
*
CMDTABLE    ASC   'CAT'              ; Must be first command so matches '*.'
            DB    $85
            DW    STARFSC-1          ; CAT    -> FSC 5, XY=>params
            ASC   'BASIC'            ; Bodge to allow *B. priority over *BUILD
            DB    $FF
            DW    STARBASIC-1        ; BASIC  -> (LPTR)=>params
CMDFILE     ASC   'CAT'
            DB    $85
            DW    STARFSC-1          ; CAT    -> FSC 5, XY=>params
            ASC   'BUILD'
            DB    $80 ; $81 ; TO DO
            DW    CMDBUILD-1         ; BUILD  -> XY=>params
            ASC   'CDIR'
            DB    $88
            DW    STARFILE-1         ; CDIR   -> OSFILE 08, CBLK=>filename
            ASC   'CLOSE'
            DB    $FF
            DW    CMDCLOSE-1         ; CLOSE  -> (LPTR)=>params
            ASC   'DELETE'
            DB    $86
            DW    STARFILE-1         ; DELETE -> OSFILE 06, CBLK=>filename
            ASC   'DUMP'
            DB    $80 ; $81 ; TO DO
            DW    CMDDUMP-1          ; DUMP   -> XY=>params
            ASC   'EXEC'
            DB    $80 ; $81 ; TO DO
            DW    CMDEXEC-1          ; EXEC   -> XY=>params
            ASC   'EX'
            DB    $89
            DW    STARFSC-1          ; EX     -> FSC 9, XY=>params
            ASC   'INFO'
            DB    $8A
            DW    STARFSC-1          ; INFO   -> FSC 10, XY=>params
            ASC   'LOAD'
            DB    $81
            DW    STARLOAD-1         ; LOAD   -> OSFILE FF, CBLK=>filename
            ASC   'MKDIR'
            DB    $88
            DW    STARFILE-1         ; MKDIR  -> OSFILE 08, CBLK=>filename
            ASC   'OPT'
            DB    $8B
            DW    STARBYTE-1         ; OPT    -> OSBYTE &8B,X,Y  XY=>params
            ASC   'RUN'
            DB    $84
            DW    STARFSC-1          ; RUN    -> FSC 4, XY=>params
            ASC   'RENAME'
            DB    $8C
            DW    STARFSC-1          ; RENAME -> FSC 12, XY=>params
            ASC   'REMOVE'
            DB    $86
            DW    STARFILECS-1       ; REMOVE -> OSFILE 06, CBLK=>filename
            ASC   'SAVE'
            DB    $81
            DW    STARSAVE-1         ; SAVE   -> OSFILE 00, CBLK=>filename
            ASC   'SPOOL'
            DB    $80 ; $81 ; TO DO
            DW    CMDSPOOL-1         ; SPOOL  -> XY=>params
            ASC   'TYPE'
            DB    $80 ; $81 ; TO DO
            DW    CMDTYPE-1          ; TYPE   -> XY=>params
* Split between HELP lists
            DB    $00
*
CMDMOS      ASC   'BASIC'
            DB    $FF
            DW    STARBASIC-1        ; BASIC  -> (LPTR)=>params
            ASC   'CODE'
            DB    $88
            DW    STARBYTE-1         ; CODE   -> OSBYTE &88,X,Y  XY=>params
            ASC   'ECHO'
            DB    $FF
            DW    CMDECHO-1          ; ECHO   -> (LPTR)=>params
            ASC   'FX'
            DB    $FF
            DW    STARFX-1           ; FX     -> OSBYTE A,X,Y    (LPTR)=>params
            ASC   'FAST'
            DB    $FF
            DW    CMDFAST-1          ; FAST   -> (LPTR)=>params
            ASC   'HELP'
            DB    $80
            DW    STARHELP-1         ; HELP   -> XY=>params
            ASC   'KEY'
            DB    $FF
            DW    STARKEY-1          ; KEY    -> (LPTR)=>params
            ASC   'LINE'
            DB    $80
            DW    CMDLINE-1          ; LINE   -> XY=>params
            ASC   'QUIT'
            DB    $FF
            DW    STARQUIT-1         ; QUIT   -> (LPTR)=>params
            ASC   'ROM'
            DB    $8D
            DW    STARBYTE-1         ; ROM    -> OSBYTE &8D,X,Y  XY=>params
            ASC   'SHOW'
            DB    $FF
            DW    STARSHOW-1         ; SHOW   -> (LPTR)=>params
            ASC   'SLOW'
            DB    $FF
            DW    CMDSLOW-1          ; SLOW   -> (LPTR)=>params
            ASC   'TAPE'
            DB    $8C
            DW    STARBYTE-1         ; TAPE   -> OSBYTE &8C,X,Y  XY=>params
            ASC   'TV'
            DB    $90
            DW    STARBYTE-1         ; TV     -> OSBYTE &90,X,Y  XY=>params
* Table terminator
            DB    $FF


* *HELP TABLE
*************
HLPTABLE    ASC   'MOS'
            DB    $FF
            DW    HELPMOS-1          ; *HELP MOS
            ASC   'FILE'
            DB    $FF
            DW    HELPFILE-1         ; *HELP FILE
            ASC   'HOSTFS'
            DB    $FF
            DW    HELPHOSTFS-1       ; *HELP HOSTFS
            DB    $FF


* Command table lookup
* ====================
* On entry, (OSLPTR)=>command string
*           XY=>command table
* On exit,  A=0  done, command called
*           A<>0 no match
*           (OSLPTR) preserved if no match
*           X,Y corrupted
*
* Search command table
CLILOOKUP   STX   OSTEXT+0           ; Start of command table
            STY   OSTEXT+1
            LDX   #0                 ; (ZP,X)=>command table
CLILP4      LDY   #0                 ; Start of command line
CLILP5      LDA   (OSTEXT,X)
            BMI   CLIMATCH           ; End of table string
            EOR   (OSLPTR),Y
            AND   #$DF               ; Force upper case match
            BNE   CLINOMATCH
            JSR   CLISTEP            ; Step to next table char
            INY                      ; Step to next command char
            BNE   CLILP5             ; Loop to check

CLINOMATCH  LDA   (OSLPTR),Y
            CMP   #'.'               ; Abbreviation?
            BEQ   CLIDOT
CLINEXT     JSR   CLISTEP            ; No match, step to next entry
            BPL   CLINEXT
CLINEXT2    JSR   CLISTEP            ; Step past byte, address
            JSR   CLISTEP
            JSR   CLISTEP
            BNE   CLINEXT3
            JSR   CLISTEP
CLINEXT3    BPL   CLILP4             ; Loop to check next
            RTS                      ; Exit, A>$7F

CLIDOT      LDA   (OSTEXT,X)
            BMI   CLINEXT2           ; Dot after full word, no match
CLIDOT2     JSR   CLISTEP            ; Step to command address
            BPL   CLIDOT2
            INY                      ; Step past dot
            BNE   CLIMATCH2          ; Jump to this command

CLIMATCH    LDA   (OSLPTR),Y
            CMP   #'.'
            BEQ   CLINEXT            ; Longer abbreviation, eg 'CAT.'
            CMP   #'A'
            BCS   CLINEXT            ; More letters, eg 'HELPER'
CLIMATCH2   JSR   CLIMATCH3          ; Call the routine
            LDA   #0
            RTS                      ; Return A=0 to claim

CLIMATCH3   JSR   SKIPSPC            ; (OSLPTR),Y=>parameters
            SEC                      ; Enter with CS pre-set
            PHP                      ; Save EQ=end of line
            LDA   (OSTEXT,X)         ; Command byte
            STA   OSTEMP
            JSR   CLISTEP            ; Address low byte
            PHA
            JSR   CLISTEP            ; Address high byte
            TAX                      ; X=high
            PLA                      ; A=low
            PLP                      ; EQ=end of line
            PHX                      ; SP->high
            PHA                      ; SP->low, high
            PHP                      ; SP->flg, low, high
            BIT OSTEMP               ; Test command parameter
            BVS CLICALL              ; If b6=1 don't convert LPTR
            JSR   LPTRtoXY           ; XY=>parameters
CLICALL     LDA   OSTEMP             ; A=command parameter
            PLP                      ; EQ=no parameters
            RTS                      ; Call command routine

CLISTEP     INC   OSTEXT+0,X         ; Point to next table byte
            BNE   CLISTEP2
            INC   OSTEXT+1,X
CLISTEP2    LDA   (OSTEXT,X)         ; Get next byte
            RTS


* OSCLI HANDLER
***************
* On entry, XY=>command string
* On exit,  AXY corrupted or error generated
*
CLIHND      JSR   XYtoLPTR           ; LPTR=>command line
CLILP1      LDA   (OSLPTR),Y
            CMP   #$0D
            BEQ   CLI2
            INY
            BNE   CLILP1
CLIEXIT1    RTS                      ; No terminating <cr>
CLI2        LDY   #$FF
CLILP2      JSR   SKIPSPC1           ; Skip leading spaces
            CMP   #'*'               ; Skip leading stars
            BEQ   CLILP2
            CMP   #$0D
            BEQ   CLIEXIT1           ; Null string
            CMP   #'|'
            BEQ   CLIEXIT1           ; Comment
            CMP   #'/'
            BEQ   CLISLASH
            JSR   LPTRtoXY           ; Add Y to LPTR
            JSR   XYtoLPTR           ; LPTR=>start of actual command
            LDX   #<CMDTABLE         ; XY=>command table
            LDY   #>CMDTABLE
            JSR   CLILOOKUP          ; Look for command
            BNE   CLIUNKNOWN         ; No match
CLIDONE     RTS

CLISLASH    JSR   SKIPSPC1
            BEQ   CLIDONE            ; */<cr>
            LDA   #$02
            BNE   STARFSC2           ; FSC 2 = */filename
*
CLIUNKNOWN  LDY   #$00               ; Point to start of command
            LDX   #$04               ; Service 4 = Unknown command
            JSR   SERVICEX           ; Offer to sideways ROM(s)
            BEQ   CLIDONE            ; Claimed
            LDA   #$03               ; FSC 3 = Unknown command
STARFSC2    PHA
            JSR   LPTRtoXY           ; XY=>command
            PLA
STARFSC     AND   #$7F               ; A=command, XY=>parameters
            JSR   CALLFSCV           ; Hand on to filing system
            TAX
            BEQ   CLIDONE            ; A=0, FSC call implemented
ERRBADCMD   BRK
            DB    $FE
            ASC   'Bad command'
ERRBADNUM   BRK
            DB    $FC
            ASC   'Bad number'
ERRBADADD   BRK
            DB    $FC
            ASC   'Bad address'
            BRK


* MOS COMMANDS
**************

* *FX num(,num(,num))
* -------------------
STARFX      JSR   SCANDEC
            BRA   STARBYTE1

* Commands passed to OSBYTE
* -------------------------
STARBYTE    JSR   XYtoLPTR
STARBYTE1   STA   OSAREG             ; Save OSBYTE number
            LDA   #$00               ; Default X and Y
            STA   OSXREG
            STA   OSYREG
            JSR   SKIPCOMMA          ; Step past any comma/spaces
            BEQ   STARBYTE2          ; End of line, do it
            JSR   SCANDEC            ; Scan for X param
            STA   OSXREG             ; Store it
            JSR   SKIPCOMMA          ; Step past any comma/spaces
            BEQ   STARBYTE2          ; End of line, do it
            JSR   SCANDEC            ; Scan for Y param
            STA   OSYREG             ; Store it
            JSR   SKIPSPC
            BNE   ERRBADCMD          ; More params, error
STARBYTE2   LDY   OSYREG
            LDX   OSXREG
            LDA   OSAREG
            JSR   OSBYTE
            BVS   ERRBADCMD
            RTS

* Line scanning
* -------------
* Scan decimal number
*********************
* On entry, (OSLPTR),Y=>first character
* On exit,  A         =8-bit decimal value
*           X         =preserved
*           (OSLPTR),Y=>skipped spaces after number
*           
SCANDEC
*           JSR   SKIPSPC
            JSR   SCANDIGIT          ; Check first digit
            BCS   ERRBADNUM          ; Doesn't start with a digit
SCANDECLP   STA   OSTEMP             ; Store as current number
            JSR   SCANDIGIT          ; Check next digit
            BCS   SCANDECOK          ; No more digits   
            PHA
            LDA   OSTEMP
            CMP   #26
            BCS   ERRBADNUM          ; num>25, num*25>255
            ASL   A                  ; num*2
            ASL   A                  ; num*4
            ADC   OSTEMP             ; num*4+num = num*5
            ASL   A                  ; num*10
            STA   OSTEMP
            PLA
            ADC   OSTEMP             ; num=num*10+digit
            BCC   SCANDECLP
            BCS   ERRBADNUM          ; Overflowed

SCANDECOK   JSR   SKIPSPC            ; Ensure trailing spaces skipped
            LDA   OSTEMP             ; Return A=number
SCANDIG2    SEC
            RTS

SCANDIGIT   LDA   (OSLPTR),Y
            CMP   #'0'
            BCC   SCANDIG2           ; <'0'
            CMP   #'9'+1
            BCS   SCANDIG2           ; >'9'
            INY
            AND   #$0F
            RTS

HEXDIGIT    JSR   SCANDIGIT
            BCC   HEXDIGIT2          ; Decimal digit
            AND   #$DF
            CMP   #'A'
            BCC   SCANDIG2           ; Bad hex character
            CMP   #'G'
            BCS   HEXDIGIT2          ; Bad hex character
            SBC   #$36               ; Convert 'A'-'F' to $0A-$0F
            INY
            CLC
HEXDIGIT2   RTS

* Scan hex address
******************
* On entry, (OSLPTR),Y=>first character
*           $0200,X = 4-byte accumulator 
* On exit,  $0200,X = 4-byte accumulator 
*           (OSLPTR),Y=>skipped spaces after number
*           X         =preserved
*           A         =next character
*           EQ        =end of line, no more parameters
*
SCANHEX     JSR   HEXDIGIT           ; Get first digit
            BCS   ERRBADADD1         ; Not a hex character
            STA   $200,X             ; Store first digit
            LDA   #0
            STA   $201,X             ; Clear rest of accumulator
            STA   $202,X
            STA   $203,X
SCANHEXLP1  JSR   HEXDIGIT           ; Get next digit
            BCS   SKIPSPC            ; Done, exit by skipping spaces
            STY   OSTEMP
            LDY   #4                 ; Four bits to rotate
SCANHEXLP2  ASL   $200,X             ; Multiple accumulator by 16
            ROL   $201,X
            ROL   $202,X
            ROL   $203,X
            BCS   ERRBADADD1         ; Overflowed
            DEY
            BNE   SCANHEXLP2         ; Loop for four bits
            ORA   $200,X             ; Add in current digit
            STA   $200,X
            LDY   OSTEMP             ; Get Y back
            BNE   SCANHEXLP1
ERRBADADD1  JMP   ERRBADADD

SKIPCOMMA   LDA   (OSLPTR),Y
            CMP   #$2C
            BNE   SKIPSPC            ; Drop through
*
* Skip spaces
SKIPSPC1    INY                      ; Step past a character
SKIPSPC     LDA   (OSLPTR),Y
            CMP   #' '
            BEQ   SKIPSPC1
            CMP   #$0D               ; Return EQ=<cr>
            RTS

* Skip a string
SKIPWORD    CLC
            JSR   GSINIT
SKIPWORDLP  JSR   GSREAD
            BCC   SKIPWORDLP
            RTS

* Convert (LPTR),Y to XY
LPTRtoXY    CLC
            TYA
            ADC   OSLPTR+0
            TAX
            LDA   #0
            ADC   OSLPTR+1
            TAY
            RTS

* Convert XY to (LPTR),Y
XYtoLPTR    STX   OSLPTR+0
            STY   OSLPTR+1
            LDY   #0
STARHELP9   RTS

* *BASIC
* ------
STARBASIC   LDX   MAXROM
:BASICLP    JSR   ROMSELECT          ; Step through ROMs
            BIT   $8006
            BPL   :BASICGO           ; No service, must be BASIC
            DEX
            BPL   :BASICLP
            JMP   ERRBADCMD          ; No BASIC, give an error
:BASICGO    JMP   BYTE8E

* *ECHO <GSTRANS string>
* ----------------------
CMDECHO     SEC
ECHO0       JSR   GSINIT
:ECHOLP1    JSR   GSREAD
            BCS   STARHELP9
            JSR   OSWRCH
            JMP   :ECHOLP1

* *HELP (<options>)
* -----------------
STARHELP    JSR   XYtoLPTR           ; Update OSLPTR=>parameters
            JSR   PRHELLO            ; Unify version message
            LDX   #<HLPTABLE         ; XY=>command table
            LDY   #>HLPTABLE
            JSR   CLILOOKUP          ; Look for *HELP subject at OSLPTR
            BEQ   STARHELP9          ; Matched
            LDA   $8006              ; Does ROM have service entry?
            BMI   STARHELP6          ; Yes, skip to send service call
            JSR   OSNEWL
            LDX   #$09               ; Language name
            LDY   #$80
            JSR   OSPRSTR
            JSR   OSNEWL
STARHELP6   LDY   #0                 ; (OSLPTR),Y=>parameters
            LDX   #9
            JMP   SERVICEX           ; Pass to sideways ROM(s)

* Print *HELP text
HELPHOSTFS  LDX   #<FSCCOMMAND       ; *HELP HOSTFS
            LDY   #>FSCCOMMAND
            BNE   HELPLIST
HELPFILE    LDX   #<CMDFILE          ; *HELP FILE
            LDY   #>CMDFILE
            BNE   HELPLIST
HELPMOS     LDX   #<CMDMOS           ; *HELP MOS
            LDY   #>CMDMOS
*
HELPLIST    STX   OSTEXT+0           ; Start of command table
            STY   OSTEXT+1
            LDX   #0
HELPLP1     LDA   #32
            JSR   OSWRCH
            JSR   OSWRCH
HELPLP2     LDY   #10
HELPLP3     LDA   (OSTEXT,X)
            BMI   HELPLP4
            JSR   OSWRCH
            DEY
            JSR   CLISTEP
            BPL   HELPLP3
HELPLP4     LDA   #32
            JSR   OSWRCH
            DEY
            BNE   HELPLP4
            JSR   CLISTEP
            JSR   CLISTEP
            JSR   CLISTEP
            BEQ   STARHELP4
            BPL   HELPLP2
STARHELP4   LDA   #$08
            JSR   OSWRCH
            JSR   OSWRCH
            JMP   FORCENL

* *QUIT command
* -------------
STARQUIT    >>>   XF2MAIN,QUIT


* FILING COMMANDS
* ***************

* *LOAD and *SAVE
* ---------------
STARLOAD    LDA   #$7E               ; Set here to A=$7E -> $FF, LOAD
STARSAVE    EOR   #$81               ; Entered with A=$81 -> $00, SAVE
* Can tweek this after HOSTFS command table updated
            PHA
            JSR   XYtoLPTR           ; Update OSLPTR=>filename
            JSR   SKIPWORD           ; Step past filename
            BNE   STARLDSV3          ; filename followed by addr
*
* filename followed by no address, must be *LOAD name
STARLDSV1   LDA   #$FF               ; $FF=load to file's address
STARLOAD2   STA   OSFILECB+6
            PLA
            BEQ   ERRBADADD2         ; *save name <no addr>
            LDA   #$7F               ; Will become A=$FF
            JMP   STARLDSVGO         ; Do the load

* At least one address specified
STARLDSV3   LDX   #OSFILECB+2-$200   ; X=>load
            JSR   SCANHEX
            BNE   STARSAVE3          ; Another address
            LDA   #$00               ; $00=load to supplied address
            BEQ   STARLOAD2          ; Only one address, must be *LOAD

* More than one address, must be *SAVE
STARSAVE3   PLA
            BNE   ERRBADADD2         ; Can't be *LOAD
            LDX   #3
STARSAVE4   LDA   OSFILECB+2,X       ; Get load
            STA   OSFILECB+6,X       ; copy to exec
            STA   OSFILECB+10,X      ; and to start
            DEX
            BPL   STARSAVE4
            LDA   (OSLPTR),Y
            CMP   #'+'
            PHP
            BNE   STARSAVE5          ; Not start+length
            JSR   SKIPSPC1           ; Step past '+' and spaces
STARSAVE5   LDX   #OSFILECB+14-$200
            JSR   SCANHEX            ; Get end or length
            PLP
            BNE   STARSAVE7          ; Not +length
            LDX   #0
            CLC
STARSAVE6   LDA   OSFILECB+10,X      ; end=start+length
            ADC   OSFILECB+14,X
            STA   OSFILECB+14,X
            INX
            TXA
            AND   #3
            BNE   STARSAVE6
* load =start
* exec =start
* start=start
* end  =end or start+length
STARSAVE7   JSR   SKIPSPC
            BEQ   STARSAVE10         ; No more, do it
            LDX   #OSFILECB+6-$200
            JSR   SCANHEX            ; Get exec
            BEQ   STARSAVE10         ; No more, do it
            LDX   #OSFILECB+2-$200
            JSR   SCANHEX            ; Get load
            BEQ   STARSAVE10         ; No more, do it
ERRBADADD2  JMP   ERRBADADD          ; Too many parameters

STARSAVE10  LDA   #$80               ; Will become $00 - SAVE
STARLDSVGO  LDX   OSLPTR+0
            LDY   OSLPTR+1           ; Continue through...
*

* Commands passed to OSFILE
* -------------------------
STARFILE    CLC                      ; CLC=Error if NotFound
STARFILECS  EOR   #$80               ; SEC=Ignore NotFound
            PHP
            STX   OSFILECB+0
            STY   OSFILECB+1
            LDX   #<OSFILECB
            LDY   #>OSFILECB
            JSR   OSFILE
            PLP
            TAX
            BCS   STARDONE           ; Ignore NotFound
            BNE   STARDONE
            JMP   ERRNOTFND

* *CLOSE
* ------
CMDCLOSE     LDA   #$00
             TAY
             JSR   OSFIND            ; Close all files
             STA   FXEXEC            ; Ensure Spool/Exec handles cleared
             STA   FXSPOOL
STARDONE     RTS

* *TYPE <afsp>
* ------------
* XY=>parameters string, EQ=no parameters
*
CMDTYPE      BEQ   ERRTYPE           ; No filename
             JSR   OPENINFILE        ; Try to open file
:LOOP        JSR   OSBGET            ; Read a byte
             BCS   TYPDMPEND         ; EOF
             CMP   #$0A
             BEQ   :LOOP             ; Ignore <lf>
             TAX                     ; Remember last character
             JSR   OSASCI            ; Print the character
             BIT   ESCFLAG
             BPL   :LOOP             ; No Escape, keep going
TYPEESC      JSR   TYPCLOSE
ERRESCAPE    BRK
             DB    $11
             ASC   'Escape'
             BRK
TYPDMPEND    CPX   #$0D
             BEQ   TYPCLOSE
             JSR   OSNEWL
TYPCLOSE     LDA   #$00
             JMP   OSFIND            ; Close file
ERRTYPE      BRK
             DB    $DC
             ASC   'Syntax: TYPE <afsp>'
ERRDUMP      BRK
             DB    $DC
             ASC   'Syntax: DUMP <afsp>'
             BRK

* *DUMP <afsp>
* ------------
* XY=>parameters string, EQ=no parameters
*
CMDDUMP      BEQ   ERRDUMP           ; No filename
             JSR   OPENINFILE        ; Try to open file
             STZ   OSNUM+0           ; Offset = zero
             STZ   OSNUM+1
:LOOP1       BIT   ESCFLAG
             BMI   TYPEESC           ; Escape pressed
             PHY                     ; Save handle
             TYA
             TAX                     ; X=handle
             LDA   #$7F
             JSR   OSBYTE            ; Read EOF
             PLY                     ; Get handle back
             TXA
             BNE   TYPCLOSE          ; At EOF
             LDA   OSNUM+1           ; Print file offset
             JSR   PRHEX
             LDA   OSNUM+0
             JSR   PRHEX
             JSR   PRSPACE
             LDA   #8                ; 8 bytes to dump
             STA   OSNUM+2
             TSX                     ; Reserve bytes on stack
             TXA
             SEC
             SBC   OSNUM+2
             TAX
             TXS                     ; X=>space on stack
:LOOP2       JSR   OSBGET            ; Read a byte
             BCS   :DUMPEOF
             STA   $0101,X           ; Store on stack
             JSR   PRHEX             ; Print as hex
             JSR   PRSPACE
             INX
             DEC   OSNUM+2
             BNE   :LOOP2            ; Loop to do 8 bytes
             CLC                     ; CLC=Not EOF
             BCC   :DUMPCHRS         ; Jump to display characters
:DUMPEOF     LDA   #'*'              ; EOF met, pad with '**'
             JSR   OSWRCH
             JSR   OSWRCH
             JSR   PRSPACE
             LDA   #$00
             STA   $0101,X
             INX
             DEC   OSNUM+2
             BNE   :DUMPEOF          ; Loop to do 8 bytes
             SEC                     ; SEC=EOF
:DUMPCHRS    LDX   #8                ; 8 bytes to print
:LOOP4       PLA                     ; Get character
             PHP                     ; Save EOF flag
             CMP   #$7F
             BEQ   :DUMPDOT
             CMP   #' '
             BCS   :DUMPCHR
:DUMPDOT     LDA   #'.'
:DUMPCHR     JSR   OSWRCH            ; Print character
             INC   OSNUM+0           ; Increment offset
             BNE   :DUMPNXT
             INC   OSNUM+1
:DUMPNXT     PLP                     ; Get EOF flag back
             DEX
             BNE   :LOOP4            ; Loop to do 8 bytes
             PHP
             JSR   OSNEWL
             PLP
             BCC   :LOOP1
             JMP   TYPCLOSE          ; Close and finish

* *BUILD <fsp>
* ------------
* XY=>parameters string, EQ=no parameters
*
BUILDLINE    EQU   $0700
ERRBUILD     BRK
             DB    $DC
             ASC   'Syntax: BUILD <fsp>'
             BRK
BUILDBUF     DW    BUILDLINE            ; Control block to read a line
             DB    $80                  ; 128 characters max
             DB    32                   ; Min char
             DB    126                  ; Max char
             
CMDBUILD     BEQ   ERRBUILD             ; No filename
             LDA   #$80                 ; A=OPENOUT, for writing
             JSR   OPENAFILE            ; Try to open file
             PHA
             LDA   #0                   ; Line number
             PHA
             PHA
:BUILDLP1    PLA                        ; Get line number
             PLY
             CLC
             SED                        ; Use BCD arithmetic
             ADC   #$01                 ; Add one to line number
             BCC   :BUILD2
             INY
:BUILD2      CLD
             PHY
             PHA
             TAX
             JSR   PR2HEX               ; Print line number
             JSR   PRSPACE              ; Followed by a space
             LDX   #<BUILDBUF           ; XY -> control block
             LDY   #>BUILDBUF
             LDA   #$00
             JSR   OSWORD               ; OSWORD &00 input line
             BCS   :BUILDDONE
             TSX
             LDY   $103,X               ; Get handle
             LDX   #$00
:BUILDLP2    LDA   BUILDLINE,X          ; Get char from line
             JSR   OSBPUT               ; Write it to the file
             INX
             CMP   #$0D
             BNE   :BUILDLP2            ; Loop until terminating CR
             BEQ   :BUILDLP1            ; Go for another line
:BUILDDONE   LDA   #$7C
             JSR   OSBYTE               ; Clear Escape state
             PLA                        ; Drop line number
             PLA
             PLY                        ; Get handle
             LDA   #$00
             JSR   OSFIND               ; Close the file
             JMP   OSNEWL               ; Print newline and exit

* *SPOOL (<fsp>)
* ---------------
* XY=>parameters string, EQ=no parameters
*
CMDSPOOL     PHP                        ; Save EQ/NE
             PHY                        ; Save Y
             LDY   FXSPOOL              ; Get SPOOL handle
             BEQ   :SPOOL1              ; Wasn't open, skip closing
             LDA   #$00                 ; A=CLOSE
             STA   FXSPOOL              ; Clear SPOOL handle
             JSR   OSFIND               ; Close SPOOL file
:SPOOL1      PLY                        ; Get Y back, XY=>filename
             PLP                        ; Get NE=filename, EQ=no filename
             BEQ   :DONE                ; No filename, all done
             LDA   #$80                 ; A=OPENOUT, for writing
             JSR   OPENAFILE            ; Try to open file
             STA   FXSPOOL              ; Store SPOOL handle
:DONE        RTS

* *EXEC (<afsp>)
* --------------
* XY=>parameters string, EQ=no parameters
*
CMDEXEC0     LDA   #$00                 ; Close EXEC file
CMDEXEC      PHP                        ; Save EQ/NE
             PHY                        ; Save Y
             LDY   FXEXEC		; Get EXEC handle
             BEQ   :EXEC1               ; Wasn't open, skip closing it
             LDA   #$00                 ; A=CLOSE
             STA   FXEXEC               ; Clear EXEC handle
             JSR   OSFIND               ; Close EXEC file
:EXEC1       PLY                        ; Get Y back, XY=>filename
             PLP                        ; Get NE=filename, EQ=no filename
             BEQ   EXECDONE             ; No filename, all done
             JSR   OPENINFILE           ; Try to open file
             STA   FXEXEC               ; Store EXEC file handle
EXECDONE     RTS

OPENINFILE   LDA   #$40                 ; Open for input
OPENAFILE    JSR   OSFIND               ; Try to open file
             TAY                        ; Was file opened?
             BNE   EXECDONE             ; File opened
EXECNOTFND   JMP   ERRNOTFND            ; File not found


* ZIP SPEED COMMANDS
* ==================

* Handle *FAST command
* --------------------
* Turn Apple II accelerators on
CMDFAST      LDA   #$80                      ; Apple IIgs
             TSB   CYAREG
             STA   GSSPEED
             JSR   ZIPUNLOCK                 ; ZipChip
             JSR   ZIPDETECT
             BCC   :NOZIP
             STA   $C05B                     ; Enable
             BCS   ZIPLOCK
:NOZIP       STA   $C05C                     ; Ultrawarp fast
             RTS

* Handle *SLOW command
* --------------------
* Turn Apple II accelerators off
CMDSLOW      LDA   #$80                      ; Apple IIgs
             TRB   CYAREG
             STZ   GSSPEED
             JSR   ZIPUNLOCK                 ; ZipChip
             JSR   ZIPDETECT
             BCC   :NOZIP
             STZ   $C05A                     ; Disable
             BCS   ZIPLOCK
:NOZIP       STA   $C05D                     ; Ultrawarp slow
             RTS

* Detect a ZipChip
* Set carry is ZipChip found
DETECTZIP
ZIPDETECT    LDA   $C05C                     ; ZipChip manual p25
             EOR   #$FF
             STA   $C05C
             CMP   $C05C
             BNE   :NOZIP
             EOR   #$FF
             STA   $C05C
             CMP   $C05C
             BEQ   :ZIPOK                    ; BEQ already has SEC
*             BNE   :NOZIP
*             SEC
*             RTS
:NOZIP       CLC
:ZIPOK       RTS
           
* Unlock ZipChip registers
UNLOCKZIP
ZIPUNLOCK    PHP
             SEI                             ; Timing sensitive
             LDA   #$5A
             STA   $C05A
             STA   $C05A
             STA   $C05A
             STA   $C05A
             PLP
             RTS

* Lock ZipChip registers
LOCKZIP
ZIPLOCK      LDA   #$A5
             STA   $C05A
             RTS

