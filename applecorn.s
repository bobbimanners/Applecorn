* Load Acorn BBC Micro ROM into aux memory
* Provide an environment where it can run
* Bobbi 2021

            XC                               ; 65c02
            ORG   $2000                      ; Load addr of loader in main memory

* Monitor routines
BELL        EQU   $FBDD
PRBYTE      EQU   $FDDA
COUT1       EQU   $FDED
CROUT       EQU   $FD8E
AUXMOVE     EQU   $C311
XFER        EQU   $C314

* Monitor ZP locations
A1L         EQU   $3C
A1H         EQU   $3D
A2L         EQU   $3E
A2H         EQU   $3F
A4L         EQU   $42
A4H         EQU   $43

* Used by XFER
STRTL       EQU   $3ED
STRTH       EQU   $3EE

* Reset vector (2 bytes + 1 byte checksum)
RSTV        EQU   $3F2

* MLI entry point
MLI         EQU   $BF00

* ProDOS MLI command numbers
QUITCMD     EQU   $65
GTIMECMD    EQU   $82
CREATCMD    EQU   $C0
ONLNCMD     EQU   $C5
GPFXCMD     EQU   $C7
OPENCMD     EQU   $C8
READCMD     EQU   $CA
WRITECMD    EQU   $CB
CLSCMD      EQU   $CC

* IO Buffer for reading file (512 bytes)
IOBUF       EQU   $4000

* File will be read 512 bytes at a time into this buffer
RDBUF       EQU   $5000
RDBUFEND    EQU   $5200

* Address in aux memory where ROM will be loaded
AUXADDR     EQU   $8000

* Address in aux memory where the MOS shim is located
AUXMOS1     EQU   $2000                      ; Temp staging area in Aux
EAUXMOS1    EQU   $3000                      ; End of staging area
AUXMOS      EQU   $D000                      ; Final location in aux LC

* Address is aux memory where the MOS entrypoints are
AUXVEC      EQU   $FFB9                      ; Final location in aux LC

START       STZ   BLOCKS
            LDX   #$00
:L1         LDA   HELLO,X                    ; Signon message
            BEQ   :S1
            JSR   COUT1
            INX
            BRA   :L1
:S1         JSR   CROUT
            JSR   SETPRFX

            STA   $C009                      ; Alt ZP on
            STZ   $9F                        ; WARMSTRT - set cold!
            STA   $C008                      ; Alt ZP off

            LDA   #<ROMFILE
            STA   OPENPL+1
            LDA   #>ROMFILE
            STA   OPENPL+2
            JSR   OPENFILE                   ; Open ROM file
            BCC   :S2
            LDX   #$00
:L2         LDA   CANTOPEN,X
            BEQ   :ER1
            JSR   COUT1
            INX
            BRA   :L2
            BRA   :S2
:ER1        JSR   CROUT
            JSR   BELL
            RTS

:S2         LDA   OPENPL+5                   ; File reference number
            STA   READPL+1

:L3         LDA   #'.'+$80                   ; Read file block by block
            JSR   COUT1
            JSR   RDBLK
            BCS   :S3                        ; EOF (0 bytes left) or some error

            LDA   #<RDBUF                    ; Source start addr -> A1L,A1H
            STA   A1L
            LDA   #>RDBUF
            STA   A1H

            LDA   #<RDBUFEND                 ; Source end addr -> A2L,A2H
            STA   A2L
            LDA   #>RDBUFEND
            STA   A2H

            LDA   #<AUXADDR                  ; Dest in aux -> A4L, A4H
            STA   A4L
            LDA   #>AUXADDR
            LDX   BLOCKS
:L4         CPX   #$00
            BEQ   :S25
            INC
            INC
            DEX
            BRA   :L4
:S25        STA   A4H

            SEC                              ; Main -> Aux
            JSR   AUXMOVE

            INC   BLOCKS
            BRA   :L3

:S3         LDA   OPENPL+5                   ; File reference number
            STA   CLSPL+1
            JSR   CLSFILE

            LDA   #<MOSSHIM                  ; Start address of MOS shim
            STA   A1L
            LDA   #>MOSSHIM
            STA   A1H

            LDA   #<MOSSHIM+$1000            ; End address of MOS shim
            STA   A2L
            LDA   #>MOSSHIM+$1000
            STA   A2H

            LDA   #<AUXMOS1                  ; To AUXMOS1 in aux memory
            STA   A4L
            LDA   #>AUXMOS1
            STA   A4H

            SEC                              ; Main->aux
            JSR   AUXMOVE

            LDA   #<RESET                    ; Set reset vector->RESET
            STA   RSTV
            LDA   #>RESET
            STA   RSTV+1
            EOR   #$A5                       ; Checksum
            STA   RSTV+2

            TSX
            STX   $0100                      ; Store SP at $0100
            LDA   #<AUXMOS1                  ; Start address in aux, for XFER
            STA   STRTL
            LDA   #>AUXMOS1
            STA   STRTH
            SEC                              ; Main -> Aux
            BIT   $FF58                      ; Set V; Use page zero and stack in aux
            JMP   XFER

:DONE       JSR   CROUT
            JSR   BELL
            RTS
BLOCKS      DB    0                          ; Counter for blocks read

* Set prefix if not already set
SETPRFX     LDA   GPFXCMD
            STA   :OPC7                      ; Initialize cmd byte to $C7
:L1         JSR   MLI
:OPC7       DB    $00
            DW    GPFXPL
            LDX   RDBUF
            BNE   :S1
            LDA   $BF30
            STA   ONLPL+1                    ; Device number
            JSR   MLI
            DB    ONLNCMD
            DW    ONLPL
            LDA   RDBUF+1
            AND   #$0F
            TAX
            INX
            STX   RDBUF
            LDA   #$2F
            STA   RDBUF+1
            DEC   :OPC7
            BNE   :L1
:S1         RTS

* Reset handler
* XFER to AUXMOS ($C000) in aux, AuxZP on, LC on
RESET       TSX
            STX   $0100
            LDA   $C08B                      ; Rd/Wt LC, bank one
            LDA   $C08B
            LDA   #<AUXMOS
            STA   STRTL
            LDA   #>AUXMOS
            STA   STRTH
            SEC
            BIT   $FF58
            JMP   XFER
            RTS

* Copy 512 bytes from RDBUF to AUXBLK in aux LC
COPYAUXBLK
            LDA   $C08B                      ; R/W LC RAM, bank 1
            LDA   $C08B
            STA   $C009                      ; Alt ZP (and Alt LC) on

            LDY   #$00
:L1         LDA   RDBUF,Y
            STA   $C005                      ; Write aux mem
            STA   AUXBLK,Y
            STA   $C004                      ; Write main mem
            CPY   #$FF
            BEQ   :S1
            INY
            BRA   :L1

:S1         LDY   #$00
:L2         LDA   RDBUF+$100,Y
            STA   $C005                      ; Write aux mem
            STA   AUXBLK+$100,Y
            STA   $C004                      ; Write main mem
            CPY   #$FF
            BEQ   :S2
            INY
            BRA   :L2

:S2         STA   $C008                      ; Alt ZP off
            LDA   $C081                      ; Bank the ROM back in
            LDA   $C081
            RTS

* ProDOS file handling for MOS OSFILE LOAD call
* Return A=0 if successful
*        A=1 if file not found
*        A=2 if read error
LOADFILE    LDX   $0100                      ; Recover SP
            TXS
            LDA   $C081                      ; Gimme the ROM!
            LDA   $C081

            STZ   BLOCKS
            LDA   #<MOSFILE
            STA   OPENPL+1
            LDA   #>MOSFILE
            STA   OPENPL+2
            JSR   OPENFILE
            BCS   :NOTFND                    ; File not found
:L1         LDA   OPENPL+5                   ; File ref number
            STA   READPL+1
            JSR   RDBLK
            BCC   :S1
            CMP   #$4C                       ; EOF
            BEQ   :EOF
            BRA   :READERR

:S1         LDA   #<RDBUF
            STA   A1L
            LDA   #>RDBUF
            STA   A1H

            LDA   #<RDBUFEND
            STA   A2L
            LDA   #>RDBUFEND
            STA   A2H

            LDA   FBLOAD
            STA   A4L
            LDA   FBLOAD+1
            LDX   BLOCKS
:L2         CPX   #$00
            BEQ   :S2
            INC
            INC
            DEX
            BRA   :L2
:S2         STA   A4H

            SEC                              ; Main -> AUX
            JSR   AUXMOVE

            INC   BLOCKS
            BRA   :L1

:NOTFND     LDA   #$01                       ; Nothing found
            PHA
            BRA   :EXIT
:READERR    LDA   #$02                       ; Read error
            PHA
            BRA   :EOF2
:EOF        LDA   #$00                       ; Success
            PHA
:EOF2       LDA   OPENPL+5                   ; File ref num
            STA   CLSPL+1
            JSR   CLSFILE
:EXIT       LDA   $C08B                      ; R/W RAM, bank 1
            LDA   $C08B
            LDA   #<OSFILERET                ; Return to caller in aux
            STA   STRTL
            LDA   #>OSFILERET
            STA   STRTH
            PLA
            SEC
            BIT   $FF58
            JMP   XFER

* ProDOS file handling for MOS OSFILE SAVE call
* Return A=0 if successful
*        A=1 if unable to create/open
*        A=2 if error during save
SAVEFILE    LDX   $0100                      ; Recover SP
            TXS
            LDA   $C081                      ; Gimme the ROM!
            LDA   $C081

            STZ   BLOCKS
            LDA   #<MOSFILE
            STA   CREATEPL+1
            STA   OPENPL+1
            LDA   #>MOSFILE
            STA   CREATEPL+2
            STA   OPENPL+2
            LDA   #$C3                       ; Access unlocked
            STA   CREATEPL+3
            LDA   #$06                       ; Filetype BIN
            STA   CREATEPL+4
            LDA   FBSTRT                     ; Auxtype = save address
            STA   CREATEPL+5
            LDA   FBSTRT+1
            STA   CREATEPL+6
            LDA   #$01                       ; Storage type - file
            STA   CREATEPL+7
            LDA   $BF90                      ; Current date
            STA   CREATEPL+8
            LDA   $BF91
            STA   CREATEPL+9
            LDA   $BF92                      ; Current time
            STA   CREATEPL+10
            LDA   $BF93
            STA   CREATEPL+11
            JSR   CRTFILE
            JSR   OPENFILE
            BCS   :FWD1                      ; :CANTOPEN error

            SEC                              ; Compute file length
            LDA   FBEND
            SBC   FBSTRT
            STA   :LEN
            LDA   FBEND+1
            SBC   FBSTRT+1
            STA   :LEN+1

:L1         LDA   FBSTRT                     ; Setup for first block
            STA   A1L
            STA   A2L
            LDA   FBSTRT+1
            STA   A1H
            STA   A2H
            INC   A2H                        ; $200 = 512 bytes
            INC   A2H
            LDA   #$00                       ; 512 byte request count
            STA   WRITEPL+4
            LDA   #$02
            STA   WRITEPL+5
            LDX   BLOCKS
:L2         CPX   #$00                       ; Adjust for subsequent blks
            BEQ   :S1
            INC   A1H
            INC   A1H
            INC   A2H
            INC   A2H
            DEX
            BRA   :L2

:FWD1       BRA   :CANTOPEN                  ; Forwarding call from above

:S1         LDA   :LEN+1                     ; MSB of length remaining
            CMP   #$02
            BCS   :S2                        ; MSB of len >= 2 (not last)

            CMP   #$00                       ; If no bytes left ...
            BNE   :S3
            LDA   :LEN
            BNE   :S3
            BRA   :NORMALEND

:S3         LDA   FBEND                      ; Adjust for last block
            STA   A2L
            LDA   FBEND+1
            STA   A2H
            LDA   :LEN
            STA   WRITEPL+4                  ; Remaining bytes to write
            LDA   :LEN+1
            STA   WRITEPL+5

:S2         LDA   #<RDBUF
            STA   A4L
            LDA   #>RDBUF
            STA   A4H

            CLC                              ; Aux -> Main
            JSR   AUXMOVE

            LDA   OPENPL+5                   ; File ref number
            STA   WRITEPL+1
            JSR   WRTBLK
            BCS   :WRITEERR

            BRA   :UPDLEN

:ENDLOOP    INC   BLOCKS
            BRA   :L1

:UPDLEN
            SEC                              ; Update length remaining
            LDA   :LEN
            SBC   WRITEPL+4
            STA   :LEN
            LDA   :LEN+1
            SBC   WRITEPL+5
            STA   :LEN+1
            BRA   :ENDLOOP

:CANTOPEN
            LDA   #$01                       ; Can't open/create
            BRA   :EXIT
:WRITEERR
            LDA   OPENPL+5                   ; File ref num
            STA   CLSPL+1
            JSR   CLSFILE
            LDA   #$02                       ; Write error
            BRA   :EXIT
:NORMALEND
            LDA   OPENPL+5                   ; File ref num
            STA   CLSPL+1
            JSR   CLSFILE
            LDA   #$00                       ; Success!
            BCC   :EXIT                      ; If close OK
            LDA   #$02                       ; Write error
:EXIT       PHA
            LDA   $C08B                      ; R/W RAM, bank 1
            LDA   $C08B
            LDA   #<OSFILERET                ; Return to caller in aux
            STA   STRTL
            LDA   #>OSFILERET
            STA   STRTH
            PLA
            SEC
            BIT   $FF58
            JMP   XFER
:LEN        DW    $0000

* Quit to ProDOS
QUIT        INC   $3F4                       ; Invalidate powerup byte
            STA   $C054                      ; PAGE2 off
            JSR   MLI
            DB    QUITCMD
            DW    QUITPL
            RTS

* Obtain catalog of current PREFIX dir
CATALOG     LDX   $0100                      ; Recover SP
            TXS
            LDA   $C081                      ; Select ROM
            LDA   $C081

            JSR   MLI                        ; Fetch prefix into RDBUF
            DB    GPFXCMD
            DW    GPFXPL
            BNE   CATEXIT                    ; If prefix not set

            LDA   #<RDBUF
            STA   OPENPL+1
            LDA   #>RDBUF
            STA   OPENPL+2
            JSR   OPENFILE
            BCS   CATEXIT                    ; Can't open dir

CATREENTRY
            LDA   OPENPL+5                   ; File ref num
            STA   READPL+1
            JSR   RDBLK
            BCC   :S1
            CMP   #$4C                       ; EOF
            BEQ   :EOF
            BRA   :READERR

:S1         JSR   COPYAUXBLK

            LDA   $C08B                      ; R/W RAM, bank 1
            LDA   $C08B
            LDA   #<PRONEBLK
            STA   STRTL
            LDA   #>PRONEBLK
            STA   STRTH
            SEC
            BIT   $FF58
            JMP   XFER

:READERR
:EOF        LDA   OPENPL+5                   ; File ref num
            STA   CLSPL+1
            JSR   CLSFILE

CATEXIT     LDA   $C08B                      ; R/W LC RAM, bank 1
            LDA   $C08B
            LDA   #<STARCATRET
            STA   STRTL
            LDA   #>STARCATRET
            STA   STRTH
            PLA
            SEC
            BIT   $FF58
            JMP   XFER

* PRONEBLK call returns here ...
CATALOGRET
            LDX   #0100                      ; Recover SP
            TXS
            LDA   $C081                      ; ROM please
            LDA   $C081
            BRA   CATREENTRY

* Create disk file
CRTFILE     JSR   MLI
            DB    CREATCMD
            DW    CREATEPL
            RTS

* Open disk file
OPENFILE    JSR   MLI
            DB    OPENCMD
            DW    OPENPL
            RTS

* Close disk file
CLSFILE     JSR   MLI
            DB    CLSCMD
            DW    CLSPL
            RTS

* Read 512 bytes into RDBUF
RDBLK       JSR   MLI
            DB    READCMD
            DW    READPL
            RTS

* Write 512 bytes from RDBUF
WRTBLK      JSR   MLI
            DB    WRITECMD
            DW    WRITEPL
            RTS

HELLO       ASC   "Applecorn - (c) Bobbi 2021 GPLv3"
            HEX   00
CANTOPEN    ASC   "Unable to open BASIC.ROM"
            HEX   00
ROMFILE     STR   "BASIC.ROM"

* ProDOS Parameter lists for MLI calls
OPENPL      HEX   03                         ; Number of parameters
            DW    $0000                      ; Pointer to filename
            DW    IOBUF                      ; Pointer to IO buffer
            DB    $00                        ; Reference number returned

CREATEPL    HEX   07                         ; Number of parameters
            DW    $0000                      ; Pointer to filename
            DB    $00                        ; Access
            DB    $00                        ; File type
            DW    $0000                      ; Aux type
            DB    $00                        ; Storage type
            DW    $0000                      ; Create date
            DW    $0000                      ; Create time

READPL      HEX   04                         ; Number of parameters
            DB    $00                        ; Reference number
            DW    RDBUF                      ; Pointer to data buffer
            DW    512                        ; Request count
            DW    $0000                      ; Trans count

WRITEPL     HEX   04                         ; Number of parameters
            DB    $01                        ; Reference number
            DW    RDBUF                      ; Pointer to data buffer
            DW    $00                        ; Request count
            DW    $0000                      ; Trans count

CLSPL       HEX   01                         ; Number of parameters
            DB    $00                        ; Reference number

ONLPL       HEX   02                         ; Number of parameters
            DB    $00                        ; Unit num
            DW    RDBUF+1                    ; Buffer

GPFXPL      HEX   01                         ; Number of parameters
            DW    RDBUF                      ; Buffer

QUITPL      HEX   04                         ; Number of parameters
            DB    $00
            DW    $0000
            DB    $00
            DW    $0000

* Buffer for Acorn MOS filename
MOSFILE     DS    20                         ; 20 bytes ought to be enough

* Acorn MOS format OSFILE param list
FILEBLK
FBPTR       DW    $0000                      ; Pointer to name (in aux)
FBLOAD      DW    $0000                      ; Load address
            DW    $0000
FBEXEC      DW    $0000                      ; Exec address
            DW    $0000
FBSTRT      DW    $0000                      ; Start address for SAVE
            DW    $0000
FBEND       DW    $0000                      ; End address for SAVE
            DW    $0000

**********************************************************
* Everything below here is the BBC Micro 'virtual machine'
* in Apple //e Auxiliary memory
**********************************************************

ZP1         EQU   $90                        ; $90-$9f are Econet space
                                             ; so safe to use
ZP2         EQU   $92

ZP3         EQU   $94

ROW         EQU   $96                        ; Cursor row
COL         EQU   $97                        ; Cursor column
WARMSTRT    EQU   $9F                        ; Cold or warm start
FAULT       EQU   $FD                        ; Error message pointer
ESCFLAG     EQU   $FF                        ; Escape status
BRKV        EQU   $202                       ; BRK vector
CLIV        EQU   $208                       ; OSCLI vector
BYTEV       EQU   $20A                       ; OSBYTE vector
WORDV       EQU   $20C                       ; OSWORD vector
WRCHV       EQU   $20E                       ; OSWRCH vector
RDCHV       EQU   $210                       ; OSRDCH vector
FILEV       EQU   $212                       ; OSFILE vector
ARGSV       EQU   $214                       ; OSARGS vector
BGETV       EQU   $216                       ; OSBGET vector
BPUTV       EQU   $218                       ; OSBPUT vector
GBPBV       EQU   $21A                       ; OSGBPB vector
FINDV       EQU   $21C                       ; OSFIND vector

MAGIC       EQU   $BC                        ; Arbitrary value

MOSSHIM
            ORG   AUXMOS                     ; MOS shim implementation

*
* Shim code to service Acorn MOS entry points using
* Apple II monitor routines
* This code is initially loaded into aux mem at AUXMOS1
* Then relocated into aux LC at AUXMOS by MOSINIT
*

MOSINIT
            STA   $C005                      ; Make sure we are writing aux
            STA   $C000                      ; Make sure 80STORE is off

            LDA   $C08B                      ; LC RAM Rd/Wt, 1st 4K bank
            LDA   $C08B

            LDA   WARMSTRT                   ; Don't relocate on restart
            CMP   #MAGIC
            BEQ   :NORELOC

            LDA   #<AUXMOS1                  ; Relocate MOS shim
            STA   A1L
            LDA   #>AUXMOS1
            STA   A1H
            LDA   #<EAUXMOS1
            STA   A2L
            LDA   #>EAUXMOS1
            STA   A2H
            LDA   #<AUXMOS
            STA   A4L
            LDA   #>AUXMOS
            STA   A4H
:L1         LDA   (A1L)
            STA   (A4L)
            LDA   A1H
            CMP   A2H
            BNE   :S1
            LDA   A1L
            CMP   A2L
            BNE   :S1
            BRA   :S4
:S1         INC   A1L
            BNE   :S2
            INC   A1H
:S2         INC   A4L
            BNE   :S3
            INC   A4H
:S3         BRA   :L1

:S4         LDA   #<MOSVEC-MOSINIT+AUXMOS1
            STA   A1L
            LDA   #>MOSVEC-MOSINIT+AUXMOS1
            STA   A1H
            LDA   #<MOSVEND-MOSINIT+AUXMOS1
            STA   A2L
            LDA   #>MOSVEND-MOSINIT+AUXMOS1
            STA   A2H
            LDA   #<AUXVEC
            STA   A4L
            LDA   #>AUXVEC
            STA   A4H
:L2         LDA   (A1L)
            STA   (A4L)
            LDA   A1H
            CMP   A2H
            BNE   :S5
            LDA   A1L
            CMP   A2L
            BNE   :S5
            BRA   :S8
:S5         INC   A1L
            BNE   :S6
            INC   A1H
:S6         INC   A4L
            BNE   :S7
            INC   A4H
:S7         BRA   :L2

:NORELOC
:S8         STA   $C00D                      ; 80 col on
            STA   $C003                      ; Alt charset off
            STA   $C055                      ; PAGE2

            STZ   ROW
            STZ   COL
            JSR   CLEAR

            STZ   ESCFLAG

            LDA   #<MOSBRKHDLR
            STA   BRKV
            LDA   #>MOSBRKHDLR
            STA   BRKV+1

            LDA   #<OSCLI                    ; Initialize MOS vectors
            STA   CLIV
            LDA   #>OSCLI
            STA   CLIV+1
            LDA   #<OSBYTE
            STA   BYTEV
            LDA   #>OSBYTE
            STA   BYTEV+1
            LDA   #<OSWORD
            STA   WORDV
            LDA   #>OSWORD
            STA   WORDV+1
            LDA   #<OSWRCH
            STA   WRCHV
            LDA   #>OSWRCH
            STA   WRCHV+1
            LDA   #<OSRDCH
            STA   RDCHV
            LDA   #>OSRDCH
            STA   RDCHV+1
            LDA   #<OSFILE
            STA   FILEV
            LDA   #>OSFILE
            STA   FILEV+1
            LDA   #<OSARGS
            STA   ARGSV
            LDA   #>OSARGS
            STA   ARGSV+1
            LDA   #<OSBGET
            STA   BGETV
            LDA   #>OSBGET
            STA   BGETV+1
            LDA   #<OSBPUT
            STA   BPUTV
            LDA   #>OSBPUT
            STA   BPUTV+1
            LDA   #<OSGBPB
            STA   GBPBV
            LDA   #>OSGBPB
            STA   GBPBV+1
            LDA   #<OSFIND
            STA   FINDV
            LDA   #>OSFIND
            STA   FINDV+1

            LDA   #<:HELLO
            LDY   #>:HELLO
            JSR   PRSTR

            LDA   WARMSTRT
            CMP   #MAGIC
            BNE   :S9
            LDA   #<:OLDM
            LDY   #>:OLDM
            JSR   PRSTR

:S9         LDA   #MAGIC                     ; So we do not reloc again
            STA   WARMSTRT

            LDA   #$01
            JMP   AUXADDR                    ; Start Acorn ROM
* No return
:HELLO      ASC   'AppleMOS v0.01'
            DB    $0D,$0A,$0D,$0A,$00
:OLDM       ASC   '(Use OLD to recover any program)'
            DB    $0D,$0A,$0D,$0A,$00
* Clear to EOL
CLREOL      LDA   ROW
            ASL
            TAX
            LDA   SCNTAB,X                   ; LSB of row
            STA   ZP1
            LDA   SCNTAB+1,X                 ; MSB of row
            STA   ZP1+1
            LDA   COL
            PHA
:L1         LDA   COL
            LSR
            TAY
            BCC   :S1
            STA   $C004                      ; Write main mem
:S1         LDA   #" "
            STA   (ZP1),Y
            STA   $C005                      ; Write aux mem
            LDA   COL
            CMP   #79
            BEQ   :S2
            INC   COL
            BRA   :L1
:S2         PLA
            STA   COL
            RTS

* Clear the screen
CLEAR       STZ   ROW
            STZ   COL
:L1         JSR   CLREOL
:S2         LDA   ROW
            CMP   #23
            BEQ   :S3
            INC   ROW
            BRA   :L1
:S3         STZ   ROW
            STZ   COL
            RTS

* Print string pointed to by A,Y to the screen
PRSTR       STA   ZP2                        ;  String in A,Y
            STY   ZP2+1
:L1         LDA   (ZP2)                      ; Ptr to string in ZP1
            BEQ   :S1
            JSR   $FFEE                      ; OSWRCH
            INC   ZP2
            BNE   :L1
            INC   ZP2+1
            BRA   :L1
:S1         RTS

* Print hex byte in A
PRHEX       PHA
            LSR
            LSR
            LSR
            LSR
            AND   #$0F
            JSR   PRNIB
            PLA
            AND   #$0F
            JSR   PRNIB
            RTS

* Print hex nibble in A
PRNIB       CMP   #$0A
            BCC   :S1
            CLC                              ; >= $0A
            ADC   #'A'-$0A
            JSR   $FFEE                      ; OSWRCH
            RTS
:S1         ADC   #'0'                       ; < $0A
            JSR   $FFEE                      ; OSWRCH
            RTS

OSRDRM      LDA   #<OSRDRMM
            LDY   #>OSRDRMM
            JSR   PRSTR
            RTS
OSRDRMM     ASC   'OSRDDRM.'
            DB    $00

OSEVEN      LDA   #<OSEVENM
            LDY   #>OSEVENM
            JSR   PRSTR
            RTS
OSEVENM     ASC   'OSEVEN.'
            DB    $00

OSINIT      LDA   #<OSINITM
            LDY   #>OSINITM
            JSR   PRSTR
            RTS
OSINITM     ASC   'OSINITM.'
            DB    $00

OSREAD      LDA   #<OSREADM
            LDY   #>OSREADM
            JSR   PRSTR
            RTS
OSREADM     ASC   'OSREAD.'
            DB    $00

OSFIND      LDA   #<OSFINDM
            LDY   #>OSFINDM
            JSR   PRSTR
            RTS
OSFINDM     ASC   'OSFIND.'
            DB    $00

OSGBPB      LDA   #<OSGBPBM
            LDY   #>OSGBPBM
            JSR   PRSTR
            RTS
OSGBPBM     ASC   'OSGBPB.'
            DB    $00

OSBPUT      LDA   #<OSBPUTM
            LDY   #>OSBPUTM
            JSR   PRSTR
            RTS
OSBPUTM     ASC   'OSBPUT.'
            DB    $00

OSBGET      LDA   #<OSBGETM
            LDY   #>OSBGETM
            JSR   PRSTR
            RTS
OSBGETM     ASC   'OSBGET.'
            DB    $00

OSARGS      LDA   #<OSARGSM
            LDY   #>OSARGSM
            JSR   PRSTR
            RTS
OSARGSM     ASC   'OSARGS.'
            DB    $00

OSFILE      PHX
            PHY
            PHA

            STX   ZP1                        ; LSB of parameter block
            STY   ZP1+1                      ; MSB of parameter block
            LDA   #<FILEBLK
            STA   ZP2
            LDA   #>FILEBLK
            STA   ZP2+1
            LDY   #$00                       ; Copy to FILEBLK in main mem
:L1         LDA   (ZP1),Y
            STA   $C004                      ; Write main
            STA   (ZP2),Y
            STA   $C005                      ; Write aux
            INY
            CPY   #$12
            BNE   :L1

            LDA   (ZP1)                      ; Pointer to filename->ZP2
            STA   ZP2
            LDY   #$01
            LDA   (ZP1),Y
            STA   ZP2+1
            LDA   #<MOSFILE+1
            STA   ZP1
            LDA   #>MOSFILE+1
            STA   ZP1+1
            LDY   #$00
:L2         LDA   (ZP2),Y
            STA   $C004                      ; Write main
            STA   (ZP1),Y
            STA   $C005                      ; Write aux
            INY
            CMP   #$0D                       ; Carriage return
            BNE   :L2
            DEY
            STA   $C004                      ; Write main
            STY   MOSFILE                    ; Length (Pascal string)
            STA   $C005                      ; Write aux

            LDA   STRTL                      ; Backup STRTL/STRTH
            STA   TEMP1
            LDA   STRTH
            STA   TEMP2

            TSX
            STX   $0101                      ; Store alt SP in $0101

            PLA
            PHA
            BEQ   :S1                        ; A=00 -> SAVE
            CMP   #$FF
            BEQ   :S2                        ; A=FF -> LOAD

            LDA   #<OSFILEM                  ; If not implemented, print msg
            LDY   #>OSFILEM
            JSR   PRSTR
            PLA
            PHA
            JSR   PRHEX
            LDA   #<OSFILEM2
            LDY   #>OSFILEM2
            JSR   PRSTR
            PLA
            PLY
            PLX
            RTS

:S1         LDA   #<SAVEFILE
            STA   STRTL
            LDA   #>SAVEFILE
            STA   STRTH
            BRA   :S3
:S2         LDA   #<LOADFILE
            STA   STRTL
            LDA   #>LOADFILE
            STA   STRTH
:S3         CLC                              ; Use main memory
            CLV                              ; Use main ZP and LC
            JMP   XFER
OSFILERET
            LDX   $0101                      ; Recover alt SP from $0101
            TXS
            PHA                              ; Return value
            LDA   TEMP1                      ; Restore STRTL/STRTH
            STA   STRTL
            LDA   TEMP2
            STA   STRTH
            PLA                              ; Return value
            PLY                              ; Value of A on entry

            CPY   #$FF                       ; LOAD
            BNE   :S4
            CMP   #$01                       ; No file found
            BNE   :SL1
            BRK
            DB    $D6                        ; Error number ?? TBD
            ASC   'File not found'
            BRK
            LDA   #$00                       ; Return code - no file
            BRA   :EXIT
:SL1        CMP   #$02                       ; Read error
            BNE   :SL2
            BRK
            DB    $D6                        ; Error number
            ASC   'Read error'
            BRK
            LDA   #$01                       ; Return code - file found
            BRA   :EXIT
:SL2        LDA   #$01                       ; Return code - file found
            BRA   :EXIT

:S4         CPY   #$00                       ; SAVE
            BNE   :S6
            CMP   #$01                       ; Unable to create or open
            BNE   :SS1
            BRK
            DB    $D5                        ; Error number ?? TBD
            ASC   'Create error'
            BRK
            BRA   :S6
:SS1        CMP   #$02                       ; Unable to write
            BNE   :S6
            BRK
            DB    $D5                        ; Error number ?? TBD
            ASC   'Write error'
            BRK
:S6         LDA   #$00
:EXIT       PLY
            PLX
            RTS
OSFILEM     ASC   'OSFILE($'
            DB    $00
OSFILEM2    ASC   ')'
            DB    $00
TEMP1       DB    $00
TEMP2       DB    $00

OSRDCH      PHX
            PHY
            JSR   GETCHRC
            STA   OLDCHAR
:L1         LDA   CURS+1                     ; Skip unless CURS=$8000
            CMP   #$80
            BNE   :S1
            LDA   CURS
            BNE   :S1

            STZ   CURS
            STZ   CURS+1
            LDA   CSTATE
            ROR
            BCS   :S2
            LDA   #'_'
            BRA   :S3
:S2         LDA   OLDCHAR
:S3         JSR   PRCHRC
            INC   CSTATE
:S1         INC   CURS
            BNE   :S4
            INC   CURS+1
:S4         LDA   $C000                      ; Keyboard data/strobe
            AND   #$80
            BEQ   :L1
            LDA   OLDCHAR                    ; Erase cursor
            JSR   PRCHRC
            LDA   $C000
            AND   #$7F
            STA   $C010                      ; Clear strobe
            PLY
            PLX
            CMP   #$1B                       ; Escape pressed?
            BEQ   :S5
            CLC
            RTS
:S5         SEC
            RTS
CURS        DW    $0000                      ; Counter
CSTATE      DB    $00                        ; Cursor on or off
OLDCHAR     DB    $00                        ; Char under cursor

* Print char in A at ROW,COL
PRCHRC      PHA
            LDA   ROW
            ASL
            TAX
            LDA   SCNTAB,X                   ; LSB of row address
            STA   ZP1
            LDA   SCNTAB+1,X                 ; MSB of row address
            STA   ZP1+1
            LDA   COL
            LSR
            TAY
            BCC   :S1
            STA   $C004                      ; Write main memory
:S1         PLA
            ORA   #$80
            STA   (ZP1),Y                    ; Screen address
            STA   $C005                      ; Write aux mem again
            RTS

* Return char at ROW,COL in A
GETCHRC     LDA   ROW
            ASL
            TAX
            LDA   SCNTAB,X
            STA   ZP1
            LDA   SCNTAB+1,X
            STA   ZP1+1
            LDA   COL
            LSR
            TAY
            BCC   :S1
            STA   $C002                      ; Read main memory
:S1         LDA   (ZP1),Y
            STX   $C003                      ; Read aux mem again
            RTS

* Perform backspace & delete operation
BACKSPC     LDA   COL
            BEQ   :S1
            DEC   COL
            BRA   :S2
:S1         LDA   ROW
            BEQ   :S3
            DEC   ROW
            STZ   COL
:S2         LDA   #' '
            JSR   PRCHRC
:S3         RTS

* Perform backspace/cursor left operation
NDBSPC      LDA   COL
            BEQ   :S1
            DEC   COL
            BRA   :S3
:S1         LDA   ROW
            BEQ   :S3
            DEC   ROW
            STZ   COL
:S3         RTS

* Perform cursor right operation
CURSRT      LDA   COL
            CMP   #78
            BCS   :S1
            INC   COL
            RTS
:S1         LDA   ROW
            CMP   #22
            BCS   :S2
            INC   ROW
            STZ   COL
:S2         RTS

OSWRCH      PHA
            PHX
            PHY

            CMP   #$00                       ; NULL
            BNE   :T1
            BRA   :DONE
:T1         CMP   #$07                       ; BELL
            BNE   :T2
            JSR   BEEP
            BRA   :DONE
:T2         CMP   #$08                       ; Backspace
            BNE   :T3
            JSR   NDBSPC
            BRA   :DONE
:T3         CMP   #$09                       ; Cursor right
            BNE   :T4
            JSR   CURSRT
            BRA   :DONE
:T4         CMP   #$0A                       ; Linefeed
            BNE   :T5
            LDA   ROW
            CMP   #23
            BEQ   :SCROLL
            INC   ROW
            BRA   :DONE
:T5         CMP   #$0B                       ; Cursor up
            BNE   :T6
            LDA   ROW
            BEQ   :DONE
            DEC   ROW
            BRA   :DONE
:T6         CMP   #$0D                       ; Carriage return
            BNE   :T7
            JSR   CLREOL
            STZ   COL
            BRA   :DONE
:T7         CMP   #$0C                       ; Ctrl-L
            BNE   :T8
            JSR   CLEAR
            BRA   :DONE
:T8         CMP   #$1E                       ; Home
            BNE   :T9
            STZ   ROW
            STZ   COL
            BRA   :DONE
:T9         CMP   #$7F                       ; Delete
            BNE   :T10
            JSR   BACKSPC
            BRA   :DONE
:T10        JSR   PRCHRC
            LDA   COL
            CMP   #79
            BNE   :S2
            STZ   COL
            LDA   ROW
            CMP   #23
            BEQ   :SCROLL
            INC   ROW
            BRA   :DONE
:S2         INC   COL
            BRA   :DONE
:SCROLL     JSR   SCROLL
            STZ   COL
            JSR   CLREOL
:DONE       PLY
            PLX
            PLA
            RTS

* Scroll whole screen one line
SCROLL      LDA   #$00
:L1         PHA
            JSR   SCR1LINE
            PLA
            INC
            CMP   #23
            BNE   :L1
            RTS

* Copy line A+1 to line A
SCR1LINE    ASL                              ; Dest addr->ZP1
            TAX
            LDA   SCNTAB,X
            STA   ZP1
            LDA   SCNTAB+1,X
            STA   ZP1+1
            INX                              ; Source addr->ZP2
            INX
            LDA   SCNTAB,X
            STA   ZP2
            LDA   SCNTAB+1,X
            STA   ZP2+1
            LDY   #$00
:L1         LDA   (ZP2),Y
            STA   (ZP1),Y
            STA   $C002                      ; Read main mem
            STA   $C004                      ; Write main
            LDA   (ZP2),Y
            STA   (ZP1),Y
            STA   $C003                      ; Read aux mem
            STA   $C005                      ; Write aux mem
            INY
            CPY   #40
            BNE   :L1
            RTS

* Addresses of screen rows in PAGE2
SCNTAB      DW    $800,$880,$900,$980,$A00,$A80,$B00,$B80
            DW    $828,$8A8,$928,$9A8,$A28,$AA8,$B28,$BA8
            DW    $850,$8D0,$950,$9D0,$A50,$AD0,$B50,$BD0

OSWORD      STX   ZP1                        ; ZP1 points to control block
            STY   ZP1+1
            CMP   #$00                       ; OSWORD 0 read a line
            BNE   :S1
            LDA   (ZP1)                      ; Addr of buf -> ZP2
            STA   ZP2
            LDY   #$01
            LDA   (ZP1),Y
            STA   ZP2+1
            LDY   #$00
:L1         JSR   OSRDCH
            STA   (ZP2),Y
            INY
            CMP   #$0D                       ; Carriage return
            BEQ   :DONE
            CMP   #27                        ; Escape
            BEQ   :CANCEL
            CMP   #$7F                       ; Delete
            BEQ   :DELETE
            JSR   OSWRCH                     ; Echo
            BRA   :L1
:DONE       JSR   OSWRCH
            LDA   #$0A
            JSR   OSWRCH
            CLC
            RTS
:CANCEL     SEC
            RTS
:DELETE     DEY
            BEQ   :L1                        ; Nothing to delete
            JSR   OSWRCH                     ; Echo
            DEY
            BRA   :L1

:S1         PHA
            LDA   #<OSWORDM                  ; Unimplemented, print msg
            LDY   #>OSWORDM
            JSR   PRSTR
            PLA
            JSR   PRHEX
            LDA   #<OSWORDM2
            LDY   #>OSWORDM2
            JSR   PRSTR
            RTS
OSWORDM     STR   'OSWORD('
            DB    $00
OSWORDM2    STR   ')'
            DB    $00

OSBYTE      PHX
            PHY
:S1         CMP   $7C                        ; $7C = clear escape condition
            BNE   :S2
            PHA
            LDA   ESCFLAG
            AND   #$7F                       ; Clear MSB
            STA   ESCFLAG
            PLA
            PLY
            PLX
            RTS
:S2         CMP   $7D                        ; $7D = set escape condition
            BNE   :S3
            PHA
            ROR   ESCFLAG
            PLA
            PLY
            PLX
            RTS
:S3         CMP   #$7E                       ; $7E = ack detection of ESC
            BNE   :S4
            PHA
            LDA   ESCFLAG
            AND   #$7F                       ; Clear MSB
            STA   ESCFLAG
            PLA
            PLY
            PLX
            LDX   #$FF                       ; Means ESC condition cleared
            RTS
:S4         CMP   #$81                       ; $81 = Read key with time lim
            BNE   :S5
            PLY
            PLX
            JMP   GETKEY
:S5         CMP   #$82                       ; $82 = read high order address
            BNE   :S6
            PLY
            PLX
            LDY   #$FF                       ; $FFFF for I/O processor
            LDX   #$FF
            RTS
:S6         CMP   #$83                       ; $83 = read bottom of user mem
            BNE   :S7
            PLY
            PLX
            LDY   #$0E                       ; $0E00
            LDX   #$00
            RTS
:S7         CMP   #$84                       ; $84 = read top of user mem
            BNE   :S8
            PLY
            PLX
            LDY   #$80
            LDX   #$00
            RTS
:S8         CMP   #$85                       ; $85 = top user mem for mode
            BNE   :S9
            PLY
            PLX
            LDY   #$80
            LDX   #$00
            RTS
:S9         CMP   #$86                       ; $86 = read cursor pos
            BNE   :S10
            PLY
            PLX
            LDY   ROW
            LDX   COL
            RTS
:S10        CMP   #$DA                       ; $DA = clear VDU queue
            BNE   :S11
            PLY
            PLX
            RTS
:S11        PHA
            LDA   #<OSBYTEM
            LDY   #>OSBYTEM
            JSR   PRSTR
            PLA
            PHA
            JSR   PRHEX
            LDA   #<OSBM2
            LDY   #>OSBM2
            JSR   PRSTR
            PLA
            PLY
            PLX
            RTS
OSBYTEM     ASC   'OSBYTE($'
            DB    $00
OSBM2       ASC   ').'
            DB    $00

OSCLI       PHX
            PHY
            STX   ZP1                        ; Pointer to CLI
            STY   ZP1+1
            LDA   #<:QUIT
            STA   ZP2
            LDA   #>:QUIT
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S1
            JSR   STARQUIT
            BRA   :EXIT
:S1         LDA   #<:CAT
            STA   ZP2
            LDA   #>:CAT
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S2
            JSR   STARCAT
            BRA   :EXIT
:S2         LDA   #<:CAT2
            STA   ZP2
            LDA   #>:CAT2
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S3
            JSR   STARCAT
            BRA   :EXIT
:S3         LDA   #<:DIR
            STA   ZP2
            LDA   #>:DIR
            STA   ZP2+1
            JSR   STRCMP
            BCS   :UNSUPP
            JSR   STARDIR
            BRA   :EXIT
:UNSUPP     LDA   #<:OSCLIM
            LDY   #>:OSCLIM
            JSR   PRSTR
:EXIT       PLY
            PLX
            RTS
:QUIT       ASC   '*QUIT'
            DB    $0D
:CAT        ASC   '*CAT'
            DB    $0D
:CAT2       ASC   '*.'
            DB    $0D
:DIR        ASC   '*DIR'
            DB    $0D
:OSCLIM     ASC   'OSCLI.'
            DB    $00

* String comparison for OSCLI
* Compares CR-terminated strings in ZP1,ZP2
* Clear carry if match, set carry otherwise
STRCMP      LDY   #$00
:L1         LDA   (ZP1),Y
            CMP   (ZP2),Y
            BNE   :MISMTCH
            CMP   #$0D                       ; Carriage return
            BEQ   :MATCH
            INY
            BRA   :L1
:MATCH      CLC
            RTS
:MISMTCH    SEC
            RTS

STARQUIT    LDA   #<QUIT
            STA   STRTL
            LDA   #>QUIT
            STA   STRTH
            CLC                              ; Main memory
            CLV                              ; Main ZP & LC
            JMP   XFER

STARCAT     LDA   STRTL
            STA   TEMP1
            LDA   STRTH
            STA   TEMP2
            TSX
            STX   $0101                      ; Stash alt SP
            LDA   #<CATALOG
            STA   STRTL
            LDA   #>CATALOG
            STA   STRTH
            CLC                              ; Main memory
            CLV                              ; Main ZP & LC
            JMP   XFER
STARCATRET
            LDX   $0101                      ; Recover alt SP
            TXS
            LDA   TEMP1
            STA   STRTL
            LDA   TEMP2
            STA   STRTH
            RTS

* Print one block of a catalog. Called by CATALOG
* Block is in AUXBLK
PRONEBLK    LDX   $0101                      ; Recover alt SP
            TXS

            LDA   AUXBLK+4                   ; Get storage type
            AND   #$E0                       ; Mask 3 MSBs
            CMP   #$E0
            BNE   :NOTKEY                    ; Not a key block
            LDA   #<:DIRM
            LDY   #>:DIRM
            JSR   PRSTR
:NOTKEY     LDA   #$00
:L1         PHA
            JSR   PRONEENT
            PLA
            INC
            CMP   #13                        ; Number of dirents in block
            BNE   :L1
            BRA   :END

:END        LDA   STRTL
            STA   TEMP1
            LDA   STRTH
            STA   TEMP2

            LDA   #<CATALOGRET
            STA   STRTL
            LDA   #>CATALOGRET
            STA   STRTH
            CLC                              ; Main memory
            CLV                              ; Main ZP & LC
            JMP   XFER
:DIRM       ASC   'Directory: '
            DB    $00

* Print a single directory entry
* On entry: A = dirent index in AUXBLK
PRONEENT    TAX
            LDA   #<AUXBLK+4                 ; Skip pointers
            STA   ZP3
            LDA   #>AUXBLK+4
            STA   ZP3+1
:L1         CPX   #$00
            BEQ   :S1
            CLC
            LDA   #$27                       ; Size of dirent
            ADC   ZP3
            STA   ZP3
            LDA   #$00
            ADC   ZP3+1
            STA   ZP3+1
            DEX
            BRA   :L1
:S1         LDY   #$00
            LDA   (ZP3),Y
            BEQ   :EXIT                      ; Inactive entry
            AND   #$0F                       ; Len of filename
            TAX
            LDY   #$01
:L2         CPX   #$00
            BEQ   :S2
            LDA   (ZP3),Y
            JSR   $FFEE                      ; OSWRCH
            DEX
            INY
            BRA   :L2
:S2         JSR   $FFE7                      ; OSNEWL
:EXIT       RTS

* Command line is in ZP1
STARDIR     LDA   #<:MSG
            LDY   #>:MSG
            JSR   PRSTR
            RTS
:MSG        ASC   'Dir:'
            DB    $0A,$0D,$00

* Performs OSBYTE $81 INKEY$ function
* X,Y has time limit
GETKEY
:L1         CPX   #$00
            BEQ   :S1
            LDA   $C000                      ; Keyb data/strobe
            AND   #$80
            BNE   :GOTKEY
            JSR   DELAY                      ; 1/100 sec
            DEX
            BRA   :L1
:S1         CPY   #$00
            BEQ   :S2
            DEY
            LDX   #$FF
            BRA   :L1
:S2         LDA   $C000                      ; Keyb data/strobe
            AND   #$80
            BNE   :GOTKEY
            LDY   #$FF                       ; No key, time expired
            SEC
            RTS
:GOTKEY     LDA   $C000                      ; Fetch char
            AND   #$7F
            STA   $C010                      ; Clear strobe
            CMP   #27                        ; Escape
            BEQ   :ESC
            TAX
            LDY   #$00
            CLC
            RTS
:ESC        LDY   #27                        ; Escape
            SEC
            RTS

* Beep
BEEP        PHA
            PHX
            LDX   #$00
:L1         LDA   $C030
            JSR   DELAY
            INX
            CPX   #$00
            BNE   :L1
            PLX
            PLA
            RTS

* Delay approx 1/100 sec
DELAY       PHX
            PHY
            LDX   #$00
:L1         INX                              ; 2
            LDY   #$00                       ; 2
:L2         INY                              ; 2
            CPY   #$00                       ; 2
            BNE   :L2                        ; 3 (taken)
            CPX   #$05                       ; 2
            BNE   :L1                        ; 3 (taken)
            PLY
            PLX
            RTS

* Break handler
BRKHDLR     PHA
            TXA
            PHA
            CLD
            TSX
            LDA   $103,X                     ; Get PSW from stack
            AND   #$10
            BEQ   :S1                        ; IRQ
            SEC
            LDA   $0104,X
            SBC   #$01
            STA   FAULT
            LDA   $0105,X
            SBC   #$00
            STA   FAULT+1
            PLA
            TAX
            PLA
            CLI
            JMP   (BRKV)
:S1                                          ; No Apple IRQs to handle
            PLA
            TAX
            PLA
            RTS

PRERR       INY
            LDA   (FAULT),Y
            JSR   $FFE3                      ; OSASCI
            TAX
            BNE   PRERR
            RTS

MOSBRKHDLR
            LDY   #$00
            JSR   PRERR
            JSR   $FFE7                      ; OSNEWL
            JSR   $FFE7
            RTS

DEFBRKHDLR
            LDA   #<BRKM
            LDY   #>BRKM
            JSR   PRSTR
            PLA
            PLX
            PLY
            PHY
            PHX
            PHA
            TYA
            JSR   PRHEX
            TXA
            JSR   PRHEX
            LDA   #<BRKM2
            LDY   #>BRKM2
            JSR   PRSTR
            RTI
BRKM        ASC   "BRK($"
            DB    $00
BRKM2       ASC   ")."
            DB    $00
*
* Acorn MOS entry points at the top of RAM
*
MOSVEC
            JMP   OSRDRM                     ; FFB9
            NOP                              ; FFBC
            NOP                              ; FFBD
            NOP                              ; FFBE
            JMP   OSEVEN                     ; FFBF
            JMP   OSINIT                     ; FFC2
            JMP   OSREAD                     ; FFC5
            JMP   OSWRCH                     ; FFC8 NVWRCH Non vectored
            JMP   OSRDCH                     ; FFCB NVRDCH Non vectored
            JMP   (FINDV)                    ; FFCE OSFIND
            JMP   (GBPBV)                    ; FFD1 OSGBPB
            JMP   (BPUTV)                    ; FFD4 OSBPUT
            JMP   (BGETV)                    ; FFD7 OSBGET
            JMP   (ARGSV)                    ; FFDA OSARGS
            JMP   (FILEV)                    ; FFDD OSFILE
            JMP   (RDCHV)                    ; FFE0 OSRDCH
            CMP   #$0D                       ; FFE3 OSASCI
            BNE   :S1
            LDA   #$0A                       ; FFE7 OSNEWL
            JSR   OSWRCH
            LDA   #$0D
:S1         JMP   (WRCHV)                    ; FFEE OSWRCH
            JMP   (WORDV)                    ; FFF1 OSWORD
            JMP   (BYTEV)                    ; FFF4 OSBYTE
            JMP   (CLIV)                     ; FFF7 OSCLI
            NOP                              ; FFFA
            NOP                              ; FFFB
            NOP                              ; FFFC
            NOP                              ; FFFD
            DW    BRKHDLR                    ; FFFE
MOSVEND

* Buffer for one 512 byte disk block in aux mem
AUXBLK      DS    $200

