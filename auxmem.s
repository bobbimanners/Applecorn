* AUXMEM.S
* (c) Bobbi 2021 GPLv3
* BBC Micro 'virtual machine' in Apple //e aux memory

ZP1         EQU   $90                        ; $90-$9f are Econet space
                                             ; so safe to use
ZP2         EQU   $92

ZP3         EQU   $94

ROW         EQU   $96                        ; Cursor row
COL         EQU   $97                        ; Cursor column
STRTBCKL    EQU   $9D
STRTBCKH    EQU   $9E
WARMSTRT    EQU   $9F                        ; Cold or warm start

* $00-$8F Language workspace
* $90-$9F Network workspace
* $A0-$A7 NMI workspace
* $A8-$AF Non-MOS *command workspace
* $B0-$BF Temporary filing system workspace
* $C0-$CF Persistant filing system workspace
* $D0-$DF VDU driver workspace
* $E0-$EE Internal MOS workspace
* $EF-$FF MOS API workspace

OSAREG      EQU   $EF
OSXREG      EQU   $F0
OSYREG      EQU   $F1
OSCTRL      EQU   OSXREG
OSLPTR      EQU   $F2

FAULT       EQU   $FD                        ; Error message pointer
ESCFLAG     EQU   $FF                        ; Escape status
BRKV        EQU   $202                       ; BRK vector
CLIV        EQU   $208                       ; OSCLI vector
BYTEV       EQU   $20A                       ; OSBYTE vector
WORDV       EQU   $20C                       ; OSWORD vector
WRCHV       EQU   $20E                       ; OSWRCH vector
RDCHV       EQU   $210                       ; OSRDCH vector
FILEV       EQU   $212                       ; OSFILE vector
ARGSV       EQU   $214                       ; OSARGS vector
BGETV       EQU   $216                       ; OSBGET vector
BPUTV       EQU   $218                       ; OSBPUT vector
GBPBV       EQU   $21A                       ; OSGBPB vector
FINDV       EQU   $21C                       ; OSFIND vector
FSCV        EQU   $21E                       ; FSCV misc file ops
OSFILECB    EQU   $2EE                       ; OSFILE control block
MAGIC       EQU   $BC                        ; Arbitrary value

MOSSHIM
            ORG   AUXMOS                     ; MOS shim implementation

*
* Shim code to service Acorn MOS entry points using
* Apple II monitor routines
* This code is initially loaded into aux mem at AUXMOS1
* Then relocated into aux LC at AUXMOS by MOSINIT
*
* Initially executing at $3000 until copied to $D000

MOSINIT     STA   $C005                      ; Make sure we are writing aux
            STA   $C000                      ; Make sure 80STORE is off

            LDA   $C08B                      ; LC RAM Rd/Wt, 1st 4K bank
            LDA   $C08B

            LDA   WARMSTRT                   ; Don't relocate on restart
            CMP   #MAGIC
            BEQ   :NORELOC

            LDA   #<AUXMOS1                  ; Relocate MOS shim
            STA   A1L
            LDA   #>AUXMOS1
            STA   A1H
            LDA   #<EAUXMOS1
            STA   A2L
            LDA   #>EAUXMOS1
            STA   A2H
            LDA   #<AUXMOS
            STA   A4L
            LDA   #>AUXMOS
            STA   A4H
:L1         LDA   (A1L)
            STA   (A4L)
            LDA   A1H
            CMP   A2H
            BNE   :S1
            LDA   A1L
            CMP   A2L
            BNE   :S1
            BRA   :S4
:S1         INC   A1L
            BNE   :S2
            INC   A1H
:S2         INC   A4L
            BNE   :S3
            INC   A4H
:S3         BRA   :L1

:S4         LDA   #<MOSVEC-MOSINIT+AUXMOS1
            STA   A1L
            LDA   #>MOSVEC-MOSINIT+AUXMOS1
            STA   A1H
            LDA   #<MOSVEND-MOSINIT+AUXMOS1
            STA   A2L
            LDA   #>MOSVEND-MOSINIT+AUXMOS1
            STA   A2H
            LDA   #<MOSAPI
            STA   A4L
            LDA   #>MOSAPI
            STA   A4H
:L2         LDA   (A1L)
            STA   (A4L)
            LDA   A1H
            CMP   A2H
            BNE   :S5
            LDA   A1L
            CMP   A2L
            BNE   :S5
            BRA   :S8
:S5         INC   A1L
            BNE   :S6
            INC   A1H
:S6         INC   A4L
            BNE   :S7
            INC   A4H
:S7         BRA   :L2

:NORELOC
:S8         STA   $C00D                      ; 80 col on
            STA   $C003                      ; Alt charset off
            STA   $C055                      ; PAGE2

            STZ   ROW
            STZ   COL
            JSR   CLEAR

            STZ   ESCFLAG

            LDX   #$35
:INITPG2    LDA   DEFVEC,X
            STA   $200,X
            DEX
            BPL   :INITPG2

            LDA   #<:HELLO
            LDY   #>:HELLO
            JSR   PRSTR

            LDA   #$09                       ; Print language name at $8009
            LDY   #$80
            JSR   PRSTR
            JSR   OSNEWL
            JSR   OSNEWL

            LDA   WARMSTRT
            CMP   #MAGIC
            BNE   :S9
            LDA   #<:OLDM
            LDY   #>:OLDM
            JSR   PRSTR

:S9         LDA   #MAGIC                     ; So we do not reloc again
            STA   WARMSTRT

            CLC                              ; CLC=Entered from RESET
            LDA   #$01                       ; $01=Entering application code
            JMP   AUXADDR                    ; Start Acorn ROM
* No return
:HELLO      ASC   'Applecorn MOS v0.01'
            DB    $0D,$0D,$00
:OLDM       ASC   '(Use OLD to recover any program)'
            DB    $0D,$0D,$00

* Clear to EOL
CLREOL      LDA   ROW
            ASL
            TAX
            LDA   SCNTAB,X                   ; LSB of row
            STA   ZP1
            LDA   SCNTAB+1,X                 ; MSB of row
            STA   ZP1+1
            LDA   COL
            PHA
:L1         LDA   COL
            LSR
            TAY
            BCC   :S1
            STA   $C004                      ; Write main mem
:S1         LDA   #" "
            STA   (ZP1),Y
            STA   $C005                      ; Write aux mem
            LDA   COL
            CMP   #79
            BEQ   :S2
            INC   COL
            BRA   :L1
:S2         PLA
            STA   COL
            RTS

* Clear the screen
CLEAR       STZ   ROW
            STZ   COL
:L1         JSR   CLREOL
:S2         LDA   ROW
            CMP   #23
            BEQ   :S3
            INC   ROW
            BRA   :L1
:S3         STZ   ROW
            STZ   COL
            RTS

* Print string pointed to by X,Y to the screen
OUTSTR      TXA

* Print string pointed to by A,Y to the screen
PRSTR       STA   ZP3+0                      ;  String in A,Y
            STY   ZP3+1
:L1         LDA   (ZP3)                      ; Ptr to string in ZP3
            BEQ   :S1
            JSR   OSASCI
            INC   ZP3
            BNE   :L1
            INC   ZP3+1
            BRA   :L1
:S1         RTS

* Print XY in hex
OUT2HEX     TYA
            JSR   OUTHEX
            TAX                              ; Continue into OUTHEX

* Print hex byte in A
OUTHEX      PHA
            LSR
            LSR
            LSR
            LSR
            AND   #$0F
            JSR   PRNIB
            PLA
            AND   #$0F                       ; Continue into PRNIB
;           JSR   PRNIB
;           RTS

* Print hex nibble in A
PRNIB       CMP   #$0A
            BCC   :S1
            CLC                              ; >= $0A
            ADC   #'A'-$0A
            JSR   OSWRCH
            RTS
:S1         ADC   #'0'                       ; < $0A
            JMP   OSWRCH

RDROM       LDA   #<OSRDRMM
            LDY   #>OSRDRMM
            JMP   PRSTR
OSRDRMM     ASC   'OSRDDRM.'
            DB    $00

EVENT       LDA   #<OSEVENM
            LDY   #>OSEVENM
            JMP   PRSTR
OSEVENM     ASC   'OSEVEN.'
            DB    $00

GSINTGO     LDA   #<OSINITM
            LDY   #>OSINITM
            JMP   PRSTR
OSINITM     ASC   'GSINITM.'
            DB    $00

GSRDGO      LDA   #<OSREADM
            LDY   #>OSREADM
            JMP   PRSTR
OSREADM     ASC   'GSREAD.'
            DB    $00

* OSFIND - open/close a file for byte access
FINDHND     PHX
            PHY
            PHA
            STX   ZP1                        ; Points to filename
            STY   ZP1+1

            CMP   #$00                       ; A=$00 = close
            BEQ   :CLOSE

            PHA
            LDA   #<MOSFILE+1
            STA   ZP2
            LDA   #>MOSFILE+1
            STA   ZP2+1
            LDY   #$00
:L1         LDA   (ZP1),Y
            STA   $C004                      ; Write main
            STA   (ZP2),Y
            STA   $C005                      ; Write aux
            INY
            CMP   #$0D                       ; Carriage return
            BNE   :L1
            DEY
            STA   $C004                      ; Write main
            STY   MOSFILE                    ; Length (Pascal string)
            STA   $C005                      ; Write aux
            PLA                              ; Recover options
            >>>   XF2MAIN,OFILE

:CLOSE      STA   $C004                      ; Write main
            STY   MOSFILE                    ; Write file number
            STA   $C005                      ; Write aux
            >>>   XF2MAIN,CFILE

OSFINDRET
            >>>   ENTAUX
            PLY                              ; Value of A on entry
            CPY   #$00                       ; Was it close?
            BNE   :S1
            TYA                              ; Preserve A for close
:S1         PLY
            PLX
            RTS

* OSFSC - miscellanous file system calls
OSFSC       LDA   #<OSFSCM
            LDY   #>OSFSCM
            JSR   PRSTR
            RTS
OSFSCM      ASC   'OSFSC.'
            DB    $00

* OSGBPB - Get/Put a block of bytes to/from an open file
GBPBHND     LDA   #<OSGBPBM
            LDY   #>OSGBPBM
            JMP   PRSTR
OSGBPBM     ASC   'OSGBPB.'
            DB    $00

* OSBPUT - write one byte to an open file
BPUTHND     PHX
            PHY
            PHA                              ; Stash char to write
            STA   $C004                      ; Write to main memory
            STY   MOSFILE                    ; File reference number
            STA   $C005                      ; Write to aux memory
            >>>   XF2MAIN,FILEPUT
OSBPUTRET
            >>>   ENTAUX
            CLC                              ; Means no error
            PLA
            PLY
            PLX
            RTS

* OSBGET - read one byte from an open file
BGETHND     PHX
            PHY
            STA   $C004                      ; Write to main memory
            STY   MOSFILE                    ; File ref number
            STA   $C005                      ; Write to aux memory
            >>>   XF2MAIN,FILEGET
OSBGETRET
            >>>   ENTAUX
            CLC                              ; Means no error
            CPY   #$00                       ; Check error status
            BEQ   :S1
            SEC                              ; Set carry for error
:S1         PLY
            PLX
            RTS

* OSARGS - adjust file arguments
* On entry, A=action
*           X=>4 byte ZP control block
*           Y=file handle
ARGSHND     PHA
            PHX
            PHY
            CPY   #$00
            BNE   :HASFILE
            CMP   #$00                       ; Y=0,A=0 => current file sys
            BNE   :S1
            PLY
            PLX
            PLA
            LDA   #$04                       ; DFS
            RTS
:S1         CMP   #$01                       ; Y=0,A=1 => addr of CLI
            BNE   :S2
* TODO: Implement this for *RUN and *command
            JSR   BEEP
            BRA   :IEXIT
:S2         CMP   #$FF                       ; Y=0,A=FF => flush all files
            BNE   :IEXIT
            STA   $C004                      ; Write main memory
            STZ   MOSFILE                    ; Zero means flush all
            STA   $C005                      ; Write aux memory
            BRA   :IFLUSH
:HASFILE    STA   $C004                      ; Write main memory
            STY   MOSFILE                    ; File ref num
            STX   MOSFILE+1                  ; Pointer to ZP control block
            STA   $C005                      ; Write aux memory
            CMP   #$00                       ; Y!=0,A=0 => read seq ptr
            BNE   :S3
            STA   $C004                      ; Write main
            STZ   MOSFILE+2                  ; 0 means get pos
            STA   $C005                      ; Write aux
            >>>   XF2MAIN,TELL
:IEXIT      BRA   :IEXIT2
:IFLUSH     BRA   :FLUSH
:S3         CMP   #$01                       ; Y!=0,A=1 => write seq ptr
            BNE   :S4
            STA   $C004                      ; Write main
            LDA   $00,X
            STA   MOSFILE+2
            LDA   $01,X
            STA   MOSFILE+3
            LDA   $02,X
            STA   MOSFILE+4
            STA   $C005                      ; Write aux
            >>>   XF2MAIN,SEEK
:IEXIT2     BRA   :EXIT
:S4         CMP   #$02                       ; Y!=0,A=2 => read file len
            BNE   :S5
            STA   $C004                      ; Write main
            STA   MOSFILE+2                  ; Non-zero means get len
            STA   $C005                      ; Write aux
            >>>   XF2MAIN,TELL
:S5         CMP   #$FF                       ; Y!=0,A=FF => flush file
            BNE   :EXIT
:FLUSH      >>>   XF2MAIN,FLUSH
:EXIT       PLY
            PLX
            PLA
            RTS
OSARGSRET
            >>>   ENTAUX
            PLY
            PLX
            PLA
            RTS

* OSFILE - perform actions on entire files
* On entry, A=action
*           XY=>control block
* On exit,  A=preserved if unimplemented
*           A=0 object not found (not load/save)
*           A=1 file found
*           A=2 directory found
*           XY  preserved
*               control block updated
FILEHND     PHX
            PHY
            PHA

            STX   ZP1                        ; LSB of parameter block
            STY   ZP1+1                      ; MSB of parameter block
            LDA   #<FILEBLK
            STA   ZP2
            LDA   #>FILEBLK
            STA   ZP2+1
            LDY   #$00                       ; Copy to FILEBLK in main mem
:L1         LDA   (ZP1),Y
            STA   $C004                      ; Write main
            STA   (ZP2),Y
            STA   $C005                      ; Write aux
            INY
            CPY   #$12
            BNE   :L1

            LDA   (ZP1)                      ; Pointer to filename->ZP2
            STA   ZP2
            LDY   #$01
            LDA   (ZP1),Y
            STA   ZP2+1
            LDA   #<MOSFILE+1
            STA   ZP1
            LDA   #>MOSFILE+1
            STA   ZP1+1
            LDY   #$00
:L2         LDA   (ZP2),Y
            STA   $C004                      ; Write main
            STA   (ZP1),Y
            STA   $C005                      ; Write aux
            INY
            CMP   #$21                       ; Space or Carriage return
            BCS   :L2
            DEY
            STA   $C004                      ; Write main
            STY   MOSFILE                    ; Length (Pascal string)
            STA   $C005                      ; Write aux

            PLA                              ; Get action back
            PHA
            BEQ   :S1                        ; A=00 -> SAVE
            CMP   #$FF
            BEQ   :S2                        ; A=FF -> LOAD

            LDA   #<OSFILEM                  ; If not implemented, print msg
            LDY   #>OSFILEM
            JSR   PRSTR
            PLA
            PHA
            JSR   OUTHEX
            LDA   #<OSFILEM2
            LDY   #>OSFILEM2
            JSR   PRSTR
            PLA                              ; Not implemented, return unchanged
            PLY
            PLX
            RTS

:S1         >>>   XF2MAIN,SAVEFILE
:S2         >>>   XF2MAIN,LOADFILE

OSFILERET
            >>>   ENTAUX
            PLY                              ; Value of A on entry
            CPY   #$FF                       ; LOAD
            BNE   :S4                        ; Deal with return from SAVE

            CMP   #$01                       ; No file found
            BNE   :SL1
            BRK
            DB    $D6                        ; $D6 = Object not found
            ASC   'File not found'
            BRK

:SL1        CMP   #$02                       ; Read error
            BNE   :SL2
            BRK
            DB    $CA                        ; $CA = Premature end, 'Data lost'
            ASC   'Read error'
            BRK

:SL2        LDA   #$01                       ; Return code - file found
            BRA   :EXIT

:S4         CPY   #$00                       ; Return from SAVE
            BNE   :S6
            CMP   #$01                       ; Unable to create or open
            BNE   :SS1
            BRK
            DB    $C0                        ; $C0 = Can't create file to save
            ASC   'Can'
            DB    $27
            ASC   't save file'
            BRK

:SS1        CMP   #$02                       ; Unable to write
            BNE   :S6
            BRK
            DB    $CA                        ; $CA = Premature end, 'Data lost'
            ASC   'Write error'
            BRK

:S6         LDA   #$00
:EXIT       PLY
            PLX
            RTS

OSFILEM     ASC   'OSFILE($'
            DB    $00
OSFILEM2    ASC   ')'
            DB    $00

RDCHHND     PHX
            PHY
            JSR   GETCHRC
            STA   OLDCHAR
:L1         LDA   CURS+1                     ; Skip unless CURS=$8000
            CMP   #$80
            BNE   :S1
            LDA   CURS
            BNE   :S1

            STZ   CURS
            STZ   CURS+1
            LDA   CSTATE
            ROR
            BCS   :S2
            LDA   #'_'
            BRA   :S3
:S2         LDA   OLDCHAR
:S3         JSR   PRCHRC
            INC   CSTATE
:S1         INC   CURS
            BNE   :S4
            INC   CURS+1
:S4         LDA   $C000                      ; Keyboard data/strobe
            AND   #$80
            BEQ   :L1
            LDA   OLDCHAR                    ; Erase cursor
            JSR   PRCHRC
            LDA   $C000
            AND   #$7F
            STA   $C010                      ; Clear strobe
            PLY
            PLX
            CMP   #$1B                       ; Escape pressed?
            BNE   :S5
            ROR   $FF                        ; Set ESCFLG
            SEC                              ; Return CS
            RTS
:S5         CLC
            RTS
CURS        DW    $0000                      ; Counter
CSTATE      DB    $00                        ; Cursor on or off
OLDCHAR     DB    $00                        ; Char under cursor

* Print char in A at ROW,COL
PRCHRC      PHA
            LDA   ROW
            ASL
            TAX
            LDA   SCNTAB,X                   ; LSB of row address
            STA   ZP1
            LDA   SCNTAB+1,X                 ; MSB of row address
            STA   ZP1+1
            LDA   COL
            LSR
            TAY
            BCC   :S1
            STA   $C004                      ; Write main memory
:S1         PLA
            ORA   #$80
            STA   (ZP1),Y                    ; Screen address
            STA   $C005                      ; Write aux mem again
            RTS

* Return char at ROW,COL in A
GETCHRC     LDA   ROW
            ASL
            TAX
            LDA   SCNTAB,X
            STA   ZP1
            LDA   SCNTAB+1,X
            STA   ZP1+1
            LDA   COL
            LSR
            TAY
            BCC   :S1
            STA   $C002                      ; Read main memory
:S1         LDA   (ZP1),Y
            STX   $C003                      ; Read aux mem again
            RTS

* Perform backspace & delete operation
BACKSPC     LDA   COL
            BEQ   :S1
            DEC   COL
            BRA   :S2
:S1         LDA   ROW
            BEQ   :S3
            DEC   ROW
            STZ   COL
:S2         LDA   #' '
            JSR   PRCHRC
:S3         RTS

* Perform backspace/cursor left operation
NDBSPC      LDA   COL
            BEQ   :S1
            DEC   COL
            BRA   :S3
:S1         LDA   ROW
            BEQ   :S3
            DEC   ROW
            STZ   COL
:S3         RTS

* Perform cursor right operation
CURSRT      LDA   COL
            CMP   #78
            BCS   :S1
            INC   COL
            RTS
:S1         LDA   ROW
            CMP   #22
            BCS   :S2
            INC   ROW
            STZ   COL
:S2         RTS

* OSWRCH handler
* All registers preserved
WRCHHND     PHA
            PHX
            PHY
* Check any output redirections
* Check any spool output
            JSR   OUTCHAR
* Check any printer output
            PLY
            PLX
            PLA
            RTS

* Output character to VDU driver
* All registers trashable
OUTCHAR     CMP   #$00                       ; NULL
            BNE   :T1
            BRA   :IDONE
:T1         CMP   #$07                       ; BELL
            BNE   :T2
            JSR   BEEP
            BRA   :IDONE
:T2         CMP   #$08                       ; Backspace
            BNE   :T3
            JSR   NDBSPC
            BRA   :DONE
:T3         CMP   #$09                       ; Cursor right
            BNE   :T4
            JSR   CURSRT
            BRA   :DONE
:T4         CMP   #$0A                       ; Linefeed
            BNE   :T5
            LDA   ROW
            CMP   #23
            BEQ   :SCROLL
            INC   ROW
:IDONE      BRA   :DONE
:T5         CMP   #$0B                       ; Cursor up
            BNE   :T6
            LDA   ROW
            BEQ   :DONE
            DEC   ROW
            BRA   :DONE
:T6         CMP   #$0D                       ; Carriage return
            BNE   :T7
            JSR   CLREOL
            STZ   COL
            BRA   :DONE
:T7         CMP   #$0C                       ; Ctrl-L
            BNE   :T8
            JSR   CLEAR
            BRA   :DONE
:T8         CMP   #$1E                       ; Home
            BNE   :T9
            STZ   ROW
            STZ   COL
            BRA   :DONE
:T9         CMP   #$7F                       ; Delete
            BNE   :T10
            JSR   BACKSPC
            BRA   :DONE
:T10        JSR   PRCHRC
            LDA   COL
            CMP   #79
            BNE   :S2
            STZ   COL
            LDA   ROW
            CMP   #23
            BEQ   :SCROLL
            INC   ROW
            BRA   :DONE
:S2         INC   COL
            BRA   :DONE
:SCROLL     JSR   SCROLL
            STZ   COL
            JSR   CLREOL
:DONE       RTS

* Scroll whole screen one line
SCROLL      LDA   #$00
:L1         PHA
            JSR   SCR1LINE
            PLA
            INC
            CMP   #23
            BNE   :L1
            RTS

* Copy line A+1 to line A
SCR1LINE    ASL                              ; Dest addr->ZP1
            TAX
            LDA   SCNTAB,X
            STA   ZP1
            LDA   SCNTAB+1,X
            STA   ZP1+1
            INX                              ; Source addr->ZP2
            INX
            LDA   SCNTAB,X
            STA   ZP2
            LDA   SCNTAB+1,X
            STA   ZP2+1
            LDY   #$00
:L1         LDA   (ZP2),Y
            STA   (ZP1),Y
            STA   $C002                      ; Read main mem
            STA   $C004                      ; Write main
            LDA   (ZP2),Y
            STA   (ZP1),Y
            STA   $C003                      ; Read aux mem
            STA   $C005                      ; Write aux mem
            INY
            CPY   #40
            BNE   :L1
            RTS

* Addresses of screen rows in PAGE2
SCNTAB      DW    $800,$880,$900,$980,$A00,$A80,$B00,$B80
            DW    $828,$8A8,$928,$9A8,$A28,$AA8,$B28,$BA8
            DW    $850,$8D0,$950,$9D0,$A50,$AD0,$B50,$BD0

* OSWORD HANDLER
* On entry, A=action
*           XY=>control block
* On exit,  All preserved (except OSWORD 0)
*           control block updated
WORDHND     STX   OSCTRL+0                   ; Point to control block
            STY   OSCTRL+1
            CMP   #$00                       ; OSWORD 0 read a line
            BNE   :S01
            JMP   OSWORD0
:S01        CMP   #$01                       ; OSWORD 1 read system clock
            BNE   :S02
            JMP   OSWORD1
:S02        CMP   #$02                       ; OSWORD 2 write system clock
            BNE   :S05
            JMP   OSWORD2
:S05        CMP   #$05                       ; OSWORD 5 read I/O memory
            BNE   :S06
            JMP   OSWORD5
:S06        CMP   #$06                       ; OSWORD 6 write I/O memory
            BNE   :UNSUPP

:UNSUPP     PHA
            LDA   #<:OSWORDM                 ; Unimplemented, print msg
            LDY   #>:OSWORDM
            JSR   PRSTR
            PLA
            PHA
            JSR   OUTHEX
            LDA   #<:OSWRDM2
            LDY   #>:OSWRDM2
            JSR   PRSTR
            PLA
            RTS
:OSWORDM    ASC   'OSWORD('
            DB    $00
:OSWRDM2    ASC   ')'
            DB    $00

* OSRDLINE - Read a line of input
* On entry, (OSCTRL)=>control block
* On exit,  Y=length of line, offset to <cr>
*           CC = Ok, CS = Escape
*
OSWORD0     LDY   #$04
:RDLNLP1    LDA   (OSCTRL),Y                 ; Copy MAXLEN, MINCH, MAXCH to workspace
            STA   :MAXLEN-2,Y
            DEY
            CPY   #$02
            BCS   :RDLNLP1
:RDLNLP2    LDA   (OSCTRL),Y                 ; (ZP2)=>line buffer
            STA   ZP2,Y
            DEY
            BPL   :RDLNLP2
            INY
            BRA   :L1

:BELL       LDA   #$07                       ; BELL
:R1         DEY
:R2         INY                              ; Step to next character
:R3         JSR   OSWRCH                     ; Output character

:L1         JSR   OSRDCH
            BCS   :EXIT
            CMP   #$08                       ; Backspace
            BEQ   :RDDEL
            CMP   #$7F                       ; Delete
            BEQ   :RDDEL
            CMP   #$15                       ; Ctrl-U
            BNE   :S2
            INY                              ; Balance first DEY
:RDCTRLU    DEY                              ; Back up one character
            BEQ   :L1                        ; Beginning of line
            LDA   #$7F                       ; Delete
            JSR   OSWRCH
            JMP   :RDCTRLU
:RDDEL      TYA
            BEQ   :L1                        ; Beginning of line
            DEY                              ; Back up one character
            LDA   #$7F                       ; Delete
            BNE   :R3                        ; Jump back to delete

:S2         STA   (ZP2),Y
            CMP   #$0D                       ; CR
            BEQ   :S3
            CPY   :MAXLEN
            BCS   :BELL                      ; Too long, beep
            CMP   :MINCH
            BCC   :R1                        ; <MINCHAR, don't step to next
            CMP   :MAXCH
            BEQ   :R2                        ; =MAXCHAR, step to next
            BCC   :R2                        ; <MAXCHAR, step to next
            BCS   :R1                        ; >MAXCHAR, don't step to next

:S3         JSR   OSNEWL
:EXIT       LDA   ESCFLAG
            ROL
            RTS
:MAXLEN     DB    $00
:MINCH      DB    $00
:MAXCH      DB    $00

OSWORD1     LDA   #$00
            LDY   #$00
:L1         STA   (OSCTRL),Y
            INY
            CPY   #$05
            BNE   :L1
            RTS

OSWORD2     RTS                              ; Nothing to do

OSWORD5     LDA   (OSCTRL)
            LDY   #$04
            STA   (OSCTRL),Y
            RTS

OSWORD6     LDA   #$04
            LDA   (OSCTRL),Y
            STA   (OSCTRL)
            RTS

* OSBYTE HANDLER
* On entry, A=action
*           X=first parameter
*           Y=second parameter if A>$7F
* On exit,  A=preserved
*           X=first returned result
*           Y=second returned result if A>$7F
*           Cy=any returned status if A>$7F
BYTEHND     PHA
            JSR   BYTECALLER
            PLA
            RTS
BYTECALLER
            CMP   #$00                       ; $00 = identify MOS version
            BNE   :S02
            LDX   #$0A
            RTS

:S02        CMP   #$02                       ; $02 = select input stream
            BNE   :S03
            RTS                              ; Nothing to do

:S03        CMP   #$03                       ; $03 = select output stream
            BNE   :S0B
            RTS                              ; Nothing to do

:S0B        CMP   #$0B                       ; $0B = set keyboard delay
            BNE   :S0C
            RTS                              ; Nothing to do

:S0C        CMP   #$0C                       ; $0C = set keyboard rate
            BNE   :S0F
            RTS                              ; Nothing to do

:S0F        CMP   #$0F                       ; $0F = flush buffers
            BNE   :S7C
            RTS                              ; Nothing to do

:S7C        CMP   #$7C                       ; $7C = clear escape condition
            BNE   :S7D
            LDA   ESCFLAG
            AND   #$7F                       ; Clear MSbit
            STA   ESCFLAG
            RTS

:S7D        CMP   #$7D                       ; $7D = set escape condition
            BNE   :S7E
            ROR   ESCFLAG
            RTS

:S7E        CMP   #$7E                       ; $7E = ack detection of ESC
            BNE   :S7F
            LDA   ESCFLAG
            AND   #$7F                       ; Clear MSB
            STA   ESCFLAG
            LDX   #$FF                       ; Means ESC condition cleared
            RTS

:S7F        CMP   #$7F                       ; $7F = check for EOF
            BNE   :S80
            PHY
            JSR   CHKEOF
            PLY
            RTS

:S80        CMP   #$80                       ; $80 = read ADC or get buf stat
            BNE   :S81
            CPX   #$00                       ; X<0 => info about buffers
            BMI   :S80BUF                    ; X>=0 read ADC info
            LDX   #$00                       ; ADC - just return 0
            LDY   #$00                       ; ADC - just return 0
            RTS
:S80BUF     CPX   #$FF                       ; Kbd buf
            BEQ   :S80KEY
            CPX   #$FE                       ; RS423
            BEQ   :NONE
:ONE        LDX   #$01                       ; For outputs, 1 char free
            RTS
:S80KEY     LDX   $C000                      ; Keyboard data/strobe
            AND   #$80
            BEQ   :NONE
            BRA   :ONE
:NONE       LDX   #$00                       ; No chars in buf
            RTS

:S81        CMP   #$81                       ; $81 = Read key with time lim
            BNE   :S82
            JSR   GETKEY
            RTS

:S82        CMP   #$82                       ; $82 = read high order address
            BNE   :S83
            LDY   #$FF                       ; $FFFF for I/O processor
            LDX   #$FF
            RTS

:S83        CMP   #$83                       ; $83 = read bottom of user mem
            BNE   :S84
            LDY   #$0E                       ; $0E00
            LDX   #$00
            RTS

:S84        CMP   #$84                       ; $84 = read top of user mem
            BNE   :S85
            LDY   #$80
            LDX   #$00
            RTS

:S85        CMP   #$85                       ; $85 = top user mem for mode
            BNE   :S86
            LDY   #$80
            LDX   #$00
            RTS

:S86        CMP   #$86                       ; $86 = read cursor pos
            BNE   :S8B
            LDY   ROW
            LDX   COL
            RTS

:S8B        CMP   #$8B                       ; $8B = *OPT
            BNE   :S8E
* TODO: Could implement some FS options here
*       messages on/off, error behaviour
            RTS                              ; Nothing to do (yet)

:S8E        CMP   #$8E                       ; $8E = Enter language ROM
            BNE   :SDA

            LDA   #$09                       ; Print language name at $8009
            LDY   #$80
            JSR   PRSTR
            JSR   OSNEWL
            JSR   OSNEWL

            CLC                              ; TODO: CLC or SEC?
            LDA   #$01
            JMP   AUXADDR

:SDA        CMP   #$DA                       ; $DA = clear VDU queue
            BNE   :SEA
            RTS

:SEA        CMP   #$EA                       ; $EA = Tube presence
            BNE   :UNSUPP
            LDX   #$00                       ; No tube
            RTS

:UNSUPP     PHX
            PHY
            PHA
            LDA   #<OSBYTEM
            LDY   #>OSBYTEM
            JSR   PRSTR
            PLA
            JSR   OUTHEX
            LDA   #<OSBM2
            LDY   #>OSBM2
            JSR   PRSTR
            PLY
            PLX
            RTS

OSBYTEM     ASC   'OSBYTE($'
            DB    $00
OSBM2       ASC   ').'
            DB    $00

* OSCLI HANDLER
* On entry, XY=>command string
CLIHND      PHX
            PHY
            STX   ZP1+0                      ; Pointer to CLI
            STY   ZP1+1
:L1         LDA   (ZP1)
            CMP   #'*'                       ; Trim any leading stars
            BEQ   :NEXT
            CMP   #' '                       ; Trim any leading spaces
            BEQ   :NEXT
            BRA   :TRIMMED
:NEXT       INC   ZP1
            BNE   :L1
            INC   ZP1+1
            BRA   :L1
:TRIMMED    CMP   #'|'                       ; | is comment
            BEQ   :IEXIT
            CMP   #$0D                       ; Carriage return
            BEQ   :IEXIT
            LDA   #<:QUIT
            STA   ZP2
            LDA   #>:QUIT
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S1
            JSR   STARQUIT
            BRA   :IEXIT
:S1         LDA   #<:CAT
            STA   ZP2
            LDA   #>:CAT
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S2
            JSR   STARCAT
            BRA   :IEXIT
:S2         LDA   #<:CAT2
            STA   ZP2
            LDA   #>:CAT2
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S3
            JSR   STARCAT
            BRA   :IEXIT
:S3         LDA   #<:DIR
            STA   ZP2
            LDA   #>:DIR
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S4
            JSR   STARDIR
            BRA   :IEXIT
:S4         LDA   #<:LOAD
            STA   ZP2
            LDA   #>:LOAD
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S5
            JSR   STARLOAD
            BRA   :EXIT
:S5         LDA   #<:SAVE
            STA   ZP2
            LDA   #>:SAVE
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S6
            JSR   STARSAVE
:IEXIT      BRA   :EXIT
:S6         LDA   #<:HELP
            STA   ZP2
            LDA   #>:HELP
            STA   ZP2+1
            JSR   STRCMP
            BCS   :ASKROM
            JSR   STARHELP
            BRA   :EXIT
:ASKROM     LDA   $8003                      ; Check service entry
            CMP   #$4C                       ; Not a JMP?
            BNE   :UNSUPP                    ; Only BASIC has no srvc entry
            LDA   ZP1                        ; String in (OSLPTR),Y
            STA   OSLPTR
            LDA   ZP1+1
            STA   OSLPTR+1
            LDY   #$00
            LDA   #$04                       ; Service 4 Unrecognized Cmd
            LDX   #$0F                       ; ROM slot
            JSR   $8003                      ; Service entry point

:UNSUPP     LDA   #<:OSCLIM
            LDY   #>:OSCLIM
            JSR   PRSTR
            PLY
            PLX
            STX   ZP3
            STY   ZP3+1
            LDY   #$00
:PL1        LDA   (ZP3),Y
            CMP   #$0D
            BEQ   :PS1
            CMP   #$00
            BEQ   :PS1
            JSR   $FFEE                      ; OSWRCH
            INY
            BRA   :PL1
:PS1        LDA   #<:OSCLIM2
            LDY   #>:OSCLIM2
            JSR   PRSTR
            RTS
:EXIT       PLY
            PLX
            RTS
:QUIT       ASC   'QUIT'
            DB    $00
:CAT        ASC   'CAT'
            DB    $00
:CAT2       ASC   '.'
            DB    $00
:DIR        ASC   'DIR'
            DB    $00
:LOAD       ASC   'LOAD'
            DB    $00
:SAVE       ASC   'SAVE'
            DB    $00
:HELP       ASC   'HELP'
            DB    $00
:OSCLIM     ASC   'OSCLI('
            DB    $00
:OSCLIM2    ASC   ').'
            DB    $00

* String comparison for OSCLI
* Compares str in ZP1 with null-terminated str in ZP2
* Clear carry if match, set carry otherwise
* Leaves (ZP1),Y pointing to char after verb
STRCMP      LDY   #$00
:L1         LDA   (ZP2),Y
            BEQ   :PMATCH
            CMP   (ZP1),Y
            BNE   :MISMTCH
            INY
            BRA   :L1
:PMATCH     LDA   (ZP1),Y
            CMP   #$0D
            BEQ   :MATCH
            CMP   #' '
            BEQ   :MATCH
            BRA   :MISMTCH
:MATCH      CLC
            RTS
:MISMTCH    SEC
            RTS

* Print *HELP test
STARHELP    LDA   #<:MSG
            LDY   #>:MSG
            JSR   PRSTR
            LDA   #$09                       ; Language name
            LDY   #$80
            JSR   PRSTR
            LDA   #<:MSG2
            LDY   #>:MSG2
            JSR   PRSTR
            RTS
:MSG        DB    $0D
            ASC   'Applecorn MOS v0.01'
            DB    $0D,$0D,$00
:MSG2       DB    $0D,$00

* Handle *QUIT command
STARQUIT    >>>   XF2MAIN,QUIT

* Handle *CAT / *. command (list directory)
STARCAT     >>>   XF2MAIN,CATALOG
STARCATRET
            >>>   ENTAUX
            RTS

* Print one block of a catalog. Called by CATALOG
* Block is in AUXBLK
PRONEBLK    >>>   ENTAUX
            LDA   AUXBLK+4                   ; Get storage type
            AND   #$E0                       ; Mask 3 MSBs
            CMP   #$E0
            BNE   :NOTKEY                    ; Not a key block
            LDA   #<:DIRM
            LDY   #>:DIRM
            JSR   PRSTR
:NOTKEY     LDA   #$00
:L1         PHA
            JSR   PRONEENT
            PLA
            INC
            CMP   #13                        ; Number of dirents in block
            BNE   :L1
            >>>   XF2MAIN,CATALOGRET
:DIRM       ASC   'Directory: '
            DB    $00

* Print a single directory entry
* On entry: A = dirent index in AUXBLK
PRONEENT    TAX
            LDA   #<AUXBLK+4                 ; Skip pointers
            STA   ZP3
            LDA   #>AUXBLK+4
            STA   ZP3+1
:L1         CPX   #$00
            BEQ   :S1
            CLC
            LDA   #$27                       ; Size of dirent
            ADC   ZP3
            STA   ZP3
            LDA   #$00
            ADC   ZP3+1
            STA   ZP3+1
            DEX
            BRA   :L1
:S1         LDY   #$00
            LDA   (ZP3),Y
            BEQ   :EXIT                      ; Inactive entry
            AND   #$0F                       ; Len of filename
            TAX
            LDY   #$01
:L2         CPX   #$00
            BEQ   :S2
            LDA   (ZP3),Y
            JSR   OSWRCH
            DEX
            INY
            BRA   :L2
:S2         JSR   OSNEWL
:EXIT       RTS

* Consume spaces in command line
* Return C set if no space found, C clear otherwise
* Command line pointer in (ZP1),Y
EATSPC      LDA   (ZP1),Y                    ; Check first char is space
            CMP   #' '
            BNE   :NOTFND
            INY
:L1         LDA   (ZP1),Y                    ; Eat any additional spaces
            CMP   #' '
            BNE   :DONE
            INY
            BRA   :L1
:DONE       CLC
            RTS
:NOTFND     SEC
            RTS

* Consume non-spaces in command line
* Command line pointer in (ZP1),Y
* Returns with carry set if EOL
EATWORD     LDA   (ZP1),Y
            CMP   #' '
            BEQ   :SPC
            CMP   #$0D                       ; Carriage return
            BEQ   :EOL
            INY
            BRA   EATWORD
:SPC        CLC
            RTS
:EOL        SEC
            RTS

* Handle *DIR (directory change) command
* On entry, ZP1 points to command line
STARDIR     JSR   EATSPC                     ; Eat leading spaces
            BCC   :S1                        ; If no space found
            RTS                              ; No argument
:S1         LDX   #$01
:L3         LDA   (ZP1),Y
            CMP   #$0D
            BEQ   :S3
            STA   $C004                      ; Write main
            STA   MOSFILE,X
            STA   $C005                      ; Write aux
            INY
            INX
            BRA   :L3
:S3         DEX
            STA   $C004                      ; Write main
            STX   MOSFILE                    ; Length byte
            STA   $C005                      ; Write aux
            >>>   XF2MAIN,SETPFX
STARDIRRET
            >>>   ENTAUX
            RTS

* Add Y to ZP1 pointer. Clear Y.
ADDZP1Y     CLC
            TYA
            ADC   ZP1
            STA   ZP1
            LDA   #$00
            ADC   ZP1+1
            STA   ZP1+1
            LDY   #$00
            RTS

* Decode ASCII hex digit in A
* Returns with carry set if bad char, C clear otherwise
HEXDIGIT    CMP   #'F'+1
            BCS   :BADCHAR                   ; char > 'F'
            CMP   #'A'
            BCC   :S1
            SEC                              ; 'A' <= char <= 'F'
            SBC   #'A'-10
            CLC
            RTS
:S1         CMP   #'9'+1
            BCS   :BADCHAR                   ; '9' < char < 'A'
            CMP   #'0'
            BCC   :BADCHAR                   ; char < '0'
            SEC                              ; '0' <= char <= '9'
            SBC   #'0'
            CLC
            RTS
:BADCHAR    SEC
            RTS

* Decode hex constant on command line
* On entry, ZP1 points to command line
HEXCONST    LDX   #$00
:L1         STZ   :BUF,X                     ; Clear :BUF
            INX
            CPX   #$04
            BNE   :L1
            LDX   #$00
            LDY   #$00
:L2         LDA   (ZP1),Y                    ; Parse hex digits into
            JSR   HEXDIGIT                   ; :BUF, left aligned
            BCS   :NOTHEX
            STA   :BUF,X
            INY
            INX
            CPX   #$04
            BNE   :L2
            LDA   (ZP1),Y                    ; Peek at next char
:NOTHEX     CPX   #$00                       ; Was it the first digit?
            BEQ   :ERR                       ; If so, bad hex constant
            CMP   #' '                       ; If whitespace, then okay
            BEQ   :OK
            CMP   #$0D
            BEQ   :OK
:ERR        SEC
            RTS
:OK         LDA   :BUF-4,X
            ASL
            ASL
            ASL
            ASL
            ORA   :BUF-3,X
            STA   ADDRBUF+1
            LDA   :BUF-2,X
            ASL
            ASL
            ASL
            ASL
            ORA   :BUF-1,X
            STA   ADDRBUF
            CLC
            RTS
:ZEROPAD    DB    $00,$00,$00
:BUF        DB    $00,$00,$00,$00

ADDRBUF     DW    $0000                      ; Used by HEXCONST

* Handle *LOAD command
* On entry, ZP1 points to command line
STARLOAD    JSR   CLRCB
            JSR   EATSPC                     ; Eat leading spaces
            BCS   :ERR
            JSR   ADDZP1Y                    ; Advance ZP1
            LDA   ZP1                        ; Pointer to filename
            STA   OSFILECB
            LDA   ZP1+1
            STA   OSFILECB+1
            JSR   EATWORD                    ; Advance past filename
            BCS   :NOADDR                    ; No load address given
            LDA   #$0D                       ; Carriage return
            STA   (ZP1),Y                    ; Terminate filename
            INY
            JSR   EATSPC                     ; Eat any whitespace
            JSR   ADDZP1Y                    ; Update ZP1
            JSR   HEXCONST
            BCS   :ERR                       ; Bad hex constant
            LDA   ADDRBUF+1
            JSR   OUTHEX
            LDA   ADDRBUF
            JSR   OUTHEX
            LDA   ADDRBUF
            STA   OSFILECB+2                 ; Load address LSB
            LDA   ADDRBUF+1
            STA   OSFILECB+3                 ; Load address MSB
:OSFILE     LDX   #<OSFILECB
            LDY   #>OSFILECB
            LDA   #$FF                       ; OSFILE load flag
            JSR   OSFILE
:END        RTS
:NOADDR     LDA   #$00                       ; DEBUG DEFAULTS TO 0E00
            STA   OSFILECB+2                 ; FOR NOW!!!!!!!!!!!!!!!
            LDA   #$0E
            STA   OSFILECB+3
            BRA   :OSFILE
:ERR        JSR   BEEP
            RTS

* Handle *SAVE command
* On entry, ZP1 points to command line
STARSAVE    JSR   CLRCB
            JSR   EATSPC                     ; Eat leading space
            BCS   :END
            JSR   ADDZP1Y                    ; Advance ZP1
            LDX   #<OSFILECB
            LDY   #>OSFILECB
            LDA   ZP1                        ; Pointer to filename
            STA   OSFILECB
            LDA   ZP1+1
            STA   OSFILECB+1
            LDA   #$00                       ; DEBUG Save $0E00
            STA   OSFILECB+10
            LDA   #$0E
            STA   OSFILECB+11
            LDA   #$00                       ; DEBUG to $1E00
            STA   OSFILECB+14
            LDA   #$1E
            STA   OSFILECB+15
            LDA   #$00                       ; OSFILE save flag
            JSR   OSFILE
:END        RTS

* Clear OSFILE control block to zeros
CLRCB       LDA   #$00
            LDX   #$00
:L1         STA   OSFILECB,X
            INX
            CPX   #18
            BNE   :L1
            RTS

* Performs OSBYTE $80 function
* Read ADC channel or get buffer status
OSBYTE80    CPX   #$00                       ; X=0 Last ADC channel
            BNE   :S1
            LDX   #$00                       ; Fire button
            LDY   #$00                       ; ADC never converted
            RTS
:S1         BMI   :S2
            LDX   #$00                       ; X +ve, ADC value
            LDY   #$00
            RTS
:S2         CPX   #$FF                       ; X $FF = keyboard buf
            BEQ   :INPUT
            CPX   #$FE                       ; X $FE = RS423 i/p buf
            BEQ   :INPUT
            LDX   #$FF                       ; Spaced remaining in o/p
            RTS
:INPUT      LDX   #$00                       ; Nothing in input buf
            RTS

* Performs OSBYTE $7F EOF function
* File ref number is in X
CHKEOF      STA   $C004                      ; Write main mem
            STX   MOSFILE                    ; File reference number
            STA   $C005                      ; Write aux mem
            >>>   XF2MAIN,FILEEOF
CHKEOFRET
            >>>   ENTAUX
            TAX                              ; Return code -> X
            RTS

* Performs OSBYTE $81 INKEY$ function
* X,Y has time limit
* On exit, CC, Y=$00, X=key - key pressed
*          CS, Y=$FF        - timeout
*          CS, Y=$1B        - escape
GETKEY      TYA
            BMI   NEGKEY                     ; Negative INKEY
:L1         CPX   #$00
            BEQ   :S1
            LDA   $C000                      ; Keyb data/strobe
            AND   #$80
            BNE   :GOTKEY
            JSR   DELAY                      ; 1/100 sec
            DEX
            BRA   :L1
:S1         CPY   #$00
            BEQ   :S2
            DEY
            LDX   #$FF
            BRA   :L1
:S2         LDA   $C000                      ; Keyb data/strobe
            AND   #$80
            BNE   :GOTKEY
            LDY   #$FF                       ; No key, time expired
            SEC
            RTS
:GOTKEY     LDA   $C000                      ; Fetch char
            AND   #$7F
            STA   $C010                      ; Clear strobe
            CMP   #27                        ; Escape
            BEQ   :ESC
            TAX
            LDY   #$00
            CLC
            RTS
:ESC        ROR   ESCFLAG
            LDY   #27                        ; Escape
            SEC
            RTS
NEGKEY      LDX   #$00                       ; Unimplemented
            LDY   #$00
            RTS

* Beep
BEEP        PHA
            PHX
            LDX   #$80
:L1         LDA   $C030
            JSR   DELAY
            INX
            BNE   :L1
            PLX
            PLA
            RTS

* Delay approx 1/100 sec
DELAY       PHX
            PHY
            LDX   #$00
:L1         INX                              ; 2
            LDY   #$00                       ; 2
:L2         INY                              ; 2
            CPY   #$00                       ; 2
            BNE   :L2                        ; 3 (taken)
            CPX   #$02                       ; 2
            BNE   :L1                        ; 3 (taken)
            PLY
            PLX
            RTS

* IRQ/BRK handler
IRQBRKHDLR  PHA
            TXA
            PHA
            CLD
            TSX
            LDA   $103,X                     ; Get PSW from stack
            AND   #$10
            BEQ   :S1                        ; IRQ
            SEC
            LDA   $0104,X
            SBC   #$01
            STA   FAULT
            LDA   $0105,X
            SBC   #$00
            STA   FAULT+1
            PLA
            TAX
            PLA
            CLI
            JMP   (BRKV)                     ; Pass on to BRK handler

:S1                                          ; TODO: No Apple IRQs handled
            PLA                              ; TODO: Pass on to IRQ1V
            TAX
            PLA
NULLRTI     RTI

PRERR       LDY   #$01
PRERRLP     LDA   (FAULT),Y
            BEQ   PRERR1
            JSR   OSWRCH
            INY
            BNE   PRERRLP
NULLRTS
PRERR1      RTS

MOSBRKHDLR  LDA   #<MSGBRK
            LDY   #>MSGBRK
            JSR   PRSTR
            JSR   PRERR
            JSR   OSNEWL
            JSR   OSNEWL
STOP        JMP   STOP                       ; Cannot return from a BRK

MSGBRK      DB    $0D
            ASC   "ERROR: "
            DB    $00

;DEFBRKHDLR
;            LDA   #<BRKM
;            LDY   #>BRKM
;            JSR   PRSTR
;            PLA
;            PLX
;            PLY
;            PHY
;            PHX
;            PHA
;            JSR   OUT2HEX
;            LDA   #<BRKM2
;            LDY   #>BRKM2
;            JSR   PRSTR
;            RTI
;BRKM        ASC   "BRK($"
;            DB    $00
;BRKM2       ASC   ")."
;            DB    $00

* Default page 2 contents
DEFVEC      DW    NULLRTS                    ; $200 USERV
            DW    MOSBRKHDLR                 ; $202 BRKV
            DW    NULLRTI                    ; $204 IRQ1V
            DW    NULLRTI                    ; $206 IRQ2V
            DW    CLIHND                     ; $208 CLIV
            DW    BYTEHND                    ; $20A BYTEV
            DW    WORDHND                    ; $20C WORDV
            DW    WRCHHND                    ; $20E WRCHV
            DW    RDCHHND                    ; $210 RDCHV
            DW    FILEHND                    ; $212 FILEV
            DW    ARGSHND                    ; $214 ARGSV
            DW    BGETHND                    ; $216 BGETV
            DW    BPUTHND                    ; $218 BPUTV
            DW    GBPBHND                    ; $21A GBPBV
            DW    FINDHND                    ; $21C FINDV
            DW    NULLRTS                    ; $21E FSCV
ENDVEC

*
* Acorn MOS entry points at the top of RAM
* Copied from loaded code to high memory
*

MOSVEC                                       ; Base of API entries here in loaded code
MOSAPI      EQU   $FFB6                      ; Real base of API entries in real memory
            ORG   MOSAPI

* OPTIONAL ENTRIES
* ----------------
*OSSERV      JMP   NULLRTS          ; FF95 OSSERV
*OSCOLD      JMP   NULLRTS          ; FF98 OSCOLD
*OSPRSTR     JMP   OUTSTR           ; FF9B PRSTRG
*OSFF9E      JMP   NULLRTS          ; FF9E
*OSSCANHEX   JMP   RDHEX            ; FFA1 SCANHX
*OSFFA4      JMP   NULLRTS          ; FFA4
*OSFFA7      JMP   NULLRTS          ; FFA7
*PRHEX       JMP   OUTHEX           ; FFAA PRHEX
*PR2HEX      JMP   OUT2HEX          ; FFAD PR2HEX
*OSFFB0      JMP   NULLRTS          ; FFB0
*OSWRRM      JMP   NULLRTS          ; FFB3 OSWRRM

* COMPULSARY ENTRIES
* ------------------
VECSIZE     DB    ENDVEC-DEFVEC              ; FFB6 VECSIZE Size of vectors
VECBASE     DW    DEFVEC                     ; FFB7 VECBASE Base of default vectors
OSRDRM      JMP   RDROM                      ; FFB9 OSRDRM  Read byte from paged ROM
OSCHROUT    JMP   OUTCHAR                    ; FFBC CHROUT  Send char to VDU driver
OSEVEN      JMP   EVENT                      ; FFBF OSEVEN  Signal an event
GSINIT      JMP   GSINTGO                    ; FFC2 GSINIT  Init string reading
GSREAD      JMP   GSRDGO                     ; FFC5 GSREAD  Parse general string
NVWRCH      JMP   WRCHHND                    ; FFC8 NVWRCH  Nonvectored WRCH
NVRDCH      JMP   RDCHHND                    ; FFCB NVRDCH  Nonvectored RDCH
OSFIND      JMP   (FINDV)                    ; FFCE OSFIND
OSGBPB      JMP   (GBPBV)                    ; FFD1 OSGBPB
OSBPUT      JMP   (BPUTV)                    ; FFD4 OSBPUT
OSBGET      JMP   (BGETV)                    ; FFD7 OSBGET
OSARGS      JMP   (ARGSV)                    ; FFDA OSARGS
OSFILE      JMP   (FILEV)                    ; FFDD OSFILE
OSRDCH      JMP   (RDCHV)                    ; FFE0 OSRDCH
OSASCI      CMP   #$0D                       ; FFE3 OSASCI
            BNE   OSWRCH
OSNEWL      LDA   #$0A                       ; FFE7 OSNEWL
            JSR   OSWRCH
OSWRCR      LDA   #$0D                       ; FFEC OSWRCR
OSWRCH      JMP   (WRCHV)                    ; FFEE OSWRCH
OSWORD      JMP   (WORDV)                    ; FFF1 OSWORD
OSBYTE      JMP   (BYTEV)                    ; FFF4 OSBYTE
OSCLI       JMP   (CLIV)                     ; FFF7 OSCLI
NMIVEC      DW    NULLRTI                    ; FFFA NMIVEC
RSTVEC      DW    STOP                       ; FFFC RSTVEC
IRQVEC

* Assembler doesn't like running up to $FFFF, so we bodge a bit
MOSEND
            ORG   MOSEND-MOSAPI+MOSVEC
            DW    IRQBRKHDLR                 ; FFFE IRQVEC
MOSVEND


* Buffer for one 512 byte disk block in aux mem
AUXBLK      DS    $200

