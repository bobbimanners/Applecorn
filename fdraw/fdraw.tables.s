********************************
*                              *
* Fast Apple II Graphics       *
* By Andy McFadden             *
* Version 0.3, Aug 2015        *
*                              *
* Pre-computed data and        *
* large internal buffers.      *
* (Included by FDRAW.S)        *
*                              *
* Developed with Merlin-16     *
*                              *
********************************

* Expected layout with alignment:
*
* P1 ylooklo, misc tables
* P2 ylookhi, colorline
* P3 rastx0l
* P4 rastx0h
* P5 rastx1l
* P6 rastx1h, div7hi, mod7hi
* P7 div7lo
* P8 mod7lo
* P9 rast_unroll, rastunidx
*
* Tables should be just under $900 bytes.

             PG_ALIGN

* Hi-res Y lookup, low part (192 bytes).
ylooklo      HEX   0000000000000000
             HEX   8080808080808080
             HEX   0000000000000000
             HEX   8080808080808080
             HEX   0000000000000000
             HEX   8080808080808080
             HEX   0000000000000000
             HEX   8080808080808080
             HEX   2828282828282828
             HEX   a8a8a8a8a8a8a8a8
             HEX   2828282828282828
             HEX   a8a8a8a8a8a8a8a8
             HEX   2828282828282828
             HEX   a8a8a8a8a8a8a8a8
             HEX   2828282828282828
             HEX   a8a8a8a8a8a8a8a8
             HEX   5050505050505050
             HEX   d0d0d0d0d0d0d0d0
             HEX   5050505050505050
             HEX   d0d0d0d0d0d0d0d0
             HEX   5050505050505050
             HEX   d0d0d0d0d0d0d0d0
             HEX   5050505050505050
             HEX   d0d0d0d0d0d0d0d0

* Color masks for odd/even bytes, colors 0-7.
evencolor    dfb   $00,$2a,$55,$7f,$80,$aa,$d5,$ff
oddcolor     dfb   $00,$55,$2a,$7f,$80,$d5,$aa,$ff

* XOR mask for colors 0-7 - non-BW flip on odd/even.
xormask      dfb   $00,$7f,$7f,$00,$00,$7f,$7f,$00

* AND mask for the 7 pixel positions, high bit set
* for the color shift.
andmask      dfb   $81,$82,$84,$88,$90,$a0,$c0

* These are pixel AND masks, used with the modulo 7
* result.  Entry #2 in leftmask means we're touching
* the rightmost 5 pixels, and entry #2 in rightmask
* means we're touching the 3 leftmost pixels.
*
* The high bit is always set, because we want to
* keep the color's high bit.
leftmask     dfb   $ff,$fe,$fc,$f8,$f0,$e0,$c0
rightmask    dfb   $81,$83,$87,$8f,$9f,$bf,$ff

             PG_ALIGN

* Hi-res Y lookup, high part (192 bytes).
* OR with $20 or $40.
ylookhi      HEX   0004080c1014181c
             HEX   0004080c1014181c
             HEX   0105090d1115191d
             HEX   0105090d1115191d
             HEX   02060a0e12161a1e
             HEX   02060a0e12161a1e
             HEX   03070b0f13171b1f
             HEX   03070b0f13171b1f
             HEX   0004080c1014181c
             HEX   0004080c1014181c
             HEX   0105090d1115191d
             HEX   0105090d1115191d
             HEX   02060a0e12161a1e
             HEX   02060a0e12161a1e
             HEX   03070b0f13171b1f
             HEX   03070b0f13171b1f
             HEX   0004080c1014181c
             HEX   0004080c1014181c
             HEX   0105090d1115191d
             HEX   0105090d1115191d
             HEX   02060a0e12161a1e
             HEX   02060a0e12161a1e
             HEX   03070b0f13171b1f
             HEX   03070b0f13171b1f

* Masks for current color (even/odd), e.g. 55 2a 55 2a ...
* Updated whenever the color changes.
colorline    ds    40

             PG_ALIGN
rastx0l      ds    NUM_ROWS
             PG_ALIGN
rastx0h      ds    NUM_ROWS
             ds    1                ;repeat mode can overstep
             PG_ALIGN
rastx1l      ds    NUM_ROWS
             PG_ALIGN
rastx1h      ds    NUM_ROWS

* Lookup tables for dividing 0-279 by 7.  The "hi"
* parts are 24 bytes each, so they fit inside
* the previous 192-byte entry.  The "lo" parts
* each fill a page.
div7hi       HEX   2424242525252525
             HEX   2525262626262626
             HEX   2627272727272727
mod7hi       HEX   0405060001020304
             HEX   0506000102030405
             HEX   0600010203040506

             PG_ALIGN

div7lo       HEX   0000000000000001
             HEX   0101010101010202
             HEX   0202020202030303
             HEX   0303030304040404
             HEX   0404040505050505
             HEX   0505060606060606
             HEX   0607070707070707
             HEX   0808080808080809
             HEX   0909090909090a0a
             HEX   0a0a0a0a0a0b0b0b
             HEX   0b0b0b0b0c0c0c0c
             HEX   0c0c0c0d0d0d0d0d
             HEX   0d0d0e0e0e0e0e0e
             HEX   0e0f0f0f0f0f0f0f
             HEX   1010101010101011
             HEX   1111111111111212
             HEX   1212121212131313
             HEX   1313131314141414
             HEX   1414141515151515
             HEX   1515161616161616
             HEX   1617171717171717
             HEX   1818181818181819
             HEX   1919191919191a1a
             HEX   1a1a1a1a1a1b1b1b
             HEX   1b1b1b1b1c1c1c1c
             HEX   1c1c1c1d1d1d1d1d
             HEX   1d1d1e1e1e1e1e1e
             HEX   1e1f1f1f1f1f1f1f
             HEX   2020202020202021
             HEX   2121212121212222
             HEX   2222222222232323
             HEX   2323232324242424
mod7lo       HEX   0001020304050600
             HEX   0102030405060001
             HEX   0203040506000102
             HEX   0304050600010203
             HEX   0405060001020304
             HEX   0506000102030405
             HEX   0600010203040506
             HEX   0001020304050600
             HEX   0102030405060001
             HEX   0203040506000102
             HEX   0304050600010203
             HEX   0405060001020304
             HEX   0506000102030405
             HEX   0600010203040506
             HEX   0001020304050600
             HEX   0102030405060001
             HEX   0203040506000102
             HEX   0304050600010203
             HEX   0405060001020304
             HEX   0506000102030405
             HEX   0600010203040506
             HEX   0001020304050600
             HEX   0102030405060001
             HEX   0203040506000102
             HEX   0304050600010203
             HEX   0405060001020304
             HEX   0506000102030405
             HEX   0600010203040506
             HEX   0001020304050600
             HEX   0102030405060001
             HEX   0203040506000102
             HEX   0304050600010203


* RastFill unrolled loop.  At each step we store the current
* color value, XOR it to flip the bits if needed, and advance.
* The caller needs to set the appropriate initial value based
* on whether the address is odd or even.
*
* We can use a 3-cycle "EOR dp" or a 2-cycle "EOR imm".  The
* former is one cycle slower, the latter requires us to
* self-mod 40 instructions when the color changes.
*
* This must be page-aligned so that we can take the value
* from the rastunidx table and self-mod a JMP without having
* to do a 16-bit add.  We have just enough room for the
* unrolled loop (40*5+3) and x5 table (41) = 244 bytes, fits
* on a single page.

             do    USE_FAST         ;*****
             ds    \
]hbasl       equ   zptr0            ;must match FillRaster
rast_unroll  equ   *
             lst   off
             lup   BYTES_PER_ROW
             sta   (]hbasl),y       ;6
             eor   #$00             ;2
             iny                    ;2  10 cycles, 5 bytes
             --^
             jmp   rastlinedone

* Index into rast_unroll.  If we need to output N bytes,
* we want to jump to (rast_unroll + (40 - N) * 5) (where
* 5 is the number of bytes per iteration).
rastunidx
]offset      =     BYTES_PER_ROW*5
             lup   BYTES_PER_ROW+1  ;0-40
             dfb   ]offset
]offset      =     ]offset-5
             --^

             fin                    ;*****


********************************
*
* Code used to generate tables above.  If you want to
* decrease load size, use these functions to generate
* the data into empty memory, then discard the code.
* (Maybe use a negative DS and overlap with rastx0l?)
*
********************************
             DO    0                ;*****

init_ylook
]hbasl       equ   zptr1
]hbash       equ   zptr1+1

* Initialize Y-lookup table.  We just call the bascalc
* function.
             ldx   #NUM_ROWS
             ldy   #NUM_ROWS-1
]loop        tya
             jsr   bascalc
             lda   hbasl
             sta   ylooklo,y
             lda   hbash
             ora   #$20             ;remove for $0000 base
             sta   ylookhi,y
             dey
             dex
             bne   ]loop
             rts

* Hi-res base address calculation.  This is based on the
* HPOSN routine at $F411.
*
* Call with the line in A.  The results are placed into
* zptr1.  X and Y are not disturbed.
*
* The value is in the $0000-1fff range, so you must OR
* the desired hi-res page in.
*
bascalc
             pha
             and   #$c0
             sta   ]hbasl
             lsr
             lsr
             ora   ]hbasl
             sta   ]hbasl
             pla
             sta   ]hbash
             asl
             asl
             asl
             rol   ]hbash
             asl
             rol   ]hbash
             asl
             ror   ]hbasl
             lda   ]hbash
             and   #$1f
             sta   ]hbash
             rts

*
* Create divide-by-7 tables.
*
mkdivtab
]val         equ   zloc0

             ldy   #0
             sty   ]val
             ldx   #0
]loop        lda   ]val
             sta   div7lo,y
             txa
             sta   mod7lo,y
             inx
             iny
             beq   :lodone
             cpx   #7
             bne   ]loop
             inc   ]val
             ldx   #0
             beq   ]loop            ;always
:lodone                             ;safe to ignore ]va update
]loop        lda   ]val
             sta   div7hi,y
             txa
             sta   mod7hi,y
             iny
             cpy   #280-256
             beq   :hidone
             inx
             cpx   #7
             bne   ]loop
             inc   ]val
             ldx   #0
             beq   ]loop            ;always
:hidone      rts

             FIN                    ;*****


