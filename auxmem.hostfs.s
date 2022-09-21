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
* 29-Oct-2021 Bad *command->Bad command, bad *RUN->File not found.
*             Optimised RENAME, COPY, CHDIR, DRIVE. FREE<cr> allowed.
* 01-Oct-2021 DRIVE, CHDIR shares same code, checking moved to maincode.
* 02-Oct-2021 ACCESS uses generic access byte parsing.
*             PRACCESS shares code with ACCESS.
* 03-Oct-2021 PARSNAME checks filename length<64.


* $B0-$BF Temporary filing system workspace
* $C0-$CF Persistant filing system workspace
FSXREG       EQU   $C0
FSYREG       EQU   $C1
FSAREG       EQU   $C2
FSZPC3       EQU   $C3                       ; (unused so far)
FSCTRL       EQU   FSXREG                    ; =>control block
FSPTR1       EQU   $C4                       ; =>directory entry
FSPTR2       EQU   $C6                       ; (unused so far)
FSNUM        EQU   $C8                       ; 32-bit number, cat file count
FSACCBYTE    EQU   FSNUM+1                   ; access bits
FSZPCC       EQU   $CC                       ; (unused so far)
FSCMDLINE    EQU   $CE                       ; command line address


* OSFIND - open/close a file for byte access
FINDHND      PHX
             PHY
             PHA
             CMP   #$00                      ; A=$00 = close
             BEQ   :CLOSE
             PHA
             JSR   PARSNAME                  ; Copy filename->MOSFILE
             PLA                             ; Recover options
             >>>   XF2MAIN,OFILE
:CLOSE       >>>   XF2MAIN,CFILE             ; Pass A,Y to main code
OSFINDRET    >>>   ENTAUX
             JSR   CHKERROR                  ; Check if error returned
             PLY                             ; Value of A on entry
             BNE   :S1                       ; It wasn't close
             TYA                             ; Preserve A for close
:S1          PLY
             PLX
             RTS

* OSGBPB - Get/Put a block of bytes to/from an open file
* Supports commands A=1,2,3,4 others unsupported
GBPBHND      CMP   #4
             BCC   :S1
             RTS                             ; Not supported: regs unchanged
:S1          PHX
             PHY
             PHA
             >>>   WRTMAIN
             STX   GBPBAUXCB+0               ; Copy address of control block ..
             STY   GBPBAUXCB+1               ; .. to main mem
             >>>   WRTAUX
             JSR   XYtoLPTR                  ; Copy control block to GBPBBLK ..
             LDY   #$0C                      ; .. in main memory
             >>>   WRTMAIN
:L1          LDA   (OSLPTR),Y
             STA   GBPBBLK,Y
             DEY
             BPL   :L1
             >>>   WRTAUX
             PLA                             ; A => OSGBPB command
             >>>   XF2MAIN,GBPB
OSGBPBRET    >>>   ENTAUX
             PLY
             PLX
             PHY
             LDY   #$05                      ; Check if bytes left = 0
             LDA   (OSLPTR),Y
             BNE   :BYTESLEFT
             INY
             LDA   (OSLPTR),Y
             BNE   :BYTESLEFT
             CLC
             BRA   :S2
:BYTESLEFT   SEC                             ; Set carry if bytes left
:S2          PLY
             LDA   #$00                      ; A=0 means supported command
             RTS

* OSBPUT - write one byte to an open file
BPUTHND      PHX
             PHY
             PHA                             ; Stash char to write
             >>>   XF2MAIN,FILEPUT           ; Pass A,Y to main code
OSBPUTRET    >>>   ENTAUX
             JSR   CHKERROR
             CLC                             ; Means no error
             PLA
             PLY
             PLX
             RTS

* OSBGET - read one byte from an open file
BGETHND      PHX
             PHY
             >>>   XF2MAIN,FILEGET           ; Pass A,Y to main code
OSBGETRET    >>>   ENTAUX
             CPY   #$01
             BCC   :EXIT                     ; If no error, return CC
             LDA   #$FE
             CPY   #$4C
             BEQ   :EXIT                     ; If at EOF, return CS
             TYA
             JSR   CHKERROR
:EXIT        PLY
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
*          (A=04 Read  alloc#Y)
*          (A=05 Read  EOF#Y)
*          (A=06 Write alloc#Y)
*      Y=0  A=FF Flush all channels
*           A=00 Return filing system number in A
*           A=01 Read command line address
*          (A=02 Read NFS bugfix flag)
*          (A=03 Read LIBFS filing system)
*          (A=04 Read used disk space)
*          (A=05 Read free disk space)
* On exit,  A=0 - implemented (except ARGS 0,0)
*           A   - preserved=unimplemented
*           X,Y - preserved
*           control block updated for 'read' calls
*           control block preserved otherwise
*
ARGSHND      PHX
             PHY
             PHA
             CPY   #$00
             BNE   :HASFILE
             CMP   #$00                      ; Y=0,A=0 => current file sys
             BNE   :S1
             PLA
             LDA   #105                      ; 105=AppleFS filing system
             PLY
             PLX
             RTS

:S1          CMP   #$01                      ; Y=0,A=1 => addr of CLI
             BNE   :S2
             LDA   FSCMDLINE+0
             STA   $00,X
             LDA   FSCMDLINE+1
             STA   $01,X
             LDA   #$FF
             STA   $02,X
             STA   $03,X
             JMP   OSARGSDONE                ; Implemented

:S2          CMP   #$FF                      ; Y=0,A=FF => flush all files
             BNE   :IEXIT
             JMP   :FLUSH
:IEXIT       JMP   :EXIT                     ; Exit preserved

:HASFILE     CMP   #$00                      ; Y!=0,A=0 => read seq ptr
             BNE   :S3
             TXA
             >>>   XF2MAIN,TELL              ; A=ZP, Y=channel

:S3          CMP   #$01                      ; Y!=0,A=1 => write seq ptr
             BNE   :S4
             >>>   WRTMAIN
             STY   GMARKPL+1                 ; Write to MLI control block
             LDA   $00,X
             STA   GMARKPL+2
             LDA   $01,X
             STA   GMARKPL+3
             LDA   $02,X
             STA   GMARKPL+4
             >>>   WRTAUX
             >>>   XF2MAIN,SEEK              ; A=???, Y=channel

:S4          CMP   #$02                      ; Y!=0,A=2 => read file len
             BNE   :S5
             TXA
             >>>   XF2MAIN,SIZE              ; A=ZP, Y=channel

:S5          CMP   #$FF                      ; Y!=0,A=FF => flush file
             BNE   :EXIT
:FLUSH       >>>   XF2MAIN,FLUSH

:EXIT        PLA                             ; Unimplemented
             PLY
             PLX
             RTS

OSARGSRET    >>>   ENTAUX
             JSR   CHKERROR
OSARGSDONE   PLA
             LDA   #0                        ; Implemented
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
OSFILEMIN    EQU   $FF                       ; $FF=LOAD
OSFILEMAX    EQU   $08                       ; $08=MKDIR

FILEHND      PHX
             PHY
             PHA
             CLC
             ADC   #256-OSFILEMIN
             CMP   #OSFILEMAX+257-OSFILEMIN  ; NB: LtoR evaluation
             BCS   FILEIGNORE

             STX   FSCTRL+0                  ; FSCTRL=>control block
             STY   FSCTRL+1
             LDA   (FSCTRL)                  ; XY=>filename
             TAX
             LDY   #$01
             LDA   (FSCTRL),Y
             TAY
             JSR   PARSNAME                  ; Copy filename->MOSFILE

             LDY   #$11
             >>>   WRTMAIN
:L1          LDA   (FSCTRL),Y                ; Copy control block to auxmem
             STA   FILEBLK,Y
             DEY
             BPL   :L1
             >>>   WRTAUX
             PLA                             ; Get action back
             >>>   XF2MAIN,CALLFILE

* On return here, A<$20 return to caller, A>$1F ProDOS error
OSFILERET    >>>   ENTAUX
             JSR   CHKERROR                  ; Check if error returned
             PHA
             LDY   #$11                      ; Copy updated control block back
:L3          LDA   OSFILECB,Y                ; Mainmem left it in OSFILECB
             STA   (FSCTRL),Y
             DEY
             BPL   :L3

FILEIGNORE   PLA                             ; Returned object type
             PLY                             ; No error, return to caller
             PLX
             RTS


* FSC Command Table
*******************
* These are commands specific to the filing system that can't be
* called via OSFILE, OSFSC, etc.
*
FSCCOMMAND   ASC   'CHDIR'
             DB    $80
             DW    FSCCHDIR-1                ; CHDIR <*objspec*>, LPTR=>params
             ASC   'CD'
             DB    $80
             DW    FSCCHDIR-1                ; CD <*objspec*> , LPTR=>params
             ASC   'DIR'
             DB    $80
             DW    FSCCHDIR-1                ; DIR <*objspec*>, LPTR=>params
             ASC   'DRIVE'
             DB    $80
             DW    FSCDRIVE-1                ; DRIVE <drive>, LPTR=>params
             ASC   'FREE'
             DB    $80
             DW    FSCFREE-1                 ; FREE <drive>, LPTR=>params
             ASC   'ACCESS'
             DB    $80
             DW    FSCACCESS-1               ; ACCESS <listspec> <access>, LPTR=>params
             ASC   'TITLE'
             DB    $80
             DW    FSCTITLE-1                ; TITLE (<drive>) <title>, LPTR=>params
             ASC   'DESTROY'
             DB    $80
             DW    FSCDESTROY-1              ; DESTROY <listspec>, LPTR=>params
             ASC   'COPY'
             DB    $80
             DW    FSCCOPY-1                 ; COPY <listspec> <*objspec*>, LPTR=>params
             ASC   'TYPE'
             DB    $80
             DW    FSCTYPE-1                 ; TYPE <*objspec*>, LPTR=>params
*
             DB    $FF                       ; Terminator

* FSC Dispatch Table
********************
FSCDISPATCH  DW    FSCOPT-1                  ; A=0  - *OPT
             DW    CHKEOF-1                  ; A=1  - Read EOF
             DW    FSCRUN-1                  ; A=2  - */filename
             DW    FSC03-1                   ; A=3  - *command
             DW    FSCRUN-1                  ; A=4  - *RUN
             DW    FSCCAT-1                  ; A=5  - *CAT
             DW    FSCUKN-1                  ; A=6
             DW    FSCUKN-1                  ; A=7
             DW    FSCUKN-1                  ; A=8
             DW    FSCCAT-1                  ; A=9  - *EX
             DW    FSCCAT-1                  ; A=10 - *INFO
             DW    FSCUKN-1                  ; A=11
             DW    FSCRENAME-1               ; A=12 - *RENAME

* OSFSC - miscellanous file system calls
*****************************************
*  On entry, A=action, XY=>command line
*       or   A=action, X=param1, Y=param2
*  On exit,  A=preserved if unimplemented
*            A=0 if implemented
*            X,Y=any return values
* 
FSCHND       CMP   #13
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
FSCNULL      LDA   FSAREG
             LDY   FSYREG
             LDX   FSXREG                    ; Set EQ/NE from X
FSCUKN
FSCRET       RTS

* OSFSC 00 - *OPT function
* Entered with A=$00 and EQ/NE from X
FSCOPT       BEQ   :OPT0
             CPX   #$05
             BCS   :OPTNULL
             CPY   #$04
             BCS   :OPTNULL
             LDA   FSFLAG2
             AND   :OPTMSK-1,X
             EOR   :OPTSET-0,Y
             AND   :OPTMSK-1,X
             EOR   :OPTSET-0,Y
:OPT0        STA   FSFLAG2
:OPTNULL     RTS
:OPTMSK      DB    $3F,$CF,$F3,$FC
:OPTSET      DB    $00,$55,$AA,$FF

*FSCUKN
*            DO    DEBUG
*            PHA
*            LDA   #<OSFSCM
*            LDY   #>OSFSCM
*            JSR   PRSTR
*            PLA
*            FIN
*            RTS
*            DO    DEBUG
*OSFSCM      ASC   'OSFSC.'
*            DB    $00
*            FIN


* OSFSC 01 - Read EOF function
* X=File ref number
*
CHKEOF       TXA                             ; A=channel
             >>>   XF2MAIN,FILEEOF
CHKEOFRET    >>>   ENTAUX
             TAX                             ; Return code -> X
             TYA                             ; Y=any ProDOS error
             JMP   CHKERROR


* OSFSC 03 - *command, fall back to *RUN command
* XY=>command line
*
FSC03        JSR   XYtoLPTR
             LDX   #<FSCCOMMAND
             LDY   #>FSCCOMMAND
             JSR   CLILOOKUP
             BEQ   FSCRET                    ; Matched, return
             JSR   LPTRtoXY                  ; Fall through to *RUN
             LDA   #$FE                      ; Will become A=$05

* OSFSC 02 - */filename, OSFSC 04 - *RUN filename
* XY=>pathname
*
FSCRUN       PHA
             STX   OSFILECB+0                ; Pointer to filename
             STY   OSFILECB+1
             JSR   XYtoLPTR
FSCRUNLP     LDA   (OSLPTR),Y                ; Look for command line
             INY
             CMP   #'!'
             BCS   FSCRUNLP
             DEY
             JSR   SKIPSPC
             JSR   LPTRtoXY
             STX   FSCMDLINE+0               ; Set CMDLINE=>command line
             STY   FSCMDLINE+1               ; Collected by OSARGS 1,0
             PLA
             EOR   #$FB                      ; Convert $FE->$05, $02/$04->$Fx
             BMI   :FSCRUN2                  ; *RUN, go direct to LOAD
             JSR   :FSCCALL                  ; Do an initial INFO
             DEC   A                         ; $01->$00
             BEQ   :FSCRUN2                  ; A file, load and run it
             JMP   FSCNULL                   ; Not a file, return all preserved
:FSCRUN2     LDA   #$FF                      ; A=LOAD
             STA   OSFILECB+6                ; Use file's address
             JSR   :FSCCALL                  ; LOAD the file
             JSR   :CALLCODE                 ; Call the loaded code
             LDA   #$00                      ; A=0 on return
             RTS
:FSCCALL     LDX   #<OSFILECB                ; Pointer to control block
             LDY   #>OSFILECB
             JMP   OSFILE
:CALLCODE    LDA   #$01                      ; A=1 - entering code
             SEC                             ; Not from RESET
             JMP   (OSFILECB+6)              ; Jump to EXEC addr


* Display catalog entries and info
* A=5 *CAT, A=9 *EX, A=10 *INFO
* XY=>pathname
*
FSCCAT       EOR   #$06
             CLC
             ROR   A                         ; 01100000=*CAT
             ROR   A                         ; 11100000=*EX
             ROR   A                         ; 10000000=*INFO
             ROR   A                         ; b7=long info
             STA   FSAREG                    ; b6=multiple items
             JSR   PARSNAME                  ; Copy filename->MOSFILE
             LDA   FSAREG                    ; Get ARG back
             >>>   XF2MAIN,CATALOG
STARCATRET   >>>   ENTAUX
             JSR   CHKERROR                  ; See if error occurred
             JSR   FORCENL
             LDA   #0                        ; 0=OK
             RTS

* Print one block of a catalog. Called by CATALOG
* Block is in AUXBLK
PRONEBLK     >>>   ENTAUX
             LDA   #<AUXBLK+4                ; FSPTR1=>first entry
             STA   FSPTR1+0
             LDA   #>AUXBLK+4
             STA   FSPTR1+1
             LDA   #13                       ; Max 13 entries per block
             STA   FSNUM
:CATLP       LDY   #$00
             LDA   (FSPTR1),Y                ; Get storage type
             CMP   #$E0
             BCC   :NOTKEY                   ; Not a key block

* Print directory name
             LDA   #<:DIRM
             LDY   #>:DIRM
             JSR   PRSTR
             SEC
:NOTKEY      JSR   PRONEENT                  ; CC=entry, CS=header
             CLC                             ; Step to next entry
             LDA   FSPTR1+0
             ADC   #$27
             STA   FSPTR1+0
             LDA   FSPTR1+1
             ADC   #$00
             STA   FSPTR1+1
             DEC   FSNUM
             BNE   :CATLP                    ; Loop for all entries
             >>>   XF2MAIN,CATALOGRET
:DIRM        ASC   'Directory: '
             DB    $00

* Print a single directory entry
* On entry: A = dirent index in AUXBLK
*           CC=entry, CS=header
PRONEENT     LDY   #$00                      ; Characters printed
             LDA   (FSPTR1),Y
             AND   #$0F                      ; Len of filename
             BEQ   NULLENT                   ; Inactive entry
             PHP
             TAX
:L2          INY
             LDA   (FSPTR1),Y
             JSR   OSWRCH                    ; Print filename
             DEX
             BNE   :L2
:S2          PLP
             BCS   :EXITHDR                  ; Header entry, no info
             JSR   PRSPACES                  ; Pad after filename
             BIT   FSAREG
             BMI   :CATINFO                  ; Display object info
             JMP   PRACCESS
:EXITHDR     JMP   OSNEWL

* Print object catalog info
:CATINFO     LDY   #$21
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
             BMI   CATLONG                   ; *OPT 1,2 - detailed EX display
             LDY   #$0A
PRSPACES     JSR   PRSPACE
             INY
             CPY   #$10
             BCC   PRSPACES
NULLENT      RTS

* Print extended catalog info
CATLONG      LDY   #$21
             JSR   PRDATETIME
             LDY   #$18
             JSR   PRDATETIME
             JMP   OSNEWL
PRDATETIME   JSR   PRSPACE
             JSR   PRSPACE
             LDA   (FSPTR1),Y
             PHA
             AND   #$1F
             JSR   PRDECSLH                  ; Day
             INY
             LDA   (FSPTR1),Y
             ASL   A
             PLA
             ROL   A
             ROL   A
             ROL   A
             ROL   A
             AND   #$0F
             JSR   PRDECSLH                  ; Month
             LDA   (FSPTR1),Y
             PHA
             CMP   #80
             LDA   #$19
             BCS   :CENTURY
             LDA   #$20
:CENTURY     JSR   PRHEX                     ; Century
             PLA
             LSR   A
             JSR   PRDEC                     ; Year
             JSR   PRSPACE
             INY
             INY
             LDA   (FSPTR1),Y
             JSR   PRDEC                     ; Hour
             LDA   #$3A
             JSR   OSWRCH
             DEY
             LDA   (FSPTR1),Y                ; Minute
PRDEC        TAX
             LDA   #$99
             SED
:PRDECLP     CLC
             ADC   #$01
             DEX
             BPL   :PRDECLP
             CLD
             JMP   PRHEX
PRDECSLH     JSR   PRDEC
             LDA   #'/'
             JMP   OSWRCH

* Print object access string
PRACCESS     LDX   #$04                      ; Offset to 'D' char
             LDY   #$00
             LDA   (FSPTR1),Y
             CMP   #$D0                      ; CS=Directory
             LDY   #$1E
             LDA   (FSPTR1),Y                ; Permission byte
             LDY   #$0C                      ; Char counter
             EOR   #$C0
*            AND   #$E3              ; Keep LLB---WR
             AND   #$C3                      ; Keep LL----WR
             BCC   :PRACC1                   ; Not a directory
             AND   #$FC                      ; Drop 'WR' bits
:PRACC1      STA   FSACCBYTE
             BCS   :PRACC2                   ; Jump to print 'D'
:PRACCLP     LDA   FSACCBYTE
             AND   ACCESSBITS,X              ; Is bit set?
             BEQ   :PRACC3
:PRACC2      LDA   ACCESSCHRS,X              ; If so, print character
             JSR   OSWRCH
             INY                             ; Inc. char counter
:PRACC3      DEX
             BPL   :PRACCLP                  ; Loop for all chars
             JMP   PRSPACES                  ; Pad

*            LDX   #$04              ; Offset to chars
*            LDY   #$1E
*            LDA   (FSPTR1),Y
*            PHA
*            LDY   #$00              ; Chars printed
*            LDA   (FSPTR1),Y
*            CMP   #$D0
*            JSR   :PRACCCHR         ; 'D'
*            PLA
*            CPY   #$01              ; Has 'D' been printed?
*            PHP
*            PHA
*            EOR   #$C0
*            CMP   #$40
*            JSR   :PRACCCHR         ; 'L'
*            PLA
*            PLP
*            BCS   :PRACCDONE        ; Dir, skip 'WR'
*            ROR   A
*            PHP
*            ROR   A
*            JSR   :PRACCCHR         ; 'W'
*            PLP
*            JSR   :PRACCCHR         ; 'R'
*:PRACCDONE  LDA   #$20
*:PRACCLP    JSR   :PRSPACE
*            CPY   #$04
*            BCC   :PRACCLP
*:PRSKIP     RTS
*:PRACCCHR   DEX
*            BCC   :PRSKIP
*            LDA   ACCESSCHRS,X
*:PRSPACE    INY
*            JMP   OSWRCH

ACCESSCHRS   ASC   'RWBLD'
ACCESSBITS   DB    $01,$02,$20,$C0,$00

* Print object addresses
PRADDR       LDX   #3
PRADDRLP     LDA   (FSPTR1),Y
PRADDR0      JSR   OUTHEX
             DEY
             DEX
             BNE   PRADDRLP
PRADDROK     RTS
PRSPACE      LDA   #' '
PRCHAR       JMP   OSWRCH


* OSFSC $0C - RENAME function
* XY=>pathnames
*
FSCRENAME    JSR   PARSNAME                  ; Copy Arg1->MOSFILE
             BEQ   :SYNTAX                   ; No <oldname>
             JSR   PARSLPTR2                 ; Copy Arg2->MOSFILE2
             BEQ   :SYNTAX                   ; No <newname>
             >>>   XF2MAIN,RENFILE
:SYNTAX      BRK
             DB    $DC
             ASC   'Syntax: RENAME <objspec> <objspec>'
             BRK
* ProDOS returns $40 (Bad filename) for bad renames.
* Not easy to seperate out, so leave as Bad filename error.
ACCRET
RENRET
COPYRET
DESTRET
CHDIRRET     >>>   ENTAUX
             JMP   CHKERROR


* Handle *COPY command
* LPTR=>parameters string
*
FSCCOPY      JSR   PARSLPTR                  ; Copy Arg1->MOSFILE
             BEQ   :SYNTAX                   ; No <source>
             JSR   PARSLPTR2                 ; Copy Arg2->MOSFILE2
             BEQ   :SYNTAX                   ; No <dest>
             >>>   XF2MAIN,COPYFILE          ; Do the heavy lifting
:SYNTAX      BRK
             DB    $DC
             ASC   'Syntax: COPY <listspec> <*objspec*>'
             BRK


* Handle *DIR/*CHDIR/*CD (directory change) command
* LPTR=>parameters string
*
FSCCHDIR     JSR   PARSLPTR                  ; Copy filename->MOSFILE
             BEQ   ERRCHDIR                  ; No <dir>
             LDY   #$00                      ; Y=$00 - CHDIR
FSCCHDIR2    >>>   XF2MAIN,SETPFX
ERRCHDIR     BRK
             DB    $DC
             ASC   'Syntax: DIR <*objspec*>'
             BRK


* Handle *DRIVE command, which is similar to CHDIR
* LPTR=>parameters string
*
FSCDRIVE     JSR   PARSLPTR                  ; Copy arg->MOSFILE
             TAY                             ; Y<>$00 - DRIVE
             BNE   FSCCHDIR2                 ; Pass on as CHDIR
:SYNTAX      BRK
             DB    $DC
             ASC   'Syntax: DRIVE <drv> (eg: DRIVE :61)'
             BRK


* Handle *FREE command
* LPTR=>parameters string
* Syntax is FREE (<drv>)
*
FSCFREE      JSR   PARSLPTR                  ; Copy arg->MOSFILE
             >>>   XF2MAIN,DRVINFO
FREERET      >>>   ENTAUX
             JSR   CHKERROR
*
* Disk size is two-byte 512-byte block count
* Maximum disk size is $FFFF blocks = 1FFFF00 bytes = 33554176 bytes = 32M-512
:NOERR       SEC
             LDA   AUXBLK+2                  ; LSB of total blocks
             SBC   AUXBLK+0                  ; LSB of blocks used
             TAX                             ; X=b0-b7 of blocks free
             LDA   AUXBLK+3                  ; MSB of total blocks
             SBC   AUXBLK+1                  ; MSB of blocks used
             TAY                             ; Y=b8-b15 of blocks free
             LDA   #$00                      ; A=b16-b23 of blocks free
             JSR   :FREEDEC                  ; Print 'AAYYXX blocks aaayyyxxx bytes '
             LDX   #<:FREE
             LDY   #>:FREE
             JSR   OUTSTR                    ; Print 'free'<nl>

             LDX   AUXBLK+0                  ; X=b0-b7 of blocks used
             LDY   AUXBLK+1                  ; Y=b8-b15 of blocks used
             LDA   #$00                      ; A=b16-b23 of blocks used
             JSR   :FREEDEC                  ; Print 'AAYYXX blocks aaayyyxxx bytes '
             LDX   #<:USED
             LDY   #>:USED
             JMP   OUTSTR                    ; Print 'used'<nl>

:FREEDEC     STX   FSNUM+1
             STY   FSNUM+2
             STA   FSNUM+3
*           JSR   PRHEX           ; Blocks b16-b23 in hex
             JSR   PR2HEX                    ; Blocks b0-b15 in hex
             LDX   #<:BLOCKS
             LDY   #>:BLOCKS
             JSR   OUTSTR                    ; ' blocks '
             STZ   FSNUM+0                   ; FSNUM=blocks*512
             ASL   FSNUM+1
             ROL   FSNUM+2
             ROL   FSNUM+3
             LDX   #FSNUM                    ; X=>number to print
             LDY   #8                        ; Y=pad up to 8 digits
             JSR   PRINTDEC                  ; Print it in decimal
             LDX   #<:BYTES
             LDY   #>:BYTES
             JMP   OUTSTR                    ; ' bytes '
:BLOCKS      ASC   ' blocks '
             DB    0
:BYTES       ASC   ' bytes '
             DB    0
:FREE        ASC   'free'
             DB    13,0
:USED        ASC   'used'
             DB    13,0


* Handle *ACCESS command
* LPTR=>parameters string
*
FSCACCESS    JSR   PARSLPTR                  ; Copy filename->MOSFILE
             BEQ   :SYNTAX                   ; No filename
             STZ   FSACCBYTE                 ; Initialise access to ""
:ACCESSLP1   LDA   (OSLPTR),Y                ; Get access character
             CMP   #$0D
             BEQ   :ACCESSGO                 ; End of line, action it
             INY
             AND   #$DF                      ; Upper case
             LDX   #$04                      ; Check five chars 'DLBWR'
:ACCESSLP2   CMP   ACCESSCHRS,X
             BNE   :ACCESSNXT
             LDA   ACCESSBITS,X              ; Add this to access mask
             ORA   FSACCBYTE
             STA   FSACCBYTE
:ACCESSNXT   DEX
             BPL   :ACCESSLP2
             BMI   :ACCESSLP1                ; Check next character
:ACCESSGO    LDA   FSACCBYTE
             EOR   #$C0                      ; MOSFILE=filename, A=access mask
             >>>   XF2MAIN,SETPERM
:SYNTAX      BRK
             DB    $DC
             ASC   'Syntax: ACCESS <listspec> <L|W|R>'
             BRK


* Handle *DESTROY command
* LPTR=>parameters string
*
FSCDESTROY
DESTROY      JSR   PARSLPTR                  ; Copy filename->MOSFILE
             BEQ   :SYNTAX                   ; No filename
             >>>   XF2MAIN,MULTIDEL
:SYNTAX      BRK
             DB    $DC
             ASC   'Syntax: DESTROY <listspec>'
             BRK


* Handle *TITLE command
* LPTR=>parameters string
*
FSCTITLE     RTS

* Handle *TYPE command
* LPTR=>parameters string
*
FSCTYPE      JSR   LPTRtoXY
             PHX
             PHY
             JSR   XYtoLPTR
             JSR   PARSLPTR                  ; Just for error handling
             BEQ   :SYNTAX                   ; No filename
             PLY
             PLX
             LDA   #$FF
             JSR   FINDHND                   ; Try to open file
             CMP   #$00                      ; Was file opened?
             BEQ   :NOTFOUND
             TAY                             ; File handle in Y
:L1          JSR   BGETHND                   ; Read a byte
             BCS   :CLOSE                    ; EOF
             JSR   OSWRCH                    ; Print the character
             LDA   ESCFLAG
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

* Parse filename pointed to by XY
* Write filename to MOSFILE in main memory
* Returns length in A with EQ/NE set
PARSNAME     JSR   XYtoLPTR
PARSLPTR     CLC                             ; Means parsing a filename
             JSR   GSINIT                    ; Init general string handling
             LDX   #$00                      ; Length
:L1          JSR   GSREAD                    ; Handle next char
             BCS   :DONE
             >>>   WRTMAIN
             STA   MOSFILE+1,X
             >>>   WRTAUX
             INX
             CPX   #$40
             BNE   :L1                       ; Name not too long
             TXA                             ; $40=Bad filename
             JMP   MKERROR
:DONE        >>>   WRTMAIN
             STX   MOSFILE                   ; Length byte (Pascal)
             >>>   WRTAUX
             TXA                             ; Return len in A
             RTS

* Parse filename pointed to by (OSLPTR),Y
* Write filename to MOSFILE2 in main memory
* Returns length in A with EQ/NE set
PARSNAME2    JSR   XYtoLPTR
PARSLPTR2    CLC                             ; Means parsing a filename
             JSR   GSINIT                    ; Init gen string handling
             LDX   #$00                      ; Length
:L1          JSR   GSREAD                    ; Handle next char
             BCS   :DONE
             >>>   WRTMAIN
             STA   MOSFILE2+1,X
             >>>   WRTAUX
             INX
             CPX   #$40
             BNE   :L1                       ; Name not too long
             TXA                             ; $40=Bad filename
             JMP   MKERROR
:DONE        >>>   WRTMAIN
             STX   MOSFILE2                  ; Length byte (Pascal)
             >>>   WRTAUX
             TXA                             ; Return len in A
NOTERROR     RTS


ERRNOTFND    LDA   #$46                      ; File not found

* Check returned code for return code or error code
* A<$20 - return to user, A>$1F - generate error
*
CHKERROR     CMP   #$20
             BCC   NOTERROR
MKERROR
             DO    DEBUG
             BIT   $E0
             BPL   MKERROR1                  ; *DEBUG*
             PHA
             LDX   #15
MKERRLP      LDA   ERRMSG,X
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
ERRHEX       AND   #15
             CMP   #10
             BCC   ERRHEX1
             ADC   #6
ERRHEX1      ADC   #48
             RTS
ERRMSG       BRK
             DB    $FF
             ASC   'ERR: $00'
             BRK
             FIN

* Translate ProDOS error code into BBC error
MKERROR1     CMP   #$40
             BCS   MKERROR2
             ORA   #$30                      ; <$40 -> $30-$3F
MKERROR2     SEC
             SBC   #$38
             CMP   #$28
             BCC   MKERROR3                  ; $28-$30, $40-$5F
             LDA   #$27                      ; Otherwise I/O error
MKERROR3     ASL   A
             TAX
             LDA   MKERROR4+1,X
             PHA
             LDA   MKERROR4+0,X
             PHA
             PHP
             RTI
MKERROR4     DW    ERROR28,ERROR27,ERROR2A,ERROR2B,ERROR2C,ERROR27,ERROR2E,ERROR27
             DW    ERROR40,ERROR41,ERROR42,ERROR43,ERROR44,ERROR45,ERROR46,ERROR47
             DW    ERROR48,ERROR49,ERROR4A,ERROR4B,ERROR4C,ERROR4D,ERROR4E,ERROR4F
             DW    ERROR50,ERROR51,ERROR52,ERROR53,ERROR54,ERROR55,ERROR56,ERROR57
             DW    ERROR27,ERROR27,ERROR5A,ERROR27,ERROR27,ERROR27,ERROR5E,ERROR27

* $27 - I/O error (disk not formatted)
* $28 - No device con'd (drive not present)  Drive not present
* $29 -(GSOS Driver is busy)
* $2A -(Not a drive specifier)               DRIVE/FREE: Bad drive
* $2B - Disk write protected.                Disk write protected
* $2C - Bad byte count - file too long       File too long
* $2D -(GSOS bad block number)              (Sector not found?)
* $2E - Disk switched                        Disk changed
* $2F - Device is offline (drive empty/absent)

* $40 - Invalid pathname syntax.             Bad filename
* $41 -(Duplicate filename. split from $47)  Is a directory
* $42 - File Control Block table full.       Too many open
* $43 - Invalid reference number.            Channel not open
* $44 - Path not found. (Dir not found)      File not found
* $45 - Volume directory not found.          Disk not found
* $46 - File not found.                      File not found
* $47 - Duplicate filename. (see also $41)   File exists
* $48 - Overrun error.                       Disk full
* $49 - Volume directory full.               Directory full
* $4A - Incompatible file format.            Disk not recognised
* $4B - Unsupported storage_type.            Not a directory
* $4C - End of file has been encountered.    End of file
* $4D - Position out of range.               Past end of file
* $4E - Access error. (see also $4F)         RD/WR: Insufficient access
* $4F -(Access error. split from $4E)        REN/DEL/SAV: Locked
* $50 - File already open.                   Can't - file open
* $51 - Directory count error.               Broken directory
* $52 - Not a ProDOS disk.                   Disk not recognised
* $53 - Invalid parameter.                   Invalid parameter
* $54 -(Dir not empty when deleting, cf $4E) DEL: Directory not empty
* $55 - Volume Control Block table full. (Too many disks mounted)
* $56 - Bad buffer address.
* $57 - Duplicate volume.
* $58 - Bad volume bitmap/Not block device.
* $59 -(GSOS File level out of range)
* $5A - Bit map disk address is impossible.  Sector not found
* $5B -(GSOS Bad ChangePath pathname)
* $5C -(GSOS Not executable file)
* $5D -(GSOS OS/FS not found)
* $5E -(Destination filename has wildcards)  Wildcards
* $5F -(GSOS Too many applications)
* $60+ - (GSOS)


*           AcornOS                     ProDOS
ERROR28      DW    $D200
             ASC   'Disk not present'        ; $28 - No device detected/connected
ERROR2A      DW    $CD00
             ASC   'Bad drive'               ; $2A - Not a drive specifier
ERROR2B      DW    $C900
             ASC   'Disk write protected'    ; $2B - Disk write protected
ERROR2C      DW    $C600
             ASC   'File too big'            ; $2C - Too big to save
ERROR2E      DW    $C800
             ASC   'Disk changed'            ; $2E - Disk switched
ERROR40      DW    $CC00
             ASC   'Bad filename'            ; $40 - Invalid pathname syntax
ERROR41      DW    $C400
             ASC   'Is a directory'          ; $41 - Duplicate filename (split from $47)
ERROR42      DW    $C000
             ASC   'Too many open'           ; $42 - File Control Block table full
ERROR43      DW    $DE00
             ASC   'Channel not open'        ; $43 - Invalid reference number
ERROR44                                      ; $44 - Path not found
ERROR46      DW    $D600
             ASC   'File not found'          ; $46 - File not found
ERROR45      DW    $D600
             ASC   'Disk not found'          ; $45 - Volume directory not found
ERROR47      DW    $C400
             ASC   'File exists'             ; $47 - Duplicate filename (see also $41)
ERROR48      DW    $C600
             ASC   'Disk full'               ; $48 - Overrun error
ERROR49      DW    $B300
             ASC   'Directory full'          ; $49 - Volume directory full
ERROR4A                                      ; $4A - Incompatible file format
ERROR52      DW    $C800
             ASC   'Disk not recognised'     ; $52 - Not a ProDOS disk
ERROR4B      DW    $BE00                     ; $4B - Unsupported storage_type
             ASC   'Not a directory'
ERROR4C      DW    $DF00
             ASC   'End of file'             ; $4C - End of file has been encountered
ERROR4D      DW    $C100
             ASC   'Not open for update'     ; $4D - Position out of range
ERROR4E      DW    $BD00
             ASC   'Insufficient access'     ; $4E - Access error (see also $4F)
ERROR4F      DW    $C300
             ASC   'Entry locked'            ; $4F - Access error (split from $4E)
ERROR50      DW    $C200
             ASC   'Can'
             DB    $27
             ASC   't - file open'           ; $50 - File is open
ERROR51      DW    $A800
             ASC   'Broken directory'        ; $51 - Directory count error
ERROR53      DW    $DC00
             ASC   'Invalid parameter'       ; $53 - Invalid parameter
ERROR54      DW    $D400
             ASC   'Directory not empty'     ; $54 - Directory not empty (split from $4E)
ERROR55      DW    $FF00
             ASC   'ProDOS: VCB full'        ; $55 - Volume Control Block table full
ERROR56      DW    $FF00
             ASC   'ProDOS: Bad addr'        ; $56 - Bad buffer address
ERROR57      DW    $FF00
             ASC   'ProDOS: Dup volm'        ; $57 - Duplicate volume
ERROR5A      DW    $FF00
             ASC   'Sector not found'        ; $5A - Bit map disk address is impossible
ERROR5E      DW    $FD00
             ASC   'Wildcards'               ; $5E - Can't use wildcards in dest filename
ERROR27      DW    $FF00
             ASC   'I/O error'               ; $27 - I/O error
             DB    $00





