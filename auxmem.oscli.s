* AUXMEM.OSCLI.S
* (c) BOBBI 2021 GPLv3
*
* Handle OSCLI system calls

* 22-Aug-2021 Uses dispatch table
*             Prepares parameters and hands on to API call
* 24-Aug-2021 Combined *LOAD and *SAVE, full address parsing.
* 02-Sep-2021 *LOAD/*SAVE now uses GSTRANS.
* 12-Sep-2021 *HELP uses subject lookup, *HELP MOS, *HELP HOSTFS.
* 25-Oct-2021 Implemented *BASIC.


* COMMAND TABLE
***************
* Table structure is: { string, byte OR $80, destword-1 } $00
* fsc commands
CMDTABLE    ASC   'CAT'              ; Must be first command so matches '*.'
            DB    $85
            DW    STARFSC-1          ; CAT    -> FSC 5, XY=>params
            ASC   'RUN'
            DB    $84
            DW    STARFSC-1          ; RUN    -> FSC 4, XY=>params
            ASC   'EX'
            DB    $89
            DW    STARFSC-1          ; EX     -> FSC 9, XY=>params
            ASC   'INFO'
            DB    $8A
            DW    STARFSC-1          ; INFO   -> FSC 10, XY=>params
            ASC   'RENAME'
            DB    $8C
            DW    STARFSC-1          ; RENAME -> FSC 12, XY=>params
* osfile commands
            ASC   'LOAD'
            DB    $FF
            DW    STARLOAD-1         ; LOAD   -> OSFILE FF, CBLK=>filename
            ASC   'SAVE'
            DB    $FF
            DW    STARSAVE-1         ; SAVE   -> OSFILE 00, CBLK=>filename
            ASC   'DELETE'
            DB    $86
            DW    STARFILE-1         ; DELETE -> OSFILE 06, CBLK=>filename
            ASC   'MKDIR'
            DB    $88
            DW    STARFILE-1         ; MKDIR  -> OSFILE 08, CBLK=>filename
            ASC   'CDIR'
            DB    $88
            DW    STARFILE-1         ; CDIR   -> OSFILE 08, CBLK=>filename
* osbyte commands
            ASC   'FX'
            DB    $80
            DW    STARFX-1           ; FX     -> OSBYTE A,X,Y    (LPTR)=>params
            ASC   'OPT'
            DB    $8B
            DW    STARBYTE-1         ; OPT    -> OSBYTE &8B,X,Y  XY=>params
* others
            ASC   'QUIT'
            DB    $80
            DW    STARQUIT-1         ; QUIT   -> (LPTR)=>params
            ASC   'HELP'
            DB    $FF
            DW    STARHELP-1         ; HELP   -> XY=>params
            ASC   'BASIC'
            DB    $80
            DW    STARBASIC-1        ; BASIC  -> (LPTR)=>params
            ASC   'KEY'
            DB    $80
            DW    STARKEY-1          ; KEY    -> (LPTR)=>params
            ASC   'ECHO'
            DB    $80
            DW    ECHO-1             ; ECHO   -> (LPTR)=>params
            ASC   'TYPE'
            DB    $80
            DW    TYPE-1             ; TYPE   -> (LPTR)=>params
            ASC   'DUMP'
            DB    $80
            DW    DUMP-1             ; DUMP   -> (LPTR)=>params
            ASC   'SPOOL'
            DB    $80
            DW    SPOOL-1            ; EXEC   -> (LPTR)=>params
            ASC   'EXEC'
            DB    $80
            DW    EXEC-1             ; EXEC   -> (LPTR)=>params
            ASC   'FAST'
            DB    $80
            DW    FAST-1             ; FAST   -> (LPTR)=>params
            ASC   'SLOW'
            DB    $80
            DW    SLOW-1             ; SLOW   -> (LPTR)=>params
* BUILD <file>
* terminator
            DB    $FF

* *HELP TABLE
*************
HLPTABLE    ASC   'MOS'
            DB    $80
            DW    HELPMOS-1          ; *HELP MOS
            ASC   'HOSTFS'
            DB    $80
            DW    HELPHOSTFS-1       ; *HELP HOSTFS
            DB    $FF


* Command table lookup
* On entry, (OSLPTR)=>command string
*           XY=>command table
* On exit,  A=0  done, command called
*           A<>0 no match
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
            BPL   CLILP4             ; Loop to check next
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
            LDA   (OSTEXT,X)         ; Command byte
            PHA
            JSR   CLISTEP            ; Address low byte
            STA   OSTEMP
            JSR   CLISTEP            ; Address high byte
            PLX                      ; Get command byte
            PHA                      ; Push address high
            LDA   OSTEMP
            PHA                      ; Push address low
            TXA                      ; Command byte
            PHA
            ASL   A                  ; Drop bit 7
            BEQ   CLICALL            ; If $80 don't convert LPTR
            JSR   LPTRtoXY           ; XY=>parameters
CLICALL     PLA                      ; A=command parameter
            RTS                      ; Call command routine

CLISTEP     INC   OSTEXT+0,X         ; Point to next table byte
            BNE   CLISTEP2
            INC   OSTEXT+1,X
CLISTEP2    LDA   (OSTEXT,X)         ; Get next byte
            RTS


* OSCLI HANDLER
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

CLIUNKNOWN  LDA   #$04
            JSR   SERVICE            ; Offer to sideways ROM(s)
            BEQ   CLIDONE            ; Claimed
            LDA   #$03               ; FSC 3 = unknown command
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


* *FX num(,num(,num))
*********************
STARFX      JSR   SCANDEC
            BRA   STARBYTE1

* Commands passed to OSBYTE
***************************
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

* Scan decimal number
SCANDEC     JSR   SKIPSPC
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

SCANDECOK   LDA   OSTEMP             ; Return A=number
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
* (OSLPTR),Y=>first character
* $200,X    = 4-byte accumulator 
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
            RTS

* Print *HELP text
STARHELP    JSR   XYtoLPTR           ; (OSLPTR),Y=>parameters
            JSR   PRHELLO            ; Unify version message
            LDX   #<HLPTABLE         ; XY=>command table
            LDY   #>HLPTABLE
            JSR   CLILOOKUP          ; Look for *HELP subject
            LDA   $8006              ; Does ROM have service entry?
            BMI   STARHELP6          ; Yes, send service call
            JSR   OSNEWL
            LDA   #$09               ; Language name
            LDY   #$80               ; *TO DO* make this and BYTE8E
            JSR   PRSTR              ;  use same code
            JSR   OSNEWL
STARHELP6   LDY   #0                 ; (OSLPTR),Y=>parameters
            LDA   #9
            JMP   SERVICE            ; Pass to sideways ROM(s)


HELPHOSTFS  LDX   #<FSCCOMMAND       ; *HELP HOSTFS
            LDY   #>FSCCOMMAND
            BNE   HELPLIST
HELPMOS     LDX   #<CMDTABLE         ; *HELP MOS
            LDY   #>CMDTABLE

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
            BPL   HELPLP2
STARHELP4   LDA   #$08
            JSR   OSWRCH
            JSR   OSWRCH
            JMP   FORCENL


* Handle *QUIT command
STARQUIT    >>>   XF2MAIN,QUIT


STARSAVE    LDA   #$00               ; Set A=0 - SAVE
STARLOAD    PHA                      ; Entered with A=$FF - LOAD
            JSR   XYtoLPTR           ; OSLPTR=>filename
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
***************************
STARFILE    EOR   #$80
            STX   OSFILECB+0
            STY   OSFILECB+1
            LDX   #<OSFILECB
            LDY   #>OSFILECB
            JSR   OSFILE
            TAX
            BNE   STARDONE
            JMP   ERRNOTFND

STARKEY
STARDONE    RTS


* *BASIC
********
STARBASIC   LDX   MAXROM
:BASICLP    JSR   ROMSELECT
            BIT   $8006
            BPL   :BASICGO           ; No service, must be BASIC
            DEX
            BPL   :BASICLP
            JMP   ERRBADCMD          ; No BASIC, give an error
:BASICGO    JMP   BYTE8E


* *ECHO <GSTRANS string>
************************
ECHO        SEC
ECHO0       JSR   GSINIT
ECHOLP1     JSR   GSREAD
            BCS   STARDONE
            JSR   OSWRCH
            JMP   ECHOLP1


* Handle *TYPE command
* LPTR=>parameters string
*
TYPE         JSR   LPTRtoXY
             PHX
             PHY
             JSR   XYtoLPTR
             JSR   PARSLPTR                  ; Just for error handling
             BEQ   :SYNTAX                   ; No filename
             PLY
             PLX
             LDA   #$40                      ; Open for input
             JSR   FINDHND                   ; Try to open file
             CMP   #$00                      ; Was file opened?
             BEQ   :NOTFOUND
             TAY                             ; File handle in Y
:L1          JSR   BGETHND                   ; Read a byte
             BCS   :CLOSE                    ; EOF
             CMP   #$0A                      ; Don't print LF
             BEQ   :S1
             JSR   OSASCI                    ; Print the character
:S1          LDA   ESCFLAG
             BMI   :ESC
             BRA   :L1
:CLOSE       LDA   #$00
             JSR   FINDHND                   ; Close file
:DONE        RTS
:SYNTAX      BRK
             DB    $DC
             ASC   'Syntax: TYPE <*objspec*>'
             BRK
:NOTFOUND    BRK
             DB    $D6
             ASC   'Not found'
             BRK
:ESC         LDA   #$00                      ; Close file
             JSR   FINDHND
             BRK
             DB    $11
             ASC   'Escape'
             BRK


* Handle *DUMP command
* LPTR=>parameters string
*
DUMP         JSR   LPTRtoXY
             PHX
             PHY
             JSR   XYtoLPTR
             JSR   PARSLPTR                  ; Just for error handling
             BEQ   :SYNTAX                   ; No filename
             PLY
             PLX
             LDA   #$40                      ; Open for input
             JSR   FINDHND                   ; Try to open file
             CMP   #$00                      ; Was file opened?
             BEQ   :NOTFOUND
             TAY                             ; File handle in Y
             STZ   DUMPOFF
             STZ   DUMPOFF+1
:L1          JSR   BGETHND                   ; Read a byte
             BCS   :CLOSE                    ; EOF
             PHA
             LDA   DUMPOFF+0
             AND   #$07
             BNE   :INC
             LDA   DUMPOFF+1                 ; Print file offset
             JSR   PRHEXBYTE
             LDA   DUMPOFF+0
             JSR   PRHEXBYTE
             LDA   #' '
             JSR   OSASCI
             LDX   #$07
             LDA   #' '                      ; Clear ASCII buffer
:L2          STA   DUMPASCI,X
             DEX
             BNE   :L2
:INC         INC   DUMPOFF+0                 ; Increment file offset
             BNE   :S1
             INC   DUMPOFF+1
:S1          PLA
             STA   DUMPASCI,X
             JSR   PRHEXBYTE
             INX
             LDA   #' '
             JSR   OSASCI
             CPX   #$08                      ; If EOL ..
             BNE   :S2
             JSR   PRCHARS                   ; Print ASCII representation
:S2          LDA   ESCFLAG
             BMI   :ESC
             BRA   :L1
:CLOSE       JSR   PRCHARS                   ; Print ASCII representation
             LDA   #$00
             JSR   FINDHND                   ; Close file
:DONE        RTS
:SYNTAX      BRK
             DB    $DC
             ASC   'Syntax: DUMP <*objspec*>'
             BRK
:NOTFOUND    BRK
             DB    $D6
             ASC   'Not found'
             BRK
:ESC         LDA   #$00                      ; Close file
             JSR   FINDHND
             BRK
             DB    $11
             ASC   'Escape'
             BRK
DUMPOFF      DW    $0000
DUMPASCI     DS    8

* Print byte in A in hex format
PRHEXBYTE    PHA
             LSR   A
             LSR   A
             LSR   A
             LSR   A
             JSR   PRHEXNIB
             PLA
             JSR   PRHEXNIB
             RTS

* Print nibble in A in hex format
PRHEXNIB     AND   #$0F
             CMP   #10
             BPL   :LETTER
             CLC
             ADC   #'0'
             BRA   :PRINT
:LETTER      CLC
             ADC   #'A'-10
:PRINT       JSR   OSASCI
             RTS

* Print ASCII char buffer
* with non-printing chars shown as '.'
PRCHARS      CPX   #$00
             BEQ   :DONE
             CPX   #$08                      ; Pad final line
             BEQ   :S0
             LDA   #' '
             JSR   OSASCI
             JSR   OSASCI
             JSR   OSASCI
             INX
             BRA   PRCHARS
:S0          LDX   #$00
:L2          LDA   DUMPASCI,X
             CMP   #$20
             BMI   :NOTPRINT
             CMP   #$7F
             BPL   :NOTPRINT
             JSR   OSASCI
:S1          INX
             CPX   #$08
             BNE   :L2            
             JSR   OSNEWL
             LDX   #$00
:DONE        RTS
:NOTPRINT    LDA   #'.'
             JSR   OSASCI
             BRA   :S1

* Handle *SPOOL command
* LPTR=>parameters string
*
SPOOL        JSR   LPTRtoXY
             PHX
             PHY
             JSR   XYtoLPTR
             JSR   PARSLPTR                  ; Just for error handling
             BEQ   :CLOSE                    ; No filename - stop spooling
             LDY   FXSPOOL                   ; Already spooling?
             BEQ   :OPEN
             LDA   #$00                      ; If so, close file
             JSR   FINDHND
:OPEN        PLY
             PLX
             LDA   #$80                      ; Open for writing
             JSR   FINDHND                   ; Try to open file
             STA   FXSPOOL                   ; Store SPOOL file handle
             RTS
:CLOSE       PLY                             ; Clean up stack
             PLX
             LDY   FXSPOOL
             BEQ   :DONE
             LDA   #$00
             JSR   FINDHND                   ; Close file
             STZ   FXSPOOL
:DONE        RTS


* Handle *EXEC command
* LPTR=>parameters string
*
EXEC         JSR   LPTRtoXY
             PHX
             PHY
             JSR   XYtoLPTR
             JSR   PARSLPTR                  ; Just for error handling
             BEQ   :SYNTAX                   ; No filename
             PLY
             PLX
             LDA   #$40                      ; Open for input
             JSR   FINDHND                   ; Try to open file
             CMP   #$00                      ; Was file opened?
             BEQ   :NOTFOUND
             STA   FXEXEC                    ; Store EXEC file handle
             RTS
             RTS
:SYNTAX      PLY                             ; Fix the stack
             PLX
             BRK
             DB    $DC
             ASC   'Syntax: EXEC <*objspec*>'
             BRK
:NOTFOUND    STZ   FXEXEC
             BRK
             DB    $D6
             ASC   'Not found'
             BRK

*
* Handle *FAST command
* Turn Apple II accelerators on
FAST         LDA   #$80                      ; Apple IIgs
             TSB   $C036
             STA   GSSPEED
             STA   $C05C                     ; Ultrawarp fast
             RTS

*
* Handle *SLOW command
* Turn Apple II accelerators off
SLOW         LDA   #$80                      ; Apple IIgs
             TRB   $C036
             STZ   GSSPEED
             STA   $C05D                     ; Ultrawarp slow
             RTS








