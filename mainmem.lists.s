* MAINMEM.LISTS.S
* (c) Bobbi 2021 GPLv3
*
* ProDOS parameter list for MLI calls.

OPENPL      HEX   03          ; Number of parameters
            DW    $0000       ; Pointer to filename
            DW    IOBUF0      ; Pointer to IO buffer
            DB    $00         ; Reference number returned

OPENPL2     HEX   03          ; Number of parameters
            DW    $0000       ; Pointer to filename
            DW    $0000       ; Pointer to IO buffer
            DB    $00         ; Reference number returned

CREATEPL    HEX   07          ; Number of parameters
            DW    $0000       ; Pointer to filename
            DB    $00         ; Access
            DB    $00         ; File type
            DW    $0000       ; Aux type
            DB    $00         ; Storage type
            DW    $0000       ; Create date
            DW    $0000       ; Create time

DESTPL      HEX   01          ; Number of parameters
            DW    $0000       ; Pointer to filename

RENPL       HEX   02          ; Number of parameters
            DW    $0000       ; Pointer to existing name
            DW    $0000       ; Pointer to new filename

READPL      HEX   04          ; Number of parameters
            DB    $00         ; Reference number
            DW    BLKBUF      ; Pointer to data buffer
            DW    512         ; Request count
            DW    $0000       ; Trans count

READPL2     HEX   04          ; Number of parameters
            DB    #00         ; Reference number
            DW    BLKBUF      ; Pointer to data buffer
            DW    1           ; Request count
            DW    $0000       ; Trans count

WRITEPL     HEX   04          ; Number of parameters
            DB    $01         ; Reference number
            DW    BLKBUF      ; Pointer to data buffer
            DW    $00         ; Request count
            DW    $0000       ; Trans count

CLSPL       HEX   01          ; Number of parameters
            DB    $00         ; Reference number

FLSHPL      HEX   01          ; Number of parameters
            DB    $00         ; Reference number

ONLNPL      HEX   02          ; Number of parameters
            DB    $00         ; Unit num
            DW    DRVBUF2     ; Buffer

GSPFXPL     HEX   01          ; Number of parameters
            DW    DRVBUF1     ; Buffer

GPFXPL      HEX   01          ; Number of parameters
            DW    PREFIX      ; Buffer

SPFXPL      HEX   01          ; Number of parameters
            DW    MOSFILE     ; Buffer

GMARKPL     HEX   02          ; Number of parameters
            DB    $00         ; File reference number
            DB    $00         ; Mark (24 bit)
            DB    $00
            DB    $00

GEOFPL      HEX   02          ; Number of parameters
            DB    $00         ; File reference number
            DB    $00         ; EOF (24 bit)
            DB    $00
            DB    $00

GINFOPL     HEX   0A          ; Number of parameters
            DW    $0000       ; Pointer to filename
            DB    $00         ; Access
            DB    $00         ; File type
            DW    $0000       ; Aux type
            DB    $00         ; Storage type
            DW    $0000       ; Blocks used
            DW    $0000       ; Mod date
            DW    $0000       ; Mod time
            DW    $0000       ; Create date
            DW    $0000       ; Create time

QUITPL      HEX   04          ; Number of parameters
            DB    $00
            DW    $0000
            DB    $00
            DW    $0000







