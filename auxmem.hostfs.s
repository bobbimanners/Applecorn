* AUXMEM.HOSTFS.S
* (c) Bobbi 2021 GPL v3
*
* AppleMOS Host File System
* 29-Aug-2021 Generalised CHKERROR routone, checks for and
*             translates ProDOS errors into Acorn errors
* Set &E0=&FF for testing to report ProDOS errors


FSXREG      EQU   $B0
FSYREG      EQU   $B1
FSAREG      EQU   $B2
FSCTRL      EQU   FSXREG
FSPTR1      EQU   $B4
FSPTR2      EQU   $B6


* OSFIND - open/close a file for byte access
FINDHND     PHX
            PHY
            PHA
            STX   ZP1                 ; Points to filename
            STY   ZP1+1
            CMP   #$00                ; A=$00 = close
            BEQ   :CLOSE
            PHA
            LDA   #<MOSFILE+1
            STA   ZP2
            LDA   #>MOSFILE+1
            STA   ZP2+1
            LDY   #$00
:L1         LDA   (ZP1),Y
            >>>   WRTMAIN
            STA   (ZP2),Y
            >>>   WRTAUX
            INY
            CMP   #$0D                ; Carriage return
            BNE   :L1
            DEY
            >>>   WRTMAIN
            STY   MOSFILE             ; Length (Pascal string)
            >>>   WRTAUX
            PLA                       ; Recover options
            >>>   XF2MAIN,OFILE
:CLOSE      >>>   WRTMAIN
            STY   MOSFILE             ; Write file number
            >>>   WRTAUX
            >>>   XF2MAIN,CFILE
OSFINDRET
            >>>   ENTAUX
            PLY                       ; Value of A on entry
            CPY   #$00                ; Was it close?
            BNE   :S1
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
            >>>   WRTMAIN
            STY   MOSFILE             ; File reference number
            >>>   WRTAUX
            >>>   XF2MAIN,FILEPUT
OSBPUTRET
            >>>   ENTAUX
            CLC                       ; Means no error
            PLA
            PLY
            PLX
            RTS

* OSBGET - read one byte from an open file
BGETHND     PHX
            PHY
            >>>   WRTMAIN
            STY   MOSFILE             ; File ref number
            >>>   WRTAUX
            >>>   XF2MAIN,FILEGET
OSBGETRET
            >>>   ENTAUX
            CLC                       ; Means no error
            CPY   #$00                ; Check error status
            BEQ   :NOERR
            SEC                       ; Set carry for error
            BRA   :EXIT
:NOERR      CLC
:EXIT       PLY
            PLX
            RTS

* OSARGS - adjust file arguments
* On entry, A=action
*           X=>4 byte ZP control block
*           Y=file handle
ARGSHND     PHA
            PHX
            PHY
            CPY   #$00
            BNE   :HASFILE
            CMP   #$00                ; Y=0,A=0 => current file sys
            BNE   :S1
            PLY
            PLX
            PLA
            LDA   #105                ; 105=AppleFS filing system
            RTS
:S1         CMP   #$01                ; Y=0,A=1 => addr of CLI
            BNE   :S2
* TODO: Implement this for *RUN and *command
            JSR   BEEP
            BRA   :IEXIT
:S2         CMP   #$FF                ; Y=0,A=FF => flush all files
            BNE   :IEXIT
            >>>   WRTMAIN
            STZ   MOSFILE             ; Zero means flush all
            >>>   WRTAUX
            BRA   :IFLUSH
:HASFILE    >>>   WRTMAIN
            STY   MOSFILE             ; File ref num
            STX   MOSFILE+1           ; Pointer to ZP control block
            >>>   WRTAUX
            CMP   #$00                ; Y!=0,A=0 => read seq ptr
            BNE   :S3
            >>>   WRTMAIN
            STZ   MOSFILE+2           ; 0 means get pos
            >>>   WRTAUX
            >>>   XF2MAIN,TELL
:IEXIT      BRA   :IEXIT2
:IFLUSH     BRA   :FLUSH
:S3         CMP   #$01                ; Y!=0,A=1 => write seq ptr
            BNE   :S4
            >>>   WRTMAIN
            LDA   $00,X
            STA   MOSFILE+2
            LDA   $01,X
            STA   MOSFILE+3
            LDA   $02,X
            STA   MOSFILE+4
            >>>   WRTAUX
            >>>   XF2MAIN,SEEK
:IEXIT2     BRA   :EXIT
:S4         CMP   #$02                ; Y!=0,A=2 => read file len
            BNE   :S5
            >>>   WRTMAIN
            STA   MOSFILE+2           ; Non-zero means get len
            >>>   WRTAUX
            >>>   XF2MAIN,TELL
:S5         CMP   #$FF                ; Y!=0,A=FF => flush file
            BNE   :EXIT
:FLUSH      >>>   XF2MAIN,FLUSH
:EXIT       PLY
            PLX
            PLA
            RTS
OSARGSRET
            >>>   ENTAUX
            PLY
            PLX
            PLA
            RTS


* OSFILE - perform actions on entire files
* On entry, A=action
*           XY=>control block
* On exit,  A=preserved if unimplemented
*           A=0 object not found (not load/save)
*           A=1 file found
*           A=2 directory found
*           XY  preserved
*               control block updated
FILEHND     PHX
            PHY
            PHA

            STX   ZP1                 ; LSB of parameter block
            STX   CBPTR
            STY   ZP1+1               ; MSB of parameter block
            STY   CBPTR+1
            LDA   #<FILEBLK
            STA   ZP2
            LDA   #>FILEBLK
            STA   ZP2+1
            LDY   #$00                ; Copy to FILEBLK in main mem
:L1         LDA   (ZP1),Y
            >>>   WRTMAIN
            STA   (ZP2),Y
            >>>   WRTAUX
            INY
            CPY   #$12
            BNE   :L1

            LDA   (ZP1)               ; Pointer to filename->ZP2
            STA   ZP2
            LDY   #$01
            LDA   (ZP1),Y
            STA   ZP2+1
            LDA   #<MOSFILE+1         ; ZP1 is dest pointer
            STA   ZP1
            LDA   #>MOSFILE+1
            STA   ZP1+1
            LDA   (ZP2)               ; Look at first char of filename
            CMP   #'9'+1
            BCS   :NOTDIGT
            CMP   #'0'
            BCC   :NOTDIGT
            LDA   #'N'                ; Prefix numeric with 'N'
            >>>   WRTMAIN
            STA   (ZP1)
            >>>   WRTAUX
            LDY   #$01                ; Increment Y
            DEC   ZP2                 ; Decrement source pointer
            LDA   ZP2
            CMP   #$FF
            BNE   :L2
            DEC   ZP2+1
            BRA   :L2
:NOTDIGT    LDY   #$00
:L2         LDA   (ZP2),Y
            >>>   WRTMAIN
            STA   (ZP1),Y
            >>>   WRTAUX
            INY
            CMP   #$21                ; Space or Carriage return
            BCS   :L2
            DEY
            >>>   WRTMAIN
            STY   MOSFILE             ; Length (Pascal string)
            >>>   WRTAUX

            PLA                       ; Get action back
            PHA
            BEQ   :SAVE               ; A=00 -> SAVE
            CMP   #$FF
            BEQ   :LOAD               ; A=FF -> LOAD
            CMP   #$06
            BEQ   :DELETE             ; A=06 -> DELETE
*            BCC   :INFO               ; A=01-05 -> INFO
            CMP   #$08
            BEQ   :MKDIR              ; A=08 -> MKDIR
*            LDA   #<OSFILEM           ; If not implemented, print msg
*            LDY   #>OSFILEM
*            JSR   PRSTR
*            PLA
*            PHA
*            JSR   OUTHEX
*            LDA   #<OSFILEM2
*            LDY   #>OSFILEM2
*            JSR   PRSTR
            PLA                       ; Not implemented, return unchanged
            PLY
            PLX
            RTS
:INFO
* TO DO     >>>   XF2MAIN,INFOFILE

:SAVE       >>>   XF2MAIN,SAVEFILE
:LOAD       >>>   XF2MAIN,LOADFILE
:DELETE     >>>   XF2MAIN,DELFILE
:MKDIR      >>>   XF2MAIN,MAKEDIR

* On return here, A<$20 return to caller, A>$1F ProDOS error
OSFILERET
            >>>   ENTAUX
            PHA
            LDA   CBPTR               ; Copy OSFILE CB to :CBPTR addr
            STA   ZP1
            LDA   CBPTR+1
            STA   ZP1+1
            LDY   #$02
:L3         LDA   AUXBLK,Y            ; Mainmem left it in AUXBLK
            STA   (ZP1),Y
            INY
            CPY   #18                 ; 18 bytes in control block
            BNE   :L3
            PLA
            PLY                       ; Original action
            JSR   CHKERROR            ; Check if error returned
            PLY                       ; No error, return to caller
            PLX
            RTS

*            BMI   :L4
*            PLY                       ; Discard val of A on entry
*            JMP   :EXIT               ; ret<$80, return it to user
*
*:L4         PLY                       ; Value of A on OSFILE entry
*            CPY   #$FF                ; See if command was LOAD
*            BNE   :NOTLOAD
*
*            CMP   #$80                ; No file found
*            BNE   :SL1
*            BRA   ERRNOTFND
*
*:SL1        BRK                       ; Must be A=$81
*            DB    $CA                 ; $CA = Premature end, 'Data lost'
*            ASC   'Read error'
*            BRK
*
*:NOTLOAD    CPY   #$00                ; See if command was SAVE
*            BNE   :NOTLS              ; Not LOAD or SAVE
*
*            CMP   #$80                ; Unable to create or open
*            BNE   :SS1
*            BRK
*            DB    $C0                 ; $C0 = Can't create file to save
*            ASC   'Can'
*            DB    $27
*            ASC   't save file'
*            BRK
*
*:SS1        BRK                       ; Must be A=$81
*            DB    $CA                 ; $CA = Premature end, 'Data lost'
*            ASC   'Write error'
*            BRK
*
*:NOTLS      CPY   #$06                ; See if command was DELETE
*            BNE   :NOTLSD
*
*            CMP   #$80                ; File was not found
*            BNE   :SD1
*            JMP   :EXIT
*            BRK
*            DB    $D6                 ; $D6 = File not found
*            ASC   'Not found'
*            BRK
*
*:SD1        BRK                       ; Must be A=$81
*            DB    $D6                 ; TODO: Better error code?
*            ASC   'Can'
*            DB    $27
*            ASC   't delete'
*            BRK
*
*:NOTLSD     CPY   #$08                ; Was it CDIR?
*            BNE   :EXIT
*
*            CMP   #$80                ; A=80 dir already exists
*            BEQ   :EXISTS
*            CMP   #$81                ; A=81 bad name
*            BNE   :SC1
*
*            BRK
*            DB    $CC
*            ASC   'Bad name'
*            BRK
*
*:SC1        BRK
*            DB    $C0
*            ASC   'Can'
*            DB    27
*            ASC   't create dir'
*            BRK
*
*:EXISTS     LDA   #$02                ; A=2 - dir exists or was created
*
*:EXIT       PLY
*            PLX
*            RTS

ERRNOTFND   BRK
            DB    $D6                 ; $D6 = Object not found
            ASC   'File not found'
            BRK

ERREXISTS   BRK
            DB    $C4                 ; Can't create a dir if a file is
            ASC   'File exists'       ; already there
            BRK

CBPTR       DW    $0000
OSFILEM     ASC   'OSFILE($'
            DB    $00
OSFILEM2    ASC   ')'
            DB    $00
OSFSCM      ASC   'OSFSC.'
            DB    $00


* OSFSC - miscellanous file system calls
*****************************************
*  On entry, A=action, XY=>command line
*       or   A=action, X=param1, Y=param2
*  On exit,  A=preserved if unimplemented
*            A=modified if implemented
*            X,Y=any return values
* 
* TO DO: use jump table
FSCHND
            CMP   #$40
            BEQ   FSCCHDIR
            CMP   #$41
            BEQ   FSCDRIVE
            CMP   #$42
            BEQ   FSCFREE
            CMP   #$43
            BEQ   FSCACCESS
            CMP   #$42
            BEQ   FSCTITLE

            CMP   #$0C
            BEQ   FSCREN              ; A=12 - *RENAME
            CMP   #$00
            BEQ   FSOPT               ; A=0  - *OPT
            CMP   #$01
            BEQ   CHKEOF              ; A=1  - Read EOF
            CMP   #$02
            BEQ   FSCRUN              ; A=2  - */filename
            CMP   #$04
            BEQ   FSCRUN              ; A=4  - *RUN
            CMP   #$05
            BEQ   FSCCAT              ; A=5  - *CAT
            CMP   #$09
            BEQ   FSCCAT              ; A=9  - *EX
            CMP   #$0A
            BEQ   FSCCAT              ; A=10 - *INFO
FSCDRIVE
FSCFREE
FSCACCESS
FSCTITLE
FSCUKN      PHA
            LDA   #<OSFSCM
            LDY   #>OSFSCM
            JSR   PRSTR
            PLA
FSCNULL     RTS

FSCRUN      STX   OSFILECB            ; Pointer to filename
            STY   OSFILECB+1
            LDA   #$FF                ; OSFILE load flag
            STA   OSFILECB+6          ; Use file's address
            LDX   #<OSFILECB          ; Pointer to control block
            LDY   #>OSFILECB
            JSR   OSFILE
            JSR   :CALL
            LDA   #$00                ; A=0 on return
            RTS
:CALL       JMP   (OSFILECB+6)        ; Jump to EXEC addr
            RTS

FSCREN      JSR   XYtoLPTR            ; Pointer to command line
            JSR   RENAME
            RTS

FSCCHDIR    STX   ZP1+0
            STY   ZP1+1
            LDY   #$00
            JMP   STARDIR1

* Performs OSFSC *OPT function
FSOPT       RTS                       ; No FS options for now

* Performs OSFSC Read EOF function
* File ref number is in X
CHKEOF      >>>   WRTMAIN
            STX   MOSFILE             ; File reference number
            >>>   WRTAUX
            >>>   XF2MAIN,FILEEOF
CHKEOFRET
            >>>   ENTAUX
            TAX                       ; Return code -> X
            RTS

* Perform CAT
* A=5 *CAT, A=9 *EX, A=10 *INFO
FSCCAT
            CMP   #10                 ; *TEMP*
            BEQ   CATDONE             ; *TEMP*
            ASL   A
            ASL   A
            ASL   A                   ; 0101xxxx=*CAT
            ASL   A                   ; 1001xxxx=*EX
            STA   FSAREG              ; 1010xxxx=*INFO
            >>>   XF2MAIN,CATALOG
STARCATRET
            >>>   ENTAUX
            LDA   VDUTEXTX
            BEQ   CATDONE
            JSR   OSNEWL
CATDONE     LDA   #0                  ; 0=OK
            RTS

* Print one block of a catalog. Called by CATALOG
* Block is in AUXBLK
PRONEBLK    >>>   ENTAUX
            LDA   AUXBLK+4            ; Get storage type
            AND   #$E0                ; Mask 3 MSBs
            CMP   #$E0
            BNE   :NOTKEY             ; Not a key block
            LDA   #<:DIRM
            LDY   #>:DIRM
            JSR   PRSTR
            SEC
:NOTKEY     LDA   #$00
:L1         PHA
            PHP
            JSR   PRONEENT
            PLP
            BCC   :L1X
            JSR   OSNEWL
:L1X        PLA
            INC
            CMP   #13                 ; Number of dirents in block
            CLC
            BNE   :L1
            >>>   XF2MAIN,CATALOGRET
:DIRM       ASC   'Directory: '
            DB    $00

* Print a single directory entry
* On entry: A = dirent index in AUXBLK
PRONEENT    PHP
            TAX
            LDA   #<AUXBLK+4          ; Skip pointers
            STA   ZP3
            LDA   #>AUXBLK+4
            STA   ZP3+1
:L1         CPX   #$00
            BEQ   :S1
            CLC
            LDA   #$27                ; Size of dirent
            ADC   ZP3
            STA   ZP3
            LDA   #$00
            ADC   ZP3+1
            STA   ZP3+1
            DEX
            BRA   :L1
:S1         LDY   #$00
            LDA   (ZP3),Y
            BEQ   :EXIT1              ; Inactive entry
            AND   #$0F                ; Len of filename
            TAX
            LDY   #$01
:L2         CPX   #$00
            BEQ   :S2
            LDA   (ZP3),Y
            JSR   OSWRCH
            DEX
            INY
            BRA   :L2
:S2         PLP
            BCS   :EXIT
            LDA   #$20
            BIT   FSAREG
            BPL   :S2LP
            INY
            INY
            INY
            INY
:S2LP       JSR   OSWRCH
            INY
            CPY   #$15
            BNE   :S2LP
            BIT   FSAREG
            BPL   :EXIT
            LDY   #$21
            LDX   #3
            LDA   #0
            JSR   PRADDR0
            LDA   #'+'
            JSR   OSWRCH
            LDY   #$17
            JSR   PRADDR
            JSR   PRSPACE
            LDY   #$00
            LDA   (ZP3),Y
            AND   #$F0
            CMP   #$D0
            BNE   :NOTDIR
            LDA   #'D'
            JSR   OSWRCH
            JSR   PRLOCK
            JMP   OSNEWL
:NOTDIR     JSR   PRLOCK
            LDA   (ZP3),Y
            LSR   A
            PHP
            AND   #1
            BEQ   :NOWR
            LDA   #'W'
            JSR   OSWRCH
:NOWR       PLP
            BCC   :NOWR
            LDA   #'R'
            JSR   OSWRCH
:NORD
*            JSR   PRSPACE
*            LDY   #$22
*            LDX   #2
*            JSR   PRADDRLP
            JMP   OSNEWL
:EXIT1      PLP
:EXIT       RTS

PRLOCK      LDY   #$1E
            LDA   (ZP3),Y
            CMP   #$40
            BCS   PRADDROK
            LDA   #'L'
            JMP   OSWRCH

PRADDR      LDX   #3
PRADDRLP    LDA   (ZP3),Y
PRADDR0     JSR   OUTHEX
            DEY
            DEX
            BNE   PRADDRLP
PRADDROK    RTS
PRSPACE     LDA   #' '
            JMP   OSWRCH

* Perform FSCV $0C RENAME function
* Parameter string in OSLPTR
RENAME      LDY   #$00
:ARG1       LDA   (OSLPTR),Y
            CMP   #$20                ; Space
            BEQ   :ENDARG1
            CMP   #$0D                ; Carriage return
            BEQ   :RENSYN
            INY
            >>>   WRTMAIN
            STA   MOSFILE,Y
            >>>   WRTAUX
            BRA   :ARG1
:ENDARG1    >>>   WRTMAIN
            STY   MOSFILE             ; Length of Pascal string
            >>>   WRTAUX
            JSR   SKIPSPC
            JSR   LPTRtoXY            ; Update LPTR and set Y=0
            JSR   XYtoLPTR            ; ...
:ARG2       LDA   (OSLPTR),Y
            CMP   #$20                ; Space
            BEQ   :ENDARG2
            CMP   #$0D                ; Carriage return
            BEQ   :ENDARG2
            INY
            >>>   WRTMAIN
            STA   MOSFILE2,Y
            >>>   WRTAUX
            BRA   :ARG2
:ENDARG2    >>>   WRTMAIN
            STY   MOSFILE2            ; Length of Pascal string
            >>>   WRTAUX
            >>>   XF2MAIN,RENFILE
:RENSYN     BRK
            DB    $DC
            ASC   'Syntax: RENAME <old fname> <new fname>'
            BRK
RENRET
            >>>   ENTAUX
*           JSR   CHKERROR
            JSR   CHKNOTFND
*            CMP   #$44                ; Path not found
*            BEQ   :NOTFND
*            CMP   #$45                ; Vol dir not found
*            BEQ   :NOTFND
*            CMP   #$46                ; File not found
*            BEQ   :NOTFND
            CMP   #$47                ; Duplicate filename
            BEQ   :EXISTS
            CMP   #$4E                ; Access error
            BEQ   :LOCKED
            CMP   #$00
            BNE   :OTHER              ; All other errors
            RTS
:NOTFND     JMP   ERRNOTFND
:EXISTS     JMP   ERREXISTS
:LOCKED     BRK
            DB    $C3
            ASC   'Locked'
:OTHER      BRK
            DB    $C7
            ASC   'Disc error'
            BRK

* Handle *DIR (directory change) command
* On entry, ZP1 points to command line
STARDIR     JSR   EATSPC              ; Eat leading spaces
STARDIR1
:S1         LDX   #$01
:L3         LDA   (ZP1),Y
            CMP   #$21                ; Check for CR or space
            BCC   :S2
            >>>   WRTMAIN
            STA   MOSFILE,X
            >>>   WRTAUX
            INY
            INX
            BRA   :L3
:S2         DEX
            BNE   :S3
            BRK
            DB    $DC
            ASC   'Syntax: DIR <pathname>'
            BRK
:S3         >>>   WRTMAIN
            STX   MOSFILE             ; Length byte
            >>>   WRTAUX
            >>>   XF2MAIN,SETPFX
STARDIRRET
            >>>   ENTAUX
            JSR   CHKERROR
            CMP   #$00
            BEQ   :EXIT
            BRK
            DB    $CE                 ; Bad directory
            ASC   'Bad dir'
            BRK
:EXIT       RTS

* Move this somewhere
CHKERROR    CMP   #$20
            BCS   MKERROR
            RTS

*ERREXISTS   LDA   #$47 ; File exists
*ERRNOTFND   LDA   #$46 ; File not found

MKERROR
            BIT   $E0
            BPL   MKERROR1            ; *TEST*
            PHA
            LDX   #15
MKERRLP
            LDA   ERRMSG,X
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
            STA   $109
            PLA
            JSR   ERRHEX
            STA   $10A
            JMP   $100
ERRHEX
            AND   #15
            CMP   #10
            BCC   ERRHEX1
            ADC   #6
ERRHEX1
            ADC   #48
            RTS
ERRMSG
            BRK
            DB    $FF
            ASC   'TEST: $00'
            BRK
MKERROR1
            CMP   #$40
            BCS   MKERROR2
            ADC   #$31
MKERROR2
            SEC
            SBC   #$40
            CMP   #$20
            BCC   MKERROR3
            LDA   #$18                ; I/O error
MKERROR3
            ASL   A
            TAX
            LDA   MKERROR4+1,X
            PHA
            LDA   MKERROR4+0,X
            PHA
            PHP
            RTI
MKERROR4
            DW    ERROR40,ERROR41,ERROR42,ERROR43,ERROR44,ERROR45,ERROR46,ERROR47
            DW    ERROR48,ERROR49,ERROR4A,ERROR4B,ERROR4C,ERROR4D,ERROR4E,ERROR4F
            DW    ERROR50,ERROR51,ERROR52,ERROR53,ERROR54,ERROR55,ERROR56,ERROR57
            DW    ERROR27,ERROR28,ERROR5A,ERROR5B,ERROR2B,ERROR5D,ERROR5E,ERROR2E

* $40 - Invalid pathname syntax.            Bad filename
* $41 - Duplicate filename. (additional)    Directory exists
* $42 - File Control Block table full.      Too many open
* $43 - Invalid reference number.           Channel not open
* $44 - Path not found.                     File not found
* $45 - Volume directory not found.         Disk not found
* $46 - File not found.                     File not found
* $47 - Duplicate filename. (see also $41)  File exists
* $48 - Overrun error.                      Disk full
* $49 - Volume directory full.              Directory full
* $4A - Incompatible file format.           Disk not recognised
* $4B - Unsupported storage_type.           Disk not recognised
* $4C - End of file has been encountered.   End of file
* $4D - Position out of range.              Past end of file
* $4E - Access error. (see also $4F)        RD/WR: Insufficient access
* $4F - Access error. (additional)          REN/DEL: Locked
* $50 - File is open.                       Can't - file open
* $51 - Directory count error.              Broken directory
* $52 - Not a ProDOS disk.                  Disk not recognised
* $53 - Invalid parameter.                  Invalid parameter
* $54 - (Dir not empty when deleting)       Dir not empty
* $55 - Volume Control Block table full.
* $56 - Bad buffer address.
* $57 - Duplicate volume.
* ($58) $27  - I/O error
* ($59) $28  - No device connected                 Disk not present
*  $5A ($29) - Bit map disk address is impossible. Sector not found
*  $5B  $2A  -
* ($5C) $2B  - Disk write protected.               Disk write protected
*  $5D ($2C) - (EOF during load or save)           Data lost
*  $5E ($2D) - (Couldn't open to save)             Can't save
* ($5F) $2E  - Disk switched                       Disk changed
*

*       AcornOS                     ProDOS
ERROR40     DW    $CC00
            ASC   'Bad filename'      ; $40 - Invalid pathname syntax
ERROR41     DW    $C400
            ASC   'Directory exists'  ; $41 - Duplicate filename (split from $47)
ERROR42     DW    $C000
            ASC   'Too many open'     ; $42 - File Control Block table full
ERROR43     DW    $DE00
            ASC   'Channel not open'  ; $43 - Invalid reference number
ERROR44                               ; $44 - Path not found
ERROR46     DW    $D600
            ASC   'File not found'    ; $46 - File not found
ERROR45     DW    $D600
            ASC   'Disk not found'    ; $45 - Volume directory not found
ERROR47     DW    $C400
            ASC   'File exists'       ; $47 - Duplicate filename (see also $41)
ERROR48     DW    $C600
            ASC   'Disk full'         ; $48 - Overrun error
ERROR49     DW    $B300
            ASC   'Directory full'    ; $49 - Volume directory full
ERROR4A                               ; $4A - Incompatible file format
ERROR4B                               ; $4B - Unsupported storage_type
ERROR52     DW    $C800
            ASC   'Disk not recognised'  ; $52 - Not a ProDOS disk
ERROR4C     DW    $DF00
            ASC   'End of file'       ; $4C - End of file has been encountered
ERROR4D     DW    $C100
            ASC   'Not open for update'  ; $4D - Position out of range
ERROR4E     DW    $BD00
            ASC   'Insufficient access'  ; $4E - Access error (see also $4F)
ERROR4F     DW    $C300
            ASC   'Locked'            ; $4F - Access error (split from $4E)
ERROR50     DW    $C200
            ASC   'Can'
            DB    $27
            ASC   't - file open'     ; $50 - File is open
ERROR51     DW    $A800
            ASC   'Broken directory'  ; $51 - Directory count error
ERROR53     DW    $DC00
            ASC   'Invalid parameter'  ; $53 - Invalid parameter
ERROR54     DW    $D400
            ASC   'Directory not empty'  ; $54 - Directory not empty
ERROR55     DW    $FF00
            ASC   'ProDOS: VCB full'  ; $55 - Volume Control Block table full
ERROR56     DW    $FF00
            ASC   'ProDOS: Bad addr'  ; $56 - Bad buffer address
ERROR57     DW    $FF00
            ASC   'ProDOS: Dup volm'  ; $57 - Duplicate volume
ERROR5B                               ; spare
ERROR27     DW    $FF00
            ASC   'I/O error'         ; $27 - I/O error
ERROR28     DW    $D200
            ASC   'Disk not present'  ; $28 - No device detected/connected
ERROR5A     DW    $FF00
            ASC   'Sector not found'  ; $5A - Bit map disk address is impossible
ERROR2B     DW    $C900
            ASC   'Disk write protected'  ; $2B - Disk write protected
ERROR5D     DW    $CA00
            ASC   'Data lost'         ; $5D - EOF during LOAD or SAVE
ERROR5E     DW    $C000
            ASC   'Can'
            DB    $27
            ASC   't save'            ; $5E - Couldn't open for save
ERROR2E     DW    $C800
            ASC   'Disk changed'      ; $2E - Disk switched
            DB    $00



