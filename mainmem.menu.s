* MAINMEM.MENU.S
* (c) Bobbi 2021 GPL3
*
* Applecorn ROM menu.  Runs in main memory.

ROMMENU     JSR   HOME        ; Clear screen
            LDA   #<TITLE1    ; Print title
            STA   A1L
            LDA   #>TITLE1
            STA   A1H
            JSR   PRSTRA1
            JSR   CROUT
            JSR   CROUT
            LDA   #<TITLE2
            STA   A1L
            LDA   #>TITLE2
            STA   A1H
            JSR   PRSTRA1
            JSR   CROUT
            JSR   CROUT
            JSR   CROUT

            LDX   #$00        ; Print menu
:L1         LDA   MSGTBL,X
            STA   A1L
            INX
            LDA   MSGTBL,X
            STA   A1H
            INX
            JSR   PRSTRA1
            JSR   CROUT
            JSR   CROUT
            CPX   #8*2
            BEQ   :KEYIN
            BRA   :L1

:KEYIN      LDA   $C000       ; Kdb data / strobe
            BPL   :KEYIN      ; Wait for keystroke
            STA   $C010       ; Clear strobe
            AND   #$7F
            SEC
            SBC   #'1'        ; '1'->0, '2'->1 etc.
            CMP   #8
            BCC   :KEYOK
            JSR   BELL        ; Invalid - beep
            BRA   :KEYIN      ; Go again
:KEYOK      ASL               ; x2
            TAX
            LDA   ROMTBL,X    ; Fetch ROM filename ...
            STA   OPENPL+1    ; ... and put in MLI OPEN PL
            LDA   ROMTBL+1,X
            STA   OPENPL+2
            RTS

* Print a string pointed to by A1L/A1H
* Trashes A, preserves X and Y
PRSTRA1     PHY
            LDY   #$00
:L1         LDA   (A1L),Y
            BEQ   :NULL
            JSR   COUT1
            INY
            BRA   :L1
:NULL       PLY
            RTS

TITLE1      ASC   "** APPLECORN **"
            DB    $00
TITLE2      ASC   "Choose a BBC Micro ROM:"
            DB    $00

MSGTBL      DW    MSG1
            DW    MSG2
            DW    MSG3
            DW    MSG4
            DW    MSG5
            DW    MSG6
            DW    MSG7
            DW    MSG8

ROMTBL      DW    ROM1
            DW    ROM2
            DW    ROM3
            DW    ROM4
            DW    ROM5
            DW    ROM6
            DW    ROM7
            DW    ROM8

MSG1        ASC   " 1. BBC BASIC"
            DB    $00
ROM1        STR   "BASIC2.ROM"

MSG2        ASC   " 2. Acornsoft COMAL"
            DB    $00
ROM2        STR   "COMAL.ROM"

MSG3        ASC   " 3. Acornsoft Lisp"
            DB    $00
ROM3        STR   "LISP501.ROM"

MSG4        ASC   " 4. Acornsoft Forth"
            DB    $00
ROM4        STR   "FORTH103.ROM"

MSG5        ASC   " 5. Acornsoft MicroProlog"
            DB    $00
ROM5        STR   "MPROLOG310.ROM"

MSG6        ASC   " 6. Acornsoft BCPL"
            DB    $00
ROM6        STR   "BCPL7.0.ROM"

MSG7        ASC   " 7. USERROM1.ROM"
            DB    $00
ROM7        STR   "USERROM1.ROM"

MSG8        ASC   " 8. USERROM2.ROM"
            DB    $00
ROM8        STR   "USERROM2.ROM"











