* AUXMEM.OSCLI.S
****************
* (c) BOBBI 2021 GPLv3
*
* Handle OSCLI system calls

* 22-Aug-2021 Uses dispatch table
*             Prepares parameters and hands on to API call


* COMMAND TABLE
***************
*
* fsc commands
CMDTABLE    ASC   'CAT',$85       ; Must be first command to match '*.'
            DW    STARFSC-1       ; CAT    -> FSC 5, XY=>params
            ASC   'RUN',$84
            DW    STARFSC-1       ; RUN    -> FSC 4, XY=>params
            ASC   'EX',$89
            DW    STARFSC-1       ; EX     -> FSC 9, XY=>params
            ASC   'INFO',$8A
            DW    STARFSC-1       ; INFO   -> FSC 10, XY=>params
            ASC   'RENAME',$8C
            DW    STARFSC-1       ; RENAME -> FSC 12, XY=>params
* osfile commands
            ASC   'LOAD',$FF
            DW    STARLOAD-1      ; LOAD   -> OSFILE FF, CBLK=>filename
            ASC   'SAVE',$FF
            DW    STARSAVE-1      ; SAVE   -> OSFILE 00, CBLK=>filename
            ASC   'DELETE',$86
            DW    STARFILE-1      ; DELETE -> OSFILE 06, CBLK=>filename
            ASC   'MKDIR',$88
            DW    STARFILE-1      ; MKDIR  -> OSFILE 08, CBLK=>filename
            ASC   'CDIR',$88
            DW    STARFILE-1      ; CDIR   -> OSFILE 08, CBLK=>filename
* other filing commands
            ASC   'CHDIR',$80
            DW    STARCHDIR-1     ; Should be a FSC call
            ASC   'DIR',$80
            DW    STARCHDIR-1     ; Should be a FSC call
            ASC   'DRIVE',$80
            DW    STARDRIVE-1     ; Should be a FSC call
* osbyte commands
            ASC   'FX',&80
            DW    STARFX-1        ; FX     -> OSBYTE A,X,Y    (LPTR)=>params
            ASC   'OPT',$8B
            DW    STARBYTE-1      ; OPT    -> OSBYTE &8B,X,Y  XY=>params
* others
            ASC   'QUIT',$80
            DW    STARQUIT-1      ; QUIT   -> (LPTR)=>params
            ASC   'HELP',$80
            DW    STARHELP-1      ; HELP   -> (LPTR)=>params
            ASC   'BASIC',$80
            DW    STARBASIC-1     ; BASIC  -> (LPTR)=>params
            ASC   'KEY',$80
            DW    STARKEY-1       ; KEY    -> (LPTR)=>params
* terminator
            DB    $00


* OSCLI HANDLER
* On entry, XY=>command string
* On exit,  AXY corrupted or error generated
*
CLIHND      STX   OSLPTR+0
            STY   OSLPTR+1        ; LPTR=>command line
            LDY   #0
CLILP1      LDA   (OSLPTR),Y
            CMP   #$0D
            BEQ   CLI2
            INY
            BNE   CLILP1
CLIEXIT1    RTS                   ; No terminating <cr>
CLI2        LDY   #0
CLILP2      LDA   (OSLPTR),Y
            INY                        
            CMP   #' '            ; Skip leading spaces
            BEQ   CLILP2
            CMP   #'*'            ; Skip leading stars
            BEQ   CLILP2
            CMP   #$0D
            BEQ   CLIEXIT1        ; Null string
            CMP   #'|'
            BEQ   CLIEXIT1        ; Comment
            CMP   #'/'
            BEQ   CLISLASH
            DEY
            JSR   LPTRtoXY        ; Add Y to LPTR
            STX   OSLPTR+0
            STY   OSLPTR+1        ; LPTR=>start of actual command
;
* Search command table
            LDX   #0              ; Start of command table
CLILP4      LDY   #0              ; Start of command line
CLILP5      LDA   CMDTABLE,X
            BEQ   CLIUNKNOWN      ; End of command table
            BMI   CLIMATCH        ; End of table string
            EOR   (OSLPTR),Y
            AND   #$DF            ; Force upper case match
            BNE   CLINOMATCH
            INX                   ; Step to next table char
            INY                   ; Step to next command char
            BNE   CLILP5          ; Loop to check

CLINOMATCH  LDA   (OSLPTR),Y
            CMP   #'.'            ; Abbreviation?
            BEQ   CLIDOT
CLINEXT     INX                   ; No match, step to next entry
            LDA   CMDTABLE,X
            BPL   CLINEXT
CLINEXT2    INX                   ; Step past byte, address
            INX
            INX
            BNE   CLILP4          ; Loop to check next

CLIDOT      LDA   CMDTABLE,X
            BMI   CLINEXT2        ; Dot after full word, no match
CLIDOT2     INX                   ; Step to command address
            LDA   CMDTABLE,X
            BPL   CLIDOT2
            INY                   ; Step past dot
            BNE   CLIMATCH2       ; Jump to this command

CLIMATCH    LDA   (OSLPTR),Y
            CMP   #'.'
            BEQ   CLINEXT         ; Longer abbreviation, eg 'CAT.'
            CMP   #'A'
            BCS   CLINEXT         ; More letters, eg 'HELPER'
CLIMATCH2   JSR   SKIPSPC         ; (OSLPTR),Y=>parameters
            LDA   CMDTABLE+2,X    ; Push destination address
            PHA
            LDA   CMDTABLE+1,X
            PHA
            LDA   CMDTABLE+0,X    ; A=command parameter
            PHA
            ASL   A               ; Drop bit 7
            BEQ   CLICALL         ; If $80 don't convert LPTR
            JSR   LPTRtoXY        ; XY=>parameters
CLICALL     PLA                   ; A=command parameter
CLIDONE     RTS

CLISLASH    JSR   SKIPSPC
            BEQ   CLIDONE         ; */<cr>
            LDA   #$02
            BNE   STARFSC2        ; FSC 2 = */filename

CLIUNKNOWN  LDA   #$04
            JSR   SERVICE         ; Offer to sideways ROM(s)
            BEQ   CLIDONE         ; Claimed
            JSR   LPTRtoXY        ; XY=>command
            LDA   #$03            ; FSC 3 = unknown command
STARFSC     AND   #$7F            ; A=command, XY=>parameters
STARFSC2    JSR   CALLFSCV        ; Hand on to filing system
* TO DO: hostfs.s needs to return A=0
            TAX
            BEQ   CLIDONE
            RTS   ; *TEMP*
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
;
* Commands passed to OSBYTE
***************************
STARBYTE    STX   OSLPTR+0
            STY   OSLPTR+1
            LDY   #$00
STARBYTE1   STA   OSAREG     ; Save OSBYTE number
            LDA   #$00       ; Default X and Y
            STA   OSXREG
            STA   OSYREG
            JSR   SKIPCOMMA  ; Step past any comma/spaces
            BEQ   STARBYTE2  ; End of line, do it
            JSR   SCANDEC    ; Scan for X param
            STA   OSXREG     ; Store it
            JSR   SKIPCOMMA  ; Step past any comma/spaces
            BEQ   STARBYTE2  ; End of line, do it
            JSR   SCANDEC    ; Scan for Y param
            STA   OSYREG     ; Store it
            JSR   SKIPSPC
            BNE   ERRBADCMD  ; More params, error
STARBYTE2   LDY   OSYREG
            LDX   OSXREG
            LDA   OSAREG
            JSR   OSBYTE
            BVS   ERRBADCMD
            RTS

* Scan decimal number
SCANDEC     JSR   SKIPSPC
            JSR   SCANDIGIT       ; Check first digit
            BCS   ERRBADNUM       ; Doesn't start with a digit
SCANDECLP   STA   OSTEMP          ; Store as current number
            JSR   SCANDIGIT       ; Check next digit
            BCS   SCANDECOK       ; No more digits   
            PHA
            LDA   OSTEMP
            CMP   #26
            BCS   ERRBADNUM       ; num>25, num*25>255
            ASL   A               ; num*2
            ASL   A               ; num*4
            ADC   OSTEMP          ; num*4+num = num*5
            ASL   A               ; num*10
            STA   OSTEMP
            PLA
            ADC   OSTEMP          ; num=num*10+digit
            BCC   SCANDECLP
            BCS   ERRBADNUM       ; Overflowed

SCANDECOK   LDA   OSTEMP          ; Return A=number
SCANDIG2    SEC
            RTS

SCANDIGIT   LDA  (OSLPTR),Y
            CMP   #'0'
            BCC   SCANDIG2   ; <'0'
            CMP   #'9'+1
            BCS   SCANDIG2   ; >'9'
            INY
            AND   #$0F
            RTS

SKIPCOMMA   LDA   (OSLPTR),Y
            CMP   #$2C
            BNE   SKIPSPC
;
* Skip spaces
SKIPSPCLP   INY              ; Step past space or comma
SKIPSPC     LDA   (OSLPTR),Y
            CMP   #' '
            BEQ   SKIPSPCLP
            CMP   #$0D       ; Return EQ=<cr>
            RTS

* Convert (LPTR),Y to XY
LPTRtoXY    CLC
            TYA
            ADC OSLPTR+0
            TAX
            LDA #0
            ADC OSLPTR+1
            TAY
            RTS

* Commands passed to OSFILE
***************************
STARFILE    AND   #$7F
            STX   OSFILECB+0
            STY   OSFILECB+1
            JMP   OSFILE

STARDRIVE
STARBASIC
STARKEY     RTS

STARCHDIR   STX   ZP1+0      ; TEMP
            STY   ZP1+1      ; TEMP
            LDY   #$00       ; TEMP
            JMP   STARDIR    ; TEMP

* Got to here....
*
* OLD CODE
;            STX   ZP1+0                      ; Pointer to CLI
;            STY   ZP1+1
;:L1         LDA   (ZP1)
;            CMP   #'*'                       ; Trim any leading stars
;            BEQ   :NEXT
;            CMP   #' '                       ; Trim any leading spaces
;            BEQ   :NEXT
;            BRA   :TRIMMED
;:NEXT       INC   ZP1
;            BNE   :L1
;            INC   ZP1+1
;            BRA   :L1
;:TRIMMED    CMP   #'|'                       ; | is comment
;            BEQ   :IEXIT
;            CMP   #$0D                       ; Carriage return
;            BEQ   :IEXIT
;            LDA   #<:QUIT
;            STA   ZP2
;            LDA   #>:QUIT
;            STA   ZP2+1
;            JSR   STRCMP
;            BCS   :S1
;            JSR   STARQUIT
;            BRA   :IEXIT
;:S1         LDA   #<:CAT
;            STA   ZP2
;            LDA   #>:CAT
;            STA   ZP2+1
;            JSR   STRCMP
;            BCS   :S2
;            JSR   STARCAT
;            BRA   :IEXIT
;:S2         LDA   #<:CAT2
;            STA   ZP2
;            LDA   #>:CAT2
;            STA   ZP2+1
;            JSR   STRCMP
;            BCS   :S3
;            JSR   STARCAT
;            BRA   :IEXIT
;:S3         LDA   #<:DIR
;            STA   ZP2
;            LDA   #>:DIR
;            STA   ZP2+1
;            JSR   STRCMP
;            BCS   :S4
;            JSR   STARDIR
;            BRA   :IEXIT
;:S4         LDA   #<:LOAD
;            STA   ZP2
;            LDA   #>:LOAD
;            STA   ZP2+1
;            JSR   STRCMP
;            BCS   :S5
;            JSR   STARLOAD
;            BRA   :EXIT
;:S5         LDA   #<:SAVE
;            STA   ZP2
;            LDA   #>:SAVE
;            STA   ZP2+1
;            JSR   STRCMP
;            BCS   :S6
;            JSR   STARSAVE
;:IEXIT      BRA   :EXIT
;:S6         LDA   #<:RUN
;            STA   ZP2
;            LDA   #>:RUN
;            STA   ZP2+1
;            JSR   STRCMP
;            BCS   :S7
;            JSR   STARRUN
;            BRA   :EXIT
;:S7         LDA   #<:HELP
;            STA   ZP2
;            LDA   #>:HELP
;            STA   ZP2+1
;            JSR   STRCMP
;            BCS   :ASKROM
;            JSR   STARHELP
;            BRA   :EXIT
;:ASKROM     LDA   $8006      ; Check for service entry
;            BPL   :UNSUPP    ; No service entry
;*            LDA   $8003     ; Check for service entry
;*            CMP   #$4C      ; Not a JMP?
;*            BNE   :UNSUPP   ; Only BASIC has no srvc entry
;            LDA   ZP1        ; String in (OSLPTR),Y
;            STA   OSLPTR
;            LDA   ZP1+1
;            STA   OSLPTR+1
;            LDY   #$00
;            LDA   #$04       ; Service 4 Unrecognized Cmd
;            LDX   #$0F       ; ROM slot
;            JSR   $8003      ; Service entry point
;            TAX              ; Check return
;            BEQ   :EXIT      ; Call claimed
;
;:UNSUPP     LDA   #<:OSCLIM
;            LDY   #>:OSCLIM
;            JSR   PRSTR
;            PLY
;            PLX
;            STX   ZP3
;            STY   ZP3+1
;            LDY   #$00
;:PL1        LDA   (ZP3),Y
;            CMP   #$0D
;            BEQ   :PS1
;            CMP   #$00
;            BEQ   :PS1
;            JSR   OSWRCH
;            INY
;            BRA   :PL1
;:PS1        LDA   #<:OSCLIM2
;            LDY   #>:OSCLIM2
;            JSR   PRSTR
;            RTS
;:EXIT       PLY
;            PLX
;            RTS
;:QUIT       ASC   'QUIT'
;            DB    $00
;:CAT        ASC   'CAT'
;            DB    $00
;:CAT2       ASC   '.'
;            DB    $00
;:DIR        ASC   'DIR'
;            DB    $00
;:LOAD       ASC   'LOAD'
;            DB    $00
;:SAVE       ASC   'SAVE'
;            DB    $00
;:RUN        ASC   'RUN'
;            DB    $00
;:HELP       ASC   'HELP'
;            DB    $00
;:OSCLIM     ASC   'OSCLI('
;            DB    $00
;:OSCLIM2    ASC   ').'
;            DB    $00
;
;* String comparison for OSCLI
;* Compares str in ZP1 with null-terminated str in ZP2
;* Clear carry if match, set carry otherwise
;* Leaves (ZP1),Y pointing to char after verb
;STRCMP      LDY   #$00
;:L1         LDA   (ZP2),Y
;            BEQ   :PMATCH
;            CMP   (ZP1),Y
;            BNE   :MISMTCH
;            INY
;            BRA   :L1
;:PMATCH     LDA   (ZP1),Y
;            CMP   #$0D
;            BEQ   :MATCH
;            CMP   #' '
;            BEQ   :MATCH
;            CMP   #'"'
;            BEQ   :MATCH
;            BRA   :MISMTCH
;:MATCH      CLC
;            RTS
;:MISMTCH    SEC
;            RTS

* Print *HELP text
STARHELP    PHY
            LDA   #<:MSG
            LDY   #>:MSG
            JSR   PRSTR
            PLY
            PHY
            LDA   (OSLPTR),Y
            CMP   #'.'
            BNE   STARHELP5
            LDX   #0
STARHELPLP1 LDY   #10
            LDA   CMDTABLE,X
            BEQ   STARHELP4
STARHELPLP2 LDA   CMDTABLE,X
            BMI   STARHELP3
            JSR   OSWRCH
            DEY
            INX
            BNE   STARHELPLP2
STARHELP3   LDA   #32
            JSR   OSWRCH
            DEY
            BNE   STARHELP3
            INX
            INX
            INX
            BNE   STARHELPLP1
STARHELP4   JSR   OSNEWL
STARHELP5   JSR   OSNEWL
            LDA   #$09       ; Language name
            LDY   #$80
            JSR   PRSTR
            LDA   #<:MSG2
            LDY   #>:MSG2
            JSR   PRSTR
            PLY
            LDA   #9
            JMP   SERVICE    ; Pass to sideways ROM(s)
:MSG        DB    $0D
            ASC   'Applecorn MOS v0.01'
            DB    $0D,$00
:MSG2       DB    $0D,$00

* Handle *QUIT command
STARQUIT    >>>   XF2MAIN,QUIT

;* Handle *CAT / *. command (list directory)
;STARCAT     LDA   #$05
;            JMP   JUMPFSCV   ; Hand on to filing system

* Consume spaces in command line. Treat " as space!
* Return C set if no space found, C clear otherwise
* Command line pointer in (ZP1),Y
EATSPC      LDA   (ZP1),Y    ; Check first char is ...
            CMP   #' '       ; ... space
            BEQ   :START
            CMP   #'"'       ; Or quote mark
            BEQ   :START
            BRA   :NOTFND
:START      INY
:L1         LDA   (ZP1),Y    ; Eat any additional ...
            CMP   #' '       ; ... spaces
            BEQ   :CONT
            CMP   #'"'       ; Or quote marks
            BNE   :DONE
:CONT       INY
            BRA   :L1
:DONE       CLC
            RTS
:NOTFND     SEC
            RTS

* Consume chars in command line until space or " is found
* Command line pointer in (ZP1),Y
* Returns with carry set if EOL
EATWORD     LDA   (ZP1),Y
            CMP   #' '
            BEQ   :SPC
            CMP   #'"'
            BEQ   :SPC
            CMP   #$0D       ; Carriage return
            BEQ   :EOL
            INY
            BRA   EATWORD
:SPC        CLC
            RTS
:EOL        SEC
            RTS

* Add Y to ZP1 pointer. Clear Y.
ADDZP1Y     CLC
            TYA
            ADC   ZP1
            STA   ZP1
            LDA   #$00
            ADC   ZP1+1
            STA   ZP1+1
            LDY   #$00
            RTS

* Decode ASCII hex digit in A
* Returns with carry set if bad char, C clear otherwise
HEXDIGIT    CMP   #'F'+1
            BCS   :BADCHAR                   ; char > 'F'
            CMP   #'A'
            BCC   :S1
            SEC                              ; 'A' <= char <= 'F'
            SBC   #'A'-10
            CLC
            RTS
:S1         CMP   #'9'+1
            BCS   :BADCHAR                   ; '9' < char < 'A'
            CMP   #'0'
            BCC   :BADCHAR                   ; char < '0'
            SEC                              ; '0' <= char <= '9'
            SBC   #'0'
            CLC
            RTS
:BADCHAR    SEC
            RTS

* Decode hex constant on command line
* On entry, ZP1 points to command line
HEXCONST    LDX   #$00
:L1         STZ   :BUF,X                     ; Clear :BUF
            INX
            CPX   #$04
            BNE   :L1
            LDX   #$00
            LDY   #$00
:L2         LDA   (ZP1),Y                    ; Parse hex digits into
            JSR   HEXDIGIT                   ; :BUF, left aligned
            BCS   :NOTHEX
            STA   :BUF,X
            INY
            INX
            CPX   #$04
            BNE   :L2
            LDA   (ZP1),Y                    ; Peek at next char
:NOTHEX     CPX   #$00                       ; Was it the first digit?
            BEQ   :ERR                       ; If so, bad hex constant
            CMP   #' '                       ; If whitespace, then okay
            BEQ   :OK
            CMP   #$0D
            BEQ   :OK
:ERR        SEC
            RTS
:OK         LDA   :BUF-4,X
            ASL
            ASL
            ASL
            ASL
            ORA   :BUF-3,X
            STA   ADDRBUF+1
            LDA   :BUF-2,X
            ASL
            ASL
            ASL
            ASL
            ORA   :BUF-1,X
            STA   ADDRBUF
            CLC
            RTS
:ZEROPAD    DB    $00,$00,$00
:BUF        DB    $00,$00,$00,$00

ADDRBUF     DW    $0000                      ; Used by HEXCONST

* Handle *LOAD command
STARLOAD
* TEMP
            STX   ZP1+0    ;  need (ZP1),Y=>parameters
            STY   ZP1+1
            LDY   #$00
* TEMP
* On entry, ZP1 points to command line
            JSR   CLRCB
;            JSR   EATSPC                     ; Eat leading spaces
;            BCS   :ERR
            JSR   ADDZP1Y                    ; Advance ZP1
            LDA   ZP1                        ; Pointer to filename
            STA   OSFILECB
            LDA   ZP1+1
            STA   OSFILECB+1
            JSR   EATWORD                    ; Advance past filename
            BCS   :NOADDR                    ; No load address given
            LDA   #$0D                       ; Carriage return
            STA   (ZP1),Y                    ; Terminate filename
            INY
            JSR   EATSPC                     ; Eat any whitespace
            JSR   ADDZP1Y                    ; Update ZP1
            JSR   HEXCONST
            BCS   :ERR                       ; Bad hex constant
            LDA   ADDRBUF
            STA   OSFILECB+2                 ; Load address LSB
            LDA   ADDRBUF+1
            STA   OSFILECB+3                 ; Load address MSB
:OSFILE     LDX   #<OSFILECB
            LDY   #>OSFILECB
            LDA   #$FF                       ; OSFILE load flag
            JSR   OSFILE
:END        RTS
:NOADDR     LDA   #$FF                       ; Set OSFILECB+6 to non-zero
            STA   OSFILECB+6                 ; Means use the file's addr
            BRA   :OSFILE
:ERR        JMP   ERRBADADD

* Handle *SAVE command
STARSAVE
* TEMP
            STX   ZP1+0    ;  need (ZP1),Y=>parameters
            STY   ZP1+1
            LDY   #$00
* TEMP
* On entry, ZP1 points to command line
            JSR   CLRCB
;            JSR   EATSPC                     ; Eat leading space
;            BCS   :ERR
            JSR   ADDZP1Y                    ; Advance ZP1
            LDA   ZP1                        ; Pointer to filename
            STA   OSFILECB
            LDA   ZP1+1
            STA   OSFILECB+1
            JSR   EATWORD
            BCS   :ERR                       ; No start address given
            LDA   #$0D                       ; Carriage return
            STA   (ZP1),Y                    ; Terminate filename
            INY
            JSR   EATSPC                     ; Eat any whitespace
            JSR   ADDZP1Y                    ; Update ZP1
            JSR   HEXCONST
            BCS   :ERR                       ; Bad start address
            LDA   ADDRBUF
            STA   OSFILECB+10
            LDA   ADDRBUF+1
            STA   OSFILECB+11
            JSR   EATSPC                     ; Eat any whitespace
            JSR   ADDZP1Y                    ; Update ZP1
            JSR   HEXCONST
            BCS   :ERR                       ; Bad end address
            LDA   ADDRBUF
            STA   OSFILECB+14
            LDA   ADDRBUF+1
            STA   OSFILECB+15
            LDX   #<OSFILECB
            LDY   #>OSFILECB
            LDA   #$00                       ; OSFILE save flag
            JSR   OSFILE
:END        RTS
:ERR        JMP   ERRBADADD

* Handle *RUN command
* On entry, ZP1 points to command line
STARRUN     LDA #$04
JUMPFSCV    PHA
            JSR   EATSPC                     ; Eat leading spaces
            JSR   ADDZP1Y
            LDX   ZP1+0
            LDY   ZP1+1
            PLA
            AND   #$7F       ; A=command, XY=>parameters
CALLFSCV    JMP (FSCV)                     ; Hand on to filing system

* Clear OSFILE control block to zeros
CLRCB       LDA   #$00
            LDX   #$00
:L1         STA   OSFILECB,X
            INX
            CPX   #18
            BNE   :L1
            RTS

