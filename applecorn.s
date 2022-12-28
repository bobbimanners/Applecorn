* APPLECORN.S
* (c) Bobbi 2021 GPLv3
*
* Load an Acorn BBC Micro ROM in aux memory and
* Provide an environment where it can run
*
* Assembled with the Merlin 8 v2.58 assembler on Apple II.

* 14-Oct-2021 XF2MAIN, ENTAUX no longer save/restore STRTL/STRTH.


            XC                ; 65c02
            ORG   $2000       ; Load addr of loader in main memory
                              ; Clear of first HGR frame buffer

* Monitor routines
BELL        EQU   $FBDD
PRBYTE      EQU   $FDDA
COUT1       EQU   $FDED
CROUT       EQU   $FD8E
IDROUTINE   EQU   $FE1F
HOME        EQU   $FC58
AUXMOVE     EQU   $C311
XFER        EQU   $C314

* Monitor ZP locations
A1L         EQU   $3C
A1H         EQU   $3D
A2L         EQU   $3E
A2H         EQU   $3F
A3L         EQU   $40         ; Used for ISR only
A3H         EQU   $41         ; Used for ISR only
A4L         EQU   $42
A4H         EQU   $43

* Used by XFER
STRTL       EQU   $3ED
STRTH       EQU   $3EE

* Apple II BREAK vector
BREAKV      EQU   $3F0

* Reset vector (2 bytes + 1 byte checksum)
RSTV        EQU   $3F2
PWRDUP      EQU   $3F4

* IRQ vector
A2IRQV      EQU   $3FE

* ProDOS Global Page equates
* MLI entry point
MLI         EQU   $BF00
* Device Addresses
DEVADR01    EQU   $BF10
DEVADR32    EQU   $BF26
* Device List
DEVNUM      EQU   $BF30
DEVCNT      EQU   $BF31
DEVLST      EQU   $BF32
* Date & time
PRODOSDATE  EQU   $BF90
PRODOSTIME  EQU   $BF92
* Machine ID byte
MACHID      EQU   $BF98
* Versioning bytes
IBAKVER     EQU   $BFFC
IVERSION    EQU   $BFFD
* System BitMap locations
P8BMAP0007  EQU   $BF58
P8BMAP080F  EQU   $BF59
P8BMAP2027  EQU   $BF5C
P8BMAP282F  EQU   $BF5D
P8BMAP3037  EQU   $BF5E
P8BMAP383F  EQU   $BF5F

*Hardware I/O locations
KEYBOARD    EQU   $C000
80STOREOFF  EQU   $C000
80STOREON   EQU   $C001	      ; Currently not used
RDMAINRAM   EQU   $C002
RDCARDRAM   EQU   $C003
WRMAINRAM   EQU   $C004
WRCARDRAM   EQU   $C005
SETSTDZP    EQU   $C008
SETALTZP    EQU   $C009
CLR80VID    EQU   $C00C
SET80VID    EQU   $C00D
CLRALTCHAR  EQU   $C00E
SETALTCHAR  EQU   $C00F
RDRAMRD     EQU   $C013
RDRAMWR     EQU   $C014
KBDSTRB     EQU   $C010
RDVBL       EQU   $C019
RD80VID     EQU   $C01F

TBCOLOR     EQU   $C022       ; GS-specific, text colour reg
NEWVIDEO    EQU   $C029       ; GS-specific, new video register

SPKR        EQU   $C030
CLOCKCTL    EQU   $C034       ; GS-specific, Clock control register
SHADOW      EQU   $C035       ; GS-specific, Shadow Register
CYAREG      EQU   $C036       ; GS-specific, CYA Register

GRON        EQU   $C050
TEXTON      EQU   $C051
FULLGR      EQU   $C052
MIXGRTXT    EQU   $C053       ; Currently not used
PAGE1       EQU   $C054
PAGE2       EQU   $C055
LORES       EQU   $C056       ; Currently not used
HIRES       EQU   $C057
AN0OFF      EQU   $C058
AN0ON       EQU   $C059
AN1OFF      EQU   $C05A
AN1ON       EQU   $C05B
AN2OFF      EQU   $C05C
AN2ON       EQU   $C05D
AN3OFF      EQU   $C05E
AN3ON       EQU   $C05F

BUTTON0     EQU   $C061
BUTTON1     EQU   $C062

ROMIN       EQU   $C081
LCBANK1     EQU   $C08B


* IO Buffer for reading file (1024 bytes)
IOBUF0      EQU   $0C00       ; For loading/saving, OSFILE, *.
IOBUF1      EQU   $1000       ; Four open files for langs
IOBUF2      EQU   $1400
IOBUF3      EQU   $1800
IOBUF4      EQU   $1C00

* 512 byte buffer sufficient for one disk block
BLKBUF      EQU   $9000       ; Can't use $400 as ProDOS uses
BLKBUFEND   EQU   $9200       ;  'hidden' bytes within screen

* 512 byte buffer for file copy (*COPY)
COPYBUF     EQU   $9200       ; File copy needs separate buffer
*COPYBUFEND  EQU   $9400

* Location of FDraw library in main memory
FDRAWADDR   EQU   $9400

* Location of FDraw library in main memory
FONTADDR    EQU   $A900

* Address in aux memory where ROM will be loaded
ROMAUXADDR  EQU   $8000

* Address in aux memory where the MOS shim is located
AUXMOS1     EQU   $2000       ; Temp staging area in Aux
EAUXMOS1    EQU   $5000       ; End of staging area
AUXMOS      EQU   $D000       ; Final location in aux LC

* Called by code running in main mem to invoke a
* routine in aux memory
XF2AUX      MAC
            SEI               ; Disable IRQ before XFER
            LDX   LCBANK1     ; R/W LC RAM, bank 1
            LDX   LCBANK1
            LDX   #<]1
            STX   STRTL
            LDX   #>]1
            STX   STRTH
            SEC               ; Use aux memory
            BIT   RTSINSTR    ; Set V: use alt ZP and LC
            JMP   XFER
            EOM

* Called by code running in aux mem to invoke a
* routine in main memory
XF2MAIN     MAC
            SEI               ; Disable IRQ before XFER
            LDX   #<]1
            STX   STRTL
            LDX   #>]1
            STX   STRTH
            TSX
            STX   $0101       ; Save alt SP
            LDX   $0100       ; Load main SP into X
            CLC               ; Use main mem
            CLV               ; Use main ZP and LC
            JMP   XFER
            EOM

* Macro called on re-entry to aux memory
* Careful: This enables IRQ - not for use in ISR
ENTAUX      MAC
            LDX   $0101       ; Recover alt SP
            TXS
            CLI               ; Re-enable IRQ after XFER
            EOM

* Macro called on re-entry to main memory
* Careful: This enables IRQ - not for use in ISR
ENTMAIN     MAC
            TXS               ; Main SP already in X
            LDX   ROMIN       ; Bank in ROM
            LDX   ROMIN
            CLI               ; Re-enable IRQ after XFER
            EOM

* Macro called on re-entry to aux memory
* For use in interrupt handlers (no CLI!)
IENTAUX     MAC
            LDX   $0101       ; Recover alt SP
            TXS
            EOM

* Macro called on re-entry to main memory
* For use in interrupt handlers (no CLI!)
IENTMAIN    MAC
            TXS               ; Main SP already in X
            LDX   ROMIN       ; Bank in ROM
            LDX   ROMIN
            EOM

* Enable writing to main memory (for code running in aux)
WRTMAIN     MAC
            PHP
            SEI               ; Keeps IRQ handler easy
            STZ   WRMAINRAM   ; Write to main memory
            EOM

* Go back to writing to aux (for code running in aux)
WRTAUX      MAC
            STZ   WRCARDRAM   ; Write to aux memory
            PLP               ; Normal service resumed
            EOM

* Enable reading from main memory (for code running in aux LC)
RDMAIN      MAC
            PHP
            SEI               ; Keeps IRQ handler easy
            STZ   RDMAINRAM   ; Read from main memory
            EOM

* Go back to reading from aux (for code running in aux LC)
RDAUX       MAC
            STZ   RDCARDRAM   ; Read from aux memory
            PLP               ; Normal service resumed
            EOM

* Manually enable AltZP + Aux LC (for code running in main)
* Banks ROM out
ALTZP       MAC
            PHP
            SEI               ; Disable IRQ when AltZP on
            LDA   LCBANK1     ; R/W LC bank 1
            LDA   LCBANK1
            STZ   SETALTZP    ; Alt ZP and LC
            EOM

* Manually disable AltZP + Aux LC (for code running in main)
* Banks ROM in
MAINZP      MAC
            STZ   SETSTDZP    ; Main ZP and LC
            LDA   ROMIN       ; Bank ROM back in
            LDA   ROMIN
            PLP               ; Turn IRQ back on
            EOM

* Code is all included from PUT files below ...
* ... order matters!
            PUT   MAINMEM.LDR
            PUT   AUXMEM.MOSEQU
            PUT   AUXMEM.INIT
            PUT   AUXMEM.VDU
            PUT   AUXMEM.HGR
            PUT   AUXMEM.SHR
            PUT   AUXMEM.HOSTFS
            PUT   AUXMEM.OSCLI
            PUT   AUXMEM.BYTWRD
            PUT   AUXMEM.CHARIO
            PUT   AUXMEM.AUDIO
            PUT   AUXMEM.MISC
            PUT   MAINMEM.MENU
            PUT   MAINMEM.FSEQU
            PUT   MAINMEM.INIT
            PUT   MAINMEM.SVC
            PUT   MAINMEM.HGR
            PUT   MAINMEM.PATH
            PUT   MAINMEM.WILD
            PUT   MAINMEM.LISTS
            PUT   MAINMEM.MISC
            PUT   MAINMEM.AUDIO
            PUT   MAINMEM.ENSQ
            PUT   MAINMEM.ENSQFREQ
            PUT   MAINMEM.MOCK
            PUT   MAINMEM.MOCKFREQ
            PUT   MAINMEM.FONT8

* Automatically save the object file:
            SAV   APLCORN.SYSTEM


