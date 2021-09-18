********************************
*                              *
* Fast Apple II Graphics       *
* By Andy McFadden             *
* Version 0.3, Aug 2015        *
*                              *
* Point and line functions     *
* (Included by FDRAW.S)        *
*                              *
* Developed with Merlin-16     *
*                              *
********************************


********************************
*
* Draw a single point in the current color.
*
********************************
DrawPoint
]hbasl   equ   zptr0

         ldy   in_y0
         lda   ylooklo,y
         sta   ]hbasl
         lda   ylookhi,y
         ora   g_page
         sta   ]hbasl+1

         ldx   in_x0l     ;x coord, lo
         lda   in_x0h     ;>= 256?
         beq   :lotabl    ;no, use the low table
         ldy   div7hi,x
         lda   mod7hi,x
         bpl   :plotit    ;always
         BREAK            ;debug
:lotabl  ldy   div7lo,x
         lda   mod7lo,x

* Plot the point.  The byte offset (0-39) is in Y,
* the bit offset (0-6) is in A.
:plotit
         tax
         lda   colorline,y ;start with color pattern
         eor   (]hbasl),y ;flip all bits
         and   andmask,x  ;clear other bits
         eor   (]hbasl),y ;restore ours, set theirs
         sta   (]hbasl),y
         rts


********************************
*
* Draw a line between two points.
*
********************************
DrawLine

]hbasl   equ   zptr0
]xposl   equ   zloc0      ;always left edge
]xposh   equ   zloc1
]ypos    equ   zloc2      ;top or bottom
]deltaxl equ   zloc3
]deltaxh equ   zloc4
]deltay  equ   zloc5
]count   equ   zloc6
]counth  equ   zloc7
]diff    equ   zloc8
]diffh   equ   zloc9
]andmask equ   zloc10
]wideflag equ  zloc11     ;doesn't really need DP

* We use a traditional Bresenham run-length approach.
* Run-slicing is possible, but the code is larger
* and the increased cost means it's only valuable
* for longer lines.  An optimal solution would switch
* approaches based on line length.
*
* Start by identifying where x0 or x1 is on the
* left.  To make life simpler we always work from
* left to right, flipping the coordinates if
* needed.
*
* We also need to figure out if the line is more
* than 255 pixels long -- which, because of
* inclusive coordinates, means abs(x0-x1) > 254.
         lda   in_x1l     ;assume x0 on left
         sec
         sbc   in_x0l
         tax
         beq   checkvert  ;low bytes even, check hi
         lda   in_x1h
         sbc   in_x0h
         bcs   lx0left

* x1 is on the left, so the values are negative
* (hi byte in A, lo byte in X)
lx0right eor   #$ff       ;invert hi
         sta   ]deltaxh   ;store
         txa
         eor   #$ff       ;invert lo
         sta   ]deltaxl
         inc   ]deltaxl   ;add one for 2s complement
         bne   :noinchi   ;rolled into high byte?
         inc   ]deltaxh   ;yes
:noinchi lda   in_x1l     ;start with x1
         sta   ]xposl
         lda   in_x1h
         sta   ]xposh
         lda   in_y1
         sta   ]ypos
         sec
         sbc   in_y0      ;compute deltay
         jmp   lncommon

checkvert
         lda   in_x1h     ;diff high bytes
         sbc   in_x0h     ;(carry still set)
         blt   lx0right   ;width=256, x0 right
         bne   lx0left    ;width=256, x0 left
         jmp   vertline   ;all zero, go vert

* (branch back from below)
* This is a purely horizontal line.  We farm the job
* out to the raster fill code for speed.  (There's
* no problem with the line code handling it; its just
* more efficient to let the raster code do it.)
phorizontal
         ldy   ]ypos
         sty   rast_top
         sty   rast_bottom
         lda   ]xposl
         sta   rastx0l,y
         clc
         adc   ]deltaxl   ;easier to add delta back
         sta   rastx1l,y  ; in than sort out which
         lda   ]xposh     ; arg is left vs. right
         sta   rastx0h,y
         adc   ]deltaxh
         sta   rastx1h,y
         jmp   FillRaster

* x0 is on the left, so the values are positive
lx0left  stx   ]deltaxl
         sta   ]deltaxh
         lda   in_x0l     ;start with x0
         sta   ]xposl
         lda   in_x0h
         sta   ]xposh
         lda   in_y0      ;and y0
         sta   ]ypos
         sec
         sbc   in_y1      ;compute deltay

* Value of (starty - endy) is in A, flags still set.
lncommon
         bcs   :posy
         eor   #$ff       ;negative, invert
         adc   #$01
         sta   ]deltay
         lda   #$e8       ;INX
         bne   gotdy
:posy
_lmb     beq   phorizontal
         sta   ]deltay
         lda   #$ca       ;DEX
gotdy    sta   _hmody
         sta   _vmody
         sta   _wmody

         do    0          ;***** for regression test
         ldx   #$01
         lda   ]deltaxh
         bne   :iswide
         lda   ]deltaxl
         cmp   #$ff       ;== 255?
         beq   :iswide
         ldx   #$00       ;notwide
:iswide  stx   $300
         lda   ]xposl
         sta   $301
         lda   ]xposh
         sta   $302
         lda   ]ypos
         sta   $303
         ldx   ]deltaxl
         stx   $304
         ldx   ]deltaxh
         stx   $305
         ldx   ]deltay
         stx   $306
         lda   _hmody
         and   #$20       ;nonzero means inc,
         sta   $307       ; zero means dec
         fin              ;*****

* At this point we have the initial X position in
* ]startxl/h, the initial Y position in ]starty,
* deltax in ]deltaxl, deltay in ]deltay, and we've
* tweaked the Y-update instructions to either INC or
* DEC depending on the direction of movement.
*
* The next step is to decide whether the line is
* horizontal-dominant or vertical-dominant, and
* branch to the appropriate handler.
*
* The core loops for horiz and vert take about
* 80 cycles when moving diagonally, and about
* 20 fewer when moving in the primary direction.
* The wide-horiz is a bit slower.
         ldy   #$01       ;set "wide" flag to 1
         lda   ]deltaxl
         ldx   ]deltaxh
         bne   horzdom    ;width >= 256
         cmp   #$ff       ;width == 255
         beq   horzdom
         dey              ;not wide
         cmp   ]deltay
         bge   horzdom    ; for diagonal lines
         jmp   vertdom

* We could special-case pure-diagonal lines here
* (just BEQ a couple lines up).  It does
* represent our worst case.  I'm not convinced
* we'll see them often enough to make it worthwhile.


* horizontal-dominant
horzdom
         sty   ]wideflag
         sta   ]count     ;:count = deltax + 1
         inc   ]count
         lsr              ;:diff = deltax / 2
         sta   ]diff

* set Y to the byte offset in the line
* load the AND mask into ]andmask
         ldx   ]xposl
         lda   ]xposh     ;>= 256?
         beq   :lotabl    ;no, use the low table
         ldy   div7hi,x
         lda   mod7hi,x
         bpl   :gottab    ;always
* BREAK ;debug
:lotabl  ldy   div7lo,x
         lda   mod7lo,x
:gottab
         tax
         lda   andmask,x
         sta   ]andmask

* Set initial value for line address.
         ldx   ]ypos
         lda   ylooklo,x
         sta   ]hbasl
         lda   ylookhi,x
         ora   g_page
         sta   ]hbasl+1

         lda   ]wideflag  ;is this a "wide" line?
         beq   :notwide   ;nope, stay local
         jmp   widedom

:notwide lda   colorline,y ;set initial color mask
         sta   _hlcolor+1
         jmp   horzloop

hrts     rts

* bottom of loop, essentially
hnoroll  sta   ]diff      ;3
hdecc    dec   ]count     ;5 :count--
         beq   hrts       ;2 :while (count != 0)
                          ;= 7 or 10

* We keep the byte offset in the line in Y, and the
* line index in X, for the entire loop.
horzloop
_hlcolor lda   #$00       ;2 start with color pattern
_lmdh    eor   (]hbasl),y ;5 flip all bits
         and   ]andmask   ;3 clear other bits
         eor   (]hbasl),y ;5 restore ours, set theirs
         sta   (]hbasl),y ;6 = 21

* Move right.  We shift the bit mask that determines
* the pixel.  When we shift into bit 7, we know it's
* time to advance another byte.
*
* If this is a shallow line we would benefit from
* keeping the index in X and just doing a 4-cycle
* indexed load to get the mask. Not having the
* line number in X makes the line calc more
* expensive for steeper lines though.
         lda   ]andmask   ;3
         asl              ;2 shift, losing hi bit
         eor   #$80       ;2 set the hi bit
         bne   :noh8      ;3 cleared hi bit?
* We could BEQ away and branch back in, but this
* happens every 7 iterations, so on average it's
* a very small improvement.  If we happen to branch
* across a page boundary the double-branch adds
* two more cycles and we lose.
         iny              ;2 advance to next byte
         lda   colorline,y ;4 update color mask
         sta   _hlcolor+1 ;4
         lda   #$81       ;2 reset
:noh8    sta   ]andmask   ;3 = 13 + ((12-1)/7) = 14

* Update error diff.
         lda   ]diff      ;3
         sec              ;2
         sbc   ]deltay    ;3 :diff -= deltay
         bcs   hnoroll    ;2+ :if (diff < 0) ...
                          ;= 11 level, 10 up/down
         adc   ]deltaxl   ;3 :  diff += deltax
         sta   ]diff      ;3
_hmody   inx              ;2 :  ypos++ (or --)
         lda   ylooklo,x  ;4 update hbasl after line
         sta   ]hbasl     ;3  change
         lda   ylookhi,x  ;4
_pg_or4  ora   #$20       ;2
         sta   ]hbasl+1   ;3
         bne   hdecc      ;3 = +27 this path -> 37
         BREAK
* horizontal: 10+21+14+11=56 cycles/pixel
* diagonal:   7+21+14+37=79 cycles/pixel


* Vertical-dominant line.  Could go up or down.
vertdom
         ldx   in_y0
         cpx   ]ypos      ;starting at y0?
         bne   :endy0     ;yup
         ldx   in_y1      ;nope
:endy0   stx   _vchk+1    ;end condition

         lda   ]deltay
         lsr
         sta   ]diff      ;:diff = deltay / 2

* set Y to the byte offset in the line
* load the AND mask into ]andmask
         ldx   ]xposl
         lda   ]xposh     ;>= 256?
         beq   :lotabl    ;no, use the low table
         ldy   div7hi,x
         lda   mod7hi,x
         bpl   :gottab    ;always
         BREAK            ;debug
:lotabl  ldy   div7lo,x
         lda   mod7lo,x
:gottab
         tax
         lda   andmask,x  ;initial pixel mask
         sta   ]andmask

         lda   colorline,y ;initial color mask
         sta   _vlcolor+1

         ldx   ]ypos
         jmp   vertloop

* We keep the byte offset in the line in Y, and the
* line index in X, for the entire loop.

* Bottom of loop, essentially.
vnoroll  sta   ]diff      ;3

vertloop
         lda   ylooklo,x  ;4
         sta   ]hbasl     ;3
         lda   ylookhi,x  ;4
_pg_or5  ora   #$20       ;2
         sta   ]hbasl+1   ;3 = 16

_vlcolor lda   #$00       ;2 start with color pattern
_lmdv    eor   (]hbasl),y ;5 flip all bits
         and   ]andmask   ;3 clear other bits
         eor   (]hbasl),y ;5 restore ours, set theirs
         sta   (]hbasl),y ;6 = 21

_vchk    cpx   #$00       ;2 was this last line?
         beq   vrts       ;2 yes, done
_vmody   inx              ;2 :ypos++ (or --)

* Update error diff.
         lda   ]diff      ;3
         sec              ;2
         sbc   ]deltaxl   ;3 :diff -= deltax
         bcs   vnoroll    ;2 :if (diff < 0) ...
                          ;= 10 vert, 9 move right

         adc   ]deltay    ;3 :  diff += deltay
         sta   ]diff      ;3
* Move right.  We shift the bit mask that determines
* the pixel.  When we shift into bit 7, we know it's
* time to advance another byte.
         lda   ]andmask   ;3
         asl              ;2 shift, losing hi bit
         eor   #$80       ;2 set the hi bit
         beq   :is8       ;2+ goes to zero on 8th bit
         sta   ]andmask   ;3
         bne   vertloop   ;3 = 21 + (18/7) = 24
         BREAK

:is8     iny              ;2 advance to next byte
         lda   colorline,y ;4 update color
         sta   _vlcolor+1 ;4
         lda   #$81       ;2 reset
         sta   ]andmask   ;3
         bne   vertloop   ;3 = 18
         BREAK
vrts     rts
* vertical: 3 + 16 + 21 + 6 + 10 = 56 cycles
* diagonal: 16 + 21 + 6 + 9 + 24 = 76 cycles


* "Wide" horizontally-dominant loop.  We have to
* maintain error-diff and deltax as 16-bit values.
* Most of the setup from the "narrow" version carried
* over, but we have to re-do the count and diff.
*
* Normally we set count to (deltax + 1) and decrement
* to zero, but it's actually easier to set it equal
* to deltax and check for -1.
widedom
         lda   ]deltaxh   ;:count = deltax
         sta   ]counth
         ldx   ]deltaxl
         stx   ]count
         stx   ]diff
         lsr              ;:diff = deltax / 2
         ror   ]diff
         sta   ]diffh
         ldx   ]ypos

         lda   colorline,y ;set initial color mask
         sta   _wlcolor+1

* We keep the byte offset in the line in Y, and the
* line index in X, for the entire loop.
wideloop
_wlcolor lda   #$00       ;2 start with color pattern
_lmdw    eor   (]hbasl),y ;5 flip all bits
         and   ]andmask   ;3 clear other bits
         eor   (]hbasl),y ;5 restore ours, set theirs
         sta   (]hbasl),y ;6 = 21

* Move right.  We shift the bit mask that determines
* the pixel.  When we shift into bit 7, we know it's
* time to advance another byte.
         lda   ]andmask   ;3
         asl              ;2 shift, losing hi bit
         eor   #$80       ;2 set the hi bit
         bne   :not7      ;3 goes to zero on 8th bit
         iny              ; 2 advance to next byte
         lda   colorline,y ; 4 update color mask
         sta   _hlcolor+1 ; 4
         lda   #$81       ; 2 reset
:not7    sta   ]andmask   ;3 = 13 usually, 25 every 7

* Update error diff, which is a positive number.  If
* it goes negative ("if (diff < 0)") we act.
         lda   ]diff
         sec
         sbc   ]deltay    ;:diff -= deltay
         bcs   wnoroll    ;didn't even roll low byte
         dec   ]diffh     ;check hi byte
         bpl   wnoroll    ;went 1->0, keep going

         adc   ]deltaxl   ;:  diff += deltax
         sta   ]diff
         lda   ]diffh
         adc   ]deltaxh
         sta   ]diffh
_wmody   inx              ;:  ypos++ (or --)
         lda   ylooklo,x  ;update hbasl after line
         sta   ]hbasl     ; change
         lda   ylookhi,x
_pg_or6  ora   #$20
         sta   ]hbasl+1
         bne   wdecc
         BREAK

wnoroll  sta   ]diff

wdecc    dec   ]count     ;5 :count--
         lda   ]count     ;3
         cmp   #$ff       ;2
         bne   wideloop   ;3 :while (count > -1)
         dec   ]counth    ;low rolled, decr high
         beq   wideloop   ;went 1->0, keep going
         rts


* Pure-vertical line.  These are common in certain
* applications, and checking for it only adds two
* cycles to the general case.
vertline
         ldx   in_y0
         ldy   in_y1
         cpx   in_y1      ;y0 < y1?
         blt   :usey0     ;yes, go from y0 to y1
         txa              ;swap X/A
         tay
         ldx   in_y1
:usey0   stx   ]ypos
         iny
         sty   _pvytest+1

         ldx   in_x0l     ;xc lo
         lda   in_x0h     ;>= 256?
         beq   :lotabl
         ldy   div7hi,x
         lda   mod7hi,x
         bpl   :gotit     ;always
:lotabl  ldy   div7lo,x
         lda   mod7lo,x

* Byte offset is in Y, mod-7 value is in A.
:gotit   tax
         lda   andmask,x
         sta   _pvand+1   ;this doesn't change

         lda   colorline,y
         sta   _pvcolor+1 ;nor does this

         ldx   ]ypos      ;top line

* There's a trick where, when (linenum & 0x07) is
* nonzero, you just add 4 to hbasl+1 instead of
* re-doing the lookup.  However, TXA+AND+BEQ
* followed by LDA+CLC+ADC+STA is 16 cycles, the same
* as our self-modified lookup, so it's not a win.
* (And if we used a second ylookhi and self-modded
* the table address, we could shave off another 2.)

* Main pure-vertical loop
pverloop
         lda   ylooklo,x  ;4
         sta   ]hbasl     ;3
         lda   ylookhi,x  ;4
_pg_or7  ora   #$20       ;2
         sta   ]hbasl+1   ;3 (= 16)

_pvcolor lda   #$00       ;2 start with color pattern
_lmdpv   eor   (]hbasl),y ;5 flip all bits
_pvand   and   #$00       ;2 clear other bits
         eor   (]hbasl),y ;5
         sta   (]hbasl),y ;6 (= 20)

         inx              ;2
_pvytest cpx   #$00       ;2 done?
         bne   pverloop   ;3 = 7
         rts
* 43 cycles/pixel


********************************
*
* Set the line mode according to in_arg
*
* A slightly silly feature to get xdraw lines
* without really working for it.
*
********************************
SetLineMode
         lda   in_arg
         beq   :standard

* configure for xdraw
         lda   #$24       ;BIT dp
         sta   _lmb
         sta   _lmdh
         sta   _lmdv
         sta   _lmdw
         sta   _lmdpv
         rts

* configure for standard drawing
:standard lda  #$f0       ;BEQ
         sta   _lmb
         lda   #$51       ;EOR (dp),y
         sta   _lmdh
         sta   _lmdv
         sta   _lmdw
         sta   _lmdpv
         rts
