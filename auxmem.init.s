***********************************************************
* BBC Micro 'virtual machine' in Apple //e aux memory
***********************************************************

ZP1         EQU   $90                        ; $90-$9f are Econet space
                                             ; so safe to use
ZP2         EQU   $92

ZP3         EQU   $94

ROW         EQU   $96                        ; Cursor row
COL         EQU   $97                        ; Cursor column
STRTBCKL    EQU   $9D
STRTBCKH    EQU   $9E
WARMSTRT    EQU   $9F                        ; Cold or warm start
MAGIC       EQU   $BC                        ; Arbitrary value

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

            LDA   WARMSTRT                   ; Don't relocate on restart
            CMP   #MAGIC
            BEQ   :NORELOC

            LDA   #<AUXMOS1                  ; Relocate MOS shim
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

:NORELOC                                     ; We should jump up into high memory here
:S8         STA   $C00D                      ; 80 col on
            STA   $C003                      ; Alt charset off
            STA   $C055                      ; PAGE2

            LDY   WARMSTRT                   ; Don't lose this
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
            STY   WARMSTRT                   ; Put it back

            JSR   CLEAR                      ; Initialise VDU driver

            LDA   #<:HELLO
            LDY   #>:HELLO
            JSR   PRSTR

            LDA   #$09                       ; Print language name at $8009
            LDY   #$80
            JSR   PRSTR
            JSR   OSNEWL
            JSR   OSNEWL

            LDA   WARMSTRT
            CMP   #MAGIC
            BNE   :S9
            LDA   #<:OLDM
            LDY   #>:OLDM
            JSR   PRSTR

:S9         LDA   #MAGIC                     ; So we do not reloc again
            STA   WARMSTRT

            CLC                              ; CLC=Entered from RESET
            LDA   #$01                       ; $01=Entering application code
            JMP   AUXADDR                    ; Start Acorn ROM
* No return
:HELLO      ASC   'Applecorn MOS v0.01'
            DB    $0D,$0D,$00
:OLDM       ASC   '(Use OLD to recover any program)'
            DB    $0D,$0D,$00

