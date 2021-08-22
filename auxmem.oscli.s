* AUXMEM.OSCLI.S
* (c) BOBBI 2021 GPLv3
*
* Handle OSCLI system calls

* OSCLI HANDLER
* On entry, XY=>command string
* TO DO: line pointer in XY should be in LPTR
*
CLIHND      PHX
            PHY
            STX   ZP1+0            ; Pointer to CLI
            STY   ZP1+1
:L1         LDA   (ZP1)
            CMP   #'*'             ; Trim any leading stars
            BEQ   :NEXT
            CMP   #' '             ; Trim any leading spaces
            BEQ   :NEXT
            BRA   :TRIMMED
:NEXT       INC   ZP1
            BNE   :L1
            INC   ZP1+1
            BRA   :L1
:TRIMMED    CMP   #'|'             ; | is comment
            BEQ   :IEXIT2
            CMP   #$0D             ; Carriage return
            BEQ   :IEXIT
            LDA   #<:QUIT
            STA   ZP2
            LDA   #>:QUIT
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S1
            JSR   STARQUIT
:IEXIT2     BRA   :IEXIT
:S1         LDA   #<:CAT
            STA   ZP2
            LDA   #>:CAT
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S2
            JSR   STARCAT
            BRA   :IEXIT
:S2         LDA   #<:CAT2
            STA   ZP2
            LDA   #>:CAT2
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S3
            JSR   STARCAT
            BRA   :IEXIT
:S3         LDA   #<:DIR
            STA   ZP2
            LDA   #>:DIR
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S4
            JSR   STARDIR
            BRA   :IEXIT
:S4         LDA   #<:LOAD
            STA   ZP2
            LDA   #>:LOAD
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S5
            JSR   STARLOAD
            BRA   :IEXIT
:S5         LDA   #<:SAVE
            STA   ZP2
            LDA   #>:SAVE
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S6
            JSR   STARSAVE
:S6         LDA   #<:RUN
            STA   ZP2
            LDA   #>:RUN
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S7
            JSR   STARRUN
            BRA   :EXIT
:IEXIT      BRA   :EXIT
:S7         LDA   #<:DELETE
            STA   ZP2
            LDA   #>:DELETE
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S8
            JSR   STARDEL
            BRA   :EXIT
:S8         LDA   #<:RENAME
            STA   ZP2
            LDA   #>:RENAME
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S9
            JSR   STARREN
            BRA   :EXIT
:S9         LDA   #<:HELP
            STA   ZP2
            LDA   #>:HELP
            STA   ZP2+1
            JSR   STRCMP
            BCS   :ASKROM
            JSR   STARHELP
            BRA   :EXIT
:ASKROM     LDA   $8006            ; Check for service entry
            BPL   :UNSUPP          ; No service entry
            LDA   ZP1              ; String in (OSLPTR),Y
            STA   OSLPTR
            LDA   ZP1+1
            STA   OSLPTR+1
            LDY   #$00
            LDA   #$04             ; Service 4 Unrecognized Cmd
            LDX   #$0F             ; ROM slot
            JSR   $8003            ; Service entry point
            TAX                    ; Check return
            BEQ   :EXIT            ; Call claimed

:UNSUPP     LDA   #<:OSCLIM
            LDY   #>:OSCLIM
            JSR   PRSTR
            PLY
            PLX
            STX   ZP3
            STY   ZP3+1
            LDY   #$00
:PL1        LDA   (ZP3),Y
            CMP   #$0D
            BEQ   :PS1
            CMP   #$00
            BEQ   :PS1
            JSR   OSWRCH
            INY
            BRA   :PL1
:PS1        LDA   #<:OSCLIM2
            LDY   #>:OSCLIM2
            JSR   PRSTR
            RTS
:EXIT       PLY
            PLX
            RTS
:QUIT       ASC   'QUIT'
            DB    $00
:CAT        ASC   'CAT'
            DB    $00
:CAT2       ASC   '.'
            DB    $00
:DIR        ASC   'DIR'
            DB    $00
:LOAD       ASC   'LOAD'
            DB    $00
:SAVE       ASC   'SAVE'
            DB    $00
:RUN        ASC   'RUN'
            DB    $00
:DELETE     ASC   'DELETE'
            DB    $00
:RENAME     ASC   'RENAME'
            DB    $00
:HELP       ASC   'HELP'
            DB    $00
:OSCLIM     ASC   'OSCLI('
            DB    $00
:OSCLIM2    ASC   ').'
            DB    $00

* String comparison for OSCLI
* Compares str in ZP1 with null-terminated str in ZP2
* Clear carry if match, set carry otherwise
* Leaves (ZP1),Y pointing to char after verb
STRCMP      LDY   #$00
:L1         LDA   (ZP2),Y
            BEQ   :PMATCH
            CMP   (ZP1),Y
            BNE   :MISMTCH
            INY
            BRA   :L1
:PMATCH     LDA   (ZP1),Y
            CMP   #$0D
            BEQ   :MATCH
            CMP   #' '
            BEQ   :MATCH
            CMP   #'"'
            BEQ   :MATCH
            BRA   :MISMTCH
:MATCH      CLC
            RTS
:MISMTCH    SEC
            RTS

* Print *HELP test
STARHELP    LDA   #<:MSG
            LDY   #>:MSG
            JSR   PRSTR
            LDA   #$09             ; Language name
            LDY   #$80
            JSR   PRSTR
            LDA   #<:MSG2
            LDY   #>:MSG2
            JSR   PRSTR
* TODO: Pass on to filing system
            RTS
:MSG        DB    $0D
            ASC   'Applecorn MOS v0.01'
            DB    $0D,$0D,$00
:MSG2       DB    $0D,$00

* Handle *QUIT command
STARQUIT    >>>   XF2MAIN,QUIT

* Handle *CAT / *. command (list directory)
STARCAT     LDA   #$05
            JMP   JUMPFSCV         ; Pass to filing system

* Consume spaces in command line. Treat " as space!
* Return C set if no space found, C clear otherwise
* Command line pointer in (ZP1),Y
EATSPC      LDA   (ZP1),Y          ; Check first char is ...
            CMP   #' '             ; ... space
            BEQ   :START
            CMP   #'"'             ; Or quote mark
            BEQ   :START
            BRA   :NOTFND
:START      INY
:L1         LDA   (ZP1),Y          ; Eat any additional ...
            CMP   #' '             ; ... spaces
            BEQ   :CONT
            CMP   #'"'             ; Or quote marks
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
            CMP   #$0D             ; Carriage return
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
            BCS   :BADCHAR         ; char > 'F'
            CMP   #'A'
            BCC   :S1
            SEC                    ; 'A' <= char <= 'F'
            SBC   #'A'-10
            CLC
            RTS
:S1         CMP   #'9'+1
            BCS   :BADCHAR         ; '9' < char < 'A'
            CMP   #'0'
            BCC   :BADCHAR         ; char < '0'
            SEC                    ; '0' <= char <= '9'
            SBC   #'0'
            CLC
            RTS
:BADCHAR    SEC
            RTS

* Decode hex constant on command line
* On entry, ZP1 points to command line
HEXCONST    LDX   #$00
:L1         STZ   :BUF,X           ; Clear :BUF
            INX
            CPX   #$04
            BNE   :L1
            LDX   #$00
            LDY   #$00
:L2         LDA   (ZP1),Y          ; Parse hex digits into
            JSR   HEXDIGIT         ; :BUF, left aligned
            BCS   :NOTHEX
            STA   :BUF,X
            INY
            INX
            CPX   #$04
            BNE   :L2
            LDA   (ZP1),Y          ; Peek at next char
:NOTHEX     CPX   #$00             ; Was it the first digit?
            BEQ   :ERR             ; If so, bad hex constant
            CMP   #' '             ; If whitespace, then okay
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

ADDRBUF     DW    $0000            ; Used by HEXCONST

* Handle *LOAD command
* On entry, ZP1 points to command line
STARLOAD    JSR   CLRCB
            JSR   EATSPC           ; Eat leading spaces
            BCS   :ERR
            JSR   ADDZP1Y          ; Advance ZP1
            LDA   ZP1              ; Pointer to filename
            STA   OSFILECB
            LDA   ZP1+1
            STA   OSFILECB+1
            JSR   EATWORD          ; Advance past filename
            BCS   :NOADDR          ; No load address given
            LDA   #$0D             ; Carriage return
            STA   (ZP1),Y          ; Terminate filename
            INY
            JSR   EATSPC           ; Eat any whitespace
            JSR   ADDZP1Y          ; Update ZP1
            JSR   HEXCONST
            BCS   :ERR             ; Bad hex constant
            LDA   ADDRBUF
            STA   OSFILECB+2       ; Load address LSB
            LDA   ADDRBUF+1
            STA   OSFILECB+3       ; Load address MSB
:OSFILE     LDX   #<OSFILECB
            LDY   #>OSFILECB
            LDA   #$FF             ; OSFILE load flag
            JSR   OSFILE
:END        RTS
:NOADDR     LDA   #$FF             ; Set OSFILECB+6 to non-zero
            STA   OSFILECB+6       ; Means use the file's addr
            BRA   :OSFILE
:ERR        JSR   BEEP
            RTS

* Handle *SAVE command
* On entry, ZP1 points to command line
STARSAVE    JSR   CLRCB
            JSR   EATSPC           ; Eat leading space
            BCS   :ERR
            JSR   ADDZP1Y          ; Advance ZP1
            LDA   ZP1              ; Pointer to filename
            STA   OSFILECB
            LDA   ZP1+1
            STA   OSFILECB+1
            JSR   EATWORD
            BCS   :ERR             ; No start address given
            LDA   #$0D             ; Carriage return
            STA   (ZP1),Y          ; Terminate filename
            INY
            JSR   EATSPC           ; Eat any whitespace
            JSR   ADDZP1Y          ; Update ZP1
            JSR   HEXCONST
            BCS   :ERR             ; Bad start address
            LDA   ADDRBUF
            STA   OSFILECB+10
            LDA   ADDRBUF+1
            STA   OSFILECB+11
            JSR   EATSPC           ; Eat any whitespace
            JSR   ADDZP1Y          ; Update ZP1
            JSR   HEXCONST
            BCS   :ERR             ; Bad end address
            LDA   ADDRBUF
            STA   OSFILECB+14
            LDA   ADDRBUF+1
            STA   OSFILECB+15
            LDX   #<OSFILECB
            LDY   #>OSFILECB
            LDA   #$00             ; OSFILE save flag
            JSR   OSFILE
:END        RTS
:ERR        JSR   BEEP
            RTS

* Handle *RUN command
* On entry, ZP1 points to command line
STARRUN     LDA   #$04
JUMPFSCV    PHA
            JSR   EATSPC           ; Eat leading space
            JSR   ADDZP1Y          ; Advance ZP1
            LDX   ZP1+0
            LDY   ZP1+1
            PLA
CALLFSCV    JMP   (FSCV)           ; Hand on to filing system

* Handle *DELETE command
* On entry, ZP1 points to command line
STARDEL     JSR   EATSPC           ; Eat leading space
            JSR   ADDZP1Y          ; Advance ZP1
            LDA   ZP1
            STA   OSFILECB+0
            LDA   ZP1+1
            STA   OSFILECB+1
            JSR   EATWORD
            LDA   #$0D
            STA   (ZP1),Y          ; Terminate filename
            LDX   #<OSFILECB
            LDY   #>OSFILECB
            LDA   #$06             ; OSFILE delete command
            JSR   OSFILE
            RTS
:ERR        JSR   BEEP
            RTS

* Handle *RENAME command
* On entry, ZP1 points to command line
STARREN     JSR   EATSPC           ; Eat leading space
            JSR   ADDZP1Y          ; Advance ZP1
            LDY   #$00
:L1         LDA   (ZP1),Y          ; Copy arg1 -> MOSFILE
            CMP   #' '
            BEQ   :ENDARG1
            CMP   #$0D             ; Carriage return
            BEQ   :ERR
            INY
            >>>   WRTMAIN
            STA   MOSFILE,Y
            >>>   WRTAUX
            BRA   :L1
:ENDARG1    >>>   WRTMAIN
            STY   MOSFILE          ; Length of arg1
            >>>   WRTAUX
            JSR   EATSPC           ; Eat space between args
            JSR   ADDZP1Y          ; Advance ZP1
            LDY   #$00
:L2         LDA   (ZP1),Y          ; Copy arg2 -> MOSFILE
            CMP   #' '
            BEQ   :ENDARG2
            CMP   #$0D
            BEQ   :ENDARG2
            INY
            >>>   WRTMAIN
            STA   MOSFILE2,Y
            >>>   WRTAUX
            BRA   :L2
:ENDARG2    >>>   WRTMAIN
            STY   MOSFILE2         ; Length of arg2
            >>>   WRTAUX
            >>>   XF2MAIN,RENFILE
:ERR
* TODO: Handle errors
            JSR   BEEP
            RTS

STARRENRET
            >>>   ENTAUX
            RTS

* Clear OSFILE control block to zeros
CLRCB       LDA   #$00
            LDX   #$00
:L1         STA   OSFILECB,X
            INX
            CPX   #18
            BNE   :L1
            RTS

