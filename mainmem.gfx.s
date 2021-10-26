* MAINMEM.GFX.S
* (c) Bobbi 2021 GPLv3
*
* Main memory HGR graphics routines.

* Call FDraw Clear routine
CLRHGR      >>>   ENTMAIN
            LDA   BGCOLOR
            STA   FDRAWADDR+5
            JSR   FDRAWADDR+16      ; FDRAW: SetColor
            JSR   FDRAWADDR+22      ; FDRAW: Clear
            LDA   FGCOLOR
            STA   FDRAWADDR+5
            JSR   FDRAWADDR+16      ; FDRAW: SetColor
            >>>   XF2AUX,VDU16RET

* Call FDraw SetLineMode routine
SETLINE     >>>   ENTMAIN
            JSR   FDRAWADDR+43      ; FDRAW: SetLineMode
            >>>   XF2AUX,VDU18RET1

* Helper function to set up colors
SETCOLOR    LDA   PLOTMODE
            AND   #$03
            CMP   #$01              ; Draw in foreground colour
            BNE   :S1
            LDA   FGCOLOR
            BRA   :SETCOLOR
:S1         CMP   #$02              ; Draw in inverse colour
            BNE   :S2
            SEC
            LDA   #$07
            SBC   FGCOLOR
            BRA   :SETCOLOR
:S2         LDA   BGCOLOR           ; Draw in background colour
:SETCOLOR   STA   FDRAWADDR+5
            JMP   FDRAWADDR+16      ; FDRAW: SetColor

* Call FDraw DrawLine routine
DRAWLINE    >>>   ENTMAIN
            JSR   SETCOLOR
            JSR   FDRAWADDR+28      ; FDRAW: DrawLine
            >>>   XF2AUX,VDU25RET

* Call FDraw DrawPoint routine
DRAWPNT     >>>   ENTMAIN
            JSR   SETCOLOR
            JSR   FDRAWADDR+25      ; FDRAW: DrawPoint
            >>>   XF2AUX,VDU25RET

* Call FDraw DrawCircle routine
DRAWCIRC    >>>   ENTMAIN
            JSR   SETCOLOR
            JSR   FDRAWADDR+37      ; FDRAW: DrawCircle
            >>>   XF2AUX,VDU25RET

* Call FDraw FillCircle routine
FILLCIRC    >>>   ENTMAIN
            JSR   SETCOLOR
            JSR   FDRAWADDR+40      ; FDRAW: FillCircle
            >>>   XF2AUX,VDU25RET

* Call FDraw FillRect routine
FILLRECT    >>>   ENTMAIN
            JSR   SETCOLOR
            LDA   FDRAWADDR+8       ; Y1
            CMP   FDRAWADDR+11      ; Y2
            BEQ   :S1
            BCS   :SWAPY            ; Y1>Y2 then swap
:S1         LDA   FDRAWADDR+7       ; MSB of X1
            CMP   FDRAWADDR+10      ; MSB of X2
            BEQ   :S2
            BCS   :SWAPX            ; MSB X1 > MSB X2
:S2         LDA   FDRAWADDR+6       ; LSB of X1
            CMP   FDRAWADDR+9       ; MSB of X2
            BEQ   :S3
            BCS   :SWAPX            ; LSB X1 > LSB X2
:S3         JSR   FDRAWADDR+34      ; FDRAW: FillRect
            >>>   XF2AUX,VDU25RET
:SWAPY      LDA   FDRAWADDR+8
            LDY   FDRAWADDR+11
            STY   FDRAWADDR+8
            STA   FDRAWADDR+11
            BRA   :S1
:SWAPX      LDA   FDRAWADDR+7
            LDY   FDRAWADDR+10
            STY   FDRAWADDR+7
            STA   FDRAWADDR+10
            LDA   FDRAWADDR+6
            LDY   FDRAWADDR+9
            STY   FDRAWADDR+6
            STA   FDRAWADDR+9
            BRA   :S3

* Reset colours and linetype
GFXINIT     JSR   FDRAWADDR+0       ; Initialize FDRAW library
            LDA   #$20
            STA   FDRAWADDR+5
            JSR   FDRAWADDR+19      ; FDRAW: Set page $2000
            STZ   LINETYPE
            STZ   FDRAWADDR+5
            JSR   FDRAWADDR+43      ; FDRAW: SetLineMode
            LDA   #$07
            STA   FGCOLOR
            STA   FDRAWADDR+5
            JSR   FDRAWADDR+16      ; FDRAW: SetColor
            STZ   BGCOLOR
            JSR   FDRAWADDR+22      ; FDRAW: clear HGR screen
            RTS

* Plot bitmap character on the HGR screen
* On entry: char is in A
DRAWCHAR    >>>   ENTMAIN
*            AND   #$7F ; Don't!
            STA   A1L               ; A*8 -> A1L,A1H
            STZ   A1H
            ASL   A1L
            ROL   A1H
            ASL   A1L
            ROL   A1H
            ASL   A1L
            ROL   A1H
            CLC                     ; FONTADDR+A*8 -> A1L,A1H
            LDA   A1L
            ADC   #<FONTADDR
            STA   A1L
            LDA   A1H
            ADC   #>FONTADDR
            STA   A1H
            LDA   HGRADDR+0         ; HGRADDR -> A4L,A4H
            STA   A4L
            LDA   HGRADDR+1
            STA   A4H
            LDY   #$00
:L1         LDA   (A1L),Y           ; Load line of pixels from font
            STA   (A4L)             ; Store them on screen
            INC   A4H               ; Skip 1024 bytes to next row
            INC   A4H
            INC   A4H
            INC   A4H
            INY
            CPY   #$08              ; All eight rows done?
            BNE   :L1
            >>>   XF2AUX,PUTCHRET

* Copy text line A+1 to line A 
HGRSCR1L    >>>   ENTMAIN
            ASL                     ; Dest addr->A4L,A4H
            TAX
            LDA   MHGRTAB,X
            STA   A4L
            LDA   MHGRTAB+1,X
            STA   A4H
            INX                     ; Source addr->A1L,A1H
            INX
            LDA   MHGRTAB,X
            STA   A1L
            LDA   MHGRTAB+1,X
            STA   A1H
            LDX   #$00
:L1         LDY   #$00
:L2         LDA   (A1L),Y
            STA   (A4L),Y
            INY
            CPY   #40               ; 40 chars in line
            BNE   :L2
            INC   A1H               ; Advance source 1024 bytes
            INC   A1H
            INC   A1H
            INC   A1H
            INC   A4H               ; Advance dest 1024 bytes
            INC   A4H
            INC   A4H
            INC   A4H
            INX
            CPX   #8                ; 8 pixel rows in character
            BNE   :L1
            >>>   XF2AUX,HSCR1RET

* Clear one text line on HGR screen
HCLRLINE    >>>   ENTMAIN
            LDA   HGRADDR+0         ; HGRADDR -> A4L,A4H
            STA   A4L
            LDA   HGRADDR+1
            STA   A4H
            LDA   #$00
            LDX   #$00
:L1         LDY   #$00
:L2         STA   (A4L),Y
            INY
*            CPY   #$39
            CPY   #40
            BNE   :L2
            INC   A4H
            INC   A4H
            INC   A4H
            INC   A4H
            INX
            CPX   #$08
            BNE   :L1
            >>>   XF2AUX,CLRLNRET

FGCOLOR     DB    $00               ; Foreground colour
BGCOLOR     DB    $00               ; Background colour
LINETYPE    DB    $00               ; 0 normal, 1 XOR
PLOTMODE    DB    $00               ; K value for PLOT K,X,Y
HGRADDR     DW    $0000             ; Address 1st line of HGR char

* Addresses of start of pixel rows in PAGE1
MHGRTAB     DW    $2000,$2080,$2100,$2180,$2200,$2280,$2300,$2380
            DW    $2028,$20A8,$2128,$21A8,$2228,$22A8,$2328,$23A8
            DW    $2050,$20D0,$2150,$21D0,$2250,$22D0,$2350,$23D0





















