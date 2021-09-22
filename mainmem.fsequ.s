* MAINMEM.FSEQU.S
* (c) Bobbi 2021 GPL v3
*
* Constant definitions for ProDOS filesystem code that
* resides in main memory.

* ProDOS string buffers
RTCBUF      EQU   $0200       ; Use by RTC calls, 40 bytes
*                                 ; $0228-$023D
DRVBUF1     EQU   $023E
DRVBUF2     EQU   $023F       ; Prefix on current drive, len+64
CMDPATH     EQU   $0280       ; Path used to start Applecorn

* Filename string buffers
MOSFILE1    EQU   $0300       ; length + 64 bytes
MOSFILE2    EQU   $0341       ; length + 64 bytes
MOSFILE     EQU   MOSFILE1
*                 $0382           ; $3C bytes here
*
FILEBLK     EQU   $03BE
FBPTR       EQU   FILEBLK+0   ; Pointer to name (in aux)
FBLOAD      EQU   FILEBLK+2   ; Load address
FBEXEC      EQU   FILEBLK+6   ; Exec address
FBSIZE      EQU   FILEBLK+10  ; Size
FBSTRT      EQU   FILEBLK+10  ; Start address for SAVE
FBATTR      EQU   FILEBLK+14  ; Attributes
FBEND       EQU   FILEBLK+14  ; End address for SAVE

* ProDOS MLI command numbers
QUITCMD     EQU   $65
GTIMECMD    EQU   $82
CREATCMD    EQU   $C0
DESTCMD     EQU   $C1
RENCMD      EQU   $C2
SINFOCMD    EQU   $C3
GINFOCMD    EQU   $C4
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























