* Load an Acorn BBC Micro ROM in aux memory and
* Provide an environment where it can run
* Bobbi 2021
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

            PUT   LOADER
            PUT   MAINMEM
            PUT   AUXMEM

