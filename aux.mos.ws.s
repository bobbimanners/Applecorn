* AUX.MOS.WS.S
* (c) Bobbi 2021 GPLv3

***********************************************************
* Acorn MOS Workspace Locations
***********************************************************

* $00-$8F Language workspace
* $90-$9F Network workspace
* $A0-$A7 NMI workspace
* $A8-$AF Non-MOS *command workspace
* $B0-$BF Temporary filing system workspace
* $C0-$CF Persistant filing system workspace
* $D0-$DF VDU driver workspace
* $E0-$EE Internal MOS workspace
* $EF-$FF MOS API workspace

FSFLAG1     EQU   $E2
FSFLAG2     EQU   $E3
GSFLAG      EQU   $E4
GSCHAR      EQU   $E5
OSTEXT      EQU   $E6
MAXLEN      EQU   OSTEXT+2    ; $E8
MINCHAR     EQU   OSTEXT+3    ; $E9
MAXCHAR     EQU   OSTEXT+4    ; $EA
OSTEMP      EQU   $EB
OSKBD1      EQU   $EC         ; Kbd workspace
OSKBD2      EQU   $ED
OSKBD3      EQU   $EE
OSAREG      EQU   $EF
OSXREG      EQU   OSAREG+1    ; $F0
OSYREG      EQU   OSXREG+1    ; $F1
OSCTRL      EQU   OSXREG
OSLPTR      EQU   $F2
*
OSINTWS     EQU   $FA         ; IRQ ZP pointer
OSINTA      EQU   $FC         ; IRQ A-reg store
FAULT       EQU   $FD         ; Error message pointer
ESCFLAG     EQU   $FF         ; Escape status

* $0200-$0235 Vectors
* $0236-$028F OSBYTE variables
* $0290-$02ED
* $02EE-$02FF MOS control block

USERV       EQU   $200        ; USER vector
BRKV        EQU   $202        ; BRK vector
CLIV        EQU   $208        ; OSCLI vector
BYTEV       EQU   $20A        ; OSBYTE vector
WORDV       EQU   $20C        ; OSWORD vector
WRCHV       EQU   $20E        ; OSWRCH vector
RDCHV       EQU   $210        ; OSRDCH vector
FILEV       EQU   $212        ; OSFILE vector
ARGSV       EQU   $214        ; OSARGS vector
BGETV       EQU   $216        ; OSBGET vector
BPUTV       EQU   $218        ; OSBPUT vector
GBPBV       EQU   $21A        ; OSGBPB vector
FINDV       EQU   $21C        ; OSFIND vector
FSCV        EQU   $21E        ; FSCV misc file ops

OSFILECB    EQU   $2EE        ; OSFILE control block


