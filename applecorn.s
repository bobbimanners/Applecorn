* Load an Acorn BBC Micro ROM in aux memory and
* Provide an environment where it can run
* (c) Bobbi 2021 GPLv3
*
* Assembled with the Merlin 8 assembler.

            XC                ; 65c02
            ORG   $2000       ; Load addr of loader in main memory

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

* IRQ vector
A2IRQV      EQU   $3FE

* MLI entry point
MLI         EQU   $BF00

* ProDOS MLI command numbers
QUITCMD     EQU   $65
GTIMECMD    EQU   $82
CREATCMD    EQU   $C0
DESTCMD     EQU   $C1
ONLNCMD     EQU   $C5
SPFXCMD     EQU   $C6
GPFXCMD     EQU   $C7
OPENCMD     EQU   $C8
READCMD     EQU   $CA
WRITECMD    EQU   $CB
CLSCMD      EQU   $CC
FLSHCMD     EQU   $CD
SMARKCMD    EQU   $CE
GMARKCMD    EQU   $CF
GEOFCMD     EQU   $D1

* IO Buffer for reading file (1024 bytes)
IOBUF0      EQU   $4000       ; For loading ROM, OSFILE, *.
IOBUF1      EQU   $4400       ; Four open files for langs
IOBUF2      EQU   $4800
IOBUF3      EQU   $4C00
IOBUF4      EQU   $5000

* 512 byte buffer sufficient for one disk block
BLKBUF      EQU   $5200
BLKBUFEND   EQU   $5400

* Address in aux memory where ROM will be loaded
AUXADDR     EQU   $8000

* Address in aux memory where the MOS shim is located
AUXMOS1     EQU   $2000       ; Temp staging area in Aux
EAUXMOS1    EQU   $3000       ; End of staging area
AUXMOS      EQU   $D000       ; Final location in aux LC

* Called by code running in main mem to invoke a
* routine in aux memory
XF2AUX      MAC
            LDX   $C08B       ; R/W LC RAM, bank 1
            LDX   $C08B
            LDX   #<]1
            STX   STRTL
            LDX   #>]1
            STX   STRTH
            SEC               ; Use aux memory
            BIT   $FF58       ; Set V: use alt ZP and LC
            JMP   XFER
            EOM

* Called by code running in aux mem to invoke a
* routine in main memory
XF2MAIN     MAC
            LDX   STRTL
            STX   STRTBCKL
            LDX   STRTH
            STX   STRTBCKH
            LDX   #<]1
            STX   STRTL
            LDX   #>]1
            STX   STRTH
            TSX
            STX   $0101       ; Save alt SP
            LDX   $0100       ; Load main SP
            TXS
            CLC               ; Use main mem
            CLV               ; Use main ZP and LC
            JMP   XFER
            EOM

* Macro called on re-entry to aux memory
ENTAUX      MAC
            LDX   STRTBCKL
            STX   STRTL
            LDX   STRTBCKH
            STX   STRTH
            LDX   $0101       ; Recover alt SP
            TXS
            EOM

* Macro called on re-entry to main memory
ENTMAIN     MAC
            LDX   $C081       ; Bank in ROM
            LDX   $C081
            EOM

* Enable writing to main memory (for code running in aux)
WRTMAIN     MAC
            SEI               ; Keeps IRQ handler easy
            STA   $C004       ; Write to main memory
            EOM

* Go back to writing to aux (for code runnign in aux)
WRTAUX      MAC
            STA   $C005       ; Write to aux memory
            CLI               ; Normal service resumed
            EOM

* Code is all included from PUT files below ...
* ... order matters!
            PUT   LOADER
            PUT   MAIN.ROMMENU
            PUT   MAINMEM
            PUT   AUXMEM.MOSEQU
            PUT   AUXMEM.INIT
            PUT   AUXMEM.VDU
            PUT   AUXMEM.HOSTFS
            PUT   AUXMEM.OSCLI
            PUT   AUXMEM.BYTWRD
            PUT   AUXMEM.CHARIO
            PUT   AUXMEM.MISC

