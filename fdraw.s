********************************
*                              *
* Fast Apple II Graphics       *
* By Andy McFadden             *
* Version 0.3, Aug 2015        *
*                              *
* Main source file             *
*                              *
* Developed with Merlin-16     *
*                              *
********************************

* Set to 1 to build FDRAW.FAST, set to zero to
* build FDRAW.SMALL.
USE_FAST equ   1

* Set to 1 to turn on beeps/clicks for debugging.
NOISE_ON equ   0


         lst   off
**         org   $6000

*
* Macros.
*
spkr     equ   $c030
bell     equ   $ff3a

* If enabled, click the speaker (changes flags only).
CLICK    mac
         do    NOISE_ON
         bit   spkr
         fin
         <<<
* If enabled, beep the speaker (scrambles regs).
BEEP     mac
         do    NOISE_ON
         jsr   bell
         fin
         <<<
* If enabled, insert a BRK.
BREAK    mac
         do    NOISE_ON
         brk   $99
         fin
         <<<

* In "fast" mode, we align tables on page boundaries so we
* don't take a 1-cycle hit when the indexing crosses a page.
* In "small" mode, we skip the alignment.
PG_ALIGN mac
         do    USE_FAST
         ds    \
         fin
         <<<

*
* Hi-res screen constants.
*
BYTES_PER_ROW = 40
NUM_ROWS =     192
NUM_COLS =     280

*
* Variable storage.  We assign generic names to
* zero-page scratch locations, then assign variables
* with real names to these.
*
* 06-09 are unused (except by SWEET-16)
* 1a-1d are Applesoft hi-res scratch
* cc-cf are only used by INTBASIC
* eb-ef and ff appear totally unused by ROM routines
*
zptr0    equ   $1a        ;2b
zloc0    equ   $06
zloc1    equ   $07
zloc2    equ   $08
zloc3    equ   $09
zloc4    equ   $1c
zloc5    equ   $1d
zloc6    equ   $cc
zloc7    equ   $cd
zloc8    equ   $ce
zloc9    equ   $cf
zloc10   equ   $eb
zloc11   equ   $ec
zloc12   equ   $ed
zloc13   equ   $ee


********************************
*
* Entry points for external programs.
*
********************************
Entry
         jmp   Init       ;initialize data tables
         dfb   0,3        ;version number

*
* Parameters passed from external programs.
*
in_arg   ds    1          ;generic argument
in_x0l   ds    1          ;X coordinate 0, low part
in_x0h   ds    1          ;X coordinate 0, high part
in_y0    ds    1          ;Y coordinate 0
in_x1l   ds    1
in_x1h   ds    1
in_y1    ds    1
in_rad   ds    1          ;radius for circles

         ds    3          ;pad to 16 bytes

         jmp   SetColor
         jmp   SetPage
         jmp   Clear
         jmp   DrawPoint
         jmp   DrawLine
         jmp   DrawRect
         jmp   FillRect
         jmp   DrawCircle
         jmp   FillCircle
         jmp   SetLineMode
         jmp   noimpl     ;reserved2
         jmp   FillRaster

* Raster fill values.  Top, bottom, and pointers to tables
* for the benefit of external callers.
rast_top ds    1
rast_bottom ds 1
         da    rastx0l
         da    rastx0h
         da    rastx1l
         da    rastx1h

noimpl   rts


********************************
*
* Global variables.
*
********************************

g_inited dfb   0          ;initialized?
g_color  dfb   0          ;hi-res color (0-7)
g_page   dfb   $20        ;hi-res page ($20 or $40)


********************************
*
* Initialize.
*
********************************
Init
         lda   #$00
         sta   in_arg
         jsr   SetColor   ;set color to zero
         jsr   SetLineMode ;set normal lines
         lda   #$20
         sta   in_arg
         sta   g_inited
         jmp   SetPage    ;set hi-res page 1


********************************
*
* Set the color.
*
********************************
SetColor
         lda   in_arg
         cmp   g_color    ;same as the old color?
         beq   :done

         and   #$07       ;safety first
         sta   g_color

* Update the "colorline" table, which provides a quick color
* lookup for odd/even bytes.  We could also have one table
* per color and self-mod the "LDA addr,y" instructions to
* point to the current one, but that uses a bunch of memory
* and is kind of ugly.  Takes 16 + (12 * 40) = 496 cycles.
         tax              ;2
         lda   xormask,x  ;4
         sta   :_xormsk+1 ;4

         lda   oddcolor,x ;4
         ldy   #BYTES_PER_ROW-1 ;2
]loop    sta   colorline,y ;5
:_xormsk eor   #$00       ;2
         dey              ;2
         bpl   ]loop      ;3

:done    rts


********************************
*
* Set the page.
*
********************************
SetPage
         lda   g_inited   ;let's just check this
         beq   noinit     ; (not called too often)

         lda   in_arg
         cmp   #$20
         beq   :good
         cmp   #$40
         beq   :good
         jmp   bell
:good
         sta   g_page

         do    0          ;*****
         cmp   ylookhi
         beq   :tabok
* Check to see if the values currently in the Y-lookup table
* match our current page setting.  If they don't, we need to
* adjust the code that does lookups.

* This approach modifies the table itself, paying a large
* cost now so we don't have to pay it on every lookup.
* However, this costs 2+(16*192)=3074 cycles, while an
* "ORA imm" only adds two to each lookup, so we'd have
* to do a lot of drawing to make this worthwhile.
* (Note: assumes ylookhi is based at $2000 not $0000)
         ldy   #NUM_ROWS  ;2
]loop    lda   ylookhi-1,y ;4
         eor   #$60       ;2 $20 <--> $40
         sta   ylookhi-1,y ;5
         dey              ;2
         bne   ]loop      ;3

         else             ;*****

* This approach uses self-modifying code to update the
* relevant instructions.  It's a bit messy to have it
* here, but it saves us from having to do it on
* every call.
*
* We could also have a second y-lookup table and
* use this to update the pointers.  That would let
* us drop the "ORA imm" entirely, without the cost
* of the rewrite above, but eating up another 192 bytes.
         sta   _pg_or1+1  ;rastfill
         sta   _pg_or2+1  ;circle hplot
         sta   _pg_or3+1  ;circle hplot
         sta   _pg_or4+1  ;drawline
         sta   _pg_or5+1  ;drawline
         sta   _pg_or6+1  ;drawline
         sta   _pg_or7+1  ;drawline

         fin              ;*****

:tabok   rts

noinit   ldy   #$00
]loop    lda   :initmsg,y
         beq   :done
         jsr   $fded      ;cout
         iny
         bne   ]loop
:done    rts

:initmsg asc   "FDRAW NOT INITIALIZED",87,87,00


********************************
*
* Clear the screen to the current color.
*
********************************
Clear

         do    USE_FAST   ;*****
* This performs a "visually linear" clear, erasing the screen
* from left to right and top to bottom.  To reduce the amount
* of code required we erase in thirds (top/middle/bottom).
*
* Compare to a "venetian blind" clear, which is what you get
* if you erase memory linearly.
*
* The docs discuss different approaches.  This version
* requires ((2 + 5*64 + 11) * 40 + 14) * 3 = 40002 cycles.
* If we didn't divide it into thirds to keep the top-down
* look, we'd need (5*64 + 9) * 120 = 39480 cycles, so
* we're spending 522 cycles to avoid the venetian look.
         lda   :clrloop+2
         cmp   g_page
         beq   :pageok

* We're on the wrong hi-res page.  Flip to the other one.
* 4 + (20*64) = 1284 cycles to do the flip (+ a few more
* because we're probably crossing a page boundary).
         BEEP
         ldy   #NUM_ROWS  ;2
]loop    lda   :clrloop-3+2,y ;4
         eor   #$60       ;2
         sta   :clrloop-3+2,y ;5
         dey              ;2
         dey              ;2
         dey              ;2
         bne   ]loop      ;3

:pageok  ldx   g_color    ;grab the current color
         lda   xormask,x
         sta   :_xormsk+1
         lda   evencolor,x

         ldy   #0
         jsr   :clearthird
         ldy   #BYTES_PER_ROW
         jsr   :clearthird
         ldy   #BYTES_PER_ROW*2
* fall through into :clearthird for final pass

:clearthird
         ldx   #BYTES_PER_ROW-1 ;2
:clrloop sta   $2000,y    ;5 (* 64)
         sta   $2400,y    ;this could probably be
         sta   $2800,y    ; done with LUP math
         sta   $2c00,y
         sta   $3000,y
         sta   $3400,y
         sta   $3800,y
         sta   $3c00,y
         sta   $2080,y
         sta   $2480,y
         sta   $2880,y
         sta   $2c80,y
         sta   $3080,y
         sta   $3480,y
         sta   $3880,y
         sta   $3c80,y
         sta   $2100,y
         sta   $2500,y
         sta   $2900,y
         sta   $2d00,y
         sta   $3100,y
         sta   $3500,y
         sta   $3900,y
         sta   $3d00,y
         sta   $2180,y
         sta   $2580,y
         sta   $2980,y
         sta   $2d80,y
         sta   $3180,y
         sta   $3580,y
         sta   $3980,y
         sta   $3d80,y
         sta   $2200,y
         sta   $2600,y
         sta   $2a00,y
         sta   $2e00,y
         sta   $3200,y
         sta   $3600,y
         sta   $3a00,y
         sta   $3e00,y
         sta   $2280,y
         sta   $2680,y
         sta   $2a80,y
         sta   $2e80,y
         sta   $3280,y
         sta   $3680,y
         sta   $3a80,y
         sta   $3e80,y
         sta   $2300,y
         sta   $2700,y
         sta   $2b00,y
         sta   $2f00,y
         sta   $3300,y
         sta   $3700,y
         sta   $3b00,y
         sta   $3f00,y
         sta   $2380,y
         sta   $2780,y
         sta   $2b80,y
         sta   $2f80,y
         sta   $3380,y
         sta   $3780,y
         sta   $3b80,y
         sta   $3f80,y
:_xormsk eor   #$00       ;2 flip odd/even bits
         iny              ;2
         dex              ;2
         bmi   :done      ;2
         jmp   :clrloop   ;3
:done    rts

         else             ;***** not USE_FAST

* This version was suggested by Marcus Heuser on
* comp.sys.apple2.programmer.  It does a "venetian blind"
* clear, and takes (5 * 32 + 7) * 248 = 41416 cycles.
* It overwrites half of the screen holes.
         lda   :clrloop+5
         cmp   g_page
         beq   :pageok

* We're on the wrong hi-res page.  Flip to the other one.
* 12 + (20*31) = 632 cycles to do the flip.  We have to
* single out the first entry because it's $1f not $20.
         BEEP
         lda   :clrloop+2 ;4
         eor   #$20       ;2 $1f <-> $3f
         sta   :clrloop+2 ;4
         ldy   #31*3      ;2
]loop    lda   :clrloop+2,y ;4
         eor   #$60       ;2 $20 <-> $40
         sta   :clrloop+2,y ;5
         dey              ;2
         dey              ;2
         dey              ;2
         bne   ]loop      ;3

:pageok  ldx   g_color
         lda   xormask,x
         sta   :_xormsk+1
         lda   oddcolor,x
         ldy   #248       ;120 + 8 + 120
:clrloop
]addr    =     $1fff
         lup   32         ;begin a loop in assembler
         sta   ]addr,y    ;5
]addr    =     ]addr+$100 ;sta 20ff,21ff,...
         --^
:_xormsk eor   #$00       ;2
         dey              ;2
         bne   :clrloop   ;3
         rts

         fin              ;***** not USE_FAST


********************************
*
* Draw rectangle outline.
*
********************************
DrawRect
* We could just issue 4 line draw calls here, maybe
* adjusting the vertical lines by 1 pixel up/down to
* avoid overdraw.  But if the user wanted 4 lines,
* they could just draw 4 lines.  Instead, we're going
* to draw a double line on each edge to ensure that
* the outline rectangle always has the correct color.
*
* Rather than draw two vertical lines, we draw a
* two-pixel-wide filled rectangle on each side.
*
* We don't want to double-up if the rect is only one
* pixel wide, so we have to check for that.
*
* If the rect is one pixel high, it's just a line.
* If it's two pixels high, we don't need to draw
* the left/right edges, just the top/bottom lines.
* If it's more than two tall, we don't need to draw
* the left/right edges on the top and bottom lines,
* so we save a few cycles by skipping those.

         lda   in_y1      ;copy top/bottom to local
         sta   rast_bottom
         dec   rast_bottom ;move up one
         sec
         sbc   in_y0
         beq   :isline    ;1 pixel high, just draw line
         cmp   #1
         beq   :twolines  ;2 pixels high, lines only
         ldy   in_y0
         iny              ;start down a line
         sty   rast_top

         lda   in_x0h     ;check to see if left/right
         cmp   in_x1h     ; coords are the same; if
         bne   :notline   ; so, going +1/-1 at edge
         lda   in_x0l     ; will overdraw.
         cmp   in_x1l
         bne   :notlin1

:isline  jmp   DrawLine   ;just treat like line

* Set up left edge.  Top line is in Y.
:notline lda   in_x0l
:notlin1 sta   rastx0l,y
         clc
         adc   #1
         sta   rastx1l,y
         lda   in_x0h
         ora   #$80       ;"repeat" flag
         sta   rastx0h,y
         and   #$7f
         adc   #0
         sta   rastx1h,y
         jsr   FillRaster

         ldy   rast_top
         lda   in_x1l     ;now set up right edge
         sta   rastx1l,y
         sec
         sbc   #1
         sta   rastx0l,y
         lda   in_x1h
         sta   rastx1h,y
         sbc   #0
         ora   #$80       ;"repeat" flag
         sta   rastx0h,y
         jsr   FillRaster

* Now the top/bottom lines.
:twolines
         ldy   in_y0
         jsr   :drawline
         ldy   in_y1

:drawline
         sty   rast_top
         sty   rast_bottom
         lda   in_x0l     ;copy left/right to the
         sta   rastx0l,y  ; table entry for the
         lda   in_x0h     ; appropriate line
         sta   rastx0h,y
         lda   in_x1l
         sta   rastx1l,y
         lda   in_x1h
         sta   rastx1h,y
         jmp   FillRaster


********************************
*
* Draw filled rectangle.
*
********************************
FillRect
* Just fill out the raster table and call the fill routine.
* We require y0=top, y1=bottom, x0=left, x1=right.
         ldy   in_y0
         sty   rast_top
         lda   in_y1
         sta   rast_bottom

         lda   in_x0l
         sta   rastx0l,y
         lda   in_x0h
         ora   #$80       ;"repeat" flag
         sta   rastx0h,y
         lda   in_x1l
         sta   rastx1l,y
         lda   in_x1h
         sta   rastx1h,y

         jmp   FillRaster


********************************
*
* Fill an area defined by the raster tables.
*
********************************
FillRaster

* Render rasterized output.  The left and right edges
* are stored in the rastx0/rastx1 tables, and the top
* and bottom-most pixels are in rast_top/rast_bottom.
*
* This can be used to render an arbitrary convex
* polygon after it has been rasterized.
*
* If the high bit of the high byte of X0 is set, we
* go into "repeat" mode, where we just repeat the
* previous line.  This saves about 40 cycles of
* overhead per line when drawing rectangles, plus
* what we would have to spend to populate multiple
* lines of the raster table.  It only increases the
* general per-line cost by 3 cycles.
*
* We could use the "repeat" flag to use this code to
* draw vertical lines, though that's mostly of value
* to an external caller who knows ahead of time that
* the line is vertical.  The DrawLine code is pretty
* good with vertical lines, and adding additional
* setup time to every vertical-dominant line to
* decide if it should call here seems like a
* losing proposition.

]hbasl   equ   zptr0
]hbash   equ   zptr0+1
]lftbyte equ   zloc0
]lftbit  equ   zloc1
]rgtbyte equ   zloc2
]rgtbit  equ   zloc3
]line    equ   zloc4
]andmask equ   zloc5
]cur_line equ  zloc6
]repting equ   zloc7

         ldx   g_color    ;configure color XOR byte
         lda   xormask,x
         do    USE_FAST   ;*****
         cmp   rast_unroll+3 ;already configured?
         beq   :goodmask
         jsr   fixrastxor
:goodmask
         else
         sta   _xorcolor+1
         fin              ;*****

         lda   #$00
         sta   ]repting

         ldy   rast_top

* Main rasterization loop.  Y holds the line number.
rastloop
         sty   ]cur_line  ;3
         ldx   ylooklo,y  ;4
         stx   ]hbasl     ;3
         lda   ylookhi,y  ;4
_pg_or1  ora   #$20       ;2 will be $20 or $40
         sta   ]hbash     ;3 = 19 cycles
         do    USE_FAST-1 ;***** i.e. not USE_FAST
         stx   _wrhires+1
         sta   _wrhires+2
         fin              ;*****

* divide left edge by 7
         ldx   rastx0l,y  ;4 line num in Y
         lda   rastx0h,y  ;4
         bpl   :noflag    ;2
         sta   rastx0h+1,y ;4 propagate
         lda   ]repting   ;3 first time through?
         beq   :firstre   ;2 yup, finish calculations
         lda   ]rgtbyte   ;3 need this in A
         bpl   :repeat    ;3 always
:firstre lda   rastx0h,y  ;reload
         sta   ]repting   ;any nonzero will do
         and   #$7f       ;strip repeat flag
:noflag  beq   :lotabl
         lda   mod7hi,x
         sta   ]lftbit
         lda   div7hi,x
         sta   ]lftbyte
         bpl   :gotlft    ;always
         BREAK            ;debug
:lotabl  lda   mod7lo,x
         sta   ]lftbit
         lda   div7lo,x
         sta   ]lftbyte
:gotlft

* divide right edge by 7
         ldx   rastx1l,y  ;4 line num in Y
         lda   rastx1h,y  ;4
         beq   :lotabr    ;3
         lda   mod7hi,x
         sta   ]rgtbit
         lda   div7hi,x
         sta   ]rgtbyte
         bpl   :gotrgt    ;always
         BREAK            ;debug
:lotabr  lda   mod7lo,x   ;4
         sta   ]rgtbit    ;3
         lda   div7lo,x   ;4
         sta   ]rgtbyte   ;3 = 25 for X1 < 256
:gotrgt

:repeat
         cmp   ]lftbyte   ;3
         bne   :not1byte  ;3

* The left and right edges are in the same byte.  We
* need to set up the mask differently, so we deal with
* it as a special case.
         ldy   ]lftbit
         lda   leftmask,y ;create the AND mask
         ldx   ]rgtbit
         and   rightmask,x ;strip out bits on right
         sta   ]andmask

         ldy   ]lftbyte
         lda   colorline,y ;get color bits
         eor   (]hbasl),y ;combine w/screen
         and   ]andmask   ;remove not-ours
         eor   (]hbasl),y ;combine again
         sta   (]hbasl),y
         jmp   rastlinedone

* This is the more general case.  We special-case the
* left and right edges, then byte-stomp the middle.
* On entry, ]rgtbyte is in A
:not1byte
         sec              ;2 compute number of full
         sbc   ]lftbyte   ;3  and partial bytes to
         tax              ;2  draw
         inx              ;2

         ldy   ]rgtbit    ;3
         cpy   #6         ;2
         beq   :rgtnospcl ;3
         lda   rightmask,y ;handle partial-byte right
         sta   ]andmask
         ldy   ]rgtbyte
         lda   colorline,y
         eor   (]hbasl),y
         and   ]andmask
         eor   (]hbasl),y
         sta   (]hbasl),y
         dex              ;adjust count
:rgtnospcl

         ldy   ]lftbit    ;3 check left for partial
         beq   :lftnospcl ;3
         lda   leftmask,y ;handle partial-byte left
         sta   ]andmask
         ldy   ]lftbyte
         lda   colorline,y
         eor   (]hbasl),y
         and   ]andmask
         eor   (]hbasl),y
         sta   (]hbasl),y
         dex              ;adjust count
         beq   rastlinedone ;bail if all done
         iny              ;advance start position
         bne   :liny      ;always
         BREAK
:lftnospcl

         ldy   ]lftbyte   ;3
:liny

         do    USE_FAST   ;***** "fast" loop
* Instead of looping, jump into an unrolled loop.
* Cost is 10 cycles per byte with an extra 14 cycles
* of overhead, so we start to win at 4 bytes.
         lda   rastunidx,x ;4
         sta   :_rastun+1 ;4
         lda   colorline,y ;4 get odd/even color val
:_rastun jmp   rast_unroll ;3

         else             ;***** "slow" loop
* Inner loop of the renderer.  This runs 0-40x.
* Cost is 14 cycles/byte.
         lda   colorline,y ;get appropriate odd/even val
_wrhires sta   $2000,y    ;5 replaced with line addr
_xorcolor eor  #$00       ;2 replaced with $00/$7f
         iny              ;2
         dex              ;2
         bne   _wrhires   ;3

         fin              ;*****

rastlinedone
         ldy   ]cur_line  ;3 more lines to go?
         cpy   rast_bottom ;4
         bge   :done      ;2
         iny              ;2
         jmp   rastloop   ;3 must have line in Y

:done    rts

fixrastxor
         do    USE_FAST   ;*****
* Update the EOR statements in the unrolled rastfill code.
* Doing this with a loop takes ~600 cycles, doing it with
* unrolled stores takes 160.  We only do this when we
* need to, so changing the color from green to blue won't
* cause this to run.
*
* Call with the XOR value in A.
]offset  =     0
         lup   BYTES_PER_ROW
         sta   rast_unroll+3+]offset
]offset  =     ]offset+5
         --^
         BEEP
         rts
         fin              ;*****


* include the line functions
**         put   FDRAW.LINE

* include the circle functions
**         put   FDRAW.CIRCLE

         lst   on
CODE_END equ   *          ;end of code section
         lst   off

* include the data tables
**         put   FDRAW.TABLES

         lst   on
DAT_END  equ   *          ;end of data / BSS
         lst   off

* Save the appropriate object file.
**         do    USE_FAST
**         sav   FDRAW.FAST
**         else
**         sav   FDRAW.SMALL
**         fin
