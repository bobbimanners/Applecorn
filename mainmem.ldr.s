* MAINMEM.LDR.S
* (c) Bobbi 2021 GPLv3
*
* Applecorn loader code.  Runs in main memory.
* 01-Oct-2021 Copies MOS code to whole $D000-$FFFF.
* 13-Nov-2021 LOADCODE uses absolute path to Applecorn directory.


* Loads Acorn ROM file (16KB) from disk and writes it
* to aux memory starting at $08000. Copies Applecorn MOS
* to aux memory starting at AUXMOS1 and jumps to it.
* (Note that the MOS code will copy itself to $D000.)

SYSTEM      LDX   #$FF             ; Init stack pointer
            TXS

            LDA   #$00
            STA   IBAKVER          ; Minimum compatible P8 version
            LDA   #$01
            STA   IVERSION         ; Version of .SYSTEM program

            SED                    ; Check for 65C02
            LDA   #$99
            CLC
            ADC   #$01
            CLD
            BPL   GOODCPU
            JMP   UNSUPPORTED

GOODCPU     LDA   MACHID
            AND   #$F2             ; Clear bits 0,2,3
            CMP   #$B2             ; Are we on a //e or //c w/ 80col and 128K or a IIgs?
            BEQ   SUPPORTED        ; Supported machine
            JMP   UNSUPPORTED      ; Unsupported machine

SUPPORTED   LDA   #$DF             ; Protect pages $0,$1,and $3-$7
            STA   P8BMAP0007
            LDA   #$F0             ; Protect pages $8-$B
            STA   P8BMAP080F
            LDA   #$FF             ; Protect HGR1
            STA   P8BMAP2027
            STA   P8BMAP282F
            STA   P8BMAP3037
            STA   P8BMAP383F

* Set prefix if not already set
SETPRFX     LDA   #GPFXCMD
            STA   :OPC7             ; Initialize cmd byte to $C7
:L1         JSR   MLI
:OPC7        DB   $00
             DW   GSPFXPL
            LDX   DRVBUF1           ; was $0300
            BNE   RTSINST
            LDA   DEVNUM
            STA   ONLNPL+1          ; Device number
            JSR   MLI
             DB   ONLNCMD
             DW   ONLNPL
            LDA   DRVBUF2           ; was $0301
            AND   #$0F
            TAX
            INX
            STX   DRVBUF1           ; was $0300
            LDA   #'/'
            STA   DRVBUF2           ; was $0301
            DEC   :OPC7
            BNE   :L1
RTSINST     LDA   CMDPATH
            BEQ   :GETPFX           ; CMDPATH empty
            LDA   CMDPATH+1
            CMP   #'/'
            BEQ   DISCONN           ; CMDPATH already absolute path
:GETPFX     JSR   MLI
             DB   GPFXCMD           ; Get Prefix
             DW   GETPFXPARM

* Disconnect /RAM ramdrive to avoid aux corruption
* Stolen from Beagle Bros Extra K
DISCONN     LDA   MACHID
            AND   #$30
            CMP   #$30
            BNE   :S1
            LDA   DEVADR32
            CMP   DEVADR01
            BNE   :S2
            LDA   DEVADR32+1
            CMP   DEVADR01+1
            BEQ   :S1
:S2         LDY   DEVCNT
:L1         LDA   DEVLST,Y
            AND   #$F3
            CMP   #$B3
            BEQ   :S3
            DEY
            BPL   :L1
            BMI   :S1
:S3         LDA   DEVLST,Y
            STA   DRVBUF2+1         ; was $0302
:L2         LDA   DEVLST+1,Y
            STA   DEVLST,Y
            BEQ   :S4
            INY
            BNE   :L2
:S4         LDA   DEVADR32
            STA   DRVBUF1           ; was $0300
            LDA   DEVADR32+1
            STA   DRVBUF2           ; was $0301
            LDA   DEVADR01
            STA   DEVADR32
            LDA   DEVADR01+1
            STA   DEVADR32+1
            DEC   DEVCNT
:S1
*            JSR   ENSQINIT          ; INITIALIZE ENSONIQ
            JSR   ROMMENU           ; This really needs to happen elsewhere

            LDA   #<:FDFILE
            STA   OPENPL+1
            LDA   #>:FDFILE
            STA   OPENPL+2
            LDA   #>FDRAWADDR      ; Address in main
            LDX   #<FDRAWADDR
            CLC                    ; Load into main
            JSR   LOADCODE

            LDA   #<:FNTFILE
            STA   OPENPL+1
            LDA   #>:FNTFILE
            STA   OPENPL+2
            LDA   #>FONTADDR       ; Address in main
            LDX   #<FONTADDR
            CLC                    ; Load into main
            JSR   LOADCODE

            LDA   #<MOSSHIM        ; Start address of MOS shim
            STA   A1L
            LDA   #>MOSSHIM
            STA   A1H

            LDA   #<MOSSHIM+$3000  ; End address of MOS shim
            STA   A2L
            LDA   #>MOSSHIM+$3000
            STA   A2H

            LDA   #<AUXMOS1        ; To AUXMOS1 in aux memory
            STA   A4L
            LDA   #>AUXMOS1
            STA   A4H

            SEC                    ; Copy MOS from Main->Aux
            JSR   AUXMOVE

            LDA   #<RESET          ; Set reset vector->RESET
            STA   RSTV
            LDA   #>RESET
            STA   RSTV+1
            EOR   #$A5             ; Checksum
            STA   PWRDUP

            LDA   #<GSBRK          ; Set BREAK vector in main mem
            STA   BREAKV
            LDA   #>GSBRK
            STA   BREAKV+1

            JSR   GFXINIT          ; Initialize FDraw graphics

            TSX                    ; Save SP at $0100 in aux
            >>>   ALTZP
            STX   $0100
            >>>   MAINZP
            >>>   XF2AUX,AUXMOS1

* Filenames for loaded binaries - we're gonna address these later

:FDFILE     STR   "FDRAW.FAST"     ; Filename for FDraw lib
:FNTFILE    STR   "FONT.DAT"       ; Filename for bitmap font

GETPFXPARM  HEX   01                ; One parameter
            DW    CMDPATH           ; Get prefix to CMDPATH

UNSUPPORTED JSR   HOME
            LDX   #$00
UNSUPLP     LDA   UNSUPMSG,X
            BEQ   UNSUPWAIT
            JSR   COUT1
            INX
            BNE   UNSUPLP
UNSUPWAIT   STA   KBDSTRB
UNSUPKEY    LDA   KEYBOARD
            BPL   UNSUPKEY
            STA   KBDSTRB

            JSR   MLI
             DB   QUITCMD
             DW   UNSUPQPARM
UNSUPQPARM  DB    $04,$00,$00,$00,$00,$00,$00

UNSUPMSG    ASC   "APPLECORN REQUIRES AN APPLE IIGS, APPLE", 8D
            ASC   "//C, OR ENHANCED APPLE //E WITH AN", 8D
            ASC   "80-COLUMN CARD AND AT LEAST 128K", 8D, 8D
            ASC   "PRESS ANY KEY TO QUIT TO PRODOS", 00

ENDSYSTEM
