* MAINMEM.SVC.S
* (c) Bobbi 2021 GPLv3
*
* Main memory entry points called by Applecorn MOS running in
* aux memory.  Each entry point performs some ProDOS service,
* then returns to aux memory.

* TO DO: All OSFILE calls combined and dispatch in here
*        All start with PREPATH, UPDFB, COPYFB then branch
*        to relevent routine.

INFOFILE     >>>   ENTMAIN
             JSR   PREPATH            ; Preprocess path
             JSR   UPDFB              ; Update FILEBLK
             JSR   COPYFB             ; Copy back to aux mem
             >>>   XF2AUX,OSFILERET


* ProDOS file handling to delete a file
* Called by AppleMOS OSFILE
* Return A=0 no object, A=1 file deleted, A=2 dir deleted
*        A>$1F ProDOS error
DELFILE      >>>   ENTMAIN
             JSR   PREPATH            ; Preprocess pathname
             JSR   UPDFB              ; Update FILEBLK
             JSR   COPYFB             ; Copy back to aux mem
             PHA                      ; Save object type
             JSR   DODELETE
             BCC   :DELETED
             PLX                      ; Drop object
             JSR   CHKNOTFND
             PHA
:DELETED     PLA                      ; Get object back
:EXIT        >>>   XF2AUX,OSFILERET

DODELETE     LDA   #<MOSFILE          ; Attempt to destroy file
             STA   DESTPL+1
             LDA   #>MOSFILE
             STA   DESTPL+2
             JSR   MLI
             DB    DESTCMD
             DW    DESTPL
             RTS

* ProDOS file handling to create a directory
* Invoked by AppleMOS OSFILE
* Return A=02 on success (ie: 'directory')
*        A>$1F ProDOS error, translated by OSFILE handler
MAKEDIR      >>>   ENTMAIN
             JSR   PREPATH            ; Preprocess pathname
             JSR   UPDFB              ; Update FILEBLK
             JSR   COPYFB             ; Copy back to aux mem
             CMP   #$02
             BEQ   :EXIT              ; Dir already exists
             LDA   #$0D               ; 'Directory'
             STA   CREATEPL+7         ; ->Storage type
             LDA   #$0F               ; 'Directory'
             STA   CREATEPL+4         ; ->File type
             STZ   CREATEPL+5         ; Aux type LSB
             STZ   CREATEPL+6         ; Aux type MSB
             LDA   #$C3               ; Default permissions
             STA   CREATEPL+3
             JSR   CRTFILE            ; Create MOSFILE
             BCS   :EXIT              ; Failed, exit with ProDOS result
             JSR   UPDFB              ; Update FILEBLK
             JSR   COPYFB             ; Copy FILEBLK to aux mem
             LDA   #$02               ; Success, $02=dir created
:EXIT        >>>   XF2AUX,OSFILERET

* ProDOS file handling to rename a file
RENFILE      >>>   ENTMAIN
             JSR   PREPATH            ; Preprocess arg1
             JSR   MFtoTMP            ; Stash arg1
             JSR   COPYMF21           ; Copy arg2
             JSR   PREPATH            ; Preprocess arg2
             JSR   COPYMF12           ; Put it back in MOSFILE2
             JSR   TMPtoMF            ; Recover arg1->MOSFILE
             LDA   #<MOSFILE
             STA   RENPL+1
             LDA   #>MOSFILE
             STA   RENPL+2
             LDA   #<MOSFILE2
             STA   RENPL+3
             LDA   #>MOSFILE2
             STA   RENPL+4
             JSR   MLI
             DB    RENCMD
             DW    RENPL
             >>>   XF2AUX,RENRET

* ProDOS file handling for file copying
* Returns with ProDOS error code in A
COPYFILE     >>>   ENTMAIN
             JSR   MFtoTMP            ; Swap MOSFILE & MOSFILE2
             JSR   COPYMF21
             JSR   TMPtoMF2
             JSR   PREPATH            ; Preprocess arg2 (in MOSFILE)
             JSR   WILDONE            ; Handle any wildcards
             JSR   EXISTS             ; See if destination exists
             STA   :DESTTYPE          ; Stash for later
             JSR   MFtoTMP            ; Swap MOSFILE & MOSFILE2 again
             JSR   COPYMF21
             JSR   TMPtoMF2
             JSR   PREPATH            ; Preprocess arg1
             SEC                      ; Force wildcard lookup
             JSR   WILDCARD           ; Handle any wildcards in arg1
             BCS   :NONE
             JSR   HASWILD
             BCC   :MAINLOOP          ; No wildcards in final segment
             LDA   :DESTTYPE          ; Wildcards, check dest type
             CMP   #$02               ; Existing directory?
             BNE   :BADDEST           ; If not, error
             BRA   :MAINLOOP          ; Source: wildcard, dest: dir
:NOWILD
:MAINLOOP
             LDA   MOSFILE2           ; Length
             STA   :OLDLEN
             JSR   EXISTS             ; See if source is file or dir
             CMP   #$02               ; Directory
             BEQ   :SKIP              ; Skip directories
             LDA   :DESTTYPE          ; Check dest type
             CMP   #$02               ; Existing directory?
             BNE   :NOTDIR
             LDY   MOSFILE2           ; Dest idx = length
             LDA   MOSFILE2,Y         ; Get last char
             CMP   #'/'               ; Is it slash?
             BEQ   :HASSLSH
             LDA   #'/'               ; Add a '/' separator
             STA   MOSFILE2+1,Y
             INY
:HASSLSH     LDX   #$00               ; Source id
:APPLOOP     CPX   MATCHBUF           ; At end?
             BEQ   :DONEAPP
             LDA   MATCHBUF+1,X       ; Appending MATCHBUF to MOSFILE2
             STA   MOSFILE2+1,Y
             INX
             INY
             BRA   :APPLOOP
:DONEAPP     STY   MOSFILE2           ; Update length
:NOTDIR      LDA   :DESTTYPE          ; Recover destination type
             JSR   COPY1FILE          ; Copy an individual file
             BCS   :COPYERR
:SKIP        JSR   WILDNEXT
             BCS   :NOMORE
             LDA   :OLDLEN            ; Restore MOSFILE2
             STA   MOSFILE2
             BRA   :MAINLOOP
             JSR   CLSDIR
:EXIT        >>>   XF2AUX,COPYRET
:NONE        JSR   CLSDIR
             LDA   #$46               ; 'File not found'
             BRA   :EXIT
:BADDEST     JSR   CLSDIR
             LDA   #$FD               ; 'Wildcards' error
             BRA   :EXIT
:NOMORE      JSR   CLSDIR
             LDA   #$00
             BRA   :EXIT
:COPYERR     PHA
             JSR   CLSDIR
             PLA
             BRA   :EXIT
:DESTTYPE    DB    $00
:OLDLEN      DB    $00

* Copy a single file
* Source is in MOSFILE, DEST in MOSFILE2
* Returns with carry set if error, carry clear otherwise
* Returns with ProDOS error code in A
* Buffer COPYBUF is used for the file copy, to avoid trashing
* directory block in RDBUF (when doing wilcard search)
COPY1FILE    LDA   #<MOSFILE
             STA   GINFOPL+1
             STA   OPENPL2+1
             LDA   #>MOSFILE
             STA   GINFOPL+2
             STA   OPENPL2+2
             JSR   GETINFO            ; GET_FILE_INFO
             BCS   :ERR
             LDA   #<MOSFILE2
             STA   GINFOPL+1
             STA   DESTPL+1
             LDA   #>MOSFILE2
             STA   GINFOPL+2
             STA   DESTPL+2
             JSR   MLI                ; DESTROY
             DB    DESTCMD
             DW    DESTPL
             LDA   #$07               ; Fix num parms in PL
             STA   GINFOPL
             LDA   #$C3               ; Default permissions
             STA   GINFOPL+3
             JSR   MLI                ; Call CREATE with ..
             DB    CREATCMD           ; .. PL from GET_FILE_INFO
             DW    GINFOPL
             LDX   #$0A               ; Num parms back as we found it
             STX   GINFOPL
             BCS   :ERR               ; Error creating dest file
             LDA   #$00               ; Look for empty slot
             JSR   FINDBUF
             STX   :BUFIDX1
             JSR   BUFADDR
             BCS   :ERR               ; No I/O bufs available
             STA   OPENPL2+3
             STY   OPENPL2+4
             JSR   MLI
             DB    OPENCMD
             DW    OPENPL2
             BCS   :ERR               ; Open error
             BRA   :S1
:ERR         SEC                      ; Report error
             RTS
:S1          LDA   OPENPL2+5          ; File ref num
             STA   RDPLCP+1
             LDX   :BUFIDX1
             STA   FILEREFS,X         ; Record the ref number
             LDA   #<MOSFILE2
             STA   OPENPL2+1
             LDA   #>MOSFILE2
             STA   OPENPL2+2
             LDA   #$00               ; Look for empty slot
             JSR   FINDBUF
             STX   :BUFIDX2
             JSR   BUFADDR
             BCS   :ERRCLS1           ; No I/O bufs available
             STA   OPENPL2+3
             STY   OPENPL2+4
             JSR   MLI
             DB    OPENCMD
             DW    OPENPL2
             BCS   :ERRCLS1
             LDA   OPENPL2+5          ; File ref num
             STA   WRTPLCP+1
             LDX   :BUFIDX2
             STA   FILEREFS,X         ; Record the ref number
:MAINLOOP    JSR   MLI                ; Read a block
             DB    READCMD
             DW    RDPLCP
             BCC   :RDOKAY
             CMP   #$4C               ; Is it EOF?
             BEQ   :EOFEXIT
             BRA   :ERRCLS2           ; Any other error
:RDOKAY      LDA   RDPLCP+6           ; Trans count MSB
             STA   WRTPLCP+4          ; Request count MSB
             LDA   RDPLCP+7           ; Trans count MSB
             STA   WRTPLCP+5          ; Request count MSB
             JSR   MLI                ; Write a block
             DB    WRITECMD
             DW    WRTPLCP
             BCS   :ERRCLS2           ; Write error
             BRA   :MAINLOOP
:EOFEXIT     CLC                      ; No error
             PHP
             LDA   #$00
             PHA
:CLOSE2      LDA   WRTPLCP+1          ; Close output file
             STA   CLSPL+1
             JSR   CLSFILE
             LDX   :BUFIDX2
             STZ   FILEREFS,X
:CLOSE1      LDA   RDPLCP+1           ; Close input file
             STA   CLSPL+1
             JSR   CLSFILE
             LDX   :BUFIDX1
             STZ   FILEREFS,X
             PLA
             PLP
             RTS
:ERRCLS1     SEC
             PHP
             PHA
             BRA   :CLOSE1
:ERRCLS2     SEC
             PHP
             PHA
             BRA   :CLOSE2
:BUFIDX1     DB    $00
:BUFIDX2     DB    $00

* ProDOS file handling for MOS OSFIND OPEN call
* Options in A: $40 'r', $80 'w', $C0 'rw'
OFILE        >>>   ENTMAIN
             PHA                      ; Preserve arg for later
             JSR   PREPATH            ; Preprocess pathname
             PLA
             PHA
             CMP   #$80               ; Is it "w"?
             BEQ   :NOWILD            ; If so, no wildcards
             JSR   WILDONE            ; Handle any wildcards
:NOWILD      JSR   EXISTS             ; See if file exists ...
             CMP   #$02               ; ... and is a directory
             BNE   :NOTDIR
             JMP   :NOTFND            ; Bail out if directory
:NOTDIR      PLA
             PHA
             CMP   #$80               ; Write mode
             BNE   :S1
             JSR   DODELETE
             LDA   #$01               ; Storage type - file
             STA   CREATEPL+7
             LDA   #$06               ; Filetype BIN
             STA   CREATEPL+4
             LDA   #<MOSFILE
             STA   OPENPL+1
             LDA   #>MOSFILE
             STA   OPENPL+2
             LDA   #$00               ; Auxtype
             STA   CREATEPL+5
             LDA   #$00
             STA   CREATEPL+6
             LDA   #$C3               ; Default permissions
             STA   CREATEPL+3
             JSR   CRTFILE            ; Create MOSFILE
:S1          LDA   #$00               ; Look for empty slot
             JSR   FINDBUF
             STX   BUFIDX
             JSR   BUFADDR
             BCS   :NOTFND
             STA   OPENPL2+3
             STY   OPENPL2+4
             LDA   #<MOSFILE
             STA   OPENPL2+1
             LDA   #>MOSFILE
             STA   OPENPL2+2
             JSR   MLI
             DB    OPENCMD
             DW    OPENPL2
             BCS   :NOTFND
             LDA   OPENPL2+5          ; File ref number
             LDX   BUFIDX
             CPX   #$FF
             BEQ   FINDEXIT
             STA   FILEREFS,X         ; Record the ref number
             BRA   FINDEXIT
:NOTFND      LDA   #$00
FINDEXIT     >>>   XF2AUX,OSFINDRET
BUFIDX       DB    $00

* ProDOS file handling for MOS OSFIND CLOSE call
CFILE        >>>   ENTMAIN
             LDA   MOSFILE            ; File ref number
             STA   CLSPL+1
             JSR   CLSFILE
             LDA   MOSFILE
             JSR   FINDBUF
             BCS   :S1
             LDA   #$00
             STA   FILEREFS,X
:S1          JMP   FINDEXIT

* ProDOS file handling for MOS OSBGET call
* Returns with char read in A and error num in Y (or 0)
FILEGET      >>>   ENTMAIN
             LDA   MOSFILE            ; File ref number
             STA   READPL2+1
             JSR   MLI
             DB    READCMD
             DW    READPL2
             BCC   :NOERR
             TAY                      ; Error number in Y
             BRA   :EXIT
:NOERR       LDY   #$00
             LDA   BLKBUF
:EXIT        >>>   XF2AUX,OSBGETRET

* ProDOS file handling for MOS OSBPUT call
* Enters with char to write in A
FILEPUT      >>>   ENTMAIN
             STA   BLKBUF             ; Char to write

             LDA   MOSFILE            ; File ref number
             STA   WRITEPL+1
             LDA   #$01               ; Bytes to write
             STA   WRITEPL+4
             LDA   #$00
             STA   WRITEPL+5
             JSR   WRTFILE
             >>>   XF2AUX,OSBPUTRET

* ProDOS file handling for OSBYTE $7F EOF
* Returns EOF status in A ($FF for EOF, $00 otherwise)
FILEEOF      >>>   ENTMAIN

             LDA   MOSFILE            ; File ref number
             STA   GEOFPL+1
             STA   GMARKPL+1
             JSR   MLI
             DB    GEOFCMD
             DW    GEOFPL
             BCS   :ISEOF             ; If error, just say EOF

             JSR   MLI
             DB    GMARKCMD
             DW    GMARKPL
             BCS   :ISEOF             ; If error, just say EOF

             LDA   GEOFPL+2           ; Subtract Mark from EOF
             SEC
             SBC   GMARKPL+2
             STA   :REMAIN
             LDA   GEOFPL+3
             SBC   GMARKPL+3
             STA   :REMAIN+1
             LDA   GEOFPL+4
             SBC   GMARKPL+4
             STA   :REMAIN+2

             LDA   :REMAIN            ; Check bytes remaining
             BNE   :NOTEOF
             LDA   :REMAIN+1
             BNE   :NOTEOF
             LDA   :REMAIN+2
             BNE   :NOTEOF
:ISEOF       LDA   #$FF
             BRA   :EXIT
:NOTEOF      LDA   #$00
:EXIT        >>>   XF2AUX,CHKEOFRET
:REMAIN      DS    3                  ; Remaining bytes

* ProDOS file handling for OSARGS flush commands
FLUSH        >>>   ENTMAIN
             LDA   MOSFILE            ; File ref number
             STA   FLSHPL+1
             JSR   MLI
             DB    FLSHCMD
             DW    FLSHPL
             >>>   XF2AUX,OSARGSRET

* ProDOS file handling for OSARGS set ptr command
SEEK         >>>   ENTMAIN
             LDA   MOSFILE            ; File ref number
             STA   GMARKPL+1          ; GET_MARK has same params
             LDA   MOSFILE+2          ; Desired offset in MOSFILE[2..4]
             STA   GMARKPL+2
             LDA   MOSFILE+3
             STA   GMARKPL+3
             LDA   MOSFILE+4
             STA   GMARKPL+4
             JSR   MLI
             DB    SMARKCMD
             DW    GMARKPL
             >>>   XF2AUX,OSARGSRET

* ProDOS file handling for OSARGS get ptr command
* and for OSARGs get length command
TELL         >>>   ENTMAIN
             LDA   MOSFILE            ; File ref number
             STA   GMARKPL+1
             LDA   MOSFILE+2          ; Mode (0=pos, otherwise len)
             CMP   #$00
             BEQ   :POS
             JSR   MLI
             DB    GEOFCMD
             DW    GMARKPL            ; MARK parms same as EOF parms
             BRA   :S1
:POS         JSR   MLI
             DB    GMARKCMD
             DW    GMARKPL
:S1          LDX   MOSFILE+1          ; Pointer to ZP control block
             BCS   :ERR
             >>>   ALTZP              ; Alt ZP & Alt LC on
             LDA   GMARKPL+2
             STA   $00,X
             LDA   GMARKPL+3
             STA   $01,X
             LDA   GMARKPL+4
             STA   $02,X
             STZ   $03,X
             >>>   MAINZP             ; Alt ZP off, ROM back in
:EXIT        >>>   XF2AUX,OSARGSRET
:ERR         LDX   MOSFILE+1          ; Address of ZP control block
             >>>   ALTZP              ; Alt ZP & Alt LC on
             STZ   $00,X
             STZ   $01,X
             STZ   $02,X
             STZ   $03,X
             >>>   MAINZP             ; Alt ZP off, ROM back in
             BRA   :EXIT


* ProDOS file handling for MOS OSFILE LOAD call
* Invoked by AppleMOS OSFILE
* Return A=01 if successful (meaning 'file')
*        A>$1F ProDOS error, translated by FILERET
LOADFILE     >>>   ENTMAIN
             JSR   PREPATH            ; Preprocess pathname
             JSR   WILDONE            ; Handle any wildcards
             JSR   EXISTS             ; See if it exists ...
             CMP   #$01               ; ... and is a file
             BEQ   :ISFILE
             JMP   :NOTFND
:ISFILE      STZ   :BLOCKS
             LDA   #<MOSFILE
             STA   OPENPL+1
             LDA   #>MOSFILE
             STA   OPENPL+2
             JSR   OPENFILE
             BCS   :NOTFND            ; File not found
:L1          LDA   OPENPL+5           ; File ref number
             STA   READPL+1
             JSR   RDFILE
             BCC   :S1
             CMP   #$4C               ; EOF
             BEQ   :EOF
             BRA   :READERR
:S1          LDA   #<BLKBUF
             STA   A1L
             LDA   #>BLKBUF
             STA   A1H
             CLC
             LDA   #<BLKBUF
             ADC   READPL+6           ; LSB of trans count
             STA   A2L
             LDA   #>BLKBUF
             ADC   READPL+7           ; MSB of trans count
             STA   A2H
             LDA   FBEXEC             ; If FBEXEC is zero, use addr
             CMP   #$00               ; in the control block
             BEQ   :CBADDR
             LDA   #<MOSFILE          ; Otherwise use file addr
             STA   GINFOPL+1
             LDA   #>MOSFILE
             STA   GINFOPL+2
             JSR   GETINFO            ; GET_FILE_INFO
             BCS   :READERR
             LDA   GINFOPL+5          ; Aux type LSB
             STA   FBLOAD+0
             LDA   GINFOPL+6          ; Aux type MSB
             STA   FBLOAD+1
:CBADDR      LDA   FBLOAD
             STA   A4L
             STA   FBEXEC             ; EXEC = LOAD
             LDA   FBLOAD+1
             STA   A4H
             STA   FBEXEC+1
             LDX   :BLOCKS
:L2          CPX   #$00
             BEQ   :S2
             INC
             INC
             DEX
             BRA   :L2
:S2          STA   A4H
             SEC                      ; Main -> AUX
             JSR   AUXMOVE
             INC   :BLOCKS
             BRA   :L1
:NOTFND      LDA   #$46               ; Nothing found
             PHA
             BRA   :EXIT
:READERR     LDA   #$5D               ; Read error
             PHA
             BRA   :EOF2
:EOF         LDA   #$01               ; Success ('File')
             PHA
:EOF2        LDA   OPENPL+5           ; File ref num
             STA   CLSPL+1
             JSR   CLSFILE
:EXIT        JSR   UPDFB              ; Update FILEBLK
             JSR   COPYFB             ; Copy FILEBLK to auxmem
             PLA                      ; Get return code back
             >>>   XF2AUX,OSFILERET
:BLOCKS      DB    $00

* ProDOS file handling for MOS OSFILE SAVE call
* Invoked by AppleMOS OSFILE
* Return A=01 if successful (ie: 'file')
*        A>$1F ProDOS error translated by FILERET
SAVEFILE     >>>   ENTMAIN
             JSR   PREPATH            ; Preprocess pathname
             JSR   EXISTS             ; See if file exists ...
             CMP   #$02               ; ... and is a directory
             BNE   :NOTDIR
             LDA   $41                ; Dir exists, return $41
             PHA
             JMP   :EXIT
:NOTDIR      LDA   #<MOSFILE          ; Attempt to destroy file
             STA   DESTPL+1
             LDA   #>MOSFILE
             STA   DESTPL+2
             JSR   MLI
             DB    DESTCMD
             DW    DESTPL
             STZ   :BLOCKS
             LDA   #$01               ; Storage type - file
             STA   CREATEPL+7
             LDA   #$06               ; Filetype BIN
             STA   CREATEPL+4
             LDA   #<MOSFILE
             STA   OPENPL+1
             LDA   #>MOSFILE
             STA   OPENPL+2
             LDA   FBLOAD             ; Auxtype = load address
             STA   CREATEPL+5
             LDA   FBLOAD+1
             STA   CREATEPL+6
             LDA   #$C3               ; Default permissions
             STA   CREATEPL+3
             JSR   CRTFILE
             BCS   :FWD1              ; :CANTOPEN error
             JSR   OPENFILE
             BCS   :FWD1              ; :CANTOPEN error
             SEC                      ; Compute file length
             LDA   FBEND
             SBC   FBSTRT
             STA   :LENREM
             LDA   FBEND+1
             SBC   FBSTRT+1
             STA   :LENREM+1
:L1          LDA   FBSTRT             ; Set up for first block
             STA   A1L
             STA   A2L
             LDA   FBSTRT+1
             STA   A1H
             STA   A2H
             INC   A2H                ; $200 = 512 bytes
             INC   A2H
             LDA   OPENPL+5           ; File ref number
             STA   WRITEPL+1
             LDA   #$00               ; 512 byte request count
             STA   WRITEPL+4
             LDA   #$02
             STA   WRITEPL+5
             LDX   :BLOCKS
:L2          CPX   #$00               ; Adjust for subsequent blks
             BEQ   :S1
             INC   A1H
             INC   A1H
             INC   A2H
             INC   A2H
             DEX
             BRA   :L2

:FWD1        BRA   :CANTOPEN          ; Forwarding call from above

:S1          LDA   :LENREM+1          ; MSB of length remaining
             CMP   #$02
             BCS   :S2                ; MSB of len >= 2 (not last)
             CMP   #$00               ; If no bytes left ...
             BNE   :S3
             LDA   :LENREM
             BNE   :S3
             BRA   :NORMALEND

:S3          LDA   FBEND              ; Adjust for last block
             STA   A2L
             LDA   FBEND+1
             STA   A2H
             LDA   :LENREM
             STA   WRITEPL+4          ; Remaining bytes to write
             LDA   :LENREM+1
             STA   WRITEPL+5

:S2          LDA   #<BLKBUF
             STA   A4L
             LDA   #>BLKBUF
             STA   A4H

             CLC                      ; Aux -> Main
             JSR   AUXMOVE

             LDA   OPENPL+5           ; File ref number
             STA   WRITEPL+1
             JSR   WRTFILE
             BCS   :WRITEERR

             BRA   :UPDLEN

:ENDLOOP     INC   :BLOCKS
             BRA   :L1

:UPDLEN      SEC                      ; Update length remaining
             LDA   :LENREM
             SBC   WRITEPL+4
             STA   :LENREM
             LDA   :LENREM+1
             SBC   WRITEPL+5
             STA   :LENREM+1
             BRA   :ENDLOOP

:CANTOPEN    LDA   #$5E               ; Can't open/create
             PHA
             BRA   :EXIT

:WRITEERR    LDA   OPENPL+5           ; File ref num
             STA   CLSPL+1
             JSR   CLSFILE
             LDA   #$5D               ; Write error
             PHA
             BRA   :EXIT

:NORMALEND   LDA   OPENPL+5           ; File ref num
             STA   CLSPL+1
             JSR   CLSFILE
             BCC   :OK                ; If close OK
             LDA   #$5D               ; Write error
             PHA
             BRA   :EXIT
:OK          LDA   #$01               ; Success ('File')
             PHA
:EXIT        JSR   UPDFB              ; Update FILEBLK
             JSR   COPYFB             ; Copy FILEBLK to aux mem
             PLA
             >>>   XF2AUX,OSFILERET
:BLOCKS      DB    $00
:LENREM      DW    $0000              ; Remaining length

* Update FILEBLK before returning to aux memory
* Returns A=object type or ProDOS error
UPDFB        LDA   #<MOSFILE
             STA   OPENPL+1
             STA   GINFOPL+1
             LDA   #>MOSFILE
             STA   OPENPL+2
             STA   GINFOPL+2
             JSR   GETINFO            ; Call GET_FILE_INFO
             BCC   :UPDFB1
             JMP   CHKNOTFND

:UPDFB1      LDA   GINFOPL+5          ; Aux type LSB
             STA   FBLOAD
             STA   FBEXEC
             LDA   GINFOPL+6          ; Aux type MSB
             STA   FBLOAD+1
             STA   FBEXEC+1
             STZ   FBLOAD+2
             STZ   FBEXEC+2
             STZ   FBLOAD+3
             STZ   FBEXEC+3
*
             LDA   GINFOPL+3          ; Access byte
             CMP   #$40               ; Locked?
             AND   #$03               ; ------wr
             PHP
             STA   FBATTR+0
             ASL   A                  ; -----wr-
             ASL   A                  ; ----wr--
             ASL   A                  ; ---wr---
             ASL   A                  ; --wr----
             PLP
             BCS   :UPDFB2
             ORA   #$08               ; --wrl---
:UPDFB2      ORA   FBATTR+0           ; --wrl-wr
             STA   FBATTR+0
*
             LDA   GINFOPL+11         ; yyyyyyym
             PHA
             ROR   A                  ; ?yyyyyyy m
             LDA   GINFOPL+10         ; mmmddddd m
             PHA
             ROR   A                  ; mmmmdddd
             LSR   A                  ; -mmmmddd
             LSR   A                  ; --mmmmdd
             LSR   A                  ; ---mmmmd
             LSR   A                  ; ----mmmm
             STA   FBATTR+2
             PLA                      ; mmmddddd
             AND   #31                ; ---ddddd
             STA   FBATTR+1
             PLA                      ; yyyyyyym
             SEC
             SBC   #81*2              ; Offset from 1981
             BCS   :UPDFB3            ; 1981-1999 -> 00-18
             ADC   #100*2             ; 2000-2080 -> 19-99
:UPDFB3      PHA                      ; yyyyyyym
             AND   #$E0               ; yyy-----
             ORA   FBATTR+1           ; yyyddddd
             STA   FBATTR+1
             PLA                      ; yyyyyyym
             AND   #$FE               ; yyyyyyy0
             ASL   A                  ; yyyyyy00
             ASL   A                  ; yyyyy000
             ASL   A                  ; yyyy0000
             ORA   FBATTR+2           ; yyyymmmm
             STA   FBATTR+2
             STZ   FBATTR+3

             JSR   OPENFILE           ; Open file
             BCS   :ERR
             LDA   OPENPL+5           ; File ref number
             STA   GMARKPL+1
             JSR   MLI                ; Call GET_EOF MLI
             DB    GEOFCMD
             DW    GMARKPL            ; MARK parms same as EOF
             LDA   GMARKPL+2
             STA   FBSIZE+0
             LDA   GMARKPL+3
             STA   FBSIZE+1
             LDA   GMARKPL+4
             STA   FBSIZE+2
             STZ   FBSIZE+3
             LDA   OPENPL+5           ; File ref number
             STA   CLSPL+1
             JSR   CLSFILE
             LDA   #$01               ; Prepare A=file
             LDX   GINFOPL+7
             CPX   #$0D               ; Is it a directory?
             BNE   :UPDFB5
             LDA   #$02               ; Return A=directory
:UPDFB5      RTS

:ERR
CHKNOTFND    CMP   #$44               ; Convert ProDOS 'not found'
             BEQ   :NOTFND            ; into result=$00
             CMP   #$45
             BEQ   :NOTFND
             CMP   #$46
             BNE   :CHKNOTFND2
:NOTFND      LDA   #$00
:CHKNOTFND2  RTS


* Quit to ProDOS
QUIT         INC   $3F4               ; Invalidate powerup byte
             STA   $C054              ; PAGE2 off
             JSR   MLI
             DB    QUITCMD
             DW    QUITPL
             RTS

* Used for *CAT, *EX and *INFO
* On entry: A=$5x *CAT, A=$9x *EX, A=$Ax *INFO
CATALOG      >>>   ENTMAIN
             AND   #$F0
             STA   CATARG             ; Stash argument
             CMP   #$A0               ; Is it *INFO?
             BNE   :NOTINFO
             JMP   INFO               ; Handle entry for *INFO
:NOTINFO     LDA   MOSFILE            ; Length of pathname
             BEQ   :NOPATH            ; If zero use prefix
             JSR   PREPATH            ; Preprocess pathname
             JSR   WILDONE            ; Handle any wildcards
             JSR   EXISTS             ; See if path exists ...
             CMP   #$01               ; ... and is a file
             BNE   :NOTFILE
             LDA   #$46               ; Not found (TO DO: err code?)
             BRA   CATEXIT
:NOTFILE     LDA   #<MOSFILE
             STA   OPENPL+1
             LDA   #>MOSFILE
             STA   OPENPL+2
             BRA   :OPEN
:NOPATH      JSR   GETPREF            ; Fetch prefix into PREFIX
             LDA   #<PREFIX
             STA   OPENPL+1
             LDA   #>PREFIX
             STA   OPENPL+2
:OPEN        JSR   OPENFILE
             BCS   CATEXIT            ; Can't open dir

CATREENTRY
             LDA   OPENPL+5           ; File ref num
             STA   READPL+1
             JSR   RDFILE
             BCC   :S1
             CMP   #$4C               ; EOF
             BEQ   :EOF
             BRA   :READERR
:S1          JSR   COPYAUXBLK
             >>>   XF2AUX,PRONEBLK
:READERR
:EOF         LDA   OPENPL+5           ; File ref num
             STA   CLSPL+1
             JSR   CLSFILE
CATEXIT      >>>   XF2AUX,STARCATRET

* PRONEBLK call returns here ...
CATALOGRET
             >>>   ENTMAIN
             LDA   CATARG
             CMP   #$A0               ; Is this an *INFO call?
             BEQ   INFOREENTRY
             BRA   CATREENTRY

CATARG       DB    $00

* Handle *INFO
INFO         JSR   PREPATH            ; Preprocess pathname
             SEC
             JSR   WILDCARD           ; Handle any wildcards
             JSR   EXISTS             ; Check matches something
             CMP   #$00
             BNE   INFOFIRST
             LDA   #$46               ; Not found (TO DO: err code?)
             BRA   CATEXIT

INFOREENTRY
             JSR   WILDNEXT2          ; Start of new block
             BCS   INFOEXIT           ; No more matches
INFOFIRST    LDA   WILDIDX
             CMP   #$FF               ; Is WILDNEXT about to read new blk?
             BEQ   :DONEBLK           ; If so, print this blk first
             JSR   WILDNEXT2
             BCS   :DONEBLK           ; If no more matches
             BRA   INFOFIRST
:DONEBLK     JSR   COPYAUXBLK
             >>>   XF2AUX,PRONEBLK

INFOEXIT     CMP   #$4C               ; EOF
             BNE   INFOCLS
             LDA   #$00               ; EOF is not an error
INFOCLS      JSR   CLSDIR             ; Be sure to close it!
             BRA   CATEXIT


* Set prefix. Used by *CHDIR to change directory
SETPFX       >>>   ENTMAIN
             JSR   PREPATH            ; Preprocess pathname
             JSR   WILDONE            ; Handle any wildcards
             BCS   :ERR
             LDA   #<MOSFILE
             STA   SPFXPL+1
             LDA   #>MOSFILE
             STA   SPFXPL+2
             JSR   MLI                ; SET_PREFIX
             DB    SPFXCMD
             DW    SPFXPL
:EXIT        >>>   XF2AUX,CHDIRRET
:ERR         LDA   #$40               ; Invalid pathname syn
             BRA   :EXIT

* Obtain info on blocks used/total blocks
DRVINFO      >>>   ENTMAIN
             JSR   PREPATH
             BCS   :ERR
             LDA   #<MOSFILE
             STA   GINFOPL+1
             LDA   #>MOSFILE
             STA   GINFOPL+2
             JSR   GETINFO            ; GET_FILE_INFO
             BCS   :EXIT
             PHA
             >>>   ALTZP              ; Alt ZP & Alt LC on
             LDA   GINFOPL+8          ; Blcks used LSB
             STA   AUXBLK
             LDA   GINFOPL+9          ; Blks used MSB
             STA   AUXBLK+1
             LDA   GINFOPL+5          ; Tot blks LSB
             STA   AUXBLK+2
             LDA   GINFOPL+6          ; Tot blks MSB
             STA   AUXBLK+3
             >>>   MAINZP             ; ALt ZP off, ROM back in
             PLA
:EXIT        >>>   XF2AUX,FREERET
:ERR         LDA   #$40               ; Invalid pathname syn
             BRA   :EXIT

* Change file permissions, for *ACCESS
* Filename in MOSFILE, flags in MOSFILE2
SETPERM      >>>   ENTMAIN
             JSR   PREPATH            ; Preprocess pathname
             BCS   :SYNERR
             CLC
             JSR   WILDCARD           ; Handle any wildcards
             BCS   :NONE
             STZ   :LFLAG
             STZ   :WFLAG
             STZ   :RFLAG
             LDX   MOSFILE2           ; Length of arg2
             INX
:L1          DEX
             CPX   #$00
             BEQ   :MAINLOOP
             LDA   MOSFILE2,X         ; Read arg2 char
             CMP   #'L'               ; L=Locked
             BNE   :S1
             STA   :LFLAG
             BRA   :L1
:S1          CMP   #'R'               ; R=Readable
             BNE   :S2
             STA   :RFLAG
             BRA   :L1
:S2          CMP   #'W'               ; W=Writable
             BNE   :ERR2              ; Bad attribute
             STA   :WFLAG
             BRA   :L1
:SYNERR      LDA   #$40               ; Invalid pathname syn
             BRA   :EXIT
:NONE        JSR   CLSDIR
             LDA   #$46               ; 'File not found'
             BRA   :EXIT
:MAINLOOP    LDA   #<MOSFILE
             STA   GINFOPL+1
             LDA   #>MOSFILE
             STA   GINFOPL+2
             JSR   GETINFO            ; GET_FILE_INFO
             BCS   :EXIT
             LDA   GINFOPL+3          ; Access byte
             AND   #$03               ; Start with R, W off
             ORA   #$C0               ; Start with dest/ren on
             LDX   :RFLAG
             BEQ   :S3
             ORA   #$01               ; Turn on read enable
:S3          LDX   :WFLAG
             BEQ   :S4
             ORA   #$02               ; Turn on write enable
:S4          LDX   :LFLAG
             BEQ   :S5
             AND   #$3D               ; Turn off destroy/ren/write
:S5          STA   GINFOPL+3          ; Access byte
             JSR   SETINFO            ; SET_FILE_INFO
             JSR   WILDNEXT
             BCS   :NOMORE
             BRA   :MAINLOOP
:EXIT        >>>   XF2AUX,ACCRET
:NOMORE      JSR   CLSDIR
             LDA   #$00
             BRA   :EXIT
:ERR2        LDA   #$53               ; Invalid parameter
             BRA   :EXIT
:LFLAG       DB    $00                ; 'L' attribute
:WFLAG       DB    $00                ; 'W' attribute
:RFLAG       DB    $00                ; 'R' attribute

* Multi file delete, for *DESTROY
* Filename in MOSFILE
MULTIDEL     >>>   ENTMAIN
             JSR   PREPATH            ; Preprocess pathname
             BCS   :SYNERR
             CLC
             JSR   WILDCARD           ; Handle any wildcards
             BCS   :NONE
             BRA   :MAINLOOP
:SYNERR      LDA   #$40               ; Invalid pathname syn
             BRA   :EXIT
:NONE        JSR   CLSDIR
             LDA   #$46               ; 'File not found'
             BRA   :EXIT
:MAINLOOP    JSR   DODELETE
             BCS   :DELERR
             JSR   WILDNEXT
             BCS   :NOMORE
             BRA   :MAINLOOP
:EXIT        >>>   XF2AUX,DESTRET
:DELERR      PHA
             JSR   CLSDIR
             PLA
             BRA   :EXIT
:NOMORE      JSR   CLSDIR
             LDA   #$00
             BRA   :EXIT

* Read mainmem from auxmem
MACHRD       LDA   $C081
             LDA   $C081
             LDA   $FBC0
             SEC
             JSR   $FE1F
             BRA   MAINRDEXIT

* Read mainmem from auxmem
MAINRDMEM    STA   A1L
             STY   A1H
             LDA   $C081
             LDA   $C081
             LDA   (A1L)
MAINRDEXIT   >>>   XF2AUX,NULLRTS     ; Back to an RTS







