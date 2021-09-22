********************************
*                              *
* Fast Apple II Graphics       *
* By Andy McFadden             *
* Version 0.3, Aug 2015        *
*                              *
* Circle rendering             *
* (Included by FDRAW.S)        *
*                              *
* Developed with Merlin-16     *
*                              *
********************************

* TODO: if USE_FAST is 0, replace the outline circle
*  plot code with calls to DrawPoint (or maybe a
*  common sub-function so we don't trash the input
*  parameters).  Saves a little space.


********************************
*
* Draw a circle.  The radius is in in_rad, and
* the center is at in_x0l+in_x0h,in_y0.
*
********************************
DrawCircle
         lda   #$20       ;JSR
         cmp   _cp08      ;configured for outline?
         beq   :okay
         jsr   fixcplot
:okay
         jmp   calc_circle


********************************
*
* Draw filled circle.
*
********************************
FillCircle
         lda   #$2c       ;BIT
         cmp   _cp08      ;configured for fill?
         beq   :okay
         jsr   fixcplot
:okay
         jsr   calc_circle
         jmp   FillRaster


* Calculate a circle, using Bresenham's algorithm.  The
* results are placed into the rasterization buffers.
*
* in_rad must be from 0 to 255.  The x/y center
* coordinates must be on the screen, but the circle
* can extend off the edge.
*
* The computed values are stored in the rasterization
* tables.  For an outline circle, we also plot the
* points immediately.

         do    USE_FAST   ;*****
* local storage -- not used often enough to merit DP
circ_8bit ds   1
circ_clip ds   1
         fin              ;*****

calc_circle
max_fast_rad equ 41
]cxl     equ   zloc0
]cxh     equ   zloc1
]cy      equ   zloc2
]dlo     equ   zloc3
]dhi     equ   zloc4
]xsav    equ   zloc5
]ysav    equ   zloc6
]min_x   equ   zloc7      ;min/max offsets from center
]max_x   equ   zloc8      ;(min is above center, max
]min_y   equ   zloc9      ; is below)
]max_y   equ   zloc10
]hitmp   equ   zloc11
* only used by hplot for outline circles
]hbasl   equ   zptr0
]andmask equ   zloc11     ;overlaps with ]hitmp
]savxreg equ   zloc12
]savyreg equ   zloc13

* Special-case radius=0.  It removes an annoying
* edge case (first y-- becomes 0xff, but 6502 cmp
* is unsigned).
         lda   in_rad
         bne   :notzero
         ldy   in_y0
         sty   rast_top
         sty   rast_bottom
         lda   in_x0l
         sta   rastx0l,y
         sta   rastx1l,y
         lda   in_x0h
         sta   rastx0h,y
         sta   rastx1h,y
         rts

* Use different version of function for small
* circles, because we can do it all in 8 bits.
:notzero
         do    USE_FAST   ;*****
         ldy   #$01
         cmp   #max_fast_rad ;in_rad in Acc
         blt   :use_fast
         dey
:use_fast sty  circ_8bit
         fin              ;*****

         lda   in_x0l     ;copy center to DP for speed
         sta   ]cxl
         lda   in_x0h
         sta   ]cxh
         lda   in_y0
         sta   ]cy

* Compute min/max values, based on offset from center.
* These are compared against offset-from-center x/y.
* We need tight bounds on Y because we use it to
* compute the rast_render top/bottom.  Getting tight
* bounds on X is not so important, but we still need
* it for the no-clip optimization.
         ldx   #$04       ;count edges needing clip

         lda   #NUM_ROWS-1 ;191
         sec
         sbc   ]cy        ;maxY = 191-cy
         cmp   in_rad
         blt   :ylimok
         lda   in_rad     ;clamp to radius
         dex
:ylimok  sta   ]max_y     ;maxY = 191-cy

         lda   ]cy        ;minY = cy
         cmp   in_rad
         blt   :ylimok2
         lda   in_rad     ;clamp to radius
         dex
:ylimok2 sta   ]min_y

         lda   ]cxh
         beq   :xlimlo
* Examples (note #<NUM_COLS-1 is 279-256 = 23):
* cx=265 (cxh=1 cxl=11), 23-11=14, chk rad
         lda   #<NUM_COLS-1 ;maxX = 279-cx
         sec
         sbc   ]cxl
         cmp   in_rad
         blt   :xlimhok
         lda   in_rad     ;clamp to radius
         dex
:xlimhok sta   ]max_x

         lda   in_rad     ;min X always out of range
         dex              ; so just clamp to radius
         sta   ]min_x
         jmp   :xlimdone

* Examples:
* For cx=0 to 24, we can never pass right edge (our
*  maximum radius is 255).
* cx=3, 23-3=20 + carry set --> bad, must use rad
* cx=24, 23-24=255 + carry clear --> ok, chk rad
* cx=255, 23-255=24 + carry clear --> ok, chk rad
:xlimlo
         lda   #<NUM_COLS-1 ;maxX = 279-cx
         sec
         sbc   ]cxl
         bcs   :xuserad
         cmp   in_rad
         blt   :xlimok
:xuserad lda   in_rad     ;clamp to radius
         dex
:xlimok  sta   ]max_x

         lda   ]cxl       ;minX = (cx > 255) ?
         cmp   in_rad
         blt   :xlimok2
         lda   in_rad     ;clamp to radius
         dex
:xlimok2 sta   ]min_x

:xlimdone

         do    USE_FAST   ;*****
         stx   circ_clip
         fin              ;*****

* set top/bottom rows for rasterizer
         lda   ]cy
         clc
         adc   ]max_y
         sta   rast_bottom
         lda   ]cy
         sec
         sbc   ]min_y
         sta   rast_top

         DO    0          ;debug debug debug
         LDA   ]min_x     ;save a copy where the
         STA   $0380      ; monitor won't trash it
         LDA   ]max_x
         STA   $0381
         LDA   ]min_y
         STA   $0382
         LDA   ]max_y
         STA   $0383
         FIN

* Set initial conditions for Bresenham.
         ldx   #0         ;:x = 0
         stx   ]xsav
         ldy   in_rad     ;:y = rad
         sty   ]ysav
         lda   #1         ;:d = 1 - rad
         sec
         sbc   ]ysav      ;in_rad
         sta   ]dlo
         bcs   :hizero    ;C==1 if in_rad<=1
         ldx   #$ff       ;C was 0, make neg
:hizero  stx   ]dhi

*
* Outer loop -- plot 8 points, then update values.
*
circ_loop

         do    USE_FAST   ;*****
         lda   circ_clip
         beq   ncypy
         jmp   with_clip

* Quick version, no clipping required
* row cy+y: cx-x and cx+x
ncypy
         lda   ]ysav
         clc
         adc   ]cy
         tay              ;y-coord in Y-reg

         lda   ]cxl
         sec
         sbc   ]xsav
         sta   rastx0l,y
         lda   ]cxh
         sbc   #$00
         sta   rastx0h,y
_cp00    jsr   cplotl

         lda   ]cxl
         clc
         adc   ]xsav
         sta   rastx1l,y
         lda   ]cxh
         adc   #$00
         sta   rastx1h,y
_cp01    jsr   cplotrn

* row cy-y: cx-x and cx+x
ncymy
         lda   ]cy
         sec
         sbc   ]ysav
         tay              ;y-coord in Y-reg

         lda   ]cxl
         sec
         sbc   ]xsav
         sta   rastx0l,y
         lda   ]cxh
         sbc   #$00
         sta   rastx0h,y
_cp02    jsr   cplotl

         lda   ]cxl
         clc
         adc   ]xsav
         sta   rastx1l,y
         lda   ]cxh
         adc   #$00
         sta   rastx1h,y
_cp03    jsr   cplotrn

* row cy+x: cx-y and cx+y
ncypx
         lda   ]xsav      ;off bottom?
         clc
         adc   ]cy
         tay              ;y-coord in Y-reg

         lda   ]cxl
         sec
         sbc   ]ysav
         sta   rastx0l,y
         lda   ]cxh
         sbc   #$00
         sta   rastx0h,y
_cp04    jsr   cplotl

         lda   ]cxl
         clc
         adc   ]ysav
         sta   rastx1l,y
         lda   ]cxh
         adc   #$00
         sta   rastx1h,y
_cp05    jsr   cplotrn

* row cy-x: cx-y and cx+y
ncymx
         lda   ]cy
         sec
         sbc   ]xsav
         tay              ;y-coord in Y-reg

         lda   ]cxl
         sec
         sbc   ]ysav
         sta   rastx0l,y
         lda   ]cxh
         sbc   #$00
         sta   rastx0h,y
_cp06    jsr   cplotl

         lda   ]cxl
         clc
         adc   ]ysav
         sta   rastx1l,y
         lda   ]cxh
         adc   #$00
         sta   rastx1h,y
_cp07    jsr   cplotrn

* CLICK
         jmp   circ_plot_done

         fin              ;***** (USE_FAST)

*
* Same thing, but this time clipping edges.
*
with_clip

* row cy+y: cx-x and cx+x
ccypy
         lda   ]ysav      ;off bottom?
         cmp   ]max_y
         beq   :cypy_ok
         bge   cypy_skip  ;completely off screen
:cypy_ok clc
         adc   ]cy
         tay              ;y-coord in Y-reg

         ldx   ]xsav      ;handle cx-x
         cpx   ]min_x
         blt   :cxmx_ok
         beq   :cxmx_ok
         lda   #0         ;clip at 0
         sta   rastx0l,y
         sta   rastx0h,y
         beq   cxmx_done0 ;always
         BREAK
:cxmx_ok lda   ]cxl
         sec
         sbc   ]xsav
         sta   rastx0l,y
         lda   ]cxh
         sbc   #$00
         sta   rastx0h,y
_cp08    jsr   cplotl
cxmx_done0

         cpx   ]max_x     ;handle cx+x
         blt   :cxpx_ok
         beq   :cxpx_ok
         lda   #<NUM_COLS-1
         sta   rastx1l,y
         lda   #>NUM_COLS-1
         sta   rastx1h,y
         bne   cxpx_done0 ;always
         BREAK
:cxpx_ok lda   ]cxl
         clc
         adc   ]xsav
         sta   rastx1l,y
         lda   ]cxh
         adc   #$00
         sta   rastx1h,y
_cp09    jsr   cplotr
cxpx_done0
cypy_skip

* row cy-y: cx-x and cx+x
ccymy
         lda   ]ysav      ;off top?
         cmp   ]min_y
         beq   :cymy_ok
         bge   cymy_skip
:cymy_ok lda   ]cy
         sec
         sbc   ]ysav
         tay              ;y-coord in Y-reg

         ldx   ]xsav      ;handle cx-x
         cpx   ]min_x
         blt   :cxmx_ok
         beq   :cxmx_ok
         lda   #0         ;clip at 0
         sta   rastx0l,y
         sta   rastx0h,y
         beq   cxmx_done1 ;always
         BREAK
:cxmx_ok lda   ]cxl
         sec
         sbc   ]xsav
         sta   rastx0l,y
         lda   ]cxh
         sbc   #$00
         sta   rastx0h,y
_cp10    jsr   cplotl
cxmx_done1

         cpx   ]max_x     ;handle cx+x
         blt   :cxpx_ok
         beq   :cxpx_ok
         lda   #<NUM_COLS-1
         sta   rastx1l,y
         lda   #>NUM_COLS-1
         sta   rastx1h,y
         bne   cxpx_done1 ;always
         BREAK
:cxpx_ok lda   ]cxl
         clc
         adc   ]xsav
         sta   rastx1l,y
         lda   ]cxh
         adc   #$00
         sta   rastx1h,y
_cp11    jsr   cplotr
cxpx_done1
cymy_skip

* row cy+x: cx-y and cx+y
ccypx
         lda   ]xsav      ;off bottom?
         cmp   ]max_y
         beq   :cypx_ok
         bge   cypx_skip
:cypx_ok clc
         adc   ]cy
         tay              ;y-coord in Y-reg

         ldx   ]ysav      ;handle cx-y
         cpx   ]min_x
         blt   :cxmy_ok
         beq   :cxmy_ok
         lda   #0         ;clip at 0
         sta   rastx0l,y
         sta   rastx0h,y
         beq   cxmy_done2 ;always
         BREAK
:cxmy_ok lda   ]cxl
         sec
         sbc   ]ysav
         sta   rastx0l,y
         lda   ]cxh
         sbc   #$00
         sta   rastx0h,y
_cp12    jsr   cplotl
cxmy_done2

         cpx   ]max_x     ;handle cx+y
         blt   :cxpy_ok
         beq   :cxpy_ok
         lda   #<NUM_COLS-1
         sta   rastx1l,y
         lda   #>NUM_COLS-1
         sta   rastx1h,y
         bne   cxpy_done2 ;always
         BREAK
:cxpy_ok lda   ]cxl
         clc
         adc   ]ysav
         sta   rastx1l,y
         lda   ]cxh
         adc   #$00
         sta   rastx1h,y
_cp13    jsr   cplotr
cxpy_done2
cypx_skip

* row cy-x: cx-y and cx+y
ccymx
         lda   ]xsav      ;off top?
         cmp   ]min_y
         beq   :cymx_ok
         bge   cymx_skip
:cymx_ok lda   ]cy
         sec
         sbc   ]xsav
         tay              ;y-coord in Y-reg

         ldx   ]ysav      ;handle cx-y
         cpx   ]min_x
         blt   :cxmy_ok
         beq   :cxmy_ok
         lda   #0         ;clip at 0
         sta   rastx0l,y
         sta   rastx0h,y
         beq   cxmy_done3 ;always
         BREAK
:cxmy_ok lda   ]cxl
         sec
         sbc   ]ysav
         sta   rastx0l,y
         lda   ]cxh
         sbc   #$00
         sta   rastx0h,y
_cp14    jsr   cplotl
cxmy_done3

         cpx   ]max_x     ;handle cx+y
         blt   :cxpy_ok
         beq   :cxpy_ok
         lda   #<NUM_COLS-1
         sta   rastx1l,y
         lda   #>NUM_COLS-1
         sta   rastx1h,y
         bne   cxpy_done3 ;always
         BREAK
:cxpy_ok lda   ]cxl
         clc
         adc   ]ysav
         sta   rastx1l,y
         lda   ]cxh
         adc   #$00
         sta   rastx1h,y
_cp15    jsr   cplotr
cxpy_done3
cymx_skip

circ_plot_done
* Update X/Y/D.  Up to about radius=41 we can maintain
* 'd' in an 8-bit register.
         do    USE_FAST   ;*****
         lda   circ_8bit
         beq   circ_slow

*
* Bresenham update, with 8-bit 'd'.
*
         ldx   ]xsav
         lda   ]dlo
         bmi   :dneg
         txa              ;:d = d + ((x-y)*4) +5
         sec
         sbc   ]ysav      ;x <= y, may be neg or 0
         asl
         asl
         clc              ;can't know carry
         adc   #5
         clc              ;still don't want carry
         adc   ]dlo
         sta   ]dlo
         dec   ]ysav      ;:y--
         jmp   :loopbot
:dneg    txa              ;:d = d + (x*4) +3
         asl
         asl              ;x always pos, C=0
         DO    0
         BCC   :TEST      ;debug
         BREAK            ;debug
:TEST                     ;debug
         FIN
         adc   #3
         adc   ]dlo
         sta   ]dlo
:loopbot
         inx              ;:x++
         stx   ]xsav
         cpx   ]ysav
         beq   :again
         bge   circ_done
:again   jmp   circ_loop

         fin              ;*****

*
* Bresenham update, with 16-bit 'd'
*
circ_slow
         CLICK
         ldx   ]xsav
         lda   ]dhi
         bmi   :dneg
         lda   ]dlo
         clc
         adc   #5
         sta   ]dlo
         bcc   :noinc
         inc   ]dhi
:noinc
         txa              ;:d = d + ((x-y)*4) +5
         ldy   #$00
         sty   ]hitmp
         sec
         sbc   ]ysav      ;x <= y, may be neg or 0
         beq   :xeqy      ;if x==y, nothing to add
         ldy   #$ff
         sty   ]hitmp
         asl
         rol   ]hitmp
         asl
         rol   ]hitmp
         clc
         adc   ]dlo
         sta   ]dlo
         lda   ]dhi
         adc   ]hitmp
         sta   ]dhi
:xeqy
         dec   ]ysav      ;:y--
         jmp   :loopbot

:dneg    lda   ]dlo       ;:d = d + (x*4) + 3
         clc
         adc   #3
         sta   ]dlo
         bcc   :noinc2
         inc   ]dhi
:noinc2  txa
         ldy   #0         ;x always positive
         sty   ]hitmp
         asl
         rol   ]hitmp
         asl
         rol   ]hitmp
         clc              ;not needed?
         adc   ]dlo
         sta   ]dlo
         lda   ]dhi
         adc   ]hitmp
         sta   ]dhi
:loopbot
         inx              ;:x++
         stx   ]xsav
         cpx   ]ysav
         beq   :again
         bge   circ_done
:again   jmp   circ_loop


circ_done rts


* Plot a point for outline circle rendering.
*
* X and Y must be preserved.  Y holds the current line
* number.
*
* Most DP locations are in use -- see the variable
* declarations at the start of the circle function.

* cplotl is the entry point for the leftmost point.
cplotl
         stx   ]savxreg
         sty   ]savyreg

         lda   ylooklo,y
         sta   ]hbasl
         lda   ylookhi,y
_pg_or2  ora   #$20
         sta   ]hbasl+1

* Convert the X coordinate into byte/bit.
         ldx   rastx0l,y  ;x coord, lo
         lda   rastx0h,y  ;>= 256?
         beq   :lotabl    ;no, use the low table
         ldy   div7hi,x
         lda   mod7hi,x
         bpl   cplotcom   ;always
         BREAK            ;debug
:lotabl  ldy   div7lo,x
         lda   mod7lo,x
         jmp   cplotcom

* cplotr is the entry point for the rightmost point.
* We use rastx1 instead of rastx0.
cplotr
         lda   ylooklo,y
         sta   ]hbasl
         lda   ylookhi,y
_pg_or3  ora   #$20
         sta   ]hbasl+1

* If we just plotted the left point on the same line,
* we can skip the Y-lookup by jumping here.
cplotrn
         stx   ]savxreg
         sty   ]savyreg

         ldx   rastx1l,y  ;x coord, lo
         lda   rastx1h,y  ;>= 256?
         beq   :lotabl    ;no, use the low table
         ldy   div7hi,x
         lda   mod7hi,x
         bpl   cplotcom   ;always
         BREAK            ;debug
:lotabl  ldy   div7lo,x
         lda   mod7lo,x

* Plot the point.  The byte offset (0-39) is in Y,
* the bit offset (0-6) is in A.
cplotcom
         tax
         lda   colorline,y ;start with color pattern
         eor   (]hbasl),y ;flip all bits
         and   andmask,x  ;clear other bits
         eor   (]hbasl),y ;restore ours, set theirs
         sta   (]hbasl),y

         ldx   ]savxreg
         ldy   ]savyreg
         rts

* Reconfigure calc_circle to either JSR to cplotl/r,
* or just BIT the address (a 4-cycle no-op).  The
* desired instruction is in A.
fixcplot
         do    USE_FAST   ;*****
         sta   _cp00
         sta   _cp01
         sta   _cp02
         sta   _cp03
         sta   _cp04
         sta   _cp05
         sta   _cp06
         sta   _cp07
         fin              ;*****
         sta   _cp08
         sta   _cp09
         sta   _cp10
         sta   _cp11
         sta   _cp12
         sta   _cp13
         sta   _cp14
         sta   _cp15
         rts
