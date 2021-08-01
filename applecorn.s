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

* Macro for calls from aux memory to main memory
XFMAIN      MAC
            CLC               ; Use main memory
            CLV               ; Use main ZP and LC
            JMP   XFER
            EOM

* Called by code running in main mem to invoke a
* routine in aux memory
XF2AUX      MAC
            PHA
            LDA   $C08B       ; R/W LC RAM, bank 1
            LDA   $C08B
            LDA   #<]1
            STA   STRTL
            LDA   #>]1
            STA   STRTH
            PLA
            SEC               ; Use aux memory
            BIT   $FF58       ; Set V: use alt ZP and LC
            JMP   XFER
            EOM

* Macro to backup STRTL/STRTH then load XFADDR
* Called by code running in aux mem
XFADDRAUX   MAC
            TSX
            STX   $0101       ; Save alt SP
            PHA
            LDA   STRTL
            STA   STRTBCKL
            LDA   STRTH
            STA   STRTBCKH
            LDA   #<]1
            STA   STRTL
            LDA   #>]1
            STA   STRTH
            PLA
            EOM

* Macro called on re-entry to aux memory
ENTAUX      MAC
            LDX   $0101       ; Recover alt SP
            TXS
            PHA
            LDA   STRTBCKL
            STA   STRTL
            LDA   STRTBCKH
            STA   STRTH
            PLA
            EOM

* Macro called on re-entry to main memory
ENTMAIN     MAC
            LDX   $0100       ; Recover SP
            TXS
            PHA               ; Preserve parm in A
            LDA   $C081       ; Bank in ROM
            LDA   $C081
            PLA
            EOM

* Code is all included from PUT files below ...
            PUT   LOADER
            PUT   MAINMEM
            PUT   AUXMEM

