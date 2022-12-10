* MAINMEM.FSEQU.S
* (c) Bobbi 2021-2022 GPL v3
*
* Constant definitions for ProDOS filesystem code that
* resides in main memory.

* ProDOS string buffers
RTCBUF      EQU   $0200       ; Use by RTC calls, 40 bytes
*               ; $0228-$023D
DRVBUF1     EQU   $023E
DRVBUF2     EQU   $023F       ; Prefix on current drive, length
*                 $0240       ; Prefix path
CMDPATH     EQU   $0280       ; Path used to start Applecorn
*               ; $02C0-$02FF

* Filename string buffers
MOSFILE1    EQU   $0300       ; length + 64 bytes
MOSFILE2    EQU   $0341       ; length + 64 bytes
MOSFILE     EQU   MOSFILE1
*               ; $0382-$03A3 ROM selection w/s (move?)
*               ; $03A4-$03BD

* Control block for OSFILE
FILEBLK     EQU   $03BE
FBPTR       EQU   FILEBLK+0   ; Pointer to name (in aux)
FBLOAD      EQU   FILEBLK+2   ; Load address (4 bytes)
FBEXEC      EQU   FILEBLK+6   ; Exec address (4 bytes)
FBSIZE      EQU   FILEBLK+10  ; Size (4 bytes)
FBSTRT      EQU   FILEBLK+10  ; Start address for SAVE (4 bytes)
FBATTR      EQU   FILEBLK+14  ; Attributes (4 bytes)
FBEND       EQU   FILEBLK+14  ; End address for SAVE (4 bytes)

* Control block for OSGBPB
GBPBBLK     EQU   FILEBLK+1
GBPBHDL     EQU   GBPBBLK+0   ; File handle
GBPBDAT     EQU   GBPBBLK+1   ; Pointer to data (4 bytes)
GBPBNUM     EQU   GBPBBLK+5   ; Num bytes to transfer (4 bytes)
GBPBPTR     EQU   GBPBBLK+9   ; File pointer (4 bytes)
GBPBAUXCB   EQU   GBPBBLK+13  ; Address of aux control block (2 bytes)

*               ; $03D0-$03FF ; ProDOS workspace

* ProDOS MLI command numbers
ALLOCCMD    EQU   $40
DEALLOCCMD  EQU   $41
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

