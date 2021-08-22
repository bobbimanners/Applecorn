* AUXMEM.HOSTFS.S
* (c) Bobbi 2021 GPL v3
*
* AppleMOS Host File System

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
            BEQ   :DELETE             ; A=06 -> DELET
            LDA   #<OSFILEM           ; If not implemented, print msg
            LDY   #>OSFILEM
            JSR   PRSTR
            PLA
            PHA
            JSR   OUTHEX
            LDA   #<OSFILEM2
            LDY   #>OSFILEM2
            JSR   PRSTR
            PLA                       ; Not implemented, return unchanged
            PLY
            PLX
            RTS
:SAVE       >>>   XF2MAIN,SAVEFILE
:LOAD       >>>   XF2MAIN,LOADFILE
:DELETE     >>>   XF2MAIN,DELFILE
OSFILERET
            >>>   ENTAUX
            PHA
            LDA   CBPTR               ; Copy OSFILE CB to :CBPTR addr
            STA   ZP1
            LDA   CBPTR+1
            STA   ZP1+1
            LDY   #$00
:L3         LDA   AUXBLK,Y            ; Mainmem left it in AUXBLK
            STA   (ZP1),Y
            INY
            CPY   #18                 ; 18 bytes in control block
            BNE   :L3
            PLA
            PLY                       ; Value of A on OSFILE entry
            CPY   #$FF                ; LOAD
            BNE   :S4                 ; Deal with return from SAVE

            CMP   #$01                ; No file found
            BNE   :SL1
            BRK
            DB    $D6                 ; $D6 = Object not found
            ASC   'File not found'
            BRK

:SL1        CMP   #$02                ; Read error
            BNE   :SL2
            BRK
            DB    $CA                 ; $CA = Premature end, 'Data lost'
            ASC   'Read error'
            BRK

:SL2        LDA   #$01                ; Return code - file found
            BRA   :EXIT

:S4         CPY   #$00                ; Return from SAVE
            BNE   :S6
            CMP   #$01                ; Unable to create or open
            BNE   :SS1
            BRK
            DB    $C0                 ; $C0 = Can't create file to save
            ASC   'Can'
            DB    $27
            ASC   't save file'
            BRK

:SS1        CMP   #$02                ; Unable to write
            BNE   :S6
            BRK
            DB    $CA                 ; $CA = Premature end, 'Data lost'
            ASC   'Write error'
            BRK

:S6         LDA   #$00
:EXIT       PLY
            PLX
            RTS

CBPTR       DW    $0000
OSFILEM     ASC   'OSFILE($'
            DB    $00
OSFILEM2    ASC   ')'
            DB    $00

* OSFSC - miscellanous file system calls
*****************************************
*  On entry, A=action, XY=>command line
*       or   A=action, X=param1, Y=param2
*  On exit,  A=preserved if unimplemented
*            A=modified if implemented
*            X,Y=any return values
* 
FSCHND      CMP   #$00
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
            CMP   #$0C
            BEQ   FSCREN              ; A=12 - *RENAME

FSCRUN      STX   OSFILECB            ; Pointer to filename
            STY   OSFILECB+1
            LDA   #$FF                ; OSFILE load flag
            STA   OSFILECB+6          ; Use file's address
            LDX   #<OSFILECB          ; Pointer to control block
            LDY   #>OSFILECB
            JSR   OSFILE
            JMP   (OSFILECB+6)        ; Jump to EXEC addr
            RTS
FSCREN
            LDA   #<OSFSCM
            LDY   #>OSFSCM
            JSR   PRSTR
            RTS
OSFSCM      ASC   'OSFSC.'
            DB    $00

* Performs OSFSC *OPT function
FSOPT       RTS                       ; No FS options for now

* Performs OSBYTE $7F EOF function
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
FSCCAT      >>>   XF2MAIN,CATALOG
STARCATRET
            >>>   ENTAUX
            JMP   OSNEWL
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
PRONEENT    TAX
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
            BEQ   :EXIT               ; Inactive entry
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
:S2         LDA   #$20
            JSR   OSWRCH
            INY
            CPY   #$15
            BNE   :S2
:EXIT       RTS

* Handle *DIR (directory change) command
* On entry, ZP1 points to command line
STARDIR     JSR   EATSPC              ; Eat leading spaces
            BCC   :S1                 ; If no space found
            RTS                       ; No argument
:S1         LDX   #$01
:L3         LDA   (ZP1),Y
            CMP   #$0D
            BEQ   :S3
            >>>   WRTMAIN
            STA   MOSFILE,X
            >>>   WRTAUX
            INY
            INX
            BRA   :L3
:S3         DEX
            >>>   WRTMAIN
            STX   MOSFILE             ; Length byte
            >>>   WRTAUX
            >>>   XF2MAIN,SETPFX
STARDIRRET
            >>>   ENTAUX
            RTS

