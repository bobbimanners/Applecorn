* AUXMEM.INIT.S
* (c) Bobbi 2021 GPL v3
*
* Initialization code running in Apple //e aux memory
* 08-Nov-2022 ResetType OSBYTE set
* 09-Nov-2022 Current language re-entered, reset on Power/Hard Reset
* BUG: If Ctrl-Break pressed during a service call, wrong ROM gets paged in


***********************************************************
* BBC Micro 'virtual machine' in Apple //e aux memory
***********************************************************

MAXROM      EQU   $F9             ; Max sideways ROM number
FXLANG      EQU   BYTEVARBASE+$FC ; Current language
FXRESET     EQU   BYTEVARBASE+$FD ; Last Reset type
FXOPTIONS   EQU   BYTEVARBASE+$FF ; Startup options


ZP1         EQU   $90             ; $90-$9f are spare Econet space
                                  ; so safe to use
ZP2         EQU   $92
ZP3         EQU   $94

*STRTBCKL    EQU   $9D             ; *TO DO* No longer needed to preserve
*STRTBCKH    EQU   $9E

MOSSHIM
            ORG   AUXMOS          ; MOS shim implementation

*
* Shim code to service Acorn MOS entry points using
* Apple II monitor routines
* This code is initially loaded into aux mem at AUXMOS1
* Then relocated into aux LC at AUXMOS by MOSINIT
*
* Initially executing at $2000 until copied to $D000
*
* When first run from loading from disk:
*  Code will be at $2000-$4FFF, then copied to $D000-$FFFF
* When Ctrl-Reset pressed:
*  AUX RESET code jumps to MAIN $D000
*
MOSINIT     SEI                   ; Ensure IRQs disabled
            LDX   #$FF            ; Initialize Alt SP to $1FF
            TXS

            STA   WRCARDRAM       ; Make sure we are writing aux
            STA   80STOREOFF      ; Make sure 80STORE is off

            LDA   LCBANK1         ; LC RAM Rd/Wt, 1st 4K bank
            LDA   LCBANK1
            LDY   #$00            ; $00=Soft Reset
:MODBRA     BRA   :RELOC          ; NOPped out on first run
            BRA   :NORELOC

:RELOC      LDA   #<AUXMOS1       ; Source
            STA   A1L
            LDA   #>AUXMOS1
            STA   A1H
            LDA   #<AUXMOS        ; Dest
            STA   A2L
            LDA   #>AUXMOS
            STA   A2H             ; Y=0 from earlier
:L1         LDA   (A1L),Y         ; Copy from source
            STA   (A2L),Y         ; to dest
            INY
            BNE   :L1             ; Do 256 bytes
            INC   A1H             ; Update source
            INC   A2H             ; Update dest
            BMI   :L1             ; Loop until wrap past &FFFF
*
:L2         LDA   MOSVEND-AUXMOS+AUXMOS1-256,Y
            STA   $FF00,Y         ; Copy MOS API and vectors
            INY                   ; to proper place
            BNE   :L2

*:S4         LDA   #<MOSVEC-MOSINIT+AUXMOS1
*            STA   A1L
*            LDA   #>MOSVEC-MOSINIT+AUXMOS1
*            STA   A1H
*            LDA   #<MOSVEND-MOSINIT+AUXMOS1
*            STA   A2L
*            LDA   #>MOSVEND-MOSINIT+AUXMOS1
*            STA   A2H
*            LDA   #<MOSAPI
*            STA   A4L
*            LDA   #>MOSAPI
*            STA   A4H
*:L2         LDA   (A1L)
*            STA   (A4L)
*            LDA   A1H
*            CMP   A2H
*            BNE   :S5
*            LDA   A1L
*            CMP   A2L
*            BNE   :S5

*            LDA   #<AUXMOS1       ; Relocate MOS shim
*            STA   A1L
*            LDA   #>AUXMOS1
*            STA   A1H
*            LDA   #<EAUXMOS1
*            STA   A2L
*            LDA   #>EAUXMOS1
*            STA   A2H
*            LDA   #<AUXMOS
*            STA   A4L
*            LDA   #>AUXMOS
*            STA   A4H
*:L1         LDA   (A1L)
*            STA   (A4L)
*            LDA   A1H
*            CMP   A2H
*            BNE   :S1
*            LDA   A1L
*            CMP   A2L
*            BNE   :S1
*            BRA   :S4
*:S1         INC   A1L
*            BNE   :S2
*            INC   A1H
*:S2         INC   A4L
*            BNE   :S3
*            INC   A4H
*:S3         BRA   :L1
*
*:S4         LDA   #<MOSVEC-MOSINIT+AUXMOS1
*            STA   A1L
*            LDA   #>MOSVEC-MOSINIT+AUXMOS1
*            STA   A1H
*            LDA   #<MOSVEND-MOSINIT+AUXMOS1
*            STA   A2L
*            LDA   #>MOSVEND-MOSINIT+AUXMOS1
*            STA   A2H
*            LDA   #<MOSAPI
*            STA   A4L
*            LDA   #>MOSAPI
*            STA   A4H
*:L2         LDA   (A1L)
*            STA   (A4L)
*            LDA   A1H
*            CMP   A2H
*            BNE   :S5
*            LDA   A1L
*            CMP   A2L
*            BNE   :S5
*            BRA   :S8
*:S5         INC   A1L
*            BNE   :S6
*            INC   A1H
*:S6         INC   A4L
*            BNE   :S7
*            INC   A4H
*:S7         BRA   :L2

:S8
            LDA   #$EA            ; NOP opcode
            STA   :MODBRA+0       ; Next time around, we're already
            STA   :MODBRA+1       ; in high memory
            LDY   #$02            ; $02=PowerOn

:NORELOC    STA   SET80VID        ; 80 col on
            STA   CLRALTCHAR      ; Alt charset off
            STA   PAGE2           ; PAGE2
            JMP   MOSHIGH         ; Ensure executing in high memory from here

* From here onwards we are always executing at $D000 onwards
* Y=ResetType

MOSHIGH     SEI                   ; Ensure IRQs disabled
            LDX   #$FF
            TXS                   ; Initialise stack
            INX                   ; X=$00
            LDA   FXLANG          ; Y=ResetType, A=Language

:SCLR       STZ   $0000,X         ; Clear Kernel memory
            STZ   $0200,X
            STZ   $0300,X
            INX
            BNE   :SCLR
            STY   FXRESET         ; Set ResetType
            STA   FXLANG          ; Current language

            LDX   #ENDVEC-DEFVEC-1
:INITPG2    LDA   DEFVEC,X        ; Set up vectors
            STA   $200,X
            DEX
            BPL   :INITPG2

            LDA   CYAREG          ; GS speed register
            AND   #$80            ; Speed bit only
            STA   GSSPEED         ; In Alt LC for IRQ/BRK hdlr

            JSR   ROMINIT         ; Build list of sideways ROMs
            JSR   KBDINIT         ; Returns A=startup MODE
            JSR   VDUINIT         ; Initialise VDU driver
            JSR   PRHELLO
            JSR   OSNEWL
            LDA   FXRESET         ; Get ResetType
            BEQ   :INITSOFT       ; Soft reset, skip past
            LDA   #7              ; Beep on HardReset/PowerReset
            JSR   OSWRCH
            LDA   #$FF
            STA   FXLANG          ; Current language=none
*
* AppleII MOS beeps anyway, so always get a Beep
* APPLECORN startup -> BBC Beep
* Press Ctrl-Reset  -> AppleII Beep
*
* Find a language to enter
:INITSOFT   LDX   FXLANG          ; Get current language
            BPL   :INITLANG       ; b7=ok, use it
            LDX   ROMMAX          ; Look for a language
:FINDLANG   JSR   ROMSELECT       ; Bring ROM X into memory
            BIT   $8006           ; Check ROM type
            BVS   :INITLANG       ; b6=set, use it
            DEX                   ; Step down to next ROM
            BPL   :FINDLANG       ; Loop until all tested
            BRK                   ; No language found
            DB    $F9
            ASC   'No Language'
            BRK
*
:INITLANG   CLC                   ; CLC=Entering from RESET

* OSBYTE $8E - Enter language ROM
*********************************
* X=ROM number to select, CC=RESET, CS=*COMMAND/OSBYTE
*
BYTE8E      PHP                   ; Save CLC=RESET, SEC=Not RESET
            JSR   ROMSELECT       ; Bring ROM X into memory
            STX   FXLANG          ; Set as current language ROM
            LDA   #$00
            STA   FAULT+0
            LDA   #$80
            STA   FAULT+1
            LDY   #$09
            JSR   PRERRLP         ; Print ROM name with PRERR to set
            STY   FAULT+0         ;  FAULT pointing to version string
            JSR   OSNEWL
            JSR   OSNEWL
            PLP                   ; Get entry type back
            LDA   #$01            ; $01=Entering code with a header
            JMP   ROMAUXADDR


* OSBYTE $8F - Issue service call
*********************************
* X=service call, Y=parameter
*
* SERVICE     TAX                   ; Enter here with A=Service Num
SERVICEX
BYTE8F      LDA   $F4             ; Enter here with X=Service Number
            PHA                   ; Save current ROM
*DEBUG
            LDA   $E0
            AND   #$20            ; Test debug *OPT255,32
            BEQ   :SERVDEBUG
            CPX   #$06
            BEQ   :SERVDONE       ; If debug on, ignore SERV06
:SERVDEBUG
*DEBUG
            TXA                   ; A=service number
            LDX   ROMMAX          ; Start at highest ROM
:SERVLP     JSR   ROMSELECT       ; Bring it into memory
            BIT   $8006
            BPL   :SERVSKIP       ; No service entry
            JSR   $8003           ; Call service entry
            TAX
            BEQ   :SERVDONE
:SERVSKIP   LDX   $F4             ; Restore X=current ROM
            DEX                   ; Step down to next
            BPL   :SERVLP         ; Loop until ROM 0 done
:SERVDONE   PLA                   ; Get caller's ROM back
            PHX                   ; Save return from service call
            TAX
            JSR   ROMSELECT       ; Restore caller's ROM
            PLX                   ; Get return value back
            TXA                   ; Return in A and X and set EQ/NE
            RTS

PRHELLO     LDX   #<HELLO
            LDY   #>HELLO
            JSR   OSPRSTR
            JMP   OSNEWL

BYTE00      BEQ   BYTE00A         ; OSBYTE 0,0 - generate error
            LDX   #$0A            ; Identify Host
            RTS                   ; %000x1xxx host type, 'A'pple
BYTE00A     BRK
            DB    $F7
HELLO       ASC   'Applecorn MOS 2022-11-25'
            DB    $00             ; Unify MOS messages
* TO DO: Move into RAM
GSSPEED     DB    $00             ; $80 if GS is fast, $00 for slow

