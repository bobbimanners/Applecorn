* Load an Acorn BBC Micro ROM in aux memory and
* Provide an environment where it can run
* Bobbi 2021
*
* Assembled with the Merlin 8 assembler.

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
SPFXCMD     EQU   $C6
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

START       STZ   BLOCKS
            LDX   #$00
:L1         LDA   HELLO,X                    ; Signon message
            BEQ   :S1
            JSR   COUT1
            INX
            BRA   :L1
:S1         JSR   CROUT
            JSR   SETPRFX
            JSR   DISCONN

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

            SEC                              ; Copy Main -> Aux
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

            SEC                              ; Copy MOS from Main->Aux
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
            JMP   XFER                       ; Jump to copied MOS code in Aux

;:DONE       JSR   CROUT
;            JSR   BELL
;            RTS
BLOCKS      DB    0                          ; Counter for blocks read

* Set prefix if not already set
SETPRFX     LDA   #GPFXCMD
            STA   :OPC7                      ; Initialize cmd byte to $C7
:L1         JSR   MLI
:OPC7       DB    $00
            DW    GSPFXPL
            LDX   $0300
            BNE   :S1
            LDA   $BF30
            STA   ONLPL+1                    ; Device number
            JSR   MLI
            DB    ONLNCMD
            DW    ONLPL
            LDA   $0301
            AND   #$0F
            TAX
            INX
            STX   $0300
            LDA   #$2F
            STA   $0301
            DEC   :OPC7
            BNE   :L1
:S1         RTS

* Disconnect /RAM
* Stolen from Beagle Bros Extra K
DISCONN     LDA   $BF98
            AND   #$30
            CMP   #$30
            BNE   :S1
            LDA   $BF26
            CMP   $BF10
            BNE   :S2
            LDA   $BF27
            CMP   $BF11
            BEQ   :S1
:S2         LDY   $BF31
:L1         LDA   $BF32,Y
            AND   #$F3
            CMP   #$B3
            BEQ   :S3
            DEY
            BPL   :L1
            BMI   :S1
:S3         LDA   $BF32,Y
            STA   $0302
:L2         LDA   $BF33,Y
            STA   $BF32,Y
            BEQ   :S4
            INY
            BNE   :L2
:S4         LDA   $BF26
            STA   $0300
            LDA   $BF27
            STA   $0301
            LDA   $BF10
            STA   $BF26
            LDA   $BF11
            STA   $BF27
            DEC   $BF31
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

* ProDOS file handling for MOS OSFIND OPEN call
OFILE       LDX   $0100                      ; Recover SP
            TXS
            LDA   $C081                      ; ROM, please
            LDA   $C081

            LDA   #<MOSFILE
            STA   OPENPL+1
            LDA   #>MOSFILE
            STA   OPENPL+2
            JSR   OPENFILE
            BCS   :NOTFND
            LDA   OPENPL+5                   ; File ref number
            PHA
            BRA   FINDEXIT
:NOTFND     LDA   #$00
            PHA
FINDEXIT    LDA   $C08B                      ; R/W RAM, LC bank 1
            LDA   $C08B
            LDA   #<OSFINDRET
            STA   STRTL
            LDA   #>OSFINDRET
            STA   STRTH
            PLA
            SEC
            BIT   $FF58
            JMP   XFER

* ProDOS file handling for MOS OSFIND CLOSE call
CFILE       LDX   $0100                      ; Recover SP
            TXS
            LDA   $C081                      ; ROM, please
            LDA   $C081

            LDA   MOSFILE                    ; File ref number
            STA   CLSPL+1
            JSR   CLSFILE

            JMP   FINDEXIT

* ProDOS file handling for MOS OSBGET call
FILEGET     LDX   $0100                      ; Recover SP
            TXS
            LDA   $C081                      ; ROM, please
            LDA   $C081

            LDA   MOSFILE                    ; File ref number
            STA   READPL1+1
            JSR   MLI
            DB    READCMD
            DW    READPL1
            PHA
* TODO HANDLE ERROR CASE WHERE C IS SET

GETEXIT     LDA   $C08B                      ; R/W RAM, LC bank 1
            LDA   $C08B
            LDA   #<OSBGETRET
            STA   STRTL
            LDA   #>OSBGETRET
            STA   STRTH
            PLA
            SEC
            BIT   $FF58
            JMP   XFER

* ProDOS file handling for MOS OSBPUT call
FILEPUT     LDX   $0100                      ; Recover SP
            TXS
            LDA   $C081                      ; ROM, please
            LDA   $C081

            JMP   GETEXIT

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

* Set the prefix
SETPFX      LDX   $0100                      ; Recover SP
            TXS
            LDA   $C081                      ; ROM, ta!
            LDA   $C081
            JSR   MLI
            DB    SPFXCMD
            DW    SPFXPL
            BCC   :S1
            JSR   BELL                       ; Beep on error

:S1         LDA   $C08B                      ; R/W LC RAM, bank 1
            LDA   $C08B
            LDA   #<STARDIRRET
            STA   STRTL
            LDA   #>STARDIRRET
            STA   STRTH
            SEC
            BIT   $FF58
            JMP   XFER

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

READPL1     HEX   04                         ; Number of parameters
            DB    #00                        ; Reference number
            DW    RDBUF                      ; Pointer to data buffer
            DW    1                          ; Request count
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
            DW    $301                       ; Buffer

GSPFXPL     HEX   01                         ; Number of parameters
            DW    $300                       ; Buffer

GPFXPL      HEX   01                         ; Number of parameters
            DW    RDBUF                      ; Buffer

SPFXPL      HEX   01                         ; Number of parameters
            DW    MOSFILE                    ; Buffer

QUITPL      HEX   04                         ; Number of parameters
            DB    $00
            DW    $0000
            DB    $00
            DW    $0000

* Buffer for Acorn MOS filename
MOSFILE     DS    64                         ; 64 bytes max prefix/file len

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

* $00-$8F Language workspace
* $90-$9F Network workspace
* $A0-$A7 NMI workspace
* $A8-$AF Non-MOS *command workspace
* $B0-$BF Temporary filing system workspace
* $C0-$CF Persistant filing system workspace
* $D0-$DF VDU driver workspace
* $E0-$EE Internal MOS workspace
* $EF-$FF MOS API workspace

OSAREG      EQU   $EF
OSXREG      EQU   $F0
OSYREG      EQU   $F1
OSCTRL      EQU   OSXREG
OSLPTR      EQU   $F2

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
FSCV        EQU   $21E                       ; FSCV misc file ops
MAGIC       EQU   $BC                        ; Arbitrary value

MOSSHIM
            ORG   AUXMOS                     ; MOS shim implementation

*
* Shim code to service Acorn MOS entry points using
* Apple II monitor routines
* This code is initially loaded into aux mem at AUXMOS1
* Then relocated into aux LC at AUXMOS by MOSINIT
*
* Initially executing at $3000 until copied to $D000

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
            LDA   #<MOSAPI
            STA   A4L
            LDA   #>MOSAPI
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

            LDX   #$35
INITPG2     LDA   DEFVEC,X
            STA   $200,X
            DEX
            BPL   INITPG2

            LDA   #<:HELLO
            LDY   #>:HELLO
            JSR   PRSTR

            LDA   #$09                       ; Print language name at $8009
            LDY   #$80
            JSR   PRSTR
            JSR   OSNEWL
            JSR   OSNEWL

            LDA   WARMSTRT
            CMP   #MAGIC
            BNE   :S9
            LDA   #<:OLDM
            LDY   #>:OLDM
            JSR   PRSTR

:S9         LDA   #MAGIC                     ; So we do not reloc again
            STA   WARMSTRT

            CLC                              ; CLC=Entered from RESET
            LDA   #$01                       ; $01=Entering application code
            JMP   AUXADDR                    ; Start Acorn ROM
* No return
:HELLO      ASC   'Applecorn MOS v0.01'
            DB    $0D,$0D,$00
:OLDM       ASC   '(Use OLD to recover any program)'
            DB    $0D,$0D,$00


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

* Print string pointed to by X,Y to the screen
OUTSTR      TXA

* Print string pointed to by A,Y to the screen
PRSTR       STA   ZP3+0                      ;  String in A,Y
            STY   ZP3+1
:L1         LDA   (ZP3)                      ; Ptr to string in ZP3
            BEQ   :S1
            JSR   OSASCI
            INC   ZP3
            BNE   :L1
            INC   ZP3+1
            BRA   :L1
:S1         RTS

* Print XY in hex
OUT2HEX     TYA
            JSR   OUTHEX
            TAX                              ; Continue into OUTHEX

* Print hex byte in A
OUTHEX      PHA
            LSR
            LSR
            LSR
            LSR
            AND   #$0F
            JSR   PRNIB
            PLA
            AND   #$0F                       ; Continue into PRNIB
;           JSR   PRNIB
;           RTS

* Print hex nibble in A
PRNIB       CMP   #$0A
            BCC   :S1
            CLC                              ; >= $0A
            ADC   #'A'-$0A
            JSR   OSWRCH
            RTS
:S1         ADC   #'0'                       ; < $0A
            JMP   OSWRCH

RDROM       LDA   #<OSRDRMM
            LDY   #>OSRDRMM
            JMP   PRSTR
OSRDRMM     ASC   'OSRDDRM.'
            DB    $00

EVENT       LDA   #<OSEVENM
            LDY   #>OSEVENM
            JMP   PRSTR
OSEVENM     ASC   'OSEVEN.'
            DB    $00

GSINTGO     LDA   #<OSINITM
            LDY   #>OSINITM
            JMP   PRSTR
OSINITM     ASC   'GSINITM.'
            DB    $00

GSRDGO      LDA   #<OSREADM
            LDY   #>OSREADM
            JMP   PRSTR
OSREADM     ASC   'GSREAD.'
            DB    $00

* OSFIND - open/close a file for byte access
FINDHND     PHX
            PHY
            PHA
            STX   ZP1                        ; Points to filename
            STY   ZP1+1

            LDA   STRTL                      ; Backup STRTL/STRTH
            STA   TEMP1
            LDA   STRTH
            STA   TEMP2
            TSX                              ; Stash alt ZP
            STX   $0101

            PLA
            PHA
            CMP   #$00                       ; A=$00 = close
            BEQ   :CLOSE

            LDA   #<MOSFILE+1
            STA   ZP2
            LDA   #>MOSFILE+1
            STA   ZP2+1
            LDY   #$00
:L1         LDA   (ZP1),Y
            STA   $C004                      ; Write main
            STA   (ZP2),Y
            STA   $C005                      ; Write aux
            INY
            CMP   #$0D                       ; Carriage return
            BNE   :L1
            DEY
            STA   $C004                      ; Write main
            STY   MOSFILE                    ; Length (Pascal string)
            STA   $C005                      ; Write aux

            LDA   #<OFILE
            STA   STRTL
            LDA   #>OFILE
            STA   STRTH
:S1         CLC                              ; Use main memory
            CLV                              ; Use main ZP and LC
            JMP   XFER

:CLOSE      STA   $C004                      ; Write main
            STY   MOSFILE                    ; Write file number
            STA   $C005                      ; Write aux

            LDA   #<CFILE
            STA   STRTL
            LDA   #>CFILE
            STA   STRTH
            BRA   :S1

OSFINDRET
            LDX   $0101                      ; Recover alt SP from $0101
            TXS
            PHA                              ; Return value
            LDA   TEMP1                      ; Restore STRTL/STRTH
            STA   STRTL
            LDA   TEMP2
            STA   STRTH
            PLA                              ; Return value
            PLY                              ; Value of A on entry
            CPY   #$00                       ; Was it close?
            BNE   :S1
            TYA                              ; Preserve A for close
:S1         PLY
            PLX
            RTS

* OSFSC - miscellanous file system calls
OSFSC       LDA   #<OSFSCM
            LDY   #>OSFSCM
            JSR   PRSTR
            RTS
OSFSCM      ASC   'OSFSC.'
            DB    $00

* OSGBPB - Get/Put a block of bytes to/from an open file
GBPBHND     LDA   #<OSGBPBM
            LDY   #>OSGBPBM
            JMP   PRSTR
OSGBPBM     ASC   'OSGBPB.'
            DB    $00

* OSBPUT - write one byte to an open file
BPUTHND     LDA   STRTL                      ; Backup STRTL/STRTH
            STA   TEMP1
            LDA   STRTH
            STA   TEMP2
            LDA   #<FILEPUT
            STA   STRTL
            LDA   #>FILEPUT
            STA   STRTH
            TSX                              ; Stash alt SP in $0101
            STX   $0101
            CLC                              ; Use main memory
            CLV                              ; Use main ZP and LC
            JMP   XFER

* OSBGET - read one byte from an open file
BGETHND     LDA   STRTL                      ; Backup STRTL/STRTH
            STA   TEMP1
            LDA   STRTH
            STA   TEMP2
            STA   $C004                      ; Write to main memory
            STY   MOSFILE                    ; File ref number
            STA   $C005                      ; Write to aux memory
            LDA   #<FILEGET
            STA   STRTL
            LDA   #>FILEGET
            STA   STRTH
            TSX                              ; Stash alt SP in $0101
            STX   $0101
            CLC                              ; Use main memory
            CLV                              ; Use main ZP and LC
            JMP   XFER
OSBGETRET
            LDX   $0101                      ; Recover alt SP from $0101
            TXS
            PHA                              ; Return code
            LDA   TEMP1                      ; Recover STRTL/STRTH
            STA   STRTL
            LDA   TEMP2
            STA   STRTH
            PLA                              ; Return code (ie: char read)
            RTS

* OSARGS - adjust file arguments
ARGSHND     LDA   #<OSARGSM
            LDY   #>OSARGSM
            JMP   PRSTR
OSARGSM     ASC   'OSARGS.'
            DB    $00

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
            CMP   #$21                       ; Space or Carriage return
            BCS   :L2
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

            PLA                              ; Get action back
            PHA
            BEQ   :S1                        ; A=00 -> SAVE
            CMP   #$FF
            BEQ   :S2                        ; A=FF -> LOAD

            LDA   #<OSFILEM                  ; If not implemented, print msg
            LDY   #>OSFILEM
            JSR   PRSTR
            PLA
            PHA
            JSR   OUTHEX
            LDA   #<OSFILEM2
            LDY   #>OSFILEM2
            JSR   PRSTR
            PLA                              ; Not implemented, return unchanged
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
            BNE   :S4                        ; Deal with return from SAVE

            CMP   #$01                       ; No file found
            BNE   :SL1
            BRK
            DB    $D6                        ; $D6 = Object not found
            ASC   'File not found'
            BRK

:SL1        CMP   #$02                       ; Read error
            BNE   :SL2
            BRK
            DB    $CA                        ; $CA = Premature end, 'Data lost'
            ASC   'Read error'
            BRK

:SL2        LDA   #$01                       ; Return code - file found
            BRA   :EXIT

:S4         CPY   #$00                       ; Return from SAVE
            BNE   :S6
            CMP   #$01                       ; Unable to create or open
            BNE   :SS1
            BRK
            DB    $C0                        ; $C0 = Can't create file to save
            ASC   'Can'
            DB    $27
            ASC   't save file'
            BRK

:SS1        CMP   #$02                       ; Unable to write
            BNE   :S6
            BRK
            DB    $CA                        ; $CA = Premature end, 'Data lost'
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

RDCHHND     PHX
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
            BNE   :S5
            ROR   $FF                        ; Set ESCFLG
            SEC                              ; Return CS
            RTS
:S5         CLC
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

* OSWRCH handler
* All registers preserved
WRCHHND     PHA
            PHX
            PHY
* Check any output redirections
* Check any spool output
            JSR   OUTCHAR
* Check any printer output
            PLY
            PLX
            PLA
            RTS

* Output character to VDU driver
* All registers trashable
OUTCHAR     CMP   #$00                       ; NULL
            BNE   :T1
            BRA   :IDONE
:T1         CMP   #$07                       ; BELL
            BNE   :T2
            JSR   BEEP
            BRA   :IDONE
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
:IDONE      BRA   :DONE
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
:DONE       RTS

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

* OSWORD HANDLER
* On entry, A=action
*           XY=>control block
* On exit,  All preserved (except OSWORD 0)
*           control block updated
WORDHND     STX   OSCTRL+0                   ; Point to control block
            STY   OSCTRL+1
            CMP   #$00                       ; OSWORD 0 read a line
            BNE   :S01
            JMP   OSWORD0
:S01        CMP   #$01                       ; OSWORD 1 read system clock
            BNE   :S02
            JMP   OSWORD1
:S02        CMP   #$02                       ; OSWORD 2 write system clock
            BNE   :S05
            JMP   OSWORD2
:S05        CMP   #$05                       ; OSWORD 5 read I/O memory
            BNE   :S06
            JMP   OSWORD5
:S06        CMP   #$06                       ; OSWORD 6 write I/O memory
            BNE   :UNSUPP

:UNSUPP     PHA
            LDA   #<:OSWORDM                 ; Unimplemented, print msg
            LDY   #>:OSWORDM
            JSR   PRSTR
            PLA
            PHA
            JSR   OUTHEX
            LDA   #<:OSWRDM2
            LDY   #>:OSWRDM2
            JSR   PRSTR
            PLA
            RTS
:OSWORDM    ASC   'OSWORD('
            DB    $00
:OSWRDM2    ASC   ')'
            DB    $00

* OSRDLINE - Read a line of input
* On entry, (OSCTRL)=>control block
* On exit,  Y=length of line, offset to <cr>
*           CC = Ok, CS = Escape
*
OSWORD0     LDY   #$04
:RDLNLP1    LDA   (OSCTRL),Y                 ; Copy MAXLEN, MINCH, MAXCH to workspace
            STA   :MAXLEN-2,Y
            DEY
            CPY   #$02
            BCS   :RDLNLP1
:RDLNLP2    LDA   (OSCTRL),Y                 ; (ZP2)=>line buffer
            STA   ZP2,Y
            DEY
            BPL   :RDLNLP2
            INY
            BRA   :L1

:BELL       LDA   #$07                       ; BELL
:R1         DEY
:R2         INY                              ; Step to next character
:R3         JSR   OSWRCH                     ; Output character

:L1         JSR   OSRDCH
            BCS   :EXIT
            CMP   #$08                       ; Backspace
            BEQ   :RDDEL
            CMP   #$7F                       ; Delete
            BEQ   :RDDEL
            CMP   #$15                       ; Ctrl-U
            BNE   :S2
            INY                              ; Balance first DEY
:RDCTRLU    DEY                              ; Back up one character
            BEQ   :L1                        ; Beginning of line
            LDA   #$7F                       ; Delete
            JSR   OSWRCH
            JMP   :RDCTRLU
:RDDEL      TYA
            BEQ   :L1                        ; Beginning of line
            DEY                              ; Back up one character
            LDA   #$7F                       ; Delete
            BNE   :R3                        ; Jump back to delete

:S2         STA   (ZP2),Y
            CMP   #$0D                       ; CR
            BEQ   :S3
            CPY   :MAXLEN
            BCS   :BELL                      ; Too long, beep
            CMP   :MINCH
            BCC   :R1                        ; <MINCHAR, don't step to next
            CMP   :MAXCH
            BEQ   :R2                        ; =MAXCHAR, step to next
            BCC   :R2                        ; <MAXCHAR, step to next
            BCS   :R1                        ; >MAXCHAR, don't step to next

:S3         JSR   OSNEWL
:EXIT       LDA   ESCFLAG
            ROL
            RTS
:MAXLEN     DB    $00
:MINCH      DB    $00
:MAXCH      DB    $00

OSWORD1     LDA   #$00
            LDY   #$00
:L1         STA   (OSCTRL),Y
            INY
            CPY   #$05
            BNE   :L1
            RTS

OSWORD2     RTS                              ; Nothing to do

OSWORD5     LDA   (OSCTRL)
            LDY   #$04
            STA   (OSCTRL),Y
            RTS

OSWORD6     LDA   #$04
            LDA   (OSCTRL),Y
            STA   (OSCTRL)
            RTS

* OSBYTE HANDLER
* On entry, A=action
*           X=first parameter
*           Y=second parameter if A>$7F
* On exit,  A=preserved
*           X=first returned result
*           Y=second returned result if A>$7F
*           Cy=any returned status if A>$7F
BYTEHND     PHA
            JSR   BYTECALLER
            PLA
            RTS
BYTECALLER
            CMP   #$00
            BNE   :S1
            LDX   #$0A
            RTS

:S1         CMP   #$7C                       ; $7C = clear escape condition
            BNE   :S2
            LDA   ESCFLAG
            AND   #$7F                       ; Clear MSbit
            STA   ESCFLAG
            RTS

:S2         CMP   #$7D                       ; $7D = set escape condition
            BNE   :S3
            ROR   ESCFLAG
            RTS

:S3         CMP   #$7E                       ; $7E = ack detection of ESC
            BNE   :S4
            LDA   ESCFLAG
            AND   #$7F                       ; Clear MSB
            STA   ESCFLAG
            LDX   #$FF                       ; Means ESC condition cleared
            RTS

:S4         CMP   #$81                       ; $81 = Read key with time lim
            BNE   :S5
            JSR   GETKEY
            RTS

:S5         CMP   #$82                       ; $82 = read high order address
            BNE   :S6
            LDY   #$FF                       ; $FFFF for I/O processor
            LDX   #$FF
            RTS

:S6         CMP   #$83                       ; $83 = read bottom of user mem
            BNE   :S7
            LDY   #$0E                       ; $0E00
            LDX   #$00
            RTS

:S7         CMP   #$84                       ; $84 = read top of user mem
            BNE   :S8
            LDY   #$80
            LDX   #$00
            RTS

:S8         CMP   #$85                       ; $85 = top user mem for mode
            BNE   :S9
            LDY   #$80
            LDX   #$00
            RTS

:S9         CMP   #$86                       ; $86 = read cursor pos
            BNE   :S10
            LDY   ROW
            LDX   COL
            RTS

:S10        CMP   #$DA                       ; $DA = clear VDU queue
            BNE   :S11
            RTS

:S11        PHX
            PHY
            LDA   #<OSBYTEM
            LDY   #>OSBYTEM
            JSR   PRSTR
            TSX
            LDA   $103,X
            JSR   OUTHEX
            LDA   #<OSBM2
            LDY   #>OSBM2
            JSR   PRSTR
            PLY
            PLX
            RTS

OSBYTEM     ASC   'OSBYTE($'
            DB    $00
OSBM2       ASC   ').'
            DB    $00

* OSCLI HANDLER
* On entry, XY=>command string
CLIHND      PHX
            PHY
            STX   ZP1+0                      ; Pointer to CLI
            STY   ZP1+1
; TO DO: needs to skip leading '*'s and ' 's
; TO DO: exit early with <cr>
; TO DO: exit early with | as comment
            LDA   #<:QUIT
            STA   ZP2
            LDA   #>:QUIT
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S1
            JSR   STARQUIT
            BRA   :IEXIT
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
            BRA   :EXIT
:S3         LDA   #<:DIR
            STA   ZP2
            LDA   #>:DIR
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S4
            JSR   STARDIR
:IEXIT      BRA   :EXIT
:S4         LDA   #<:HELP
            STA   ZP2
            LDA   #>:HELP
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S5
            JSR   STARHELP
            BRA   :EXIT
:S5         LDA   #<:LISP                    ; HACK TO MAKE LISP WORK??
            STA   ZP2
            LDA   #>:LISP
            STA   ZP2+1
            JSR   STRCMP
            BCS   :UNSUPP
            LDA   #$01
            JMP   $8000
:UNSUPP
            LDA   #<:OSCLIM
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
            JSR   $FFEE                      ; OSWRCH
            INY
            BRA   :PL1
:PS1        LDA   #<:OSCLIM2
            LDY   #>:OSCLIM2
            JSR   PRSTR
            RTS
:EXIT       PLY
            PLX
            RTS
:QUIT       ASC   '*QUIT'
            DB    $00
:CAT        ASC   '*CAT'
            DB    $00
:CAT2       ASC   '*.'
            DB    $00
:DIR        ASC   '*DIR'
            DB    $00
:HELP       ASC   '*HELP'
            DB    $00
:LISP       ASC   'LISP'
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
            BRA   :MISMTCH
:MATCH      CLC
            RTS
:MISMTCH    SEC
            RTS

* Print *HELP test
STARHELP    LDA   #<:MSG
            LDY   #>:MSG
            JSR   PRSTR
            LDA   #$09                       ; Language name
            LDY   #$80
            JSR   PRSTR
            LDA   #<:MSG2
            LDY   #>:MSG2
            JSR   PRSTR
            RTS
:MSG        DB    $0D
            ASC   'Applecorn MOS v0.01'
            DB    $0D,$0D,$00
:MSG2       DB    $0D,$00

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
            JSR   OSWRCH
            DEX
            INY
            BRA   :L2
:S2         JSR   OSNEWL
:EXIT       RTS

* On entry, command line is in ZP1
STARDIR     LDA   ZP1                        ; Move ZP1->ZP3 (OSWRCH uses ZP1)
            STA   ZP3
            LDA   ZP1+1
            STA   ZP3+1
            LDX   #$01
            LDY   #$00
:L1         LDA   (ZP3),Y
            CMP   #' '
            BEQ   :L2
            CMP   #$0D                       ; Carriage return
            BEQ   :S2                        ; No space in cmdline
            INY
            BRA   :L1
:S2         RTS                              ; No argument
:L2         LDA   (ZP3),Y
            CMP   #$0D
            BEQ   :S2                        ; Hit EOL before arg
            CMP   #' '
            BNE   :L3
            INY
            BRA   :L2
:L3         LDA   (ZP3),Y
            CMP   #$0D
            BEQ   :S3
            STA   $C004                      ; Write main
            STA   MOSFILE,X
            STA   $C005                      ; Write aux
            INY
            INX
            BRA   :L3
:S3         DEX
            STA   $C004                      ; Write main
            STX   MOSFILE                    ; Length byte
            STA   $C005                      ; Write aux

            LDA   STRTL
            STA   TEMP1
            LDA   STRTH
            STA   TEMP2
            TSX
            STX   $0101                      ; Stash alt SP
            LDA   #<SETPFX
            STA   STRTL
            LDA   #>SETPFX
            STA   STRTH
            CLC                              ; Main memory
            CLV                              ; Main ZP & LC
            JMP   XFER
STARDIRRET
            LDX   $0101                      ; Recover Alt SP
            TXS
            LDA   TEMP1
            STA   STRTL
            LDA   TEMP2
            STA   STRTH
            RTS

* Performs OSBYTE $80 function
* Read ADC channel or get buffer status
OSBYTE80    CPX   #$00                       ; X=0 Last ADC channel
            BNE   :S1
            LDX   #$00                       ; Fire button
            LDY   #$00                       ; ADC never converted
            RTS
:S1         BMI   :S2
            LDX   #$00                       ; X +ve, ADC value
            LDY   #$00
            RTS
:S2         CPX   #$FF                       ; X $FF = keyboard buf
            BEQ   :INPUT
            CPX   #$FE                       ; X $FE = RS423 i/p buf
            BEQ   :INPUT
            LDX   #$FF                       ; Spaced remaining in o/p
            RTS
:INPUT      LDX   #$00                       ; Nothing in input buf
            RTS

* Performs OSBYTE $81 INKEY$ function
* X,Y has time limit
* On exit, CC, Y=$00, X=key - key pressed
*          CS, Y=$FF        - timeout
*          CS, Y=$1B        - escape
GETKEY      TYA
            BMI   NEGKEY                     ; Negative INKEY
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
:ESC        ROR   ESCFLAG
            LDY   #27                        ; Escape
            SEC
            RTS
NEGKEY      LDX   #$00                       ; Unimplemented
            LDY   #$00
            RTS

* Beep
BEEP        PHA
            PHX
            LDX   #$80
:L1         LDA   $C030
            JSR   DELAY
            INX
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

* IRQ/BRK handler
IRQBRKHDLR  PHA
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
            JMP   (BRKV)                     ; Pass on to BRK handler

:S1                                          ; No Apple IRQs to handle
            PLA                              ; TO DO: pass on to IRQ1V
            TAX
            PLA
NULLRTI     RTI

PRERR       LDY   #$01
PRERRLP     LDA   (FAULT),Y
            BEQ   PRERR1
            JSR   OSWRCH
            INY
            BNE   PRERRLP
NULLRTS
PRERR1      RTS

MOSBRKHDLR  LDA   #<MSGBRK
            LDY   #>MSGBRK
            JSR   PRSTR
            JSR   PRERR
            JSR   OSNEWL
            JSR   OSNEWL
STOP        JMP   STOP                       ; Cannot return from a BRK

MSGBRK      DB    $0D
            ASC   "ERROR: "
            DB    $00

;DEFBRKHDLR
;            LDA   #<BRKM
;            LDY   #>BRKM
;            JSR   PRSTR
;            PLA
;            PLX
;            PLY
;            PHY
;            PHX
;            PHA
;            JSR   OUT2HEX
;            LDA   #<BRKM2
;            LDY   #>BRKM2
;            JSR   PRSTR
;            RTI
;BRKM        ASC   "BRK($"
;            DB    $00
;BRKM2       ASC   ")."
;            DB    $00

* Default page 2 contents
DEFVEC      DW    NULLRTS                    ; $200 USERV
            DW    MOSBRKHDLR                 ; $202 BRKV
            DW    NULLRTI                    ; $204 IRQ1V
            DW    NULLRTI                    ; $206 IRQ2V
            DW    CLIHND                     ; $208 CLIV
            DW    BYTEHND                    ; $20A BYTEV
            DW    WORDHND                    ; $20C WORDV
            DW    WRCHHND                    ; $20E WRCHV
            DW    RDCHHND                    ; $210 RDCHV
            DW    FILEHND                    ; $212 FILEV
            DW    ARGSHND                    ; $214 ARGSV
            DW    BGETHND                    ; $216 BGETV
            DW    BPUTHND                    ; $218 BPUTV
            DW    GBPBHND                    ; $21A GBPBV
            DW    FINDHND                    ; $21C FINDV
            DW    NULLRTS                    ; $21E FSCV
ENDVEC

*
* Acorn MOS entry points at the top of RAM
* Copied from loaded code to high memory
*

MOSVEC                                       ; Base of API entries here in loaded code
MOSAPI      EQU   $FFB6                      ; Real base of API entries in real memory
            ORG   MOSAPI

* OPTIONAL ENTRIES
* ----------------
*OSSERV      JMP   NULLRTS          ; FF95 OSSERV
*OSCOLD      JMP   NULLRTS          ; FF98 OSCOLD
*OSPRSTR     JMP   OUTSTR           ; FF9B PRSTRG
*OSFF9E      JMP   NULLRTS          ; FF9E
*OSSCANHEX   JMP   RDHEX            ; FFA1 SCANHX
*OSFFA4      JMP   NULLRTS          ; FFA4
*OSFFA7      JMP   NULLRTS          ; FFA7
*PRHEX       JMP   OUTHEX           ; FFAA PRHEX
*PR2HEX      JMP   OUT2HEX          ; FFAD PR2HEX
*OSFFB0      JMP   NULLRTS          ; FFB0
*OSWRRM      JMP   NULLRTS          ; FFB3 OSWRRM

* COMPULSARY ENTRIES
* ------------------
VECSIZE     DB    ENDVEC-DEFVEC              ; FFB6 VECSIZE Size of vectors
VECBASE     DW    DEFVEC                     ; FFB7 VECBASE Base of default vectors
OSRDRM      JMP   RDROM                      ; FFB9 OSRDRM  Read byte from paged ROM
OSCHROUT    JMP   OUTCHAR                    ; FFBC CHROUT  Send char to VDU driver
OSEVEN      JMP   EVENT                      ; FFBF OSEVEN  Signal an event
GSINIT      JMP   GSINTGO                    ; FFC2 GSINIT  Init string reading
GSREAD      JMP   GSRDGO                     ; FFC5 GSREAD  Parse general string
NVWRCH      JMP   WRCHHND                    ; FFC8 NVWRCH  Nonvectored WRCH
NVRDCH      JMP   RDCHHND                    ; FFCB NVRDCH  Nonvectored RDCH
OSFIND      JMP   (FINDV)                    ; FFCE OSFIND
OSGBPB      JMP   (GBPBV)                    ; FFD1 OSGBPB
OSBPUT      JMP   (BPUTV)                    ; FFD4 OSBPUT
OSBGET      JMP   (BGETV)                    ; FFD7 OSBGET
OSARGS      JMP   (ARGSV)                    ; FFDA OSARGS
OSFILE      JMP   (FILEV)                    ; FFDD OSFILE
OSRDCH      JMP   (RDCHV)                    ; FFE0 OSRDCH
OSASCI      CMP   #$0D                       ; FFE3 OSASCI
            BNE   OSWRCH
OSNEWL      LDA   #$0A                       ; FFE7 OSNEWL
            JSR   OSWRCH
OSWRCR      LDA   #$0D                       ; FFEC OSWRCR
OSWRCH      JMP   (WRCHV)                    ; FFEE OSWRCH
OSWORD      JMP   (WORDV)                    ; FFF1 OSWORD
OSBYTE      JMP   (BYTEV)                    ; FFF4 OSBYTE
OSCLI       JMP   (CLIV)                     ; FFF7 OSCLI
NMIVEC      DW    NULLRTI                    ; FFFA NMIVEC
RSTVEC      DW    STOP                       ; FFFC RSTVEC
IRQVEC

* Assembler doesn't like running up to $FFFF, so we bodge a bit
MOSEND
            ORG   MOSEND-MOSAPI+MOSVEC
            DW    IRQBRKHDLR                 ; FFFE IRQVEC
MOSVEND


* Buffer for one 512 byte disk block in aux mem
AUXBLK      DS    $200

