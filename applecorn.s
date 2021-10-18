* APPLECORN.S
* (c) Bobbi 2021 GPLv3
*
* Load an Acorn BBC Micro ROM in aux memory and
* Provide an environment where it can run
*
* Assembled with the Merlin 8 v2.58 assembler on Apple II.

* 14-Oct-2021 XF2MAIN, ENTAUX no longer save/restore STRTL/STRTH.


            XC                ; 65c02
            ORG   $4000       ; Load addr of loader in main memory
                              ; Clear of first HGR frame buffer

* Monitor routines
BELL        EQU   $FBDD
PRBYTE      EQU   $FDDA
COUT1       EQU   $FDED
CROUT       EQU   $FD8E
HOME        EQU   $FC58
AUXMOVE     EQU   $C311
XFER        EQU   $C314

* Monitor ZP locations
A1L         EQU   $3C
A1H         EQU   $3D
A2L         EQU   $3E
A2H         EQU   $3F
A4L         EQU   $42
A4H         EQU   $43

* ProDOS ZP locations
* $38-$4F

* Used by MOS support code
ZP30        EQU   $30
ZP32        EQU   $32
ZP34        EQU   $34
ZP36        EQU   $36

* Used by XFER
STRTL       EQU   $3ED
STRTH       EQU   $3EE

* Reset vector (2 bytes + 1 byte checksum)
RSTV        EQU   $3F2

* IRQ vector
A2IRQV      EQU   $3FE

* MLI entry point
MLI         EQU   $BF00

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
AUXADDR     EQU   $8000

* Address in aux memory where the MOS shim is located
AUXMOS1     EQU   $2000       ; Temp staging area in Aux
EAUXMOS1    EQU   $5000       ; End of staging area
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
            SEI               ; Disable IRQ before XFER
            SEC               ; Use aux memory
            BIT   $FF58       ; Set V: use alt ZP and LC
            JMP   XFER
            EOM

* Called by code running in aux mem to invoke a
* routine in main memory
XF2MAIN     MAC
*            LDX   STRTL      ; No longer needed
*            STX   STRTBCKL   ; $03E0-$03FF reserved for memory
*            LDX   STRTH      ; switching
*            STX   STRTBCKH
            LDX   #<]1
            STX   STRTL
            LDX   #>]1
            STX   STRTH
            SEI               ; Disable IRQ before XFER
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
*            LDX   STRTBCKL   ; No longer needed
*            STX   STRTL      ; $03e0-$03FF reserved for memory
*            LDX   STRTBCKH   ; switching
*            STX   STRTH
            EOM

* Macro called on re-entry to main memory
* Careful: This enables IRQ - not for use in ISR
ENTMAIN     MAC
            TXS               ; Main SP already in X
            LDX   $C081       ; Bank in ROM
            LDX   $C081
            CLI               ; Re-enable IRQ after XFER
            EOM

* Macro called on re-entry to aux memory
* For use in interrupt handlers (no CLI!)
IENTAUX     MAC
            LDX   $0101       ; Recover alt SP
            TXS
            LDX   STRTBCKL
            STX   STRTL
            LDX   STRTBCKH
            STX   STRTH
            EOM

* Macro called on re-entry to main memory
* For use in interrupt handlers (no CLI!)
IENTMAIN    MAC
            TXS               ; Main SP already in X
            LDX   $C081       ; Bank in ROM
            LDX   $C081
            EOM

* Enable writing to main memory (for code running in aux)
WRTMAIN     MAC
            SEI               ; Keeps IRQ handler easy
            STA   $C004       ; Write to main memory
            EOM

* Go back to writing to aux (for code running in aux)
WRTAUX      MAC
            STA   $C005       ; Write to aux memory
            CLI               ; Normal service resumed
            EOM

* Manually enable AltZP (for code running in main)
ALTZP       MAC
            SEI               ; Disable IRQ when AltZP on
            LDA   $C08B       ; R/W LC bank 1
            LDA   $C08B
            STA   $C009       ; Alt ZP and LC
            EOM

* Manually disable AltZP (for code running in main)
MAINZP      MAC
            STA   $C008       ; Main ZP and LC
            LDA   $C081       ; Bank ROM back in
            LDA   $C081
            CLI               ; Turn IRQ back on
            EOM

* Code is all included from PUT files below ...
* ... order matters!
            PUT   MAINMEM.LDR
            PUT   MAINMEM.MENU
            PUT   MAINMEM.FSEQU
            PUT   MAINMEM.INIT
            PUT   MAINMEM.SVC
            PUT   MAINMEM.GFX
            PUT   MAINMEM.PATH
            PUT   MAINMEM.WILD
            PUT   MAINMEM.LISTS
            PUT   MAINMEM.MISC
            PUT   AUXMEM.MOSEQU
            PUT   AUXMEM.INIT
            PUT   AUXMEM.VDU
            PUT   AUXMEM.GFX
            PUT   AUXMEM.HOSTFS
            PUT   AUXMEM.OSCLI
            PUT   AUXMEM.BYTWRD
            PUT   AUXMEM.CHARIO
            PUT   AUXMEM.MISC

* Automatically save the object file:
            SAV   APPLECORN





























