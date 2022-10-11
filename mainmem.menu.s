* MAINMEM.MENU.S
* (c) Bobbi 2021 GPL3
*
* Applecorn ROM menu.  Runs in main memory.

* 13-Nov-2021 List of selected ROMs kept locally.

             ORG   ENDSYSTEM+ENDVEC-AUXMOS+MOSEND-MOSAPI+2

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

* Load image from file into memory
* On entry: OPENPL set up to point to leafname of file to load
*           Loads file from directory applecorn started from
*           Uses BLKBUF at loading buffer
*           Load address in A,X
*           Carry set->load to aux, carry clear->load to main
LOADCODE    PHP                    ; Save carry flag
            STA   :ADDRH           ; MSB of load address
            STX   :ADDRL           ; LSB of load address
            STZ   :BLOCKS

            LDX   #0
:LP1        LDA   CMDPATH+1,X      ; Copy Applecorn path to MOSFILE
            STA   MOSFILE2+1,X
            INX
            CPX   CMDPATH
            BCC   :LP1
:LP2        DEX
            LDA   MOSFILE2+1,X
            CMP   #'/'
            BNE   :LP2
            LDA   OPENPL+1
            STA   A1L
            LDA   OPENPL+2
            STA   A1H
            LDY   #1
            LDA   (A1L),Y
            CMP   #'/'
            BEQ   :L4              ; Already absolute path
:LP3        LDA   (A1L),Y
            STA   MOSFILE2+2,X
            INX
            INY
            TYA
            CMP   (A1L)
            BCC   :LP3
            BEQ   :LP3
            INX
            STX   MOSFILE2+0
            LDA   #<MOSFILE2       ; Point to absolute path
            STA   OPENPL+1
            LDA   #>MOSFILE2
            STA   OPENPL+2

:L4         JSR   OPENFILE         ; Open ROM file
            BCC   :S1
            PLP
            BCC   :L1A             ; Load to main, report error
            RTS                    ; Load to aux, return CS=Failed
:L1A        LDX   #$00
:L1B        LDA   :CANTOPEN,X      ; Part one of error msg
            BEQ   :S0
            JSR   COUT1
            INX
            BRA   :L1B
:S0         LDA   OPENPL+1         ; Print filename
            STA   A1L
            LDA   OPENPL+2
            STA   A1H
            LDY   #$00
            LDA   (A1L),Y
            STA   :LEN
:L1C        CPY   :LEN
            BEQ   :ERR1
            INY
            LDA   (A1L),Y
            JSR   COUT1
            BRA   :L1C
:ERR1       JSR   CROUT
            JSR   BELL
:SPIN       BRA   :SPIN
:S1         LDA   OPENPL+5         ; File reference number
            STA   READPL+1
:L2         PLP
            PHP
            BCS   :L2A             ; Loading to aux, skip dots
            LDA   #'.'+$80         ; Print progress dots
            JSR   COUT1
:L2A        JSR   RDFILE           ; Read file block by block
            BCS   :CLOSE           ; EOF (0 bytes left) or some error
            LDA   #<BLKBUF         ; Source start addr -> A1L,A1H
            STA   A1L
            LDA   #>BLKBUF
            STA   A1H
            LDA   #<BLKBUFEND      ; Source end addr -> A2L,A2H
            STA   A2L
            LDA   #>BLKBUFEND
            STA   A2H
            LDA   :ADDRL           ; Dest in aux -> A4L, A4H
            STA   A4L
            LDA   :ADDRH
            LDX   :BLOCKS
:L3         CPX   #$00
            BEQ   :S2
            INC
            INC
            DEX
            BRA   :L3
:S2         STA   A4H
            PLP                    ; Recover carry flag
            PHP
            BCS   :TOAUX
            JSR   MEMCPY           ; Destination in main mem
            BRA   :S3
:TOAUX      JSR   AUXMOVE          ; Carry already set (so to aux)
:S3         INC   :BLOCKS
            BRA   :L2
:CLOSE      LDA   OPENPL+5         ; File reference number
            STA   CLSPL+1
            JSR   CLSFILE
            JSR   CROUT
            PLP
            CLC                    ; CC=Ok
            RTS
:ADDRL      DB    $00              ; Destination address (LSB)
:ADDRH      DB    $00              ; Destination address (MSB)
:BLOCKS     DB    $00              ; Counter for blocks read
:LEN        DB    $00              ; Length of filename
:CANTOPEN   ASC   "Unable to open "
            DB    $00





