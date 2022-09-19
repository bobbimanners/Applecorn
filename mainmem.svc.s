* MAINMEM.SVC.S
* (c) Bobbi 2021 GPLv3
*
* Main memory entry points called by Applecorn MOS running in
* aux memory.  Each entry point performs some ProDOS service,
* then returns to aux memory.

* 12-Oct-2021 OSFIND exits with bad filename, allows OPENIN(dir),
*             exits with MFI error, returns error if no more buffers,
*             OPENOUT doesn't try to delete if nothing to delete.
* 13-Oct-2021 OSFIND implementes CLOSE#0.
* 13-Oct-2021 FIND, BGET, BPUT optimised passing registers to main.
* 13-Oct-2021 ARGS, EOF returns errors, optimised.
* 15-Oct-2021 LOADFILE updated.
* 16-Oct-2021 LOADFILE only reads object info once.
* 17-Oct-2021 SAVEFILE updated.
* 18-Oct-2021 Optimised CREATE, removed dead code, RDDATA and WRDATA.
* 23-Oct-2021 Moved all the OSFILE routines together.
*             Optimised entry and return from OSFILE routines.
*             DELETE returns 'Dir not empty' when appropriate.
* 29-Oct-2021 DRVINFO reads current drive if "".
* 01-Nov-2021 DRVINFO checks reading info on a root directory.
* 02-Nov-2021 SETPERMS passed parsed access byte.
* 03-Nov-2021 Optimised CAT/EX/INFO, DESTROY.
* *BUG* RENAME won't rename between directories, eg RENAME CHARS VDU/CHARS.


* ProDOS file handling to rename a file
RENFILE       >>>   ENTMAIN
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
COPYFILE      >>>   ENTMAIN
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
:HASSLSH      LDX   #$00               ; Source id
:APPLOOP      CPX   MATCHBUF           ; At end?
              BEQ   :DONEAPP
              LDA   MATCHBUF+1,X       ; Appending MATCHBUF to MOSFILE2
              STA   MOSFILE2+1,Y
              INX
              INY
              BRA   :APPLOOP
:DONEAPP      STY   MOSFILE2           ; Update length
:NOTDIR       LDA   :DESTTYPE          ; Recover destination type
              JSR   COPY1FILE          ; Copy an individual file
              BCS   :COPYERR
:SKIP         JSR   WILDNEXT
              BCS   :NOMORE
              LDA   :OLDLEN            ; Restore MOSFILE2
              STA   MOSFILE2
              BRA   :MAINLOOP
              JSR   CLSDIR
:EXIT         >>>   XF2AUX,COPYRET
:NONE         JSR   CLSDIR
              LDA   #$46               ; 'File not found'
              BRA   :EXIT
:BADDEST      JSR   CLSDIR
              LDA   #$5E               ; 'Wildcards' error
              BRA   :EXIT
:NOMORE       JSR   CLSDIR
              LDA   #$00
              BRA   :EXIT
:COPYERR      PHA
              JSR   CLSDIR
              PLA
              BRA   :EXIT
:DESTTYPE     DB    $00
:OLDLEN       DB    $00

* Copy a single file
* Source is in MOSFILE, DEST in MOSFILE2
* Returns with carry set if error, carry clear otherwise
* Returns with ProDOS error code in A
* Buffer COPYBUF is used for the file copy, to avoid trashing
* directory block in RDBUF (when doing wilcard search)
COPY1FILE     LDA   #<MOSFILE
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
:ERR          SEC                      ; Report error
              RTS
:S1           LDA   OPENPL2+5          ; File ref num
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
:MAINLOOP     JSR   MLI                ; Read a block
              DB    READCMD
              DW    RDPLCP
              BCC   :RDOKAY
              CMP   #$4C               ; Is it EOF?
              BEQ   :EOFEXIT
              BRA   :ERRCLS2           ; Any other error
:RDOKAY       LDA   RDPLCP+6           ; Trans count MSB
              STA   WRTPLCP+4          ; Request count MSB
              LDA   RDPLCP+7           ; Trans count MSB
              STA   WRTPLCP+5          ; Request count MSB
              JSR   MLI                ; Write a block
              DB    WRITECMD
              DW    WRTPLCP
              BCS   :ERRCLS2           ; Write error
              BRA   :MAINLOOP
:EOFEXIT      CLC                      ; No error
              PHP
              LDA   #$00
              PHA
:CLOSE2       LDA   WRTPLCP+1          ; Close output file
              STA   CLSPL+1
              JSR   CLSFILE
              LDX   :BUFIDX2
              STZ   FILEREFS,X
:CLOSE1       LDA   RDPLCP+1           ; Close input file
              STA   CLSPL+1
              JSR   CLSFILE
              LDX   :BUFIDX1
              STZ   FILEREFS,X
              PLA
              PLP
              RTS
:ERRCLS1      SEC
              PHP
              PHA
              BRA   :CLOSE1
:ERRCLS2      SEC
              PHP
              PHA
              BRA   :CLOSE2
:BUFIDX1      DB    $00
:BUFIDX2      DB    $00


* ProDOS file handling for MOS OSFIND OPEN call
* Options in A: $40 'r', $80 'w', $C0 'rw'
OFILE         >>>   ENTMAIN
              AND   #$C0               ; Keep just action bits
              PHA                      ; Preserve arg for later
              JSR   PREPATH            ; Preprocess pathname
              BCS   :JMPEXIT1          ; Bad filename
              PLA
              PHA
              CMP   #$80               ; Is it "w"?
              BEQ   :NOWILD            ; If so, no wildcards
              JSR   WILDONE            ; Handle any wildcards
:NOWILD       JSR   EXISTS             ; See if file exists ...
              TAX
              CMP   #$02               ; ... and is a directory
              BNE   :NOTDIR
              PLA                      ; Get action back
              BPL   :NOTDIR2           ; OPENIN(dir) allowed
              LDA   #$41               ; $41=Directory exists
              PHA                      ; Balance PLA
:JMPEXIT1     PLA
:JMPEXIT      JMP   FINDEXIT
:NOTDIR       PLA
:NOTDIR2      CMP   #$80               ; Write mode
              BNE   :S1
              TXA
              BEQ   :S0                ; No file, don't try to delete
              JSR   DODELETE
              BCS   FINDEXIT           ; Abort if error
:S0           LDX   #$00               ; LOAD=$0000
              LDY   #$00
              JSR   CREATEFILE
              BCS   FINDEXIT           ; Abort if error
* Looking for a buffer should be done before creating a file
:S1           LDA   #$00               ; Look for empty slot
              JSR   FINDBUF
              STX   BUFIDX
              JSR   BUFADDR
              BCS   NOBUFFS            ; No empty slot (BUFIDX=FF)
              STA   OPENPL2+3
              STY   OPENPL2+4
              LDA   #<MOSFILE
              STA   OPENPL2+1
              LDA   #>MOSFILE
              STA   OPENPL2+2
              JSR   MLI
              DB    OPENCMD
              DW    OPENPL2
              BCS   FINDEXIT
              LDA   OPENPL2+5          ; File ref number
              LDX   BUFIDX
              STA   FILEREFS,X         ; Record the ref number
FINDEXIT      JSR   CHKNOTFND          ; Convert NotFound to $00
              >>>   XF2AUX,OSFINDRET
NOBUFFS       LDA   #$42               ; $42=File buffers full
              BNE   FINDEXIT
BUFIDX        DB    $00

* ProDOS file handling for MOS OSFIND CLOSE call
* ProDOS can do CLOSE#0 but we need to manually update FILEREFS
CFILE         >>>   ENTMAIN
              LDX   #$00               ; Prepare for one file
              TYA                      ; File ref number
              BNE   :CFILE1            ; Close one file
              LDX   #$03               ; Loop through all files
:CFILE0       LDA   FILEREFS,X
              BEQ   :CFILE3            ; Not open, try next
:CFILE1       PHX
              PHA
              STA   CLSPL+1
              JSR   CLSFILE
              BCS   :CFILEERR          ; Error occured during closing
              PLA
              JSR   FINDBUF
              BNE   :CFILE2
              LDA   #$00
              STA   FILEREFS,X         ; Release buffer
:CFILE2       PLX
:CFILE3       DEX
              BPL   :CFILE0            ; Loop to close all files
              LDA   #$00
              BEQ   FINDEXIT
:CFILEERR     PLX                      ; Balance stack
              PLX
              BCS   FINDEXIT

* ProDOS file handling for MOS OSGBPB call
* A=1 : Write bytes to disk, using new seq pointer
* A=2 : Write bytes to disk, ignoring seq pointer
* A=3 : Read bytes from disk, using new seq pointer
* A=4 : Read bytes from disk, ignoring seq pointer
* All others unsupported
GBPB          >>>   ENTMAIN
*             ...
              LDY   GBPBHDL            ; File ref number
              STY   READPL2+1
:L1           JSR   MLI                ; Read one byte
              DB    READCMD
              DW    READPL2
              BCS   :ERR
              LDA   GBPBDAT+0
              STA   ZPMOS+0
              LDA   GBPBDAT+1
              STA   ZPMOS+1
              LDA   BLKBUF
              >>>   WRTAUX
              STA   (ZPMOS)            ; Store byte in aux mem
              >>>   WRTMAIN
              INC   GBPBDAT+0          ; Increment data pointer
              BNE   :S1
              INC   GBPBDAT+1
:S1           LDA   GBPBNUM+0          ; Decrement number of bytes
              BNE   :S2
              LDA   GBPBNUM+1
              BEQ   :ZERO              ; Zero remaining, done!
              DEC   GBPBNUM+1
:S2           DEC   GBPBNUM+0
              BRA   :L1
*             ...
:ERR
:ZERO         LDA   GBPBAUXCB+0        ; Copy control block back ..
              STA   ZPMOS+0            ; .. to aux memory
              LDA   GBPBAUXCB+1
              STA   ZPMOS+1
              LDY   #$0C+1
              >>>   WRTAUX
:L2           LDA   GBPBBLK,Y
              STA   (ZPMOS),Y
              DEY
              BPL   :L2
              >>>   WRTMAIN
              >>>   XF2AUX,OSGBPBRET

* ProDOS file handling for MOS OSBGET call
* Returns with char read in A and error num in Y (or 0)
FILEGET       >>>   ENTMAIN
              STY   READPL2+1          ; File ref number
              JSR   MLI
              DB    READCMD
              DW    READPL2
              TAY                      ; Error number in Y
              BCS   :EXIT
              LDY   #$00               ; 0=Ok
              LDA   BLKBUF
:EXIT         >>>   XF2AUX,OSBGETRET


* ProDOS file handling for MOS OSBPUT call
* Enters with char to write in A
FILEPUT       >>>   ENTMAIN
              STA   BLKBUF             ; Byte to write
              STY   WRITEPL+1          ; File ref number
              LDA   #$01               ; Bytes to write
              STA   WRITEPL+4
              LDA   #$00
              STA   WRITEPL+5
              JSR   WRTFILE
              BCS   :FILEPUT2
              LDA   #$00               ; 0=Ok
:FILEPUT2     >>>   XF2AUX,OSBPUTRET


* ProDOS file handling for FSC $01 called by OSBYTE $7F EOF
* Returns EOF status in A ($FF for EOF, $00 otherwise)
* A=channel to test
FILEEOF       >>>   ENTMAIN
              STA   GEOFPL+1
              STA   GMARKPL+1
              JSR   MLI
              DB    GEOFCMD
              DW    GEOFPL
              TAY
              BCS   :EXIT              ; Abort with any error
              JSR   MLI
              DB    GMARKCMD
              DW    GMARKPL
              TAY
              BCS   :EXIT              ; Abort with any error

              SEC
              LDA   GEOFPL+2           ; Subtract Mark from EOF
              SBC   GMARKPL+2
              STA   GEOFPL+2
              LDA   GEOFPL+3
              SBC   GMARKPL+3
              STA   GEOFPL+3
              LDA   GEOFPL+4
              SBC   GMARKPL+4
              STA   GEOFPL+4

              LDA   GEOFPL+2           ; Check bytes remaining
              ORA   GEOFPL+3
              ORA   GEOFPL+4
              BEQ   :ISEOF             ; EOF     -> $00
              LDA   #$FF               ; Not EOF -> $FF
:ISEOF        EOR   #$FF               ; EOF -> $FF, Not EOF ->$00
              LDY   #$00               ; 0=No error
:EXIT         >>>   XF2AUX,CHKEOFRET


* ProDOS file handling for OSARGS flush commands
FLUSH         >>>   ENTMAIN
              STY   FLSHPL+1           ; File ref number
              JSR   MLI
              DB    FLSHCMD
              DW    FLSHPL
              JMP   TELLEXIT


* ProDOS file handling for OSARGS set ptr command
* GMARKPL+1=channel, GMARKPL+2,+3,+4=offset already set
SEEK          >>>   ENTMAIN
              JSR   MLI
              DB    SMARKCMD
              DW    GMARKPL
              JMP   TELLEXIT


* ProDOS file handling for OSARGS get ptr command
* and for OSARGs get length command
* A=ZP, Y=channel
SIZE          LDX   #$02               ; $02=SIZE, Read EXT
              BNE   TELL2
TELL          LDX   #$00               ; $00=TELL, Read PTR
TELL2         STY   GMARKPL+1          ; File ref number
              PHA                      ; Pointer to zero page
              CPX   #$00               ; OSARGS parameter
              BEQ   :POS
              JSR   MLI
              DB    GEOFCMD
              DW    GMARKPL            ; MARK parms same as EOF parms
              BRA   :S1
:POS          JSR   MLI
              DB    GMARKCMD
              DW    GMARKPL
:S1           PLX                      ; Pointer to ZP control block
              BCS   TELLEXIT           ; Exit with error
              >>>   ALTZP              ; Alt ZP & Alt LC on
              LDA   GMARKPL+2
              STA   $00,X
              LDA   GMARKPL+3
              STA   $01,X
              LDA   GMARKPL+4
              STA   $02,X
              STZ   $03,X              ; Sizes are $00xxxxxx
              >>>   MAINZP             ; Alt ZP off, ROM back in
              LDA   #$00               ; 0=Ok
TELLEXIT      >>>   XF2AUX,OSARGSRET


ZPMOS         EQU   $30

* ProDOS file MOS OSFILE calls
CALLFILE      >>>   ENTMAIN
              JSR   FILEDISPATCH
              >>>   XF2AUX,OSFILERET
FILEDISPATCH  CMP   #$00
              BEQ   SVCSAVE            ; A=00 -> SAVE
              CMP   #$FF
              BEQ   SVCLOAD            ; A=FF -> LOAD
              CMP   #$06
              BEQ   DELFILE            ; A=06 -> DELETE
              BCC   INFOFILE           ; A=01-05 -> INFO
              CMP   #$08
              BEQ   MAKEDIR            ; A=08 -> MKDIR
              RTS
SVCSAVE       JMP   SAVEFILE
SVCLOAD       JMP   LOADFILE

INFOFILE      JSR   UPDPATH            ; Process path and get info
              JMP   COPYFB             ; Copy back to aux mem


* ProDOS file handling to delete a file
* Called by AppleMOS OSFILE
* Return A=0 no object, A=1 file deleted, A=2 dir deleted
*        A>$1F ProDOS error
DELFILE       JSR   UPDPATH            ; Process path and get info
              JSR   COPYFB             ; Copy back to aux mem
              PHA                      ; Save object type
              JSR   DODELETE
              BCC   :DELETED           ; Success

              TAX                      ; X=error code
              PLA                      ; Get object back
              CPX   #$4E
              BNE   :DELERROR          ; Not 'Insuff. access', return it
              LDX   #$4F               ; Change to 'Locked'

              CMP   #$02
              BNE   :DELERROR          ; Wasn't a directory, return 'Locked'
              LDA   FBATTR+0
              AND   #$08
              BNE   :DELERROR          ; Dir locked, return 'Locked'
              LDX   #$54               ; Change to 'Dir not empty'

:DELERROR     TXA
              JSR   CHKNOTFND
              PHA
:DELETED      PLA                      ; Get object back
:EXIT         RTS

DODELETE      LDA   #<MOSFILE          ; Attempt to destroy file
              STA   DESTPL+1
              LDA   #>MOSFILE
              STA   DESTPL+2
              JSR   MLI
              DB    DESTCMD
              DW    DESTPL
              RTS


* ProDOS file handling to create a directory
* Invoked by AppleMOS OSFILE
* Return A=$02 on success (ie: 'directory')
*        A>$1F ProDOS error, translated by OSFILE handler
MAKEDIR       JSR   UPDPATH            ; Process path and get info
              CMP   #$02
              BEQ   :EXIT1             ; Dir already exists

              LDA   #$0D               ; OBJT='Directory'
              STA   CREATEPL+7         ; ->Storage type
              LDA   #$0F               ; TYPE='Directory'
              LDX   #$00               ; LOAD=$0000
              LDY   #$00
              JSR   CREATEOBJ
              BCS   :EXIT              ; Failed, exit with ProDOS result
              JSR   UPDFB              ; Update FILEBLK, returns A=$02
:EXIT1        JSR   COPYFB             ; Copy FILEBLK to aux mem
:EXIT         RTS


* ProDOS file handling for MOS OSFILE LOAD call
* Invoked by AppleMOS OSFILE
* Return A=01 if successful (meaning 'file')
*        A>$1F ProDOS error, translated by FILERET
LOADFILE      LDX   #4
:LP           LDA   FBLOAD,X           ; Get address to load to
              STA   ZPMOS,X
              DEX
              BPL   :LP
              JSR   PREPATH            ; Preprocess pathname
              JSR   WILDONE            ; Handle any wildcards
              JSR   UPDFB              ; Get object info
              CMP   #$20
              BCS   :JMPEXIT           ; Error occured
              CMP   #$01               ; Is it a file
              BEQ   :ISFILE
              ROL   A                  ; 0->0, 2->5
              EOR   #$05               ; 0->5, 2->0
              ADC   #$41               ; 0->$46, 2->$41
:JMPEXIT      JMP   :EXIT2             ; Return error

:ISFILE       LDA   ZPMOS+4            ; If FBEXEC is zero, use addr
              BEQ   :CBADDR            ; in the control block
              LDA   FBLOAD+0           ; Otherwise, use file's address
              STA   ZPMOS+0
              LDA   FBLOAD+1
              STA   ZPMOS+1

:CBADDR       JSR   OPENMOSFILE
              BCS   :EXIT2             ; File not opened

:L1           LDA   OPENPL+5           ; File ref number
              JSR   READDATA           ; Read data from open file

              PHA                      ; Save result
              LDA   OPENPL+5           ; File ref num
              STA   CLSPL+1
              JSR   CLSFILE
              PLA
              BNE   :EXIT2
              JSR   COPYFB             ; Copy FILEBLK to auxmem
              LDA   #$01               ; $01=File
:EXIT2        RTS


* A=channel, MOSZP+0/1=address to load to, TO DO: MOS+4/5=length to read
READDATA      STA   READPL+1
:RDLP         JSR   RDFILE
              BCS   :READERR           ; Close file and return any error

              LDA   #<BLKBUF           ; LSB of start of data buffer
              STA   A1L                ; A1=>start of data buffer
              ADC   READPL+6           ; LSB of trans count
              TAX                      ; X=>LSB end of data buffer

              LDA   #>BLKBUF           ; MSB of start of data buffer
              STA   A1H                ; A1=>start of data buffer
              ADC   READPL+7           ; MSB of trans count
              TAY                      ; Y=>MSB end of data buffer

              TXA
              BNE   :L2
              DEY
:L2           DEX                      ; XY=XY-1, end address is start+len-1
              STX   A2L                ; A2=>end of data buffer
              STY   A2H

              LDA   ZPMOS+0            ; A4=>address to load to
              STA   A4L
              LDA   ZPMOS+1
              STA   A4H
              INC   ZPMOS+1            ; Step to next block
              INC   ZPMOS+1

              SEC                      ; Main -> AUX
              JSR   AUXMOVE            ; A4 updated to next address
              JMP   :RDLP

:READERR      CMP   #$4C
              BNE   :EXITERR
:EXITOK       LDA   #$00               ; $00=Success
:EXITERR      RTS


* ProDOS file handling for MOS OSFILE SAVE call
* Invoked by AppleMOS OSFILE
* Return A=01 if successful (ie: 'file')
*        A>$1F ProDOS error translated by FILERET
SAVEFILE      SEC                      ; Compute file length
              LDA   FBEND+0
              SBC   FBSTRT+0
              STA   LENREM+0
              LDA   FBEND+1
              SBC   FBSTRT+1
              STA   LENREM+1
              LDA   FBEND+2
              SBC   FBSTRT+2
              BNE   :TOOBIG            ; >64K
              LDA   FBEND+3
              SBC   FBSTRT+3
              BEQ   :L0                ; >16M
:TOOBIG       LDA   #$2C               ; Bad byte count - file too long
              RTS

:L0           JSR   PREPATH            ; Preprocess pathname
              JSR   EXISTS             ; See if file exists ...
              CMP   #$01
              BEQ   :NOTDIR            ; Overwrite file
              BCC   :NOFILE            ; Create new file
              CMP   #$02
              BNE   :JMPEXIT2
              LDA   #$41               ; Dir exists, return $41
:JMPEXIT2     JMP   :EXIT2

:NOTDIR       LDA   #<MOSFILE          ; Attempt to destroy file
              STA   DESTPL+1
              LDA   #>MOSFILE
              STA   DESTPL+2
              JSR   MLI
              DB    DESTCMD
              DW    DESTPL
              BCS   :EXIT2             ; Error trying to delete

:NOFILE       LDX   FBLOAD+0           ; Auxtype = load address
              LDY   FBLOAD+1
              JSR   CREATEFILE
              BCS   :JMPEXIT2          ; Error trying to create
              JSR   OPENMOSFILE
              BCS   :JMPEXIT2          ; Error trying to open
              LDA   OPENPL+5           ; File ref number
              JSR   WRITEDATA

:EXIT1        PHA                      ; Save result
              LDA   OPENPL+5           ; File ref num
              STA   CLSPL+1
              JSR   CLSFILE
              PLA
              BNE   :EXIT2             ; Error returned
              JSR   UPDFB              ; Update FILEBLK
              JSR   COPYFB             ; Copy FILEBLK to aux mem
              LDA   #$01               ; Return A='File'
:EXIT2        CMP   #$4E
              BNE   :EXIT3             ; Change 'Insuff. access'
              LDA   #$4F               ; to 'Locked'
:EXIT3        RTS


* A=channel, FBSTRT+0/1=address to save from
* LENREM+0/1=length to write
WRITEDATA     STA   WRITEPL+1
:L1           LDA   #$00               ; 512 bytes request count
              STA   WRITEPL+4
              LDA   #$02
              STA   WRITEPL+5

              LDA   LENREM+1
              CMP   #$02
              BCS   :L15               ; More than 511 bytes remaining
              STA   WRITEPL+5
              LDA   LENREM+0
              STA   WRITEPL+4
              ORA   WRITEPL+5
              BEQ   :SAVEOK            ; Zero bytes remaining

:L15          SEC
              LDA   LENREM+0           ; LENREM=LENREM-count
              SBC   WRITEPL+4
              STA   LENREM+0
              LDA   LENREM+1
              SBC   WRITEPL+5
              STA   LENREM+1

              CLC
              LDA   FBSTRT+0
              STA   A1L                ; A1=>start of this block
              ADC   WRITEPL+4
              STA   FBSTRT+0           ; Update FBSTRT=>start of next block
              TAX                      ; X=>end of this block

              LDA   FBSTRT+1
              STA   A1H
              ADC   WRITEPL+5
              STA   FBSTRT+1
              TAY

              TXA
              BNE   :L2
              DEY
:L2           DEX                      ; XY=XY-1, end address is start+len-1
              STX   A2L                ; A2=>end of data buffer
              STY   A2H

:S2           LDA   #<BLKBUF
              STA   A4L
              LDA   #>BLKBUF
              STA   A4H
              CLC                      ; Aux -> Main
              JSR   AUXMOVE            ; Copy data from aux to local buffer

              JSR   WRTFILE            ; Write the data
              BCS   :WRITEERR
              JMP   :L1                ; Loop back for next block
:SAVEOK                                ; Enter here with A=$00
:WRITEERR     RTS
LENREM        DW    $0000              ; Remaining length


CREATEFILE    LDA   #$01               ; Storage type - file
              STA   CREATEPL+7
              LDA   #$06               ; Filetype BIN

CREATEOBJ     STA   CREATEPL+4         ; Type = BIN or DIR
              STX   CREATEPL+5         ; Auxtype = load address
              STY   CREATEPL+6
              JMP   CRTFILE


* Process pathname and read object info
UPDPATH       JSR   PREPATH            ; Process pathname
              BCC   UPDFB              ; If no error, update control block
              RTS

* Update FILEBLK before returning to aux memory
* Returns A=object type or ProDOS error
UPDFB         LDA   #<MOSFILE
              STA   GINFOPL+1
              LDA   #>MOSFILE
              STA   GINFOPL+2
              JSR   GETINFO            ; Call GET_FILE_INFO
              BCC   :UPDFB1
              JMP   CHKNOTFND

:UPDFB1       LDA   GINFOPL+5          ; Aux type LSB
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
:UPDFB2       ORA   FBATTR+0           ; --wrl-wr
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
:UPDFB3       PHA                      ; yyyyyyym
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

              JSR   OPENMOSFILE        ; Open file
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
              ADC   #$00               ; Becomes A=2 for directory
:UPDFB5       RTS

:ERR
CHKNOTFND     CMP   #$44               ; Convert ProDOS 'not found'
              BEQ   :NOTFND            ; into result=$00
              CMP   #$45
              BEQ   :NOTFND
              CMP   #$46
              BNE   :CHKNOTFND2
:NOTFND       LDA   #$00
:CHKNOTFND2   RTS


* Quit to ProDOS
QUIT          INC   $03F4              ; Invalidate powerup byte
              STA   $C054              ; PAGE2 off
              STA   $C00E              ; Alt font off
              JSR   MLI
              DB    QUITCMD
              DW    QUITPL
              RTS

* Used for *CAT, *EX and *INFO
* On entry: b7=0 - short info (*CAT)
*           b7=1 - long info (*INFO, *EX)
*           b6=0 - single entry, parameter is object (*INFO)
*           b6=1 - multiple items, parameter is dir (*CAT, *EX)
*
CATALOG       >>>   ENTMAIN
              STA   CATARG             ; Stash argument
              CMP   #$80               ; Is it *INFO?
              BNE   :NOTINFO
              JMP   INFO               ; Handle entry for *INFO
:NOTINFO      LDA   MOSFILE            ; Length of pathname
              BEQ   :NOPATH            ; If zero use prefix
              JSR   PREPATH            ; Preprocess pathname
              JSR   WILDONE            ; Handle any wildcards
              JSR   EXISTS             ; See if path exists ...
              BEQ   :NOTFND            ; Not found
              CMP   #$02
              BEQ   :DIRFOUND
              LDA   #$0D               ; Becomes Not a directory
:NOTFND       EOR   #$46               ; $00->$46, $xx->$4B          
              BNE   CATEXIT

:NOPATH       JSR   GETPREF            ; Fetch prefix into PREFIX
              LDX   #<PREFIX           ; XY=>prefix
              LDY   #>PREFIX
              BRA   :OPEN
:DIRFOUND     LDX   #<MOSFILE          ; XY=>specified directory
              LDY   #>MOSFILE

:OPEN         STX   OPENPL+1           ; Open the specified directory
              STY   OPENPL+2
              JSR   OPENFILE
              BCS   CATEXIT            ; Can't open dir

CATREENTRY    LDA   OPENPL+5           ; File ref num
              STA   READPL+1
              JSR   RDFILE
              BCS   :CATERR
              JSR   COPYAUXBLK
              >>>   XF2AUX,PRONEBLK

:CATERR       CMP   #$4C               ; EOF
              BNE   :NOTEOF
              LDA   #$00
:NOTEOF       PHA
              LDA   OPENPL+5           ; File ref num
              STA   CLSPL+1
              JSR   CLSFILE
              PLA
CATEXIT       >>>   XF2AUX,STARCATRET

* Handle *INFO
INFO          JSR   PREPATH            ; Preprocess pathname
              SEC
              JSR   WILDCARD           ; Handle any wildcards
              JSR   EXISTS             ; Check matches something
              BNE   INFOFIRST          ; Match found, start listing
              LDA   #$46               ; No match, error Not found
INFOEXIT      CMP   #$4C               ; EOF
              BNE   INFOCLS
              LDA   #$00               ; EOF is not an error
INFOCLS       PHA
              JSR   CLSDIR             ; Be sure to close it!
              PLA
              BRA   CATEXIT

* PRONEBLK call returns here ...
CATALOGRET    >>>   ENTMAIN
              LDA   CATARG
              CMP   #$80               ; Is this an *INFO call?
              BNE   CATREENTRY         ; No, go back and do another CAT/EX

INFOREENTRY   JSR   WILDNEXT2          ; Start of new block
              BCS   INFOEXIT           ; No more matches
INFOFIRST     LDA   WILDIDX
              CMP   #$FF               ; Is WILDNEXT about to read new blk?
              BEQ   :DONEBLK           ; If so, print this blk first
              JSR   WILDNEXT2
              BCC   INFOFIRST          ; Find more entries
:DONEBLK      JSR   COPYAUXBLK
              >>>   XF2AUX,PRONEBLK

CATARG        DB    $00


* Set prefix. Used by *CHDIR/*DRIVE to change directory
* Y= $00 - CHDIR, select any directory
* Y<>$00 - DRIVE, must select root
*
SETPFX        >>>   ENTMAIN
              PHY                      ; Save CHDIR/DRIVE flag
              JSR   PREPATH            ; Preprocess pathname
              BCS   :EXIT
              JSR   WILDONE            ; Handle any wildcards
              LDA   #$2E
              BCS   :EXIT              ; Exit with wildcard path
* TO DO: If DRIVE disallow selecting a directory
*
              LDA   #<MOSFILE
              STA   SPFXPL+1
              LDA   #>MOSFILE
              STA   SPFXPL+2
              JSR   MLI                ; SET_PREFIX
              DB    SPFXCMD
              DW    SPFXPL

:EXIT         PLY                      ; Drop CHDIR/DRIVE flag
              >>>   XF2AUX,CHDIRRET


* Obtain info on total/used blocks
DRVINFO       >>>   ENTMAIN
              LDA   MOSFILE
              BNE   :DRVINF2
              INC   MOSFILE
              LDA   #'@'
              STA   MOSFILE+1          ; Convert "" to "@"
:DRVINF2      JSR   PREPATH
              BCS   :EXIT
              LDA   #<MOSFILE
              STA   GINFOPL+1
              LDA   #>MOSFILE
              STA   GINFOPL+2
              JSR   GETINFO            ; GET_FILE_INFO
              BCS   :EXIT
              LDA   GINFOPL+7
              CMP   #$0F
              BNE   :EXIT1             ; Not a drive, exit with 'Bad drive'

              >>>   ALTZP              ; Alt ZP & Alt LC on
              LDA   GINFOPL+8          ; Blocks used LSB
              STA   AUXBLK+0
              LDA   GINFOPL+9          ; Blocks used MSB
              STA   AUXBLK+1
              LDA   GINFOPL+5          ; Total blocks LSB
              STA   AUXBLK+2
              LDA   GINFOPL+6          ; Total blocks MSB
              STA   AUXBLK+3
              >>>   MAINZP             ; ALt ZP off, ROM back in
              LDA   #$00               ; $00=Ok

:EXIT         CMP   #$46
              BNE   :EXIT2
:EXIT1        LDA   #$2A               ; Change 'Not found' to 'Bad drive'
:EXIT2        >>>   XF2AUX,FREERET


* Change file permissions, for *ACCESS
* Filename in MOSFILE, access mask in A
*
SETPERM       >>>   ENTMAIN
              PHA                      ; Save access mask
              JSR   PREPATH            ; Preprocess pathname
              BCS   :SYNERR
              CLC
              JSR   WILDCARD           ; Handle any wildcards
              BCS   :NONE
              BCC   :MAINLOOP
*             STZ   :LFLAG
*             STZ   :WFLAG
*             STZ   :RFLAG
*             LDX   MOSFILE2           ; Length of arg2
*             INX
*:L1          DEX
*             CPX   #$00
*             BEQ   :MAINLOOP
*             LDA   MOSFILE2,X         ; Read arg2 char
*             CMP   #'L'               ; L=Locked
*             BNE   :S1
*             STA   :LFLAG
*             BRA   :L1
*:S1          CMP   #'R'               ; R=Readable
*             BNE   :S2
*             STA   :RFLAG
*             BRA   :L1
*:S2          CMP   #'W'               ; W=Writable
*             BNE   :ERR2              ; Bad attribute
*             STA   :WFLAG
*             BRA   :L1

:SYNERR       LDA   #$40               ; Invalid pathname syn
              BRA   :EXIT
:NONE         JSR   CLSDIR
              LDA   #$46               ; 'File not found'
              BRA   :EXIT
:MAINLOOP     LDA   #<MOSFILE
              STA   GINFOPL+1
              LDA   #>MOSFILE
              STA   GINFOPL+2
              JSR   GETINFO            ; GET_FILE_INFO
              BCS   :EXIT
              PLA                      ; Access byte
              PHA

*             LDA   GINFOPL+3          ; Access byte
*             AND   #$03               ; Start with R, W off
*             ORA   #$C0               ; Start with dest/ren on
*             LDX   :RFLAG
*             BEQ   :S3
*             ORA   #$01               ; Turn on read enable
*:S3          LDX   :WFLAG
*             BEQ   :S4
*             ORA   #$02               ; Turn on write enable
*:S4          LDX   :LFLAG
*             BEQ   :S5
*             AND   #$3D               ; Turn off destroy/ren/write

:S5           STA   GINFOPL+3          ; Access byte
              JSR   SETINFO            ; SET_FILE_INFO
              JSR   WILDNEXT
              BCC   :MAINLOOP
*             BCS   :NOMORE
:NOMORE       JSR   CLSDIR
              LDA   #$00
*             BRA   :EXIT
:EXIT         PLX                      ; Drop access byte
              >>>   XF2AUX,ACCRET
:ERR2         LDA   #$53               ; Invalid parameter
              BRA   :EXIT

*:LFLAG       DB    $00                ; 'L' attribute
*:WFLAG       DB    $00                ; 'W' attribute
*:RFLAG       DB    $00                ; 'R' attribute


* Multi file delete, for *DESTROY
* Filename in MOSFILE
*
MULTIDEL      >>>   ENTMAIN
              JSR   PREPATH            ; Preprocess pathname
              BCS   :EXIT
*             CLC                     ; CC already set
              JSR   WILDCARD           ; Handle any wildcards
              BCC   :MAINLOOP
              LDA   #$46               ; 'File not found'
              BRA   :DELERR
:MAINLOOP     JSR   DODELETE
              BCS   :DELERR
              JSR   WILDNEXT
              BCC   :MAINLOOP          ; More to do
              LDA   #$00               ; $00=Done
:DELERR       PHA
              JSR   CLSDIR
              PLA
:EXIT         >>>   XF2AUX,DESTRET


* Read machid from auxmem
MACHRD        LDA   $C081
              LDA   $C081
              LDA   $FBC0
              SEC
              JSR   $FE1F
              BRA   MAINRDEXIT

* Read mainmem from auxmem
MAINRDMEM     STA   A1L
              STY   A1H
              LDA   $C081
              LDA   $C081
              LDA   (A1L)
MAINRDEXIT    >>>   XF2AUX,NULLRTS     ; Back to an RTS







