* AUXMEM.GFX.S
* (c) Bobbi 2021 GPLv3
*
* Graphics operations
*
* 26-Sep-2021 All graphics screen code moved to here.
* 02-Oct-2021 Added temp'y wrapper to HGRPLOT.


* Write character to HGR screen
PRCHRSOFT    CMP   #$A0              ; Convert to screen code
             BCS   :B0
             CMP   #$80
             BCC   :B0
             EOR   #$80
:B0          TAX
             AND   #$20
             BNE   :B1
             TXA
             EOR   #$40
             TAX
:B1          PHX
             JSR   HCHARADDR         ; Addr in VDUADDR
             PHP                     ; Disable IRQs while
             SEI                     ;  toggling memory
             STA   $C004             ; Write to main
             LDA   VDUADDR+0
             STA   HGRADDR+0
             LDA   VDUADDR+1
             STA   HGRADDR+1
             STA   $C005             ; Write to aux
             PLP                     ; Restore IRQs
             PLA                     ; Recover character
             >>>   XF2MAIN,DRAWCHAR  ; Plot char on HGR screen
PUTCHRET     >>>   ENTAUX
             RTS

HSCR1LINE    >>>   XF2MAIN,HGRSCR1L
HSCR1RET     >>>   ENTAUX
             RTS

HSCRCLREOL   LDA   VDUTEXTY
             ASL
             TAX
             >>>   WRTMAIN
             LDA   HGRTAB+0,X
             STA   HGRADDR+0
             LDA   HGRTAB+1,X
             STA   HGRADDR+1
             >>>   WRTAUX
             >>>   XF2MAIN,HCLRLINE

HSCRCLEAR    >>>   XF2MAIN,CLRHGR
VDU16RET     >>>   ENTAUX
             STZ   XPIXEL+0
             STZ   XPIXEL+1
             LDA   #191
             STA   YPIXEL
             RTS
CLRLNRET     >>>   ENTAUX
             RTS


* A=txt colour
HSCRSETTCOL  RTS


* A=gfx colour, X=gcol action
* GCOL actions:
*  0 = SET pixel
*  1 = ORA with pixel
*  2 = AND with pixel
*  3 = XOR with pixel
*  4 = NOT pixel
*  5 = NUL no change to pixel
*  6 = CLR clear pixel to background
*  7 = UND undefined
HSCRSETGCOL  PHA
             LDA   #$00              ; Normal drawing mode
             CPX   #$04              ; k=4 means toggle
             BNE   :NORM
             LDA   #$01              ; Change to toggle mode
:NORM        >>>   WRTMAIN
             STA   LINETYPE
             STA   FDRAWADDR+5
             >>>   WRTAUX
             >>>   XF2MAIN,SETLINE
VDU18RET1    >>>   ENTAUX
:NORM        PLA                     ; Colour
             BPL   :FOREGND          ; <128 is foreground
             >>>   WRTMAIN
             AND   #$7F
             STA   BGCOLOR           ; Stored in main memory
             >>>   WRTAUX
             RTS
:FOREGND     >>>   WRTMAIN
             STA   FGCOLOR           ; Stored in main memory
             >>>   WRTAUX
             RTS

* TEMP *
HGRPLOTTER   LDX   #3
HGRPLOTTER1  LDA   VDUQ+5,X
             PHA
             DEX
             BPL   HGRPLOTTER1
             JSR   HGRPLOT
             LDX   #0
HGRPLOTTER2  LDA   VDUQ+5,X
             STA   PIXELPLOTX,X
             PLA
             STA   VDUQ+5,X
             INX
             CPX   #4
             BCC   HGRPLOTTER2
             RTS
* TEMP *

* Plot actions, PLOT k,x,y
* k is in VDUQ+4
* x is in VDUQ+5,VDUQ+6
* y is in VDUQ+7,VDUQ+8
*
* Plot actions capable with FastDraw:
*  $00+x - move/draw lines
*  $40+x - plot point
*  $50+x - fill triangle
*  $60+x - fill rectangle
*  $90+x - draw circle
*  $98+x - fill circle
*
HGRPLOT      JSR   CVTCOORD          ; Convert coordinate system
HGRPLOT2     LDA   VDUQ+4
             AND   #$04              ; Bit 2 set -> absolute
             BNE   HGRPLOTABS
             JSR   RELCOORD          ; Add coords to XPIXEL/YPIXEL
HGRPLOTABS   LDA   VDUQ+4
             AND   #$03
             CMP   #$0               ; Bits 0,1 clear -> just move
             BNE   HGRPLOTACT
HGRPLOTPOS   JMP   HGRPOS            ; Just update pos
HGRPLOTACT   LDA   VDUQ+4
             AND   #$F0
             CMP   #$00
             BEQ   :LINE
             CMP   #$40
             BEQ   :POINT
             CMP   #$60
             BNE   :S1
             JMP   :RECT
:S1          CMP   #$90
             BNE   :UNDEF
             JMP   :CIRC
:UNDEF       RTS
:POINT       >>>   WRTMAIN
             LDA   VDUQ+4
             STA   PLOTMODE
             LDA   VDUQ+5
             STA   FDRAWADDR+6       ; LSB of X1
             LDA   VDUQ+6
             STA   FDRAWADDR+7       ; MSB of X1
             LDA   VDUQ+7
             STA   FDRAWADDR+8       ; Y1
             >>>   WRTAUX
             >>>   XF2MAIN,DRAWPNT
:LINE        >>>   WRTMAIN
             LDA   VDUQ+4
             STA   PLOTMODE
             LDA   XPIXEL+0
             STA   FDRAWADDR+6       ; LSB of X1
             LDA   XPIXEL+1
             STA   FDRAWADDR+7       ; MSB of X1
             LDA   YPIXEL
             STA   FDRAWADDR+8       ; Y1
             LDA   VDUQ+5
             STA   FDRAWADDR+9       ; LSB of X2
             LDA   VDUQ+6
             STA   FDRAWADDR+10      ; MSB of X2
             LDA   VDUQ+7
             STA   FDRAWADDR+11      ; Y2
             >>>   WRTAUX
             >>>   XF2MAIN,DRAWLINE
:RECT        >>>   WRTMAIN
             LDA   VDUQ+4
             STA   PLOTMODE
             LDA   XPIXEL+0
             STA   FDRAWADDR+6       ; LSB of X1
             LDA   XPIXEL+1
             STA   FDRAWADDR+7       ; MSB of X1
             LDA   YPIXEL
             STA   FDRAWADDR+8       ; Y1
             LDA   VDUQ+5
             STA   FDRAWADDR+9       ; LSB of X2
             LDA   VDUQ+6
             STA   FDRAWADDR+10      ; MSB of X2
             LDA   VDUQ+7
             STA   FDRAWADDR+11      ; Y2
             >>>   WRTAUX
             >>>   XF2MAIN,FILLRECT
:CIRC        >>>   WRTMAIN
             LDA   XPIXEL+0
             STA   FDRAWADDR+6
             LDA   XPIXEL+1
             STA   FDRAWADDR+7
             LDA   YPIXEL
             STA   FDRAWADDR+8
             LDA   VDUQ+5
             STA   FDRAWADDR+12      ; Radius
             LDA   VDUQ+4
             STA   PLOTMODE
             >>>   WRTAUX
             AND   #$F8
             CMP   #$98
             BEQ   :FILLCIRC
             >>>   XF2MAIN,DRAWCIRC
:FILLCIRC    >>>   XF2MAIN,FILLCIRC
VDU25RET     >>>   ENTAUX
* Fall through into HGRPOS
* Save pixel X,Y position
HGRPOS       LDA   VDUQ+5
             STA   XPIXEL+0
             LDA   VDUQ+6
             STA   XPIXEL+1
             LDA   VDUQ+7
             STA   YPIXEL
             RTS
XPIXEL       DW    $0000             ; Previous plot x-coord
YPIXEL       DW    $0000             ; Previous plot y-coord

* Convert high-resolution screen coordinates
* from 1280x1024 to 280x192
CVTCOORD
* X-coordinate in VDUQ+5,+6   1280*7/32=280
             LDA   VDUQ+6            ; MSB of X-coord
             CMP   #$05              ; $500 is 1280
             BCS   :BIGX             ; Value >=1280
             STA   ZP1+1             ; X-coord -> ZP1 and ZP2
             STA   ZP2+1
             LDA   VDUQ+5
             STA   ZP1+0
             ASL   A                 ; ZP2 *= 8
             ROL   ZP2+1
             ASL   A
             ROL   ZP2+1
             ASL   A
             ROL   ZP2+1
             SEC                     ; ZP2-ZP1->ZP2
             SBC   ZP1+0
             STA   ZP2+0
             LDA   ZP2+1
             SBC   ZP1+1
             LSR   A                 ; ZP2 /= 32
             ROR   ZP2+0
             LSR   A
             ROR   ZP2+0
             LSR   A
             ROR   ZP2+0
             LSR   A
             ROR   ZP2+0
             LSR   A
             ROR   ZP2+0
             STA   VDUQ+6            ; ZP2 -> X-coord
             LDA   ZP2+0
             STA   VDUQ+5

* Y-coordinate in VDUQ+7,+8   1024*3/16=192
:YCOORD      LDA   VDUQ+8            ; MSB of Y-coord
             AND   #$FC
             BNE   :BIGY             ; Y>1023
             LDA   VDUQ+8            ; Y-coord -> ZP1
             STA   ZP1+1
             STA   ZP2+1
             LDA   VDUQ+7
             STA   ZP1+0
*             STA   ZP2+0
*             LDA   VDUQ+8
*             JMP   :YCOORD4
             ASL   A                 ; ZP2 *= 2
             ROL   ZP2+1
             CLC                     ; ZP2+ZP1->ZP2
             ADC   ZP1+0
             STA   ZP2+0
             LDA   ZP2+1
             ADC   ZP1+1
             LSR   A                 ; ZP2 /= 16
             ROR   ZP2+0
             LSR   A
             ROR   ZP2+0
:YCOORD4     LSR   A
             ROR   ZP2+0
             LSR   A
             ROR   ZP2+0
             STZ   VDUQ+8            ; MSB always zero
             SEC
             LDA   #191              ; 191 - ZP2 -> Y-coord
             SBC   ZP2+0
             STA   VDUQ+7
             CMP   #192
             BCS   :BIGY
             RTS
:BIGY        STZ   VDUQ+7            ; Y too large, row zero
             STZ   VDUQ+8
             RTS
:BIGX        LDA   #$17              ; X too large, use 279
             STA   VDUQ+5
             LDA   #$01
             STA   VDUQ+6
             BRA   :YCOORD

* Add coordinates to XPIXEL, YPIXEL
RELCOORD     CLC
             LDA   XPIXEL+0
             ADC   VDUQ+5
             STA   VDUQ+5
             LDA   XPIXEL+1
             ADC   VDUQ+6
             STA   VDUQ+6
             CLC
             LDA   YPIXEL
             ADC   VDUQ+7
             STA   VDUQ+7
             RTS









