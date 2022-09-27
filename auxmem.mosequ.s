* AUXMEM.MOSEQU.S
* (c) Bobbi 2021 GPLv3
*

*******************************
* BBC MOS WORKSPACE LOCATIONS *
*******************************

* $00-$8F Language workspace
* $90-$9F Network workspace
* $A0-$A7 NMI workspace
* $A8-$AF Non-MOS *command workspace
* $B0-$BF Temporary filing system workspace
* $C0-$CF Persistant filing system workspace
* $D0-$DF VDU driver workspace
* $E0-$EE Internal MOS workspace
* $EF-$FF MOS API workspace

* DEBUG       EQU   $00         ; $00=*OPT 255 debug code removed
DEBUG        EQU   $E0         ; $E0=*OPT 255 debug code included
*                             ; $E1
FSFLAG1      EQU   $E2         ; $E2
FSFLAG2      EQU   $E3         ; $E3 HOSTFS *OPT settings
GSFLAG       EQU   $E4         ; $E4 GSREAD processing flags
GSCHAR       EQU   $E5         ; $E5 GSREAD accumulator
OSTEXT       EQU   $E6         ; $E6 => text string  $E6 OSNUM+0
MAXLEN       EQU   OSTEXT+2    ; $E8                 $E8 OSNUM+2
MINCHAR      EQU   OSTEXT+3    ; $E9                 $E9 OSNUM+3
MAXCHAR      EQU   OSTEXT+4    ; $EA                 $EA OSPAD
OSTEMP       EQU   $EB         ; $EB                 $EB OSTEMP
OSKBD1       EQU   $EC         ; $EC kbd ws
OSKBD2       EQU   OSKBD1+1    ; $ED kbd ws
OSKBD3       EQU   OSKBD1+2    ; $EE kbd ws
OSAREG       EQU   $EF         ; $EF   A  register
OSXREG       EQU   OSAREG+1    ; $F0   X  register
OSYREG       EQU   OSXREG+1    ; $F1   Y  register
OSCTRL       EQU   OSXREG      ; $F0  (XY)=>control block
OSLPTR       EQU   $F2         ; $F2 => command line
ROMID        EQU   $F4         ; $F4 current ROM 
ROMTMP       EQU   $F5         ; $F5 
ROMPTR       EQU   $F6         ; $F6 =>
*                             ; $F8 *TEMP* pseudo-SROM settings
*                             ; $F9 *TEMP* pseudo-SROM settings
OSINTWS      EQU   $FA         ; $FA  IRQ ZP pointer, use when IRQs off
OSINTA       EQU   $FC         ; $FC  IRQ register A store
FAULT        EQU   $FD         ; $FD  Error message pointer
ESCFLAG      EQU   $FF         ; $FF  Escape status


* $0200-$0235 Vectors
* $0236-$028F OSBYTE variables ($190+BYTENUM)
* $0290-$02ED
* $02EE-$02FF MOS control block

USERV        EQU   $200        ; USER vector
BRKV         EQU   $202        ; BRK vector
CLIV         EQU   $208        ; OSCLI vector
BYTEV        EQU   $20A        ; OSBYTE vector
WORDV        EQU   $20C        ; OSWORD vector
WRCHV        EQU   $20E        ; OSWRCH vector
RDCHV        EQU   $210        ; OSRDCH vector
FILEV        EQU   $212        ; OSFILE vector
ARGSV        EQU   $214        ; OSARGS vector
BGETV        EQU   $216        ; OSBGET vector
BPUTV        EQU   $218        ; OSBPUT vector
GBPBV        EQU   $21A        ; OSGBPB vector
FINDV        EQU   $21C        ; OSFIND vector
FSCV         EQU   $21E        ; FSCV misc file ops

BYTEVARBASE  EQU   $190        ; Base of OSBYTE variables

SND0EMPTY    EQU   $2D3        ; Empty flag for sound bufs
SND1EMPTY    EQU   $2D4
SND2EMPTY    EQU   $2D5
SND3EMPTY    EQU   $2D6
SND0STARTIDX EQU   $2DC        ; Start index for sound bufs
SND1STARTIDX EQU   $2DD
SND2STARTIDX EQU   $2DE
SND3STARTIDX EQU   $2DF
SND0ENDIDX   EQU   $2E5        ; End index for sound bufs
SND1ENDIDX   EQU   $2E6
SND2ENDIDX   EQU   $2E7
SND3ENDIDX   EQU   $2E8

OSFILECB     EQU   $2EE        ; OSFILE control block
OSGBPBCB     EQU   OSFILECB+1  ; OSGBPB control block


* $0300-$03DF
* $03E0-$03FF Used for interfacing with ProDOS XFER

* $0800-$08FF
SNDBUF0      EQU  $840         ; Sound buffers (16 bytes each)
SNDBUF1      EQU  $850
SNDBUF2      EQU  $860
SNDBUF3      EQU  $870





