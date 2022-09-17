* AUXMEM.INIT.S
* (c) Bobbi 2021 GPL v3
*
* Initialization code running in Apple //e aux memory

***********************************************************
* BBC Micro 'virtual machine' in Apple //e aux memory
***********************************************************

MAXROM      EQU   $F9                        ; Max sideways ROM number

ZP1         EQU   $90                        ; $90-$9f are spare Econet space
                                             ; so safe to use
ZP2         EQU   $92
ZP3         EQU   $94

STRTBCKL    EQU   $9D                        ; *TO DO* don't need to preserve
STRTBCKH    EQU   $9E

MOSSHIM
            ORG   AUXMOS                     ; MOS shim implementation

*
* Shim code to service Acorn MOS entry points using
* Apple II monitor routines
* This code is initially loaded into aux mem at AUXMOS1
* Then relocated into aux LC at AUXMOS by MOSINIT
*
* Initially executing at $3000 until copied to $D000

MOSINIT     LDX   #$FF                       ; Initialize Alt SP to $1FF
            TXS

            STA   $C005                      ; Make sure we are writing aux
            STA   $C000                      ; Make sure 80STORE is off

            LDA   $C08B                      ; LC RAM Rd/Wt, 1st 4K bank
            LDA   $C08B

:MODBRA     BRA   :RELOC                     ; NOPped out on first run
            BRA   :NORELOC

            LDA   #$EA                       ; NOP opcode
            STA   :MODBRA
            STA   :MODBRA+1

:RELOC      LDA   #<AUXMOS1                  ; Relocate MOS shim
            STA   A1L
            LDA   #>AUXMOS1
            STA   A1H
            LDA   #<EAUXMOS1
            STA   A2L
            LDA   #>EAUXMOS1
            STA   A2H
            LDA   #<AUXMOS
            STA   A4L
            LDA   #>AUXMOS
            STA   A4H
:L1         LDA   (A1L)
            STA   (A4L)
            LDA   A1H
            CMP   A2H
            BNE   :S1
            LDA   A1L
            CMP   A2L
            BNE   :S1
            BRA   :S4
:S1         INC   A1L
            BNE   :S2
            INC   A1H
:S2         INC   A4L
            BNE   :S3
            INC   A4H
:S3         BRA   :L1

:S4         LDA   #<MOSVEC-MOSINIT+AUXMOS1
            STA   A1L
            LDA   #>MOSVEC-MOSINIT+AUXMOS1
            STA   A1H
            LDA   #<MOSVEND-MOSINIT+AUXMOS1
            STA   A2L
            LDA   #>MOSVEND-MOSINIT+AUXMOS1
            STA   A2H
            LDA   #<MOSAPI
            STA   A4L
            LDA   #>MOSAPI
            STA   A4H
:L2         LDA   (A1L)
            STA   (A4L)
            LDA   A1H
            CMP   A2H
            BNE   :S5
            LDA   A1L
            CMP   A2L
            BNE   :S5
            BRA   :S8
:S5         INC   A1L
            BNE   :S6
            INC   A1H
:S6         INC   A4L
            BNE   :S7
            INC   A4H
:S7         BRA   :L2

:NORELOC
:S8         STA   $C00D                      ; 80 col on
            STA   $C003                      ; Alt charset off
            STA   $C055                      ; PAGE2
            JMP   MOSHIGH                    ; Ensure executing in high memory here

MOSHIGH     SEI
            LDX   #$FF
            TXS                              ; Initialise stack
            INX                              ; X=$00
            TXA
:SCLR       STA   $0000,X                    ; Clear Kernel memory
            STA   $0200,X
            STA   $0300,X
            INX
            BNE   :SCLR

            LDX   #ENDVEC-DEFVEC-1
:INITPG2    LDA   DEFVEC,X                   ; Set up vectors
            STA   $200,X
            DEX
            BPL   :INITPG2

            JSR   ROMINIT                    ; Build list of sideways ROMs
            JSR   KBDINIT                    ; Returns A=startup MODE
            JSR   VDUINIT                    ; Initialise VDU driver
            JSR   PRHELLO
            LDA   #7
            JSR   OSWRCH
            JSR   OSNEWL
            LDX   MAXROM                     ; TEMP X=language to enter
            CLC

* OSBYTE $8E - Enter language ROM
* X=ROM number to select
*
BYTE8E      PHP                              ; Save CLC=RESET, SEC=Not RESET
            JSR   ROMSELECT                  ; Bring ROM X into memory 
            STX   BYTEVARBASE+$FC            ; Set current language ROM
            LDA   #$00
            STA   FAULT+0
            LDA   #$80
            STA   FAULT+1
            LDY   #$09
            JSR   PRERRLP                    ; Print ROM name with PRERR to set
            STY   FAULT+0                    ;  FAULT pointing to version string
            JSR   OSNEWL
            JSR   OSNEWL
            PLP                              ; Get entry type back
            LDA   #$01
            JMP   AUXADDR

* OSBYTE $8F - Issue service call
* X=service call, Y=parameter
*
SERVICE     TAX                              ; Enter here with A=Service Num
BYTE8F
SERVICEX    LDA   $F4
            PHA                              ; Save current ROM

*            LDA   $E0             ; *DEBUG*
*            AND   #$20
*            BEQ   :SERVDEBUG
*            TXA
*            JSR   PRHEX
*            LDA   OSLPTR+1
*            JSR   PRHEX
*            LDA   OSLPTR+0
*            JSR   PRHEX           ; *DEBUG*
*:SERVDEBUG

            TXA
            LDX   MAXROM                     ; Start at highest ROM
:SERVLP     JSR   ROMSELECT                  ; Bring it into memory
            BIT   $8006
            BPL   :SERVSKIP                  ; No service entry
            JSR   $8003                      ; Call service entry
            TAX
            BEQ   :SERVDONE
:SERVSKIP   LDX   $F4                        ; Restore X=current ROM
            DEX                              ; Step down to next
            BPL   :SERVLP                    ; Loop until ROM 0 done
:SERVDONE   PLA                              ; Get caller's ROM back
            PHX                              ; Save return from service call
            TAX
            JSR   ROMSELECT                  ; Restore caller's ROM
            PLX                              ; Get return value back
            TXA                              ; Return in A and X and set EQ/NE
            RTS


PRHELLO     LDA   #<HELLO
            LDY   #>HELLO
            JSR   PRSTR
            JMP   OSNEWL

BYTE00XX
BYTE00      BEQ   BYTE00A                    ; OSBYTE 0,0 - generate error
            LDX   #$0A                       ; Identify Host
            RTS                              ; %000x1xxx host type, 'A'pple
BYTE00A     BRK
            DB    $F7
HELLO       ASC   'Applecorn MOS 2022-09-17'
            DB    $00                        ; Unify MOS messages








