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

FSFLAG1      EQU   $E2
FSFLAG2      EQU   $E3
GSFLAG       EQU   $E4
GSCHAR       EQU   $E5
OSTEXT       EQU   $E6         ; $E6 => text string
MAXLEN       EQU   OSTEXT+2    ; $E8
MINCHAR      EQU   OSTEXT+3    ; $E9
MAXCHAR      EQU   OSTEXT+4    ; $EA
OSTEMP       EQU   $EB         ; $EB
OSKBD1       EQU   $EC         ; $EC kbd ws
OSKBD2       EQU   OSKBD1+1    ; $ED kbd ws
OSKBD3       EQU   OSKBD1+2    ; $EE kbd ws
OSAREG       EQU   $EF         ; $EF   A  register
OSXREG       EQU   OSAREG+1    ; $F0   X  register
OSYREG       EQU   OSXREG+1    ; $F1   Y  register
OSCTRL       EQU   OSXREG      ; $F0  (XY)=>control block
OSLPTR       EQU   $F2         ; $F2 => command line
*
OSINTWS      EQU   $FA         ; $FA  IRQ ZP pointer, use when IRQs off
OSINTA       EQU   $FC         ; $FC  IRQ register A store
FAULT        EQU   $FD         ; $FD  Error message pointer
ESCFLAG      EQU   $FF         ; $FF  Escape status


* $0200-$0235 Vectors
* $0236-$028F OSBYTE variables
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
OSFILECB     EQU   $2EE        ; OSFILE control block




