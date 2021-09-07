* AUXMEM.INIT.S
* (c) Bobbi 2021 GPL v3
*
* Initialization code running in Apple //e aux memory

***********************************************************
* BBC Micro 'virtual machine' in Apple //e aux memory
***********************************************************

ZP1         EQU   $90                        ; $90-$9f are Econet space
                                             ; so safe to use
ZP2         EQU   $92

ZP3         EQU   $94

* COL,ROW needs to be in X,Y order
* TO DO: will be moved to VDU space
COL         EQU   $96                        ; Cursor column
ROW         EQU   $97                        ; Cursor row
STRTBCKL    EQU   $9D
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

            JSR   KBDINIT                    ; Returns A=startup MODE
            JSR   VDUINIT                    ; Initialise VDU driver
            JSR   PRHELLO
            LDA   #7
            JSR   OSWRCH
            JSR   OSNEWL
            CLC
            JMP   BYTE8E

PRHELLO     LDA   #<HELLO
            LDY   #>HELLO
            JSR   PRSTR
            JMP   OSNEWL

BYTE00XX    BEQ   BYTE00A                    ; OSBYTE 0,0 - generate error
            LDX   #$0A                       ; $00 = identify Host
            RTS                              ; %000x1xxx host type, 'A'pple
BYTE00A     BRK
            DB    $F7
HELLO       ASC   'Applecorn MOS 2021-09-06 snapshot'
            DB    $00                        ; Unify MOS messages









