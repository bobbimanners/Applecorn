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

* Call FDraw DrawLine routine
DRAWLINE    >>>   ENTMAIN
            LDA   PLOTMODE
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
            JSR   FDRAWADDR+16      ; FDRAW: SetColor
            JSR   FDRAWADDR+28      ; FDRAW: DrawLine
            >>>   XF2AUX,VDU25RET

* Call FDraw DrawPoint routine
DRAWPNT     >>>   ENTMAIN
            LDA   PLOTMODE
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
            JSR   FDRAWADDR+16      ; FDRAW: SetColor
            JSR   FDRAWADDR+25      ; FDRAW: DrawPoint
            >>>   XF2AUX,VDU25RET

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
            AND   #$7F
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

FGCOLOR     DB    $00               ; Foreground colour
BGCOLOR     DB    $00               ; Background colour
LINETYPE    DB    $00               ; 0 normal, 1 XOR
PLOTMODE    DB    $00               ; K value for PLOT K,X,Y
HGRADDR     DW    $0000             ; Address 1st line of HGR char










