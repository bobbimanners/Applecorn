* MAINMEM.S
* (c) Bobbi 2021 GPL v3
*
* Code that runs on the Apple //e in main memory.
* This code is mostly glue between the BBC Micro code
* which runs in aux mem and Apple II ProDOS.

* 24-Aug-2021 AUXTYPE set from load address
* 27-Aug-2021 Delete and MkDir return ProDOS result to caller
* 29-Aug-2021 All calls (seem to) return ProDOS result to caller
* Set ?&E0=255 for testing to report ProDOS result
* 30-Aug-2021 INFOFILE semi-implemented, UPDFB returns moddate
* Lots of tidying up possible once confirmed code working


* ProDOS string buffers
RTCBUF       EQU   $0200              ; Use by RTC calls, 40 bytes
*                                 ; $0228-$023D
DRVBUF1      EQU   $023E
DRVBUF2      EQU   $023F              ; Prefix on current drive, len+64
CMDPATH      EQU   $0280              ; Path used to start Applecorn

* Filename string buffers
MOSFILE1     EQU   $0300              ; length + 64 bytes
MOSFILE2     EQU   $0341              ; length + 64 bytes
MOSFILE      EQU   MOSFILE1
*                 $0382           ; $3C bytes here
*
FILEBLK      EQU   $03BE
FBPTR        EQU   FILEBLK+0          ; Pointer to name (in aux)
FBLOAD       EQU   FILEBLK+2          ; Load address
FBEXEC       EQU   FILEBLK+6          ; Exec address
FBSIZE       EQU   FILEBLK+10         ; Size
FBSTRT       EQU   FILEBLK+10         ; Start address for SAVE
FBATTR       EQU   FILEBLK+14         ; Attributes
FBEND        EQU   FILEBLK+14         ; End address for SAVE

* ProDOS MLI command numbers
QUITCMD      EQU   $65
GTIMECMD     EQU   $82
CREATCMD     EQU   $C0
DESTCMD      EQU   $C1
RENCMD       EQU   $C2
SFILECMD     EQU   $C3
GINFOCMD     EQU   $C4
ONLNCMD      EQU   $C5
SPFXCMD      EQU   $C6
GPFXCMD      EQU   $C7
OPENCMD      EQU   $C8
READCMD      EQU   $CA
WRITECMD     EQU   $CB
CLSCMD       EQU   $CC
FLSHCMD      EQU   $CD
SMARKCMD     EQU   $CE
GMARKCMD     EQU   $CF
GEOFCMD      EQU   $D1

* Trampoline in main memory used by aux memory IRQ handler
* to invoke Apple II / ProDOS IRQs in main memory
A2IRQ        >>>   IENTMAIN           ; IENTMAIN does not do CLI
             JSR   A2IRQ2
             >>>   XF2AUX,IRQBRKRET
A2IRQ2       PHP                      ; Fake things to look like IRQ
             JMP   (A2IRQV)           ; Call Apple II ProDOS ISR

* BRK handler in main memory. Used on Apple IIgs only.
GSBRK        >>>   XF2AUX,GSBRKAUX

* Set prefix if not already set
SETPRFX      LDA   #GPFXCMD
             STA   :OPC7              ; Initialize cmd byte to $C7
:L1          JSR   MLI
:OPC7        DB    $00
             DW    GSPFXPL
             LDX   DRVBUF1            ; was $0300
             BNE   RTSINST
             LDA   $BF30
             STA   ONLNPL+1           ; Device number
             JSR   MLI
             DB    ONLNCMD
             DW    ONLNPL
             LDA   DRVBUF2            ; was $0301
             AND   #$0F
             TAX
             INX
             STX   DRVBUF1            ; was $0300
             LDA   #$2F
             STA   DRVBUF2            ; was $0301
             DEC   :OPC7
             BNE   :L1
RTSINST      RTS

* Disconnect /RAM ramdrive to avoid aux corruption
* Stolen from Beagle Bros Extra K
DISCONN      LDA   $BF98
             AND   #$30
             CMP   #$30
             BNE   :S1
             LDA   $BF26
             CMP   $BF10
             BNE   :S2
             LDA   $BF27
             CMP   $BF11
             BEQ   :S1
:S2          LDY   $BF31
:L1          LDA   $BF32,Y
             AND   #$F3
             CMP   #$B3
             BEQ   :S3
             DEY
             BPL   :L1
             BMI   :S1
:S3          LDA   $BF32,Y
             STA   DRVBUF2+1          ; was $0302
:L2          LDA   $BF33,Y
             STA   $BF32,Y
             BEQ   :S4
             INY
             BNE   :L2
:S4          LDA   $BF26
             STA   DRVBUF1            ; was $0300
             LDA   $BF27
             STA   DRVBUF2            ; was $0301
             LDA   $BF10
             STA   $BF26
             LDA   $BF11
             STA   $BF27
             DEC   $BF31
:S1          RTS

* Reset handler - invoked on Ctrl-Reset
* XFER to AUXMOS ($C000) in aux, AuxZP on, LC on
RESET        TSX
             STX   $0100
             LDA   $C058              ; AN0 off
             LDA   $C05A              ; AN1 off
             LDA   $C05D              ; AN2 on
             LDA   $C05F              ; AN3 on
             LDA   #$20               ; PAGE2 shadow on ROM3 GS
             TRB   $C035
             >>>   XF2AUX,AUXMOS
             RTS

* Copy 512 bytes from BLKBUF to AUXBLK in aux LC
COPYAUXBLK
             SEI
             >>>   ALTZP              ; Alt ZP & Alt LC on

             LDY   #$00
:L1          LDA   BLKBUF,Y
             STA   $C005              ; Write aux mem
             STA   AUXBLK,Y
             STA   $C004              ; Write main mem
             CPY   #$FF
             BEQ   :S1
             INY
             BRA   :L1

:S1          LDY   #$00
:L2          LDA   BLKBUF+$100,Y
             STA   $C005              ; Write aux mem
             STA   AUXBLK+$100,Y
             STA   $C004              ; Write main mem
             CPY   #$FF
             BEQ   :S2
             INY
             BRA   :L2

:S2          >>>   MAINZP             ; Alt ZP off, ROM back in
             CLI
             RTS

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
             JSR   DESTROY
             BCC   :DELETED
             PLX                      ; Drop object
             JSR   CHKNOTFND
*            CMP   #$44               ; Path not found
*            BEQ   :NOTFND
*            CMP   #$45               ; Volume dir not found
*            BEQ   :NOTFND
*            CMP   #$46               ; File not found
*            BNE   :EXIT
*:NOTFND     LDA   #$00               ; 'Not found'
*            BRA   :EXIT
             PHA
:DELETED     PLA                      ; Get object back
*            LDA   #$02               ; Prepare A=2, it was a dir
*            LDX   GINFOPL+7          ; Storage type
*            CPX   #$0D
*            BEQ   :EXIT              ; It was a directory
*            LDA   #$01               ; A=1, it was a file
:EXIT        >>>   XF2AUX,OSFILERET

DESTROY      LDA   #<MOSFILE          ; Attempt to destroy file
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
* Make into a subroutine
             LDA   #$0D               ; 'Directory'
             STA   CREATEPL+7         ; ->Storage type
             LDA   #$0F               ; 'Directory'
             STA   CREATEPL+4         ; ->File type
* subroutine....
             LDA   #<MOSFILE
             STA   CREATEPL+1
             LDA   #>MOSFILE
             STA   CREATEPL+2
             LDA   #$C3               ; 'Default access'
             STA   CREATEPL+3         ; ->Access
             STZ   CREATEPL+5         ; Aux type LSB
             STZ   CREATEPL+6         ; Aux type MSB
* Don't we have to make a call to update BF90-BF93?
             LDA   $BF90              ; Current date
             STA   CREATEPL+8
             LDA   $BF91
             STA   CREATEPL+9
             LDA   $BF92              ; Current time
             STA   CREATEPL+10
             LDA   $BF93
             STA   CREATEPL+11
             JSR   CRTFILE
* ...
             BCS   :EXIT              ; Failed, exit with ProDOS result
             JSR   UPDFB              ; Update FILEBLK
             JSR   COPYFB             ; Copy FILEBLK to aux mem
             LDA   #$02               ; Success, $02=dir created
:EXIT        >>>   XF2AUX,OSFILERET

* ProDOS file handling to rename a file
RENFILE      >>>   ENTMAIN
             JSR   DORENAME
             >>>   XF2AUX,RENRET

DORENAME     LDA   #<MOSFILE
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
             RTS

* ProDOS file handling for MOS OSFIND OPEN call
* Options in A: $40 'r', $80 'w', $C0 'rw'
OFILE        >>>   ENTMAIN
             PHA                      ; Preserve arg for later
             JSR   PREPATH            ; Preprocess pathname
             JSR   EXISTS             ; See if file exists ...
             CMP   #$02               ; ... and is a directory
             BNE   :NOTDIR
             JMP   :NOTFND            ; Bail out if directory
:NOTDIR      PLA
             PHA
             CMP   #$80               ; Write mode
             BNE   :S0
             JSR   DESTROY
* Make into a subroutine
             LDA   #$01               ; Storage type - file
             STA   CREATEPL+7
             LDA   #$06               ; Filetype BIN
             STA   CREATEPL+4
             LDA   #<MOSFILE          ; Attempt to create file
             STA   CREATEPL+1
             STA   OPENPL+1
             LDA   #>MOSFILE
             STA   CREATEPL+2
             STA   OPENPL+2
             LDA   #$C3               ; Access unlocked
             STA   CREATEPL+3
             LDA   #$00               ; Auxtype
             STA   CREATEPL+5
             LDA   #$00
             STA   CREATEPL+6
             LDA   $BF90              ; Current date
             STA   CREATEPL+8
             LDA   $BF91
             STA   CREATEPL+9
             LDA   $BF92              ; Current time
             STA   CREATEPL+10
             LDA   $BF93
             STA   CREATEPL+11
             JSR   CRTFILE
* ...
:S0          LDA   #$00               ; Look for empty slot
             JSR   FINDBUF
             STX   BUFIDX
             CPX   #$00
             BNE   :S1
             LDA   #<IOBUF1
             LDY   #>IOBUF1
             BRA   :S4
:S1          CPX   #$01
             BNE   :S2
             LDA   #<IOBUF2
             LDY   #>IOBUF2
             BRA   :S4
:S2          CPX   #$02
             BNE   :S3
             LDA   #<IOBUF3
             LDY   #>IOBUF3
             BRA   :S4
:S3          CPX   #$03
             BNE   :NOTFND            ; Out of buffers really
             LDA   #<IOBUF4
             LDY   #>IOBUF4

:S4          STA   OPENPL2+3
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
             CPX   #$FF
             BEQ   :S1
             LDA   #$00
             STA   FILEREFS,X
:S1          JMP   FINDEXIT

* Map of file reference numbers to IOBUF1..4
FILEREFS     DB    $00,$00,$00,$00

* Search FILEREFS for value in A
FINDBUF      LDX   #$00
:L1          CMP   FILEREFS,X
             BEQ   :END
             INX
             CPX   #$04
             BNE   :L1
             LDX   #$FF               ; $FF for not found
:END         RTS

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
             JSR   MLI                ; Call GET_FILE_INFO
             DB    GINFOCMD
             DW    GINFOPL
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

* Check if file exists
* Return A=0 if doesn't exist, A=1 file, A=2 fir
EXISTS       LDA   #<MOSFILE
             STA   GINFOPL+1
             LDA   #>MOSFILE
             STA   GINFOPL+2
             JSR   MLI                ; GET_FILE_INFO
             DB    GINFOCMD
             DW    GINFOPL
             BCS   :NOEXIST
             LDA   GINFOPL+7          ; Storage type
             CMP   #$0D
             BCS   :DIR               ; >= $0D
             LDA   #$01               ; File
             RTS
:DIR         LDA   #$02
             RTS
:NOEXIST     LDA   #$00
             RTS

* Copy FILEBLK to AUXBLK in aux memory
* Preserves A
COPYFB       PHA
             LDX   #$00
:L1          LDA   FILEBLK,X
             TAY
             >>>   ALTZP              ; Alt ZP and LC
             TYA
             STA   AUXBLK,X
             >>>   MAINZP             ; Back to normal
             INX
             CPX   #18                ; 18 bytes in FILEBLK
             BNE   :L1
             PLA
             RTS

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
* TO DO: Make this a subroutine
             LDA   #$01               ; Storage type - file
             STA   CREATEPL+7
             LDA   #$06               ; Filetype BIN
             STA   CREATEPL+4
* subroutine....
             LDA   #<MOSFILE
             STA   CREATEPL+1
             STA   OPENPL+1
             LDA   #>MOSFILE
             STA   CREATEPL+2
             STA   OPENPL+2
             LDA   #$C3               ; Access unlocked
             STA   CREATEPL+3
             LDA   FBLOAD             ; Auxtype = load address
             STA   CREATEPL+5
             LDA   FBLOAD+1
             STA   CREATEPL+6
             LDA   $BF90              ; Current date
             STA   CREATEPL+8
             LDA   $BF91
             STA   CREATEPL+9
             LDA   $BF92              ; Current time
             STA   CREATEPL+10
             LDA   $BF93
             STA   CREATEPL+11
             JSR   CRTFILE
* ...
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
             JSR   MLI                ; Call GET_FILE_INFO
             DB    GINFOCMD
             DW    GINFOPL
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

* Obtain catalog of current PREFIX dir
CATALOG      >>>   ENTMAIN

             JSR   GETPREF            ; Fetch prefix into MOSFILE2
             LDA   #<MOSFILE2
             STA   OPENPL+1
             LDA   #>MOSFILE2
             STA   OPENPL+2
             JSR   OPENFILE
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
             BRA   CATREENTRY

* This needs to be a generalised routine
* Needs to be callable from OSFIND, OSFILE, CAT, RENAME
* Preprocess path in MOSFILE, handling '..' sequence
* dir/file.ext filesystem, so '..' means parent dir (eg: '../SOMEDIR')
* Also allows '^' as '^' is illegal character
* Carry set on error, clear otherwise
PREPATH      LDX   MOSFILE            ; Length
             BEQ   :EXIT              ; If zero length
             LDA   MOSFILE+1          ; 1st char of pathname
             CMP   #$3A               ; ':'
             BNE   :NOTCOLN           ; Not colon
             CPX   #$03               ; Length >= 3?
             BCC   :ERR               ; If not
             LDA   MOSFILE+3          ; Drive
             SEC
             SBC   #'1'
             TAX
             LDA   MOSFILE+2          ; Slot
             SEC
             SBC   #'0'
             JSR   DRV2PFX            ; Slot/drv->pfx in MOSFILE2
             JSR   DEL1CHAR           ; Delete ':' from MOSFILE
             JSR   DEL1CHAR           ; Delete slot from MOSFILE
             JSR   DEL1CHAR           ; Delete drive from MOSFILE
             LDA   MOSFILE            ; Is there more?
             BEQ   :APPEND            ; Only ':sd'
             CMP   #$02               ; Length >= 2
             BCC   :ERR               ; If not
             LDA   MOSFILE+1          ; 1st char of filename
             CMP   #$2F               ; '/'
             BNE   :ERR
             JSR   DEL1CHAR           ; Delete '/' from MOSFILE
             BRA   :APPEND
:NOTCOLN     JSR   GETPREF            ; Current pfx -> MOSFILE2
:REENTER     LDA   MOSFILE+1          ; First char of dirname
             CMP   #'.'
             BEQ   :UPDIR1
             CMP   #$5E               ; '^' char
             BEQ   :CARET             ; If '^'
             CMP   #$2F               ; '/' char - abs path
             BEQ   :EXIT              ; Nothing to do
             BRA   :APPEND

:UPDIR1      LDA   MOSFILE+2
             CMP   #'.'               ; '..'
             BNE   :EXIT
             JSR   DEL1CHAR           ; Delete two leading characters
:CARET       JSR   DEL1CHAR           ; Delete '^' from MOSFILE
             JSR   PARENT             ; Parent dir -> MOSFILE2
             LDA   MOSFILE            ; Is there more?
             BEQ   :APPEND            ; Only '^'
             CMP   #$02               ; Len at least two?
             BCC   :ERR               ; Nope!
             LDA   MOSFILE+1          ; What is next char?
             CMP   #$2F               ; Is it slash?
             BNE   :ERR               ; Nope!
             JSR   DEL1CHAR           ; Delete '/' from MOSFILE
             BRA   :REENTER           ; Go again!
:APPEND      JSR   APPMF2             ; Append MOSFILE->MOSFILE2
             JSR   COPYMF2            ; Copy back to MOSFILE
:EXIT        CLC
             RTS
:ERR         SEC
             RTS

* Set prefix. Used by *CHDIR to change directory
SETPFX       >>>   ENTMAIN
             JSR   PREPATH            ; Preprocess pathname
             BCS   :ERR
             LDA   #<MOSFILE
             STA   SPFXPL+1
             LDA   #>MOSFILE
             STA   SPFXPL+2
             JSR   MLI                ; SET_PREFIX
             DB    SPFXCMD
             DW    SPFXPL
:EXIT        >>>   XF2AUX,STARDIRRET
:ERR         LDA   #$40               ; Invalid pathname syn
             BRA   :EXIT

* Create disk file
CRTFILE      JSR   MLI
             DB    CREATCMD
             DW    CREATEPL
             RTS

* Open disk file
OPENFILE     JSR   MLI
             DB    OPENCMD
             DW    OPENPL
             RTS

* Close disk file
CLSFILE      JSR   MLI
             DB    CLSCMD
             DW    CLSPL
             RTS

* Read 512 bytes into BLKBUF
RDFILE       JSR   MLI
             DB    READCMD
             DW    READPL
             RTS

* Write data in BLKBUF to disk
WRTFILE      JSR   MLI
             DB    WRITECMD
             DW    WRITEPL
             RTS

* Put PREFIX in MOSFILE2
GETPREF      JSR   MLI
             DB    GPFXCMD
             DW    GPFXPL
             RTS

* Convert path in MOSFILE2 by removing leaf dir to leave
* parent directory. If already at top, return unchanged.
PARENT       LDX   MOSFILE2           ; Length of string
             BEQ   :EXIT              ; Prefix len zero
             DEX                      ; Ignore trailing '/'
:L1          LDA   MOSFILE2,X
             CMP   #$2F               ; Slash '/'
             BEQ   :FOUND
             DEX
             CPX   #$01
             BNE   :L1
             BRA   :EXIT              ; No slash found
:FOUND       STX   MOSFILE2           ; Truncate string
:EXIT        RTS

* Convert slot/drive to prefix
* Expect slot number (1..7) in A, drive (0..1) in X
* Puts prefix (or empty string) in MOSFILE2
DRV2PFX      CLC                      ; Cy=0 A=00000sss
             ROR   A                  ;    s   000000ss
             ROR   A                  ;    s   s000000s
             ROR   A                  ;    s   ss000000
             ROR   A                  ;    0   sss00000
             CPX   #1                 ;    d   sss00000
             ROR   A                  ;    0   dsss0000

             STA   ONLNPL+1           ; Device number
             JSR   MLI                ; Call ON_LINE
             DB    ONLNCMD
             DW    ONLNPL             ; Buffer set to DRVBUF2 (was $301)
             LDA   DRVBUF2            ; was $301 ; Slot/Drive/Length
             AND   #$0F               ; Mask to get length
             TAX
             INC                      ; Plus '/' at each end
             INC
             STA   MOSFILE2           ; Store length
             LDA   #$2F               ; '/'
             STA   MOSFILE2+1
             STA   MOSFILE2+2,X
:L1          CPX   #$00               ; Copy -> MOSFILE2
             BEQ   :EXIT
             LDA   DRVBUF2,X          ; was $301,X
             STA   MOSFILE2+1,X
             DEX
             BRA   :L1
:EXIT        RTS

* Delete first char of MOSFILE
DEL1CHAR     LDX   MOSFILE            ; Length
             BEQ   :EXIT              ; Nothing to delete
             LDY   #$02               ; Second char
:L1          CPY   MOSFILE
             BEQ   :S2                ; If Y=MOSFILE okay
             BCS   :S1                ; If Y>MOSFILE done
:S2          LDA   MOSFILE,Y
             STA   MOSFILE-1,Y
             INY
             BRA   :L1
:S1          DEC   MOSFILE
:EXIT        RTS

* Append MOSFILE to MOSFILE2
APPMF2       LDY   MOSFILE2           ; Length of MOSFILE2
             LDX   #$00               ; Index into MOSFILE
:L1          CPX   MOSFILE            ; Length of MOSFILE
             BEQ   :DONE
             LDA   MOSFILE+1,X
             STA   MOSFILE2+1,Y
             INX
             INY
             BRA   :L1
:DONE        STY   MOSFILE2           ; Update length MOSFILE2
             RTS

* Copy MOSFILE2 to MOSFILE
COPYMF2      LDX   #$00
:L1          CPX   MOSFILE2
             BEQ   :DONE
             LDA   MOSFILE2+1,X
             STA   MOSFILE+1,X
             INX
             BRA   :L1
:DONE        STX   MOSFILE
             RTS

******************************************************
* ProDOS Parameter lists for MLI calls
******************************************************
OPENPL       HEX   03                 ; Number of parameters
             DW    $0000              ; Pointer to filename
             DW    IOBUF0             ; Pointer to IO buffer
             DB    $00                ; Reference number returned

OPENPL2      HEX   03                 ; Number of parameters
             DW    $0000              ; Pointer to filename
             DW    $0000              ; Pointer to IO buffer
             DB    $00                ; Reference number returned

CREATEPL     HEX   07                 ; Number of parameters
             DW    $0000              ; Pointer to filename
             DB    $00                ; Access
             DB    $00                ; File type
             DW    $0000              ; Aux type
             DB    $00                ; Storage type
             DW    $0000              ; Create date
             DW    $0000              ; Create time

DESTPL       HEX   01                 ; Number of parameters
             DW    $0000              ; Pointer to filename

RENPL        HEX   02                 ; Number of parameters
             DW    $0000              ; Pointer to existing name
             DW    $0000              ; Pointer to new filename

READPL       HEX   04                 ; Number of parameters
             DB    $00                ; Reference number
             DW    BLKBUF             ; Pointer to data buffer
             DW    512                ; Request count
             DW    $0000              ; Trans count

READPL2      HEX   04                 ; Number of parameters
             DB    #00                ; Reference number
             DW    BLKBUF             ; Pointer to data buffer
             DW    1                  ; Request count
             DW    $0000              ; Trans count

WRITEPL      HEX   04                 ; Number of parameters
             DB    $01                ; Reference number
             DW    BLKBUF             ; Pointer to data buffer
             DW    $00                ; Request count
             DW    $0000              ; Trans count

CLSPL        HEX   01                 ; Number of parameters
             DB    $00                ; Reference number

FLSHPL       HEX   01                 ; Number of parameters
             DB    $00                ; Reference number

ONLNPL       HEX   02                 ; Number of parameters
             DB    $00                ; Unit num
             DW    DRVBUF2            ; was $301 ; Buffer

GSPFXPL      HEX   01                 ; Number of parameters
             DW    DRVBUF1            ; was $300 ; Buffer

GPFXPL       HEX   01                 ; Number of parameters
             DW    MOSFILE2           ; Buffer

SPFXPL       HEX   01                 ; Number of parameters
             DW    MOSFILE            ; Buffer

GMARKPL      HEX   02                 ; Number of parameters
             DB    $00                ; File reference number
             DB    $00                ; Mark (24 bit)
             DB    $00
             DB    $00

GEOFPL       HEX   02                 ; Number of parameters
             DB    $00                ; File reference number
             DB    $00                ; EOF (24 bit)
             DB    $00
             DB    $00

GINFOPL      HEX   0A                 ; Number of parameters
             DW    $0000              ; Pointer to filename
             DB    $00                ; Access
             DB    $00                ; File type
             DW    $0000              ; Aux type
             DB    $00                ; Storage type
             DW    $0000              ; Blocks used
             DW    $0000              ; Mod date
             DW    $0000              ; Mod time
             DW    $0000              ; Create date
             DW    $0000              ; Create time

QUITPL       HEX   04                 ; Number of parameters
             DB    $00
             DW    $0000
             DB    $00
             DW    $0000

** Buffer for Acorn MOS filename
** Pascal string
*MOSFILE     DS    65                 ; 64 bytes max prefix/file len
*
** Buffer for second filename (for rename)
** Pascal string
*MOSFILE2    DS    65                 ; 64 bytes max prefix/file len

** Acorn MOS format OSFILE param list
*FILEBLK
*FBPTR       DW    $0000              ; Pointer to name (in aux)
*FBLOAD      DW    $0000              ; Load address
*            DW    $0000
*FBEXEC      DW    $0000              ; Exec address
*            DW    $0000
*FBSIZE
*FBSTRT      DW    $0000              ; Size / Start address for SAVE
*            DW    $0000
*FBATTR
*FBEND       DW    $0000              ; Attributes / End address for SAVE
*            DW    $0000

