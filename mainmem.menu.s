* MAINMEM.MENU.S
* (c) Bobbi 2021 GPL3
*
* Applecorn ROM menu.  Runs in main memory.

* 13-Nov-2021 List of selected ROMs kept locally.


ROMTOTL      EQU   $0382              ; Prevent name clash
ROMTHIS      EQU   $0383
ROMADDRS     EQU   $0384              ; List of ROM filename addresses

ROMMENU      JSR   HOME               ; Clear screen
             LDX   #0
:LP0         LDA   TITLE1,X           ; Print title
             BEQ   :LP1
             JSR   COUT1
             INX
             BNE   :LP0
:LP1

:KEYIN       LDA   $C000              ; Kdb data / strobe
             BPL   :KEYIN             ; Wait for keystroke
             STA   $C010              ; Clear strobe
             AND   #$7F
             SEC
             SBC   #'1'               ; '1'->0, '2'->1 etc.
             CMP   #9
             BCC   :KEYOK
             JSR   BELL               ; Invalid - beep
             BRA   :KEYIN             ; Go again
:KEYOK       STA   USERSEL            ; Record selection

* Make list of ROMs
             LDX   #63
             LDA   #0
:INITLP1     STA   ROMADDRS,X
             DEX
             BPL   :INITLP1
             STX   ROMTHIS            ; Current ROM=none
             LDY   USERSEL            ; Index to ROM to load
             LDA   #0                 ; Load it to bank 0
             CPY   #6
             BCC   :INITROM2          ; <=6, single ROM
             CPY   #8
             BEQ   :INITROM2          ; =8, also single ROM
             LDA   #1                 ; Load to bank 1 and 0
             CPY   #7
             BCC   :INITROM2          ; =7, two ROMs
             LDA   #7                 ; Load to bank 7 to 0
             LDY   #0                 ; Starting at ROM 0
:INITROM2    STA   ROMTOTL
             ASL   A
             TAX                      ; X=>ROM address table
             TYA
             ASL   A
             TAY                      ; Y=>ROM addresses
:INITROM3    LDA   ROMLIST+0,Y
             STA   ROMADDRS+0,X
             LDA   ROMLIST+1,Y
             STA   ROMADDRS+1,X
             INY
             INY
             DEX
             DEX
             BPL   :INITROM3
             RTS

SELECTROM    >>>   ENTMAIN
             CMP   ROMTHIS
             BEQ   :SELECTDONE        ; Already selected
             CMP   ROMTOTL
             BCC   :GETROM
             BNE   :SELECTDONE        ; Out of range
:GETROM      PHA
             ASL   A
             TAX
             LDA   ROMADDRS+0,X       ; ROM filename
             STA   OPENPL+1
             LDA   ROMADDRS+1,X
             STA   OPENPL+2
             LDA   #$80               ; Load address $8000
             LDX   #$00
             SEC                      ; Aux memory
             JSR   LOADCODE           ; Try and fetch it
             PLA                      ; Get bank back
             BCS   :SELECTDONE        ; Failed
             STA   ROMTHIS            ; It is paged in
:SELECTDONE  >>>   XF2AUX,ROMSELDONE


TITLE1       ASC   "** APPLECORN **"
             DB    $8D,$8D
TITLE2       ASC   "Choose a BBC Micro ROM:"
             DB    $8D,$8D

MSG1         ASC   " 1. BBC BASIC"
             DB    $8D,$8D
MSG2         ASC   " 2. Acornsoft COMAL"
             DB    $8D,$8D
MSG3         ASC   " 3. Acornsoft Lisp"
             DB    $8D,$8D
MSG4         ASC   " 4. Acornsoft Forth"
             DB    $8D,$8D
MSG5         ASC   " 5. Acornsoft MicroProlog"
             DB    $8D,$8D
MSG6         ASC   " 6. Acornsoft BCPL"
             DB    $8D,$8D
MSG7         ASC   " 7. Acornsoft ISO Pascal (2 ROMs)"
             DB    $8D,$8D
MSG8         ASC   " 8. 1 through 7 (8 ROMs)"
             DB    $8D,$8D
MSG9         ASC   " 9. Acornsoft View"
             DB    $8D
             DB    $00


ROMLIST      DW    ROM1
             DW    ROM2
             DW    ROM3
             DW    ROM4
             DW    ROM5
             DW    ROM6
             DW    ROM7
             DW    ROM8
             DW    ROM9

ROM1         STR   "BASIC2.ROM"
ROM2         STR   "COMAL.ROM"
ROM3         STR   "LISP501.ROM"
ROM4         STR   "FORTH103.ROM"
ROM5         STR   "MPROLOG310.ROM"
ROM6         STR   "BCPL700.ROM"
ROM7         STR   "PASCAL110A.ROM"
ROM8         STR   "PASCAL110B.ROM"
ROM9         STR   "VIEWA3.0.ROM"

USERSEL      DB    $00





