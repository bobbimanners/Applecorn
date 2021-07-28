* MAINMEM.S
* Code that runs on the Apple //e in main memory
* This code is mostly glue between the BBC Micro code
* running in aux mem and ProDOS

* Set prefix if not already set
SETPRFX     LDA   #GPFXCMD
            STA   :OPC7          ; Initialize cmd byte to $C7
:L1         JSR   MLI
:OPC7       DB    $00
            DW    GSPFXPL
            LDX   $0300
            BNE   :S1
            LDA   $BF30
            STA   ONLPL+1        ; Device number
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
            LDA   $C08B          ; Rd/Wt LC, bank one
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
            LDA   $C08B          ; R/W LC RAM, bank 1
            LDA   $C08B
            STA   $C009          ; Alt ZP (and Alt LC) on

            LDY   #$00
:L1         LDA   RDBUF,Y
            STA   $C005          ; Write aux mem
            STA   AUXBLK,Y
            STA   $C004          ; Write main mem
            CPY   #$FF
            BEQ   :S1
            INY
            BRA   :L1

:S1         LDY   #$00
:L2         LDA   RDBUF+$100,Y
            STA   $C005          ; Write aux mem
            STA   AUXBLK+$100,Y
            STA   $C004          ; Write main mem
            CPY   #$FF
            BEQ   :S2
            INY
            BRA   :L2

:S2         STA   $C008          ; Alt ZP off
            LDA   $C081          ; Bank the ROM back in
            LDA   $C081
            RTS

* ProDOS file handling for MOS OSFIND OPEN call
* Options in A: $40 'r', $80 'w', $C0 'rw'
OFILE       LDX   $0100          ; Recover SP
            TXS
            PHA                  ; Option
            LDA   $C081          ; ROM, please
            LDA   $C081

* TODO if A=$80 then attempt to delete before open
* TODO if A=$80 or $c0 then attempt to create before open

            LDA   #$00           ; Look for empty slot
            JSR   FINDBUF
            STX   BUFIDX
            CPX   #$00
            BNE   :S1
            LDA   #<IOBUF1
            LDY   #>IOBUF1
            BRA   :S4
:S1         CPX   #$01
            BNE   :S2
            LDA   #<IOBUF2
            LDY   #>IOBUF2
            BRA   :S4
:S2         CPX   #$02
            BNE   :S3
            LDA   #<IOBUF3
            LDY   #>IOBUF3
            BRA   :S4
:S3         CPX   #$03
            BNE   :NOTFND        ; Out of buffers really
            LDA   #<IOBUF4
            LDY   #>IOBUF4

:S4         STA   OPENPL2+3
            STY   OPENPL2+4

            LDA   #<MOSFILE
            STA   OPENPL2+1
            LDA   #>MOSFILE
            STA   OPENPL2+2
            JSR   MLI
            DB    OPENCMD
            DW    OPENPL2
            BCS   :NOTFND
            LDA   OPENPL2+5      ; File ref number
            PHA
            LDX   BUFIDX
            CPX   #$FF
            BEQ   FINDEXIT
            STA   FILEREFS,X     ; Record ref number
            BRA   FINDEXIT
:NOTFND     LDA   #$00
            PHA
FINDEXIT    LDA   $C08B          ; R/W RAM, LC bank 1
            LDA   $C08B
            LDA   #<OSFINDRET
            STA   STRTL
            LDA   #>OSFINDRET
            STA   STRTH
            PLA
            SEC
            BIT   $FF58
            JMP   XFER
BUFIDX      DB    $00

* ProDOS file handling for MOS OSFIND CLOSE call
CFILE       LDX   $0100          ; Recover SP
            TXS
            LDA   $C081          ; ROM, please
            LDA   $C081

            LDA   MOSFILE        ; File ref number
            STA   CLSPL+1
            JSR   CLSFILE

            LDA   MOSFILE
            JSR   FINDBUF
            CPX   #$FF
            BEQ   :S1

            LDA   #$00
            STA   FILEREFS,X

:S1         JMP   FINDEXIT

* Map of file reference numbers to IOBUF1..4
FILEREFS    DB    $00,$00,$00,$00

* Search FILEREFS for value in A
FINDBUF     LDX   #$00
:L1         CMP   FILEREFS,X
            BEQ   :END
            INX
            CPX   #$04
            BNE   :L1
            LDX   #$FF           ; $FF for not found
:END        RTS


* ProDOS file handling for MOS OSBGET call
* Returns with char read in A and error num in X (or 0)
FILEGET     LDX   $0100          ; Recover SP
            TXS
            LDA   $C081          ; ROM, please
            LDA   $C081

            LDA   MOSFILE        ; File ref number
            STA   READPL2+1
            JSR   MLI
            DB    READCMD
            DW    READPL2
            BCC   :NOERR
            TAY                  ; Error number in Y
            BRA   GETEXIT
:NOERR      LDX   #$00
            LDA   RDBUF
            PHA
GETEXIT     LDA   $C08B          ; R/W RAM, LC bank 1
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
FILEPUT     LDX   $0100          ; Recover SP
            TXS
            LDA   $C081          ; ROM, please
            LDA   $C081

            JMP   GETEXIT

* ProDOS file handling for MOS OSFILE LOAD call
* Return A=0 if successful
*        A=1 if file not found
*        A=2 if read error
LOADFILE    LDX   $0100          ; Recover SP
            TXS
            LDA   $C081          ; Gimme the ROM!
            LDA   $C081

            STZ   :BLOCKS
            LDA   #<MOSFILE
            STA   OPENPL+1
            LDA   #>MOSFILE
            STA   OPENPL+2
            JSR   OPENFILE
            BCS   :NOTFND        ; File not found
:L1         LDA   OPENPL+5       ; File ref number
            STA   READPL+1
            JSR   RDBLK
            BCC   :S1
            CMP   #$4C           ; EOF
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
            LDX   :BLOCKS
:L2         CPX   #$00
            BEQ   :S2
            INC
            INC
            DEX
            BRA   :L2
:S2         STA   A4H

            SEC                  ; Main -> AUX
            JSR   AUXMOVE

            INC   :BLOCKS
            BRA   :L1

:NOTFND     LDA   #$01           ; Nothing found
            PHA
            BRA   :EXIT
:READERR    LDA   #$02           ; Read error
            PHA
            BRA   :EOF2
:EOF        LDA   #$00           ; Success
            PHA
:EOF2       LDA   OPENPL+5       ; File ref num
            STA   CLSPL+1
            JSR   CLSFILE
:EXIT       LDA   $C08B          ; R/W RAM, bank 1
            LDA   $C08B
            LDA   #<OSFILERET    ; Return to caller in aux
            STA   STRTL
            LDA   #>OSFILERET
            STA   STRTH
            PLA
            SEC
            BIT   $FF58
            JMP   XFER
:BLOCKS     DB    $00

* ProDOS file handling for MOS OSFILE SAVE call
* Return A=0 if successful
*        A=1 if unable to create/open
*        A=2 if error during save
SAVEFILE    LDX   $0100          ; Recover SP
            TXS
            LDA   $C081          ; Gimme the ROM!
            LDA   $C081

            STZ   :BLOCKS
            LDA   #<MOSFILE
            STA   CREATEPL+1
            STA   OPENPL+1
            LDA   #>MOSFILE
            STA   CREATEPL+2
            STA   OPENPL+2
            LDA   #$C3           ; Access unlocked
            STA   CREATEPL+3
            LDA   #$06           ; Filetype BIN
            STA   CREATEPL+4
            LDA   FBSTRT         ; Auxtype = save address
            STA   CREATEPL+5
            LDA   FBSTRT+1
            STA   CREATEPL+6
            LDA   #$01           ; Storage type - file
            STA   CREATEPL+7
            LDA   $BF90          ; Current date
            STA   CREATEPL+8
            LDA   $BF91
            STA   CREATEPL+9
            LDA   $BF92          ; Current time
            STA   CREATEPL+10
            LDA   $BF93
            STA   CREATEPL+11
            JSR   CRTFILE
            JSR   OPENFILE
            BCS   :FWD1          ; :CANTOPEN error

            SEC                  ; Compute file length
            LDA   FBEND
            SBC   FBSTRT
            STA   :LEN
            LDA   FBEND+1
            SBC   FBSTRT+1
            STA   :LEN+1

:L1         LDA   FBSTRT         ; Setup for first block
            STA   A1L
            STA   A2L
            LDA   FBSTRT+1
            STA   A1H
            STA   A2H
            INC   A2H            ; $200 = 512 bytes
            INC   A2H
            LDA   #$00           ; 512 byte request count
            STA   WRITEPL+4
            LDA   #$02
            STA   WRITEPL+5
            LDX   :BLOCKS
:L2         CPX   #$00           ; Adjust for subsequent blks
            BEQ   :S1
            INC   A1H
            INC   A1H
            INC   A2H
            INC   A2H
            DEX
            BRA   :L2

:FWD1       BRA   :CANTOPEN      ; Forwarding call from above

:S1         LDA   :LEN+1         ; MSB of length remaining
            CMP   #$02
            BCS   :S2            ; MSB of len >= 2 (not last)

            CMP   #$00           ; If no bytes left ...
            BNE   :S3
            LDA   :LEN
            BNE   :S3
            BRA   :NORMALEND

:S3         LDA   FBEND          ; Adjust for last block
            STA   A2L
            LDA   FBEND+1
            STA   A2H
            LDA   :LEN
            STA   WRITEPL+4      ; Remaining bytes to write
            LDA   :LEN+1
            STA   WRITEPL+5

:S2         LDA   #<RDBUF
            STA   A4L
            LDA   #>RDBUF
            STA   A4H

            CLC                  ; Aux -> Main
            JSR   AUXMOVE

            LDA   OPENPL+5       ; File ref number
            STA   WRITEPL+1
            JSR   WRTBLK
            BCS   :WRITEERR

            BRA   :UPDLEN

:ENDLOOP    INC   :BLOCKS
            BRA   :L1

:UPDLEN
            SEC                  ; Update length remaining
            LDA   :LEN
            SBC   WRITEPL+4
            STA   :LEN
            LDA   :LEN+1
            SBC   WRITEPL+5
            STA   :LEN+1
            BRA   :ENDLOOP

:CANTOPEN
            LDA   #$01           ; Can't open/create
            BRA   :EXIT
:WRITEERR
            LDA   OPENPL+5       ; File ref num
            STA   CLSPL+1
            JSR   CLSFILE
            LDA   #$02           ; Write error
            BRA   :EXIT
:NORMALEND
            LDA   OPENPL+5       ; File ref num
            STA   CLSPL+1
            JSR   CLSFILE
            LDA   #$00           ; Success!
            BCC   :EXIT          ; If close OK
            LDA   #$02           ; Write error
:EXIT       PHA
            LDA   $C08B          ; R/W RAM, bank 1
            LDA   $C08B
            LDA   #<OSFILERET    ; Return to caller in aux
            STA   STRTL
            LDA   #>OSFILERET
            STA   STRTH
            PLA
            SEC
            BIT   $FF58
            JMP   XFER
:LEN        DW    $0000
:BLOCKS     DB    $00

* Quit to ProDOS
QUIT        INC   $3F4           ; Invalidate powerup byte
            STA   $C054          ; PAGE2 off
            JSR   MLI
            DB    QUITCMD
            DW    QUITPL
            RTS

* Obtain catalog of current PREFIX dir
CATALOG     LDX   $0100          ; Recover SP
            TXS
            LDA   $C081          ; Select ROM
            LDA   $C081

            JSR   MLI            ; Fetch prefix into RDBUF
            DB    GPFXCMD
            DW    GPFXPL
            BNE   CATEXIT        ; If prefix not set

            LDA   #<RDBUF
            STA   OPENPL+1
            LDA   #>RDBUF
            STA   OPENPL+2
            JSR   OPENFILE
            BCS   CATEXIT        ; Can't open dir

CATREENTRY
            LDA   OPENPL+5       ; File ref num
            STA   READPL+1
            JSR   RDBLK
            BCC   :S1
            CMP   #$4C           ; EOF
            BEQ   :EOF
            BRA   :READERR

:S1         JSR   COPYAUXBLK

            LDA   $C08B          ; R/W RAM, bank 1
            LDA   $C08B
            LDA   #<PRONEBLK
            STA   STRTL
            LDA   #>PRONEBLK
            STA   STRTH
            SEC
            BIT   $FF58
            JMP   XFER

:READERR
:EOF        LDA   OPENPL+5       ; File ref num
            STA   CLSPL+1
            JSR   CLSFILE

CATEXIT     LDA   $C08B          ; R/W LC RAM, bank 1
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
            LDX   #0100          ; Recover SP
            TXS
            LDA   $C081          ; ROM please
            LDA   $C081
            BRA   CATREENTRY

* Set the prefix
SETPFX      LDX   $0100          ; Recover SP
            TXS
            LDA   $C081          ; ROM, ta!
            LDA   $C081
            JSR   MLI
            DB    SPFXCMD
            DW    SPFXPL
            BCC   :S1
            JSR   BELL           ; Beep on error

:S1         LDA   $C08B          ; R/W LC RAM, bank 1
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
OPENPL      HEX   03             ; Number of parameters
            DW    $0000          ; Pointer to filename
            DW    IOBUF0         ; Pointer to IO buffer
            DB    $00            ; Reference number returned

OPENPL2     HEX   03             ; Number of parameters
            DW    $0000          ; Pointer to filename
            DW    $0000          ; Pointer to IO buffer
            DB    $00            ; Reference number returned

CREATEPL    HEX   07             ; Number of parameters
            DW    $0000          ; Pointer to filename
            DB    $00            ; Access
            DB    $00            ; File type
            DW    $0000          ; Aux type
            DB    $00            ; Storage type
            DW    $0000          ; Create date
            DW    $0000          ; Create time

READPL      HEX   04             ; Number of parameters
            DB    $00            ; Reference number
            DW    RDBUF          ; Pointer to data buffer
            DW    512            ; Request count
            DW    $0000          ; Trans count

READPL2     HEX   04             ; Number of parameters
            DB    #00            ; Reference number
            DW    RDBUF          ; Pointer to data buffer
            DW    1              ; Request count
            DW    $0000          ; Trans count

WRITEPL     HEX   04             ; Number of parameters
            DB    $01            ; Reference number
            DW    RDBUF          ; Pointer to data buffer
            DW    $00            ; Request count
            DW    $0000          ; Trans count

CLSPL       HEX   01             ; Number of parameters
            DB    $00            ; Reference number

ONLPL       HEX   02             ; Number of parameters
            DB    $00            ; Unit num
            DW    $301           ; Buffer

GSPFXPL     HEX   01             ; Number of parameters
            DW    $300           ; Buffer

GPFXPL      HEX   01             ; Number of parameters
            DW    RDBUF          ; Buffer

SPFXPL      HEX   01             ; Number of parameters
            DW    MOSFILE        ; Buffer

QUITPL      HEX   04             ; Number of parameters
            DB    $00
            DW    $0000
            DB    $00
            DW    $0000

* Buffer for Acorn MOS filename
MOSFILE     DS    64             ; 64 bytes max prefix/file len

* Acorn MOS format OSFILE param list
FILEBLK
FBPTR       DW    $0000          ; Pointer to name (in aux)
FBLOAD      DW    $0000          ; Load address
            DW    $0000
FBEXEC      DW    $0000          ; Exec address
            DW    $0000
FBSTRT      DW    $0000          ; Start address for SAVE
            DW    $0000
FBEND       DW    $0000          ; End address for SAVE
            DW    $0000

