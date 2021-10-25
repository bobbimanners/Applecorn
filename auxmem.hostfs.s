* AUXMEM.HOSTFS.S
* (c) Bobbi 2021 GPL v3
*
* AppleMOS Host File System
* 29-Aug-2021 Generalised CHKERROR routone, checks for and
*             translates ProDOS errors into Acorn errors
* Set &E0=&FF for testing to report ProDOS errors
* 30-Aug-2021 FSC commands moved to here
*             Command line set by *RUN, and read by OSARGS
* 20-Sep-2021 *FREE uses new PRDECIMAL routine
* 12-Oct-2021 OSFIND checks return value from calling maincode.
* 12-Oct-2021 BGET and BPUT check for returned error.
* 13-Oct-2021 FIND, BGET, BPUT optimised passing registers to main.
* 13-Oct-2021 ARGS, EOF returns errors, optimised passing registers.
* 14-Oct-2021 Tidied FILE handler.
* 23-Oct-2021 Uses single dispatch to mainmem FILE handler.
* 24-Oct-2021 Tidied FSC handler. Optimised CATALOG, CAT shows access.
*             *EX can use two columns. *OPT stored.


* $B0-$BF Temporary filing system workspace
* $C0-$CF Persistant filing system workspace
FSXREG      EQU   $C0
FSYREG      EQU   $C1
FSAREG      EQU   $C2
FSZPC3      EQU   $C3
FSCTRL      EQU   FSXREG
FSPTR1      EQU   $C4
FSPTR2      EQU   $C6
FSNUM       EQU   $C8
FSZPCC      EQU   $CC
FSCMDLINE   EQU   $CE


* OSFIND - open/close a file for byte access
FINDHND     PHX
            PHY
            PHA
            CMP   #$00                ; A=$00 = close
            BEQ   :CLOSE
            PHA
            JSR   PARSNAME            ; Copy filename->MOSFILE
            PLA                       ; Recover options
            >>>   XF2MAIN,OFILE
:CLOSE
*            >>>   WRTMAIN
*            STY   MOSFILE             ; Write file number
*            >>>   WRTAUX
            >>>   XF2MAIN,CFILE       ; Pass A,Y to main code

OSFINDRET   >>>   ENTAUX
            JSR   CHKERROR            ; Check if error returned
            PLY                       ; Value of A on entry
            BNE   :S1                 ; It wasn't close
            TYA                       ; Preserve A for close
:S1         PLY
            PLX
            RTS

* OSGBPB - Get/Put a block of bytes to/from an open file
GBPBHND     LDA   #<OSGBPBM
            LDY   #>OSGBPBM
            JMP   PRSTR
OSGBPBM     ASC   'OSGBPB.'
            DB    $00

* OSBPUT - write one byte to an open file
BPUTHND     PHX
            PHY
            PHA                       ; Stash char to write
*            >>>   WRTMAIN
*            STY   MOSFILE             ; File reference number
*            >>>   WRTAUX
            >>>   XF2MAIN,FILEPUT     ; Pass A,Y to main code
OSBPUTRET   >>>   ENTAUX
            JSR   CHKERROR
            CLC                       ; Means no error
            PLA
            PLY
            PLX
            RTS

* OSBGET - read one byte from an open file
BGETHND     PHX
            PHY
*            >>>   WRTMAIN
*            STY   MOSFILE             ; File ref number
*            >>>   WRTAUX
            >>>   XF2MAIN,FILEGET     ; Pass A,Y to main code
OSBGETRET   >>>   ENTAUX
            CPY   #$01
            BCC   :EXIT               ; If no error, return CC
            LDA   #$FE
            CPY   #$4C
            BEQ   :EXIT               ; If at EOF, return CS
            TYA
            JSR   CHKERROR
:EXIT       PLY
            PLX
            RTS

* OSARGS - adjust file arguments
* On entry, A=action
*           X=>4 byte ZP control block
*           Y=file handle
*      Y<>0 A=FF Flush channel Y
*           A=00 Read  PTR#Y
*           A=01 Write PTR#Y
*           A=02 Read  EXT#Y
*           A=03 Write EXT#Y
*      Y=0  A=FF Flush all channels
*           A=00 Return filing system number in A
*           A=01 Read command line address
* On exit,  A=0 - implemented (except ARGS 0,0)
*           A   - preserved=unimplemented
*           X,Y - preserved
*           control block updated for 'read' calls
*           control block preserved otherwise
*
ARGSHND     PHX
            PHY
            PHA
            CPY   #$00
            BNE   :HASFILE
            CMP   #$00                ; Y=0,A=0 => current file sys
            BNE   :S1
            PLA
            LDA   #105                ; 105=AppleFS filing system
            PLY
            PLX
            RTS

:S1         CMP   #$01                ; Y=0,A=1 => addr of CLI
            BNE   :S2
            LDA   FSCMDLINE+0
            STA   $00,X
            LDA   FSCMDLINE+1
            STA   $01,X
            LDA   #$FF
            STA   $02,X
            STA   $03,X
            JMP   OSARGSDONE          ; Implemented

:S2         CMP   #$FF                ; Y=0,A=FF => flush all files
            BNE   :IEXIT
*            >>>   WRTMAIN
*            STZ   MOSFILE             ; Zero means flush all
*            >>>   WRTAUX
            JMP   :FLUSH
:IEXIT      JMP   :EXIT               ; Exit preserved

:HASFILE
*            >>>   WRTMAIN
*            STY   MOSFILE             ; File ref num
*            STX   MOSFILE+1           ; Pointer to ZP control block
*            >>>   WRTAUX
            CMP   #$00                ; Y!=0,A=0 => read seq ptr
            BNE   :S3
*            >>>   WRTMAIN
*            STZ   MOSFILE+2           ; 0 means get pos
*            >>>   WRTAUX
            TXA
            >>>   XF2MAIN,TELL        ; A=ZP, Y=channel

:S3         CMP   #$01                ; Y!=0,A=1 => write seq ptr
            BNE   :S4
            >>>   WRTMAIN
            STY   GMARKPL+1           ; Write to MLI control block
            LDA   $00,X
            STA   GMARKPL+2
            LDA   $01,X
            STA   GMARKPL+3
            LDA   $02,X
            STA   GMARKPL+4
            >>>   WRTAUX
            >>>   XF2MAIN,SEEK        ; A=???, Y=channel

:S4         CMP   #$02                ; Y!=0,A=2 => read file len
            BNE   :S5
*            >>>   WRTMAIN
*            STA   MOSFILE+2           ; Non-zero means get len
*            >>>   WRTAUX
            TXA
            >>>   XF2MAIN,SIZE        ; A=ZP, Y=channel

:S5         CMP   #$FF                ; Y!=0,A=FF => flush file
            BNE   :EXIT
:FLUSH      >>>   XF2MAIN,FLUSH

:EXIT       PLA                       ; Unimplemented
            PLY
            PLX
            RTS

OSARGSRET   >>>   ENTAUX
            JSR   CHKERROR
OSARGSDONE  PLA
            LDA   #0                  ; Implemented
            PLY
            PLX
            RTS


* OSFILE - perform actions on entire files/objects
* On entry, A=action
*           XY=>control block
* On exit,  A=preserved if unimplemented
*           A=0 object not found (not load/save)
*           A=1 file found
*           A=2 directory found (not load/save)
*           XY  preserved
*               control block updated
*
OSFILEMIN   EQU   $FF         ; $FF=LOAD
OSFILEMAX   EQU   $08         ; $08=MKDIR

FILEHND     PHX
            PHY
            PHA
            CLC
            ADC   #256-OSFILEMIN
            CMP   #OSFILEMAX+257-OSFILEMIN  ; NB: LtoR evaluation
            BCS   FILEIGNORE

            STX   FSCTRL+0            ; FSCTRL=>control block
            STY   FSCTRL+1
            LDA   (FSCTRL)            ; XY=>filename
            TAX
            LDY   #$01
            LDA   (FSCTRL),Y
            TAY
            JSR   PARSNAME            ; Copy filename->MOSFILE

            LDY   #$11
            >>>   WRTMAIN
:L1         LDA   (FSCTRL),Y          ; Copy control block to auxmem
            STA   FILEBLK,Y
            DEY
            BPL   :L1
            >>>   WRTAUX
            PLA                       ; Get action back
            >>>   XF2MAIN,CALLFILE

*            BEQ   :SAVE               ; A=00 -> SAVE
*            CMP   #$FF
*            BEQ   :LOAD               ; A=FF -> LOAD
*            CMP   #$06
*            BEQ   :DELETE             ; A=06 -> DELETE
*            BCC   :JMPINFO            ; A=01-05 -> INFO
*            CMP   #$08
*            BEQ   :MKDIR              ; A=08 -> MKDIR
*
*            PLY                       ; Not implemented, return unchanged
*            PLX
*            RTS
*
*:JMPINFO    JMP   :INFO
*:SAVE       >>>   XF2MAIN,SAVEFILE
*:LOAD       >>>   XF2MAIN,LOADFILE
*:DELETE     >>>   XF2MAIN,DELFILE
*:INFO       >>>   XF2MAIN,INFOFILE
*:MKDIR      >>>   XF2MAIN,MAKEDIR

* On return here, A<$20 return to caller, A>$1F ProDOS error
OSFILERET   >>>   ENTAUX
            JSR   CHKERROR            ; Check if error returned
            PHA
            LDY   #$11                ; Copy updated control block back
:L3
*           LDA   AUXBLK,Y            ; Mainmem left it in AUXBLK
            LDA   OSFILECB,Y          ; Mainmem left it in OSFILECB
            STA   (FSCTRL),Y
            DEY
            BPL   :L3

FILEIGNORE  PLA                       ; Returned object type
            PLY                       ; No error, return to caller
            PLX
            RTS


* FSC Command Table
*******************
* These are commands specific to the filing system that can't be
* called via OSFILE, OSFSC, etc.
*
FSCCOMMAND  ASC   'CHDIR'
            DB    $80
            DW    FSCCHDIR-1          ; Change directory, LPTR=>params
            ASC   'CD'
            DB    $80
            DW    FSCCHDIR-1          ; Change directory, LPTR=>params
            ASC   'DIR'
            DB    $80
            DW    FSCCHDIR-1          ; Change directory, LPTR=>params
            ASC   'DRIVE'
            DB    $80
            DW    FSCDRIVE-1          ; Select drive, LPTR=>params
            ASC   'FREE'
            DB    $80
            DW    FSCFREE-1           ; FREE <drive>, LPTR=>params
            ASC   'ACCESS'
            DB    $80
            DW    FSCACCESS-1         ; ACCESS <objlist> <access>, LPTR=>params
            ASC   'TITLE'
            DB    $80
            DW    FSCTITLE-1          ; TITLE (<drive>) <title>, LPTR=>params
            ASC   'DESTROY'
            DB    $80
            DW    FSCDESTROY-1        ; DESTROY <objlist>, LPTR=>params
            ASC   'COPY'
            DB    $80
            DW    FSCCOPY-1           ; COPY <source> <dest>, LPTR=>params
*
            DB    $FF                 ; Terminator

* FSC Dispatch Table
********************
FSCDISPATCH DW   FSCOPT-1             ; A=0  - *OPT
            DW   CHKEOF-1             ; A=1  - Read EOF
            DW   FSCRUN-1             ; A=2  - */filename
            DW   FSC03-1              ; A=3  - *command
            DW   FSCRUN-1             ; A=4  - *RUN
            DW   FSCCAT-1             ; A=5  - *CAT
            DW   FSCUKN-1             ; A=6
            DW   FSCUKN-1             ; A=7
            DW   FSCUKN-1             ; A=8
            DW   FSCCAT-1             ; A=9  - *EX
            DW   FSCCAT-1             ; A=10 - *INFO
            DW   FSCUKN-1             ; A=11
            DW   FSCRENAME-1          ; A=12 - *RENAME

* OSFSC - miscellanous file system calls
*****************************************
*  On entry, A=action, XY=>command line
*       or   A=action, X=param1, Y=param2
*  On exit,  A=preserved if unimplemented
*            A=0 if implemented
*            X,Y=any return values
* 
FSCHND      CMP   #13
            BCS   FSCUKN
            STA   FSAREG
            STX   FSXREG
            STY   FSYREG
            ASL   A
            TAX
            LDA   FSCDISPATCH+1,X
            PHA
            LDA   FSCDISPATCH+0,X
            PHA
            LDX   FSXREG
            LDA   FSAREG
            RTS

*            CMP   #$00
*            BEQ   FSOPT               ; A=0  - *OPT
*            CMP   #$01
*            BEQ   CHKEOF              ; A=1  - Read EOF
*            CMP   #$02
*            BEQ   FSCRUN              ; A=2  - */filename
*            CMP   #$03
*            BEQ   FSC03               ; A=3  - *command
*            CMP   #$04
*            BEQ   FSCRUN              ; A=4  - *RUN
*            CMP   #$05
*            BEQ   JMPCAT              ; A=5  - *CAT
*            CMP   #$09
*            BEQ   JMPCAT              ; A=9  - *EX
*            CMP   #$0A
*            BEQ   JMPCAT              ; A=10 - *INFO
*            CMP   #$0C
*            BEQ   FSCREN              ; A=12 - *RENAME

* OSFSC 00 - *OPT function
FSCOPT       TXA
             BEQ   :OPT0
             LDA   FSFLAG2
             AND   :OPTMSK-1,X
             EOR   :OPTSET-0,Y
             AND   :OPTMSK-1,X
             EOR   :OPTSET-0,Y
:OPT0        STA   FSFLAG2
:OPTNULL     RTS
:OPTMSK      DB    $3F,$CF,$F3,$FC
:OPTSET      DB    $00,$55,$AA,$FF

*FSCDRIVE    JMP   DRIVE
*
*FSCFREE     JMP   FREE
*
*FSCACCESS   JMP   ACCESS
*
*FSCDESTROY  JMP   DESTROY
*
*JMPCAT      JMP   FSCCAT

FSCUKN      PHA
            LDA   #<OSFSCM
            LDY   #>OSFSCM
            JSR   PRSTR
            PLA
FSCNULL     RTS
OSFSCM      ASC   'OSFSC.'
            DB    $00


* OSFSC 01 - Read EOF function
* X=File ref number
*
CHKEOF
*            >>>   WRTMAIN
*            STX   MOSFILE             ; File reference number
*            >>>   WRTAUX
            TXA                       ; A=channel
            >>>   XF2MAIN,FILEEOF
CHKEOFRET   >>>   ENTAUX
            TAX                       ; Return code -> X
            TYA                       ; Y=any ProDOS error
            JMP   CHKERROR


* OSFSC 03 - *command, fall back to *RUN command
* XY=>command line
*
FSC03       JSR   XYtoLPTR
            LDX   #<FSCCOMMAND
            LDY   #>FSCCOMMAND
            JSR   CLILOOKUP
            BEQ   FSCNULL             ; Matched, return
            JSR   LPTRtoXY            ; Fall through to *RUN

* OSFSC 04 - *RUN filename
* XY=>pathname
*
FSCRUN      STX   OSFILECB            ; Pointer to filename
            STY   OSFILECB+1
            JSR   XYtoLPTR
FSCRUNLP    LDA   (OSLPTR),Y          ; Look for command line
            INY
            CMP   #'!'
            BCS   FSCRUNLP
            DEY
            JSR   SKIPSPC
            JSR   LPTRtoXY
            STX   FSCMDLINE+0         ; Set CMDLINE=>command line
            STY   FSCMDLINE+1         ; Collected by OSARGS 1,0
            LDA   #$FF                ; OSFILE load flag
            STA   OSFILECB+6          ; Use file's address
            LDX   #<OSFILECB          ; Pointer to control block
            LDY   #>OSFILECB
            JSR   OSFILE
            JSR   :CALL
            LDA   #$00                ; A=0 on return
            RTS
:CALL       LDA   #$01                ; A=1 - entering code
            SEC                       ; Not from RESET
            JMP   (OSFILECB+6)        ; Jump to EXEC addr

* FSCREN      JMP   RENAME
*
* FSCCHDIR    JMP   CHDIR


* Display catalog entries and info
* A=5 *CAT, A=9 *EX, A=10 *INFO
* XY=>pathname
*
FSCCAT      EOR   #$06
            CLC
            ROR   A                   ; 01100000=*CAT
            ROR   A                   ; 11100000=*EX
            ROR   A                   ; 10000000=*INFO
            ROR   A                   ; b7=long info
            STA   FSAREG              ; b6=multiple items
            JSR   PARSNAME            ; Copy filename->MOSFILE
            LDA   FSAREG              ; Get ARG back
            >>>   XF2MAIN,CATALOG
STARCATRET  >>>   ENTAUX
            JSR   CHKERROR            ; See if error occurred
            JSR   FORCENL
            LDA   #0                  ; 0=OK
            RTS

* Print one block of a catalog. Called by CATALOG
* Block is in AUXBLK
PRONEBLK    >>>   ENTAUX
*
            LDA   #<AUXBLK+4          ; FSPTR1=>first entry
            STA   FSPTR1+0
            LDA   #>AUXBLK+4
            STA   FSPTR1+1
            LDA   #13                 ; Max 13 entries per block
            STA   FSNUM
:CATLP      LDY   #$00
            LDA   (FSPTR1),Y          ; Get storage type
            CMP   #$E0
*            PHP
            BCC   :NOTKEY             ; Not a key block

*            LDA   AUXBLK+4            ; Get storage type
*            AND   #$E0                ; Mask 3 MSBs
*            CMP   #$E0
*            BNE   :NOTKEY             ; Not a key block

* Print directory name
            LDA   #<:DIRM
            LDY   #>:DIRM
            JSR   PRSTR
            SEC
:NOTKEY
*            LDA   #$00
*:L1         PHA
*            PHP
            JSR   PRONEENT              ; CC=entry, CS=header
*            PLP
*            BCC   :L1X
*            JSR   OSNEWL
*:L1X
            CLC                         ; Step to next entry
            LDA   FSPTR1+0
            ADC   #$27
            STA   FSPTR1+0
            LDA   FSPTR1+1
            ADC   #$00
            STA   FSPTR1+1
            DEC   FSNUM
            BNE   :CATLP                ; Loop for all entries

*           PLA
*            INC
*            CMP   #13                 ; Number of dirents in block
*            CLC
*            BNE   :L1

            >>>   XF2MAIN,CATALOGRET
:DIRM       ASC   'Directory: '
            DB    $00

* Print a single directory entry
* On entry: A = dirent index in AUXBLK
*           CC=entry, CS=header
PRONEENT
*            PHP
*            TAX
*            LDA   #<AUXBLK+4          ; Skip pointers
*            STA   ZP3
*            LDA   #>AUXBLK+4
*            STA   ZP3+1
*:L1         CPX   #$00
*            BEQ   :S1
*            CLC
*            LDA   #$27                ; Size of dirent
*            ADC   ZP3
*            STA   ZP3
*            LDA   #$00
*            ADC   ZP3+1
*            STA   ZP3+1
*            DEX
*            BRA   :L1
:S1         LDY   #$00                ; Characters printed
            LDA   (FSPTR1),Y
            AND   #$0F                ; Len of filename
            BEQ   :CATEXIT            ; Inactive entry
            PHP
            TAX

:L2         INY
            LDA   (FSPTR1),Y
            JSR   OSWRCH              ; Print filename
            DEX
            BNE   :L2

*            LDY   #$01
*:L2         CPX   #$00
*            BEQ   :S2
*            LDA   (FSPTR1),Y
*            JSR   OSWRCH
*            DEX
*            INY
*            BRA   :L2

:S2         PLP
            BCS   :EXITHDR            ; Header entry, no info
            JSR   PRSPACES

*            LDA   #$20
*            BIT   FSAREG
*            BPL   :S2LP
*            INY
*            INY
*            INY
*            INY
*:S2LP       JSR   OSWRCH
*            INY
*            CPY   #$10
*            BCC   :S2LP

            BIT   FSAREG
            BMI   :CATINFO            ; Display object info
            JMP   PRACCESS
:EXITHDR    JMP   OSNEWL
            PLP
:CATEXIT    RTS

*            BPL   :EXIT
:CATINFO    LDY   #$21
            LDX   #3
            LDA   #0
            JSR   PRADDR0
            LDA   #'+'
            JSR   OSWRCH
            LDY   #$17
            JSR   PRADDR
            JSR   PRSPACE
            JSR   PRACCESS
            BIT   FSFLAG2
            BVS   CATLONG
            LDY   #$0A
PRSPACES    JSR   PRSPACE
            INY
            CPY   #$10
            BCC   PRSPACES
            RTS

CATLONG     LDY   #$21
            JSR   PRDATETIME
            LDY   #$18
            JSR   PRDATETIME
            JMP   OSNEWL
PRDATETIME  JSR   PRSPACE
            JSR   PRSPACE
            LDA   (FSPTR1),Y
            PHA
            AND   #$1F
            JSR   PRDECSLH   ; Day
            INY
            LDA   (FSPTR1),Y
            ASL A
            PLA
            ROL   A
            ROL   A
            ROL   A
            ROL   A
            AND   #$0F
            JSR   PRDECSLH   ; Month
            LDA   (FSPTR1),Y
            PHA
            CMP   #80
            LDA   #$19
            BCS   :CENTURY
            LDA   #$20
:CENTURY    JSR   PRHEX      ; Century
            PLA
            LSR   A
            JSR   PRDEC      ; Year
            JSR   PRSPACE
            INY
            INY
            LDA   (FSPTR1),Y
            JSR   PRDEC      ; Hour
            LDA   #$3A
            JSR   OSWRCH
            DEY
            LDA   (FSPTR1),Y ; Minute
PRDEC       TAX
            LDA   #$99
            SED
:PRDECLP    CLC
            ADC   #$01
            DEX
            BPL   :PRDECLP
            CLD
            JMP   PRHEX
PRDECSLH    JSR   PRDEC
            LDA   #'/'
            JMP   OSWRCH

*            LDY   #$00
*            LDA   (FSPTR1),Y
*            AND   #$F0
*            CMP   #$D0
*            BNE   :NOTDIR
*            LDA   #'D'
*            JSR   OSWRCH
*            JSR   PRLOCK
*            JMP   OSNEWL
*:NOTDIR     JSR   PRLOCK
*            LDA   (FSPTR1),Y
*            LSR   A
*            PHP
*            AND   #1
*            BEQ   :NOWR
*            LDA   #'W'
*            JSR   OSWRCH
*:NOWR       PLP
*            BCC   :NOWR
*            LDA   #'R'
*            JSR   OSWRCH
*:NORD
*            JSR   PRSPACE
*            LDY   #$22
*            LDX   #2
*            JSR   PRADDRLP
:EXITHDR    JMP   OSNEWL

PRACCESS    LDX   #$04              ; Offset to chars
            LDY   #$1E
            LDA   (FSPTR1),Y
            PHA
            LDY   #$00              ; Chars printed
            LDA   (FSPTR1),Y
            CMP   #$D0
            JSR   :PRACCCHR         ; 'D'
            PLA
            CPY   #$01              ; Has 'D' been printed?
            PHP
            PHA
            EOR   #$C0
            CMP   #$40
            JSR   :PRACCCHR         ; 'L'
            PLA
            PLP
            BCS   :PRACCDONE        ; Dir, skip 'WR'
            ROR   A
            PHP
            ROR   A
            JSR   :PRACCCHR         ; 'W'
            PLP
            JSR   :PRACCCHR         ; 'R'
:PRACCDONE  LDA   #$20
:PRACCLP    JSR   :PRSPACE
            CPY   #$04
            BCC   :PRACCLP
:PRSKIP     RTS
:PRACCCHR   DEX
            BCC   :PRSKIP
            LDA   ACCESSCHRS,X
:PRSPACE    INY
            JMP   OSWRCH
ACCESSCHRS  ASC   'RWLD'


*PRLOCK      LDY   #$1E
*            LDA   (FSPTR1),Y
*            CMP   #$40
*            BCS   PRADDROK
*            LDA   #'L'
*            JMP   OSWRCH

PRADDR      LDX   #3
PRADDRLP    LDA   (FSPTR1),Y
PRADDR0     JSR   OUTHEX
            DEY
            DEX
            BNE   PRADDRLP
PRADDROK    RTS
PRSPACE     LDA   #' '
PRCHAR      JMP   OSWRCH


* OSFSC $0C - RENAME function
* XY=>pathname
FSCRENAME
RENAME      JSR   PARSNAME            ; Copy Arg1->MOSFILE
            CMP   #$00                ; Length of arg1
            BEQ   :SYNTAX
            JSR   PARSLPTR2           ; Copy Arg2->MOSFILE2
            CMP   #$00                ; Length of arg2
            BEQ   :SYNTAX
            >>>   XF2MAIN,RENFILE
:SYNTAX     BRK
            DB    $DC
            ASC   'Syntax: RENAME <objspec> <objspec>'
            BRK
RENRET
            >>>   ENTAUX
            JSR   CHKERROR
            LDA   #$00
            RTS


* Handle *COPY command
* LPTR=>parameters string
*
FSCCOPY     JSR   PARSLPTR
* COPY        JSR   PARSNAME            ; Copy Arg1->MOSFILE
            CMP   #$00                ; Length of arg1
            BEQ   :SYNTAX
            JSR   PARSLPTR2           ; Copy Arg2->MOSFILE2
            CMP   #$00                ; Length of arg2
            BEQ   :SYNTAX
            >>>   XF2MAIN,COPYFILE
:SYNTAX     BRK
            DB    $DC
            ASC   'Syntax: COPY <listspec> <*objspec*>'
            BRK
COPYRET
            >>>   ENTAUX
            JSR   CHKERROR
            LDA   #$00
            RTS


* Handle *DIR/*CHDIR/*CD (directory change) command
* LPTR=>parameters string
*
FSCCHDIR    JSR   PARSLPTR
* CHDIR       JSR   PARSNAME            ; Copy filename->MOSFILE
            CMP   #$00                ; Filename length
            BNE   :HASPARM
            BRK
            DB    $DC
            ASC   'Syntax: DIR <*objspec*>'
            BRK
:HASPARM    >>>   XF2MAIN,SETPFX


* Handle *DRIVE command, which is similar
* LPTR=>parameters string
*
FSCDRIVE
DRIVE       LDA   (OSLPTR),Y          ; First char
            CMP   #$3A                ; Colon
            BNE   :ERR
            JSR   PARSLPTR            ; Copy arg->MOSFILE
            CMP   #$03                ; Check 3 char arg
            BEQ   :HASPARM
:ERR        BRK
            DB    $DC
            ASC   'Syntax: DRIVE <drv>  (eg: DRIVE :61)'
            BRK
:HASPARM    >>>   XF2MAIN,SETPFX

CHDIRRET
            >>>   ENTAUX
            JSR   CHKERROR
            CMP   #$00
            BEQ   :EXIT
            BRK
            DB    $CE                 ; Bad directory
            ASC   'Bad dir'
            BRK
:EXIT       RTS


* Handle *FREE command
* LPTR=>parameters string
*
FSCFREE
FREE        LDA   (OSLPTR),Y          ; First char
            CMP   #$3A                ; Colon
            BNE   :ERR
            JSR   PARSLPTR            ; Copy arg->MOSFILE
            CMP   #$03                ; Check 3 char arg
            BEQ   :HASPARM
:ERR        BRK
            DB    $DC
            ASC   'Syntax: FREE <drv>  (eg: FREE :61)'
            BRK
:HASPARM    >>>   XF2MAIN,DRVINFO

FREERET
            >>>   ENTAUX
            JSR   CHKERROR
            CMP   #$00
            BEQ   :NOERR
            BRK
            DB    $CE                 ; Bad directory
            ASC   'Bad dir'
            BRK
:NOERR      SEC
            LDA   AUXBLK+2            ; LSB of total blks
            SBC   AUXBLK+0            ; LSB of blocks used
            TAX
            LDA   AUXBLK+3            ; MSB of total blks
            SBC   AUXBLK+1            ; MSB of blocks used
            TAY
            LDA   #$00       ; *TO DO* b16-b23 of free

            JSR   :FREEDEC   ; Print 'AAYYXX blocks aaayyyxxx bytes '
            LDX   #<:FREE
            LDY   #>:FREE
            JSR   OUTSTR     ; Print 'free'<nl>
            LDX   AUXBLK+0   ; Blocks used
            LDY   AUXBLK+1
            LDA   #$00       ; *TO DO* b16-b23 of used
            JSR   :FREEDEC   ; Print 'AAYYXX blocks aaayyyxxx bytes '
            LDX   #<:USED
            LDY   #>:USED
            JMP   OUTSTR     ; Print 'used'<nl>

:FREEDEC    STX   FSNUM+1
            STY   FSNUM+2
            STA   FSNUM+3
* What's the maximum number of blocks?
*           JSR   PRHEX           ; Blocks b16-b23 in hex
            JSR   PR2HEX          ; Blocks b0-b15 in hex
            LDX   #<:BLOCKS
            LDY   #>:BLOCKS
            JSR   OUTSTR          ; ' blocks '
            STZ   FSNUM+0         ; FSNUM=blocks*512
            ASL   FSNUM+1
            ROL   FSNUM+2
            ROL   FSNUM+3
            LDX   #FSNUM          ; X=>number to print
            LDY   #8              ; Y=pad up to 8 digits
            JSR   PRINTDEC        ; Print it in decimal
            LDX   #<:BYTES
            LDY   #>:BYTES
            JMP   OUTSTR          ; ' bytes '
:BLOCKS     ASC   ' blocks '
            DB    0
:BYTES      ASC   ' bytes '
            DB    0
:FREE       ASC   'free'
            DB    13,0
:USED       ASC   'used'
            DB    13,0


* Handle *ACCESS command
* LPTR=>parameters string
*
FSCACCESS
ACCESS      JSR   PARSLPTR            ; Copy filename->MOSFILE
            CMP   #$00                ; Filename length
            BEQ   :SYNTAX
            JSR   PARSLPTR2           ; Copy Arg2->MOSFILE2
            >>>   XF2MAIN,SETPERM
:SYNTAX     BRK
            DB    $DC
            ASC   'Syntax: ACCESS <listspec> <L|W|R>'
            BRK

ACCRET      >>>   ENTAUX
            JSR   CHKERROR
            LDA   #$00
            RTS


* Handle *DESTROY command
* LPTR=>parameters string
*
FSCDESTROY
DESTROY     JSR   PARSLPTR            ; Copy filename->MOSFILE
            CMP   #$00                ; Filename length
            BEQ   :SYNTAX
            >>>   XF2MAIN,MULTIDEL
:SYNTAX     BRK
            DB    $DC
            ASC   'Syntax: DESTROY <listspec>'
            BRK

DESTRET     >>>   ENTAUX
            JSR   CHKERROR
            LDA   #$00
            RTS


* Handle *TITLE command
* LPTR=>parameters string
* Syntax: *TITLE (<drive>) <title>
*
FSCTITLE    RTS


* Parse filename pointed to by XY
* Write filename to MOSFILE in main memory
* Returns length in A with EQ/NE set
PARSNAME    JSR   XYtoLPTR
PARSLPTR    CLC                       ; Means parsing a filename
            JSR   GSINIT              ; Init general string handling
            PHP
            SEI                       ; Disable IRQs
            LDX   #$00                ; Length
:L1         JSR   GSREAD              ; Handle next char
            BCS   :DONE
            STA   $C004               ; Write to main mem
            STA   MOSFILE+1,X
            STA   $C005               ; Write to aux mem
            INX
            BNE   :L1
:DONE       STA   $C004               ; Write to main mem
            STX   MOSFILE             ; Length byte (Pascal)
            STA   $C005               ; Back to aux
            PLP                       ; IRQs back as they were
            TXA                       ; Return len in A
            RTS

* Parse filename pointed to by (OSLPTR),Y
* Write filename to MOSFILE2 in main memory
* Returns length in A with EQ/NE set
PARSNAME2   JSR   XYtoLPTR
PARSLPTR2   CLC                       ; Means parsing a filename
            JSR   GSINIT              ; Init gen string handling
            PHP
            SEI                       ; Disable IRQs
            LDX   #$00                ; Length
:L1         JSR   GSREAD              ; Handle next char
            BCS   :DONE
            STA   $C004               ; Write to main mem
            STA   MOSFILE2+1,X
            STA   $C005               ; Write to aux mem
            INX
            BNE   :L1
:DONE       STA   $C004               ; Write to main mem
            STX   MOSFILE2            ; Length byte (Pascal)
            STA   $C005               ; Back to aux
            PLP                       ; IRQs back as they were
            TXA                       ; Return len in A
NOTERROR    RTS


ERRNOTFND   LDA   #$46                ; File not found

* Check returned code for return code or error code
* A<$20 - return to user, A>$1F - generate error
*
CHKERROR    CMP   #$20
            BCC   NOTERROR
MKERROR
*            IF    FALSE
            BIT   $E0
            BPL   MKERROR1            ; *DEBUG*
            PHA
            LDX   #15
MKERRLP     LDA   ERRMSG,X
            STA   $100,X
            DEX
            BPL   MKERRLP
            PLA
            PHA
            LSR   A
            LSR   A
            LSR   A
            LSR   A
            JSR   ERRHEX
            STA   $108
            PLA
            JSR   ERRHEX
            STA   $109
            JMP   $100
ERRHEX      AND   #15
            CMP   #10
            BCC   ERRHEX1
            ADC   #6
ERRHEX1     ADC   #48
            RTS
ERRMSG      BRK
            DB    $FF
            ASC   'ERR: $00'
            BRK
*            FIN

* Translate ProDOS error code into BBC error
MKERROR1    CMP   #$40
            BCS   MKERROR2
            ORA   #$30       ; <$40 -> $30-$3F
MKERROR2    SEC
            SBC   #$38
            CMP   #$28
            BCC   MKERROR3   ; $28-$30, $40-$5F
            LDA   #$27       ; Otherwise I/O error
MKERROR3    ASL   A
            TAX
            LDA   MKERROR4+1,X
            PHA
            LDA   MKERROR4+0,X
            PHA
            PHP
            RTI
MKERROR4    DW    ERROR28,ERROR27,ERROR27,ERROR2B,ERROR27,ERROR27,ERROR2E,ERROR27
            DW    ERROR40,ERROR41,ERROR42,ERROR43,ERROR44,ERROR45,ERROR46,ERROR47
            DW    ERROR48,ERROR49,ERROR4A,ERROR4B,ERROR4C,ERROR4D,ERROR4E,ERROR4F
            DW    ERROR50,ERROR51,ERROR52,ERROR53,ERROR54,ERROR55,ERROR56,ERROR57
            DW    ERROR27,ERROR27,ERROR5A,ERROR5B,ERROR27,ERROR5D,ERROR5E,ERROR27

* $27 - I/O error (disk not formatted)
* $28 - No device con'd (drive not present)  Disk not present
* $29 -(GSOS Driver is busy)
* $2A - 
* $2B - Disk write protected.                Disk write protected
* $2C -(GSOS bad byte count)
* $2D -(GSOS bad block number)
* $2E - Disk switched                        Disk changed
* $2F - Device is offline (drive empty/absent)

* $40 - Invalid pathname syntax.             Bad filename
* $41 -(Duplicate filename. split from $47)  Is a directory)
* $42 - File Control Block table full.       Too many open
* $43 - Invalid reference number.            Channel not open
* $44 - Path not found. (Dir not found)      File not found
* $45 - Volume directory not found.          Disk not found
* $46 - File not found.                      File not found
* $47 - Duplicate filename. (see also $41)   File exists
* $48 - Overrun error.                       Disk full
* $49 - Volume directory full.               Directory full
* $4A - Incompatible file format.            Disk not recognised
* $4B - Unsupported storage_type.            Disk not recognised
* $4C - End of file has been encountered.    End of file
* $4D - Position out of range.               Past end of file
* $4E - Access error. (see also $4F)         RD/WR: Insufficient access
* $4F -(Access error. split from $4E)        REN/DEL/SAV: Locked
* $50 - File already open.                   Can't - file open
* $51 - Directory count error.               Broken directory
* $52 - Not a ProDOS disk.                   Disk not recognised
* $53 - Invalid parameter.                   Invalid parameter
* $54 -(Dir not empty when deleting, cf $4E) DEL: Dir not empty
* $55 - Volume Control Block table full.
* $56 - Bad buffer address.
* $57 - Duplicate volume.
* $58 - Bad volume bitmap.
* $59 -(GSOS File level out of range)
* $5A - Bit map disk address is impossible.  Sector not found
* $5B -(GSOS Bad ChangePath pathname)
* $5C -(GSOS Not executable file)
* $5D -(GSOS OS/FS not found) (EOF during load or save)  Data lost
* $5E -(Couldn't open to save)                           Can't save
* $5F -(GSOS Too many applications)
* $60+ - (GSOS)


*       AcornOS                     ProDOS
ERROR28     DW    $D200
            ASC   'Disk not present'    ; $28 - No device detected/connected
ERROR2B     DW    $C900
            ASC   'Disk write protected'; $2B - Disk write protected
ERROR2E     DW    $C800
            ASC   'Disk changed'        ; $2E - Disk switched
ERROR40     DW    $CC00
            ASC   'Bad filename'        ; $40 - Invalid pathname syntax
ERROR41     DW    $C400
            ASC   'Is a directory'      ; $41 - Duplicate filename (split from $47)
ERROR42     DW    $C000
            ASC   'Too many open'       ; $42 - File Control Block table full
ERROR43     DW    $DE00
            ASC   'Channel not open'    ; $43 - Invalid reference number
ERROR44                                 ; $44 - Path not found
ERROR46     DW    $D600
            ASC   'File not found'      ; $46 - File not found
ERROR45     DW    $D600
            ASC   'Disk not found'      ; $45 - Volume directory not found
ERROR47     DW    $C400
            ASC   'File exists'         ; $47 - Duplicate filename (see also $41)
ERROR48     DW    $C600
            ASC   'Disk full'           ; $48 - Overrun error
ERROR49     DW    $B300
            ASC   'Directory full'      ; $49 - Volume directory full
ERROR4A                                 ; $4A - Incompatible file format
ERROR4B                                 ; $4B - Unsupported storage_type
ERROR52     DW    $C800
            ASC   'Disk not recognised' ; $52 - Not a ProDOS disk
ERROR4C     DW    $DF00
            ASC   'End of file'         ; $4C - End of file has been encountered
ERROR4D     DW    $C100
            ASC   'Not open for update' ; $4D - Position out of range
ERROR4E     DW    $BD00
            ASC   'Insufficient access' ; $4E - Access error (see also $4F)
ERROR4F     DW    $C300
            ASC   'Entry locked'        ; $4F - Access error (split from $4E)
ERROR50     DW    $C200
            ASC   'Can'
            DB    $27
            ASC   't - file open'       ; $50 - File is open
ERROR51     DW    $A800
            ASC   'Broken directory'    ; $51 - Directory count error
ERROR53     DW    $DC00
            ASC   'Invalid parameter'   ; $53 - Invalid parameter
ERROR54     DW    $D400
            ASC   'Directory not empty' ; $54 - Directory not empty (split from $4E)
ERROR55     DW    $FF00
            ASC   'ProDOS: VCB full'    ; $55 - Volume Control Block table full
ERROR56     DW    $FF00
            ASC   'ProDOS: Bad addr'    ; $56 - Bad buffer address
ERROR57     DW    $FF00
            ASC   'ProDOS: Dup volm'    ; $57 - Duplicate volume
ERROR5B                                 ; spare
ERROR5A     DW    $FF00
            ASC   'Sector not found'    ; $5A - Bit map disk address is impossible
ERROR5D     DW    $CA00
            ASC   'Data lost'           ; $5D - EOF during LOAD or SAVE
ERROR5E     DW    $C000
            ASC   'Can'
            DB    $27
            ASC   't save'              ; $5E - Couldn't open for save
ERROR27     DW    $FF00
            ASC   'I/O error'           ; $27 - I/O error
            DB    $00
