* AUXMEM.S
****************************
* BBC MOS in auxilary memory
****************************

* MOSEQU.S
*******************************
* BBC MOS WORKSPACE LOCATIONS *
*******************************

* $00-$8F Language workspace
* $90-$9F Network workspace
* $A0-$A7 NMI workspace
* $A8-$AF Non-MOS *command workspace
* $B0-$BF Temporary filing system workspace
* $C0-$CF Persistant filing system workspace
* $D0-$DF VDU driver workspace
* $E0-$EE Internal MOS workspace
* $EF-$FF MOS API workspace

FSFLAG1     EQU   $E2
FSFLAG2     EQU   $E3
GSFLAG      EQU   $E4
GSCHAR      EQU   $E5
OSTEXT      EQU   $E6
MAXLEN      EQU   OSTEXT+2 ; $E8
MINCHAR     EQU   OSTEXT+3 ; $E9
MAXCHAR     EQU   OSTEXT+4 ; $EA
OSTEMP      EQU   $EB
; $EC kbd ws
; $ED kbd ws
; $EE kbd ws
OSAREG      EQU   $EF
OSXREG      EQU   OSAREG+1 ; $F0
OSYREG      EQU   OSXREG+1 ; $F1
OSCTRL      EQU   OSXREG
OSLPTR      EQU   $F2
;
OSINTWS     EQU   $FA             ; IRQ ZP pointer, use when IRQs off
OSINTA      EQU   $FC             ; IRQ register A store
FAULT       EQU   $FD             ; Error message pointer
ESCFLAG     EQU   $FF             ; Escape status


* $0200-$0235 Vectors
* $0236-$028F OSBYTE variable
* $0290-$02ED
* $02EE-$02FF MOS control block

USERV       EQU   $200            ; USER vector
BRKV        EQU   $202            ; BRK vector
CLIV        EQU   $208            ; OSCLI vector
BYTEV       EQU   $20A            ; OSBYTE vector
WORDV       EQU   $20C            ; OSWORD vector
WRCHV       EQU   $20E            ; OSWRCH vector
RDCHV       EQU   $210            ; OSRDCH vector
FILEV       EQU   $212            ; OSFILE vector
ARGSV       EQU   $214            ; OSARGS vector
BGETV       EQU   $216            ; OSBGET vector
BPUTV       EQU   $218            ; OSBPUT vector
GBPBV       EQU   $21A            ; OSGBPB vector
FINDV       EQU   $21C            ; OSFIND vector
FSCV        EQU   $21E            ; FSCV misc file ops

OSFILECB    EQU   $2EE            ; OSFILE control block

* MOSINIT.S
*****************************************************
* BBC Micro 'virtual machine' in Apple //e aux memory
* (c) Bobbi 2021 GPLv3

ZP1         EQU   $90                        ; $90-$9f are Econet space
                                             ; so safe to use
ZP2         EQU   $92

ZP3         EQU   $94

ROW         EQU   $96                        ; Cursor row
COL         EQU   $97                        ; Cursor column
STRTBCKL    EQU   $9D
STRTBCKH    EQU   $9E
WARMSTRT    EQU   $9F                        ; Cold or warm start

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

* VDU.S
***********************************************************
* Apple //e VDU Driver for 80 column mode (PAGE2)
***********************************************************

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
            >>>   WRTMAIN
:S1         LDA   #" "
            STA   (ZP1),Y
            >>>   WRTAUX
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

* Print char in A at ROW,COL
PRCHRC      PHA
            LDA   $C000                      ; Kbd data/strobe
            BMI   :KEYHIT
:RESUME     LDA   ROW
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
            >>>   WRTMAIN
:S1         PLA
            ORA   #$80
            STA   (ZP1),Y                    ; Screen address
            >>>   WRTAUX
            RTS
:KEYHIT     STA   $C010                      ; Clear strobe
            AND   #$7F
            CMP   #$13                       ; Ctrl-S
            BEQ   :PAUSE
            CMP   #$1B                       ; Esc
            BNE   :RESUME
:ESC        SEC
            ROR   ESCFLAG                    ; Set ESCFLAG
            BRA   :RESUME
:PAUSE      STA   $C010                      ; Clear strobe
:L1         LDA   $C000                      ; Kbd data/strobe
            BPL   :L1
            AND   #$7F
            CMP   #$11                       ; Ctrl-Q
            BEQ   :RESUME
            CMP   #$1B                       ; Esc
            BEQ   :ESC
            BRA   :PAUSE

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
            >>>   WRTMAIN
            LDA   (ZP2),Y
            STA   (ZP1),Y
            STA   $C003                      ; Read aux mem
            >>>   WRTAUX
            INY
            CPY   #40
            BNE   :L1
            RTS

* Addresses of screen rows in PAGE2
SCNTAB      DW    $800,$880,$900,$980,$A00,$A80,$B00,$B80
            DW    $828,$8A8,$928,$9A8,$A28,$AA8,$B28,$BA8
            DW    $850,$8D0,$950,$9D0,$A50,$AD0,$B50,$BD0

* FILESYS.S
*********************************************************
* AppleMOS Host File System
*********************************************************


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
            >>>   WRTMAIN
            STA   (ZP2),Y
            >>>   WRTAUX
            INY
            CMP   #$0D                       ; Carriage return
            BNE   :L1
            DEY
            >>>   WRTMAIN
            STY   MOSFILE                    ; Length (Pascal string)
            >>>   WRTAUX
            PLA                              ; Recover options
            >>>   XF2MAIN,OFILE
:CLOSE      >>>   WRTMAIN
            STY   MOSFILE                    ; Write file number
            >>>   WRTAUX
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
            >>>   WRTMAIN
            STY   MOSFILE                    ; File reference number
            >>>   WRTAUX
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
            >>>   WRTMAIN
            STY   MOSFILE                    ; File ref number
            >>>   WRTAUX
            >>>   XF2MAIN,FILEGET
OSBGETRET
            >>>   ENTAUX
            CLC                              ; Means no error
            CPY   #$00                       ; Check error status
            BEQ   :NOERR
            SEC                              ; Set carry for error
            BRA   :EXIT
:NOERR      CLC
:EXIT       PLY
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
            LDA   #$09                       ; Hosted filing system
            RTS
:S1         CMP   #$01                       ; Y=0,A=1 => addr of CLI
            BNE   :S2
* TODO: Implement this for *RUN and *command
            JSR   BEEP
            BRA   :IEXIT
:S2         CMP   #$FF                       ; Y=0,A=FF => flush all files
            BNE   :IEXIT
            >>>   WRTMAIN
            STZ   MOSFILE                    ; Zero means flush all
            >>>   WRTAUX
            BRA   :IFLUSH
:HASFILE    >>>   WRTMAIN
            STY   MOSFILE                    ; File ref num
            STX   MOSFILE+1                  ; Pointer to ZP control block
            >>>   WRTAUX
            CMP   #$00                       ; Y!=0,A=0 => read seq ptr
            BNE   :S3
            >>>   WRTMAIN
            STZ   MOSFILE+2                  ; 0 means get pos
            >>>   WRTAUX
            >>>   XF2MAIN,TELL
:IEXIT      BRA   :IEXIT2
:IFLUSH     BRA   :FLUSH
:S3         CMP   #$01                       ; Y!=0,A=1 => write seq ptr
            BNE   :S4
            >>>   WRTMAIN
            LDA   $00,X
            STA   MOSFILE+2
            LDA   $01,X
            STA   MOSFILE+3
            LDA   $02,X
            STA   MOSFILE+4
            >>>   WRTAUX
            >>>   XF2MAIN,SEEK
:IEXIT2     BRA   :EXIT
:S4         CMP   #$02                       ; Y!=0,A=2 => read file len
            BNE   :S5
            >>>   WRTMAIN
            STA   MOSFILE+2                  ; Non-zero means get len
            >>>   WRTAUX
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
            >>>   WRTMAIN
            STA   (ZP2),Y
            >>>   WRTAUX
            INY
            CPY   #$12
            BNE   :L1

            LDA   (ZP1)                      ; Pointer to filename->ZP2
            STA   ZP2
            LDY   #$01
            LDA   (ZP1),Y
            STA   ZP2+1
            LDA   #<MOSFILE+1                ; ZP1 is dest pointer
            STA   ZP1
            LDA   #>MOSFILE+1
            STA   ZP1+1
            LDA   (ZP2)                      ; Look at first char of filename
            CMP   #'9'+1
            BCS   :NOTDIGT
            CMP   #'0'
            BCC   :NOTDIGT
            LDA   #'N'                       ; Prefix numeric with 'N'
            >>>   WRTMAIN
            STA   (ZP1)
            >>>   WRTAUX
            LDY   #$01                       ; Increment Y
            DEC   ZP2                        ; Decrement source pointer
            LDA   ZP2
            CMP   #$FF
            BNE   :L2
            DEC   ZP2+1
            BRA   :L2
:NOTDIGT    LDY   #$00
:L2         LDA   (ZP2),Y
            >>>   WRTMAIN
            STA   (ZP1),Y
            >>>   WRTAUX
            INY
            CMP   #$21                       ; Space or Carriage return
            BCS   :L2
            DEY
            >>>   WRTMAIN
            STY   MOSFILE                    ; Length (Pascal string)
            >>>   WRTAUX

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

* Performs OSBYTE $7F EOF function
* File ref number is in X
CHKEOF      >>>   WRTMAIN
            STX   MOSFILE                    ; File reference number
            >>>   WRTAUX
            >>>   XF2MAIN,FILEEOF
CHKEOFRET
            >>>   ENTAUX
            TAX                              ; Return code -> X
            RTS

* KERNEL.S
*********************************************************
* AppleMOS Kernel
*********************************************************

* KERNEL/STARTUP.S
******************
* KERNEL/SWROM.S
****************

BYTE8E      PHP                              ; Save CLC=RESET, SEC=Not RESET
            LDA   #$09                       ; $8E = Enter language ROM
            LDY   #$80                       ; Print language name at $8009
            JSR   PRSTR
            JSR   OSNEWL
            JSR   OSNEWL

            PLP                              ; Get entry type back
            LDA   #$01
            JMP   AUXADDR

SERVICE     RTS

* KERNEL/OSCLI.S
****************

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
:S6         LDA   #<:RUN
            STA   ZP2
            LDA   #>:RUN
            STA   ZP2+1
            JSR   STRCMP
            BCS   :S7
            JSR   STARRUN
            BRA   :EXIT
:S7         LDA   #<:HELP
            STA   ZP2
            LDA   #>:HELP
            STA   ZP2+1
            JSR   STRCMP
            BCS   :ASKROM
            JSR   STARHELP
            BRA   :EXIT
:ASKROM     LDA   $8006                      ; Check for service entry
            BPL   :UNSUPP                    ; No service entry
;            LDA   $8003                      ; Check for service entry
;            CMP   #$4C                       ; Not a JMP?
;            BNE   :UNSUPP                    ; Only BASIC has no srvc entry
            LDA   ZP1                        ; String in (OSLPTR),Y
            STA   OSLPTR
            LDA   ZP1+1
            STA   OSLPTR+1
            LDY   #$00
            LDA   #$04                       ; Service 4 Unrecognized Cmd
            LDX   #$0F                       ; ROM slot
            JSR   $8003                      ; Service entry point
            TAX                              ; Check return
            BEQ   :EXIT                      ; Call claimed

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
:RUN        ASC   'RUN'
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
            CMP   #'"'
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

* Consume spaces in command line. Treat " as space!
* Return C set if no space found, C clear otherwise
* Command line pointer in (ZP1),Y
EATSPC      LDA   (ZP1),Y                    ; Check first char is ...
            CMP   #' '                       ; ... space
            BEQ   :START
            CMP   #'"'                       ; Or quote mark
            BEQ   :START
            BRA   :NOTFND
:START      INY
:L1         LDA   (ZP1),Y                    ; Eat any additional ...
            CMP   #' '                       ; ... spaces
            BEQ   :CONT
            CMP   #'"'                       ; Or quote marks
            BNE   :DONE
:CONT       INY
            BRA   :L1
:DONE       CLC
            RTS
:NOTFND     SEC
            RTS

* Consume chars in command line until space or " is found
* Command line pointer in (ZP1),Y
* Returns with carry set if EOL
EATWORD     LDA   (ZP1),Y
            CMP   #' '
            BEQ   :SPC
            CMP   #'"'
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
            >>>   WRTMAIN
            STA   MOSFILE,X
            >>>   WRTAUX
            INY
            INX
            BRA   :L3
:S3         DEX
            >>>   WRTMAIN
            STX   MOSFILE                    ; Length byte
            >>>   WRTAUX
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
            LDA   ADDRBUF
            STA   OSFILECB+2                 ; Load address LSB
            LDA   ADDRBUF+1
            STA   OSFILECB+3                 ; Load address MSB
:OSFILE     LDX   #<OSFILECB
            LDY   #>OSFILECB
            LDA   #$FF                       ; OSFILE load flag
            JSR   OSFILE
:END        RTS
:NOADDR     LDA   #$FF                       ; Set OSFILECB+6 to non-zero
            STA   OSFILECB+6                 ; Means use the file's addr
            BRA   :OSFILE
:ERR        JSR   BEEP
            RTS

* Handle *SAVE command
* On entry, ZP1 points to command line
STARSAVE    JSR   CLRCB
            JSR   EATSPC                     ; Eat leading space
            BCS   :ERR
            JSR   ADDZP1Y                    ; Advance ZP1
            LDA   ZP1                        ; Pointer to filename
            STA   OSFILECB
            LDA   ZP1+1
            STA   OSFILECB+1
            JSR   EATWORD
            BCS   :ERR                       ; No start address given
            LDA   #$0D                       ; Carriage return
            STA   (ZP1),Y                    ; Terminate filename
            INY
            JSR   EATSPC                     ; Eat any whitespace
            JSR   ADDZP1Y                    ; Update ZP1
            JSR   HEXCONST
            BCS   :ERR                       ; Bad start address
            LDA   ADDRBUF
            STA   OSFILECB+10
            LDA   ADDRBUF+1
            STA   OSFILECB+11
            JSR   EATSPC                     ; Eat any whitespace
            JSR   ADDZP1Y                    ; Update ZP1
            JSR   HEXCONST
            BCS   :ERR                       ; Bad end address
            LDA   ADDRBUF
            STA   OSFILECB+14
            LDA   ADDRBUF+1
            STA   OSFILECB+15
            LDX   #<OSFILECB
            LDY   #>OSFILECB
            LDA   #$00                       ; OSFILE save flag
            JSR   OSFILE
:END        RTS
:ERR        JSR   BEEP
            RTS

* Handle *RUN command
* On entry, ZP1 points to command line
STARRUN     TYA
            CLC
            ADC ZP1
            TAX
            LDA #$00
            ADC ZP2
            TAY
            LDA #$04
CALLFSCV    JMP (FSCV)                     ; Hand on to filing system

* Clear OSFILE control block to zeros
CLRCB       LDA   #$00
            LDX   #$00
:L1         STA   OSFILECB,X
            INX
            CPX   #18
            BNE   :L1
            RTS

************************
* OSWORD/OSBYTE dispatch
************************

* OSWORD:
* On entry, A=action
*           XY=>control block
* On exit,  A=preserved
*           X,Y,Cy trashed (except OSWORD 0)
*           control block updated
*
WORDHND     PHA
            PHP
            SEI
            STA   OSAREG          ; Store registers
            STX   OSCTRL+0        ; Point to control block
            STY   OSCTRL+1
            LDX   #$08            ; X=SERVWORD
            CMP   #$E0            ; User OSWORD
            BCS   WORDGO1
            CMP   #WORDMAX+1
            BCS   BYTWRDFAIL      ; Pass on to service call
            ADC   #WORDOFF
            BCC   BYTWRDCALL      ; Call OSWORD routine
WORDGO1     LDA   #WORDOFF+WORDMAX+1
            BCS   BYTWRDCALL      ; Call User OSWORD routine

* OSBYTE:
* On entry, A=action
*           X=first parameter
*           Y=second parameter if A>$7F
* On exit,  A=preserved
*           X=first returned result
*           Y=second returned result if A>$7F
*           Cy=any returned status if A>$7F
*
BYTEHND     PHA
            PHP
            SEI
            STA   OSAREG          ; Store registers
            STX   OSXREG
            STY   OSYREG
            LDX   #$07            ; X=SERVBYTE
            CMP   #$A6
            BCS   BYTEGO1         ; OSBYTE &A6+
            CMP   #BYTEMAX+1
            BCS   BYTWRDFAIL      ; Pass on to service call
            CMP   #BYTEHIGH
            BCS   BYTEGO2         ; High OSBYTEs
            CMP   #BYTELOW+1
            BCS   BYTWRDFAIL      ; Pass on to service call
            STZ   OSYREG          ; Prepare Y=0 for low OSBYTEs
            BCC   BYTEGO3

BYTEGO1     LDA   #BYTEMAX+1          ; Index for BYTEVAR
BYTEGO2     SBC   #BYTEHIGH-BYTELOW-1 ; Reduce OSBYTE number
BYTEGO3     ORA   #$80                ; Will become CS=OSBYTE call

BYTWRDCALL  ASL   A               ; Index into dispatch table
            TAY                   ; Y=offset into dispatch table
;           BIT   FXNETCLAIM      ; Check Econet intercept flag
;           BPL   BYTWRDNONET     ; No intercept, skip past
;           TXA                   ; Set A=BYTE or WORD call
;           CLV                   ; Clear V
;           JSR   CALLNET         ; Call Econet with X=call type
;           BVS   BYTWRDEXIT      ; V now set, claimed by NETV, return

BYTWRDNONET LDA   BYTWRDADDR+1,Y  ; Get routine address
            STA   OSINTWS+1
            LDA   BYTWRDADDR+0,Y
            STA   OSINTWS+0
            LDA   OSAREG          ; Get A parameter back
            LDY   OSYREG          ; Get Y parameter back
            LDX   OSXREG          ; Get X parameter, set EQ from it
            BCS   BYTWRDGO        ; Skip if OSBYTE call
            LDY   #$00            ; OSWORD call, enter with Y=0
            LDA   (OSCTRL),Y      ; and A=first byte in control block, set EQ from it
            SEC                   ; Enter routine with CS
BYTWRDGO    JSR   JMPADDR         ; Call the routine
* Routines are entered with:
*  A=OSBYTE call or first byte of OSWORD control block
*  X=X parameter
*  Y=OSBYTE Y parameter for A>$7F
*  Y=$00 for OSBYTE A<$80
*  Y=$00 for OSWORD so (OSCTRL),Y => first byte
*  Carry Set
*  EQ set from OSBYTE X or from OSWORD first byte
* X,Y,Cy from routine returned to caller

BYTWRDEXIT  ROR   A               ; Move Carry to A
            PLP                   ; Restore original flags
            ROL   A               ; Move Carry back to flags
            PLA                   ; Restore A
            CLV                   ; Clear V = Actioned
            RTS

BYTWRDFAIL
;           JSR   SERVICE         ; Offer to sideways ROMs
;           LDX   OSXREG          ; Get returned X
;           CMP   #$00
;           BEQ   BYTWRDEXIT      ; Claimed, return
            JSR   UNSUPBYTWRD     ; *DEBUG*
            LDX   #$FF            ; X=&FF if unclaimed (normally set within SERVICE)
            PLP                   ; Restore IRQs
            PLA                   ; Restore A
            BIT   SETV            ; Set V = Not actioned
            RTS

SETV                              ; JMP() is $6C, bit 6 set, use to set V
JMPADDR     JMP   ((OSINTWS))


*************************
* OSBYTE DISPATCH TABLE *
*************************

BYTWRDADDR  DW    BYTE00   ; OSBYTE   0 - Machine host
;           DW    BYTE01   ; OSBYTE   1 - User flag
;           DW    BYTE02   ; OSBYTE   2 - OSRDCH source
;           DW    BYTE03   ; OSBYTE   3 - OSWRCH dest
;           DW    BYTE04   ; OSBYTE   4 - Cursor keys
BYTWRDLOW
BYTELOW     EQU   {BYTWRDLOW-BYTWRDADDR}/2-1          ; Maximum low OSBYTE
BYTEHIGH    EQU   $7C                                 ; First high OSBYTE
            DW    BYTE7C   ; OSBYTE 124 - Clear Escape
            DW    BYTE7D   ; OSBYTE 125 - Set Escape
            DW    BYTE7E   ; OSBYTE 126 - Ack. Escape
            DW    BYTE7F   ; OSBYTE 127 - Read EOF
            DW    BYTE80   ; OSBYTE 128 - ADVAL
            DW    BYTE81   ; OSBYTE 129 - INKEY
            DW    BYTE82   ; OSBYTE 130 - Memory high word
            DW    BYTE83   ; OSBYTE 131 - MEMBOT
            DW    BYTE84   ; OSBYTE 132 - MEMTOP
            DW    BYTE85   ; OSBYTE 133 - MEMTOP for MODE
            DW    BYTE86   ; OSBYTE 134 - POS, VPOS
            DW    BYTE87   ; OSBYTE 135 - Character, MODE
;           DW    BYTE88   ; OSBYTE 136 - *CODE
;           DW    BYTE89   ; OSBYTE 137 - *MOTOR
;           DW    BYTE8A   ; OSBYTE 138 - Buffer insert
;           DW    BYTE8B   ; OSBYTE 139 - *OPT
;           DW    BYTE8C   ; OSBYTE 140 - *TAPE
;           DW    BYTE8D   ; OSBYTE 141 - *ROM
;           DW    BYTE8E   ; OSBYTE 142 - Enter language
;           DW    BYTE8F   ; OSBYTE 143 - Service call
BYTWRDTOP
            DW    BYTEVAR  ; OSBYTE 166+ - Read/Write OSBYTE variable
BYTEMAX     EQU   {BYTWRDTOP-BYTWRDLOW}/2+BYTEHIGH-1  ; Maximum high OSBYTE

*************************
* OSWORD DISPATCH TABLE *
*************************
OSWBASE     DW    WORD00   ; OSWORD  0 - Read input line
            DW    WORD01   ; OSWORD  1 - Read elapsed time
            DW    WORD02   ; OSWORD  2 - Write eleapsed time
            DW    WORD03   ; OSWORD  3 - Read interval timer
            DW    WORD04   ; OSWORD  4 - Write interval timer
            DW    WORD05   ; OSWORD  5 - Read I/O memory
            DW    WORD06   ; OSWORD  6 - Write I/O memory
;           DW    WORD07   ; OSWORD  7 - SOUND
;           DW    WORD08   ; OSWORD  8 - ENVELOPE
;           DW    WORD09   ; OSWORD  9 - POINT
;           DW    WORD0A   ; OSWORD 10 - Read character bitmap
;           DW    WORD0B   ; OSWORD 11 - Read palette
;           DW    WORD0C   ; OSWORD 12 - Write palette
;           DW    WORD0D   ; OSWORD 13 - Read coordinates
OSWEND
            DW    WORDE0   ; OSWORD &E0+ - User OSWORD
WORDOFF     EQU   {OSWBASE-BYTWRDADDR}/2              ; Offset to start of OSWORD table
WORDMAX     EQU   {OSWEND-OSWBASE}/2-1                ; Maximum OSWORD

* OSWORD &00 - Read a line of input
***********************************
* On entry, (OSCTRL)=>control block
*           Y=0, A=(OSCTRL)
* On exit,  Y=length of line, offset to <cr>
*           CC = Ok, CS = Escape
*

WORD00    IF MAXLEN-OSTEXT-2
            LDY   #$04
:WORD00LP1  LDA   (OSCTRL),Y         ; Copy MAXLEN, MINCH, MAXCH to workspace
            STA   MAXLEN-2,Y
            DEY
            CPY   #$02
            BCS   :WORD00LP1
:WORD00LP2  LDA   (OSCTRL),Y         ; (OSTEXT)=>line buffer
            STA   OSTEXT,Y
            DEY
            BPL   :WORD00LP2
            INY                      ; Initial line length = zero
          ELSE
            LDA   (OSCTRL),Y         ; Copy control block 
            STA   OSTEXT,Y           ; 0,1 => text
            INY                      ;  2  = MAXLEN 
            CPY   #$05               ;  3  = MINCHAR
            BCC   WORD00             ;  4  = MAXCHAR
            LDY   #$00               ; Initial line length = zero
          FIN
;           STY   FXLINES            ; Reset line counter
            CLI
            BEQ   :WORD00LP          ; Enter main loop

:WORD00BELL LDA   #$07               ; $07=BELL
            DEY                      ; Balance next INY
:WORD00NEXT INY                      ; Step to next character
:WORD00ECHO JSR   OSWRCH             ; Print character

:WORD00LP   JSR   OSRDCH
            BCS   :WORD00ESC         ; Escape
;           TAX                      ; Save character in X for a mo
;           LDA   FXVAR03            ; Get FX3 destination
;           ROR   A
;           ROR   A                  ; Move bit 1 into Carry
;           TXA                      ; Get character back
;           BCS   :WORD00TEST        ; VDU disabled, ignore VDU queue
;           LDX   FXVDUQLEN          ; Get length of VDU queue
;           BNE   :WORD00ECHO        ; Not zero, just print and loop
:WORD00TEST CMP   #$7F               ; Delete
            BNE   :WORD00CHAR
            CPY   #$00
            BEQ   :WORD00LP          ; Nothing to delete
            DEY                      ; Back up one character
            BCS   :WORD00ECHO        ; Loop back to print DEL
:WORD00CHAR CMP   #$15               ; Ctrl-U
            BNE   :WORD00INS         ; No, insert character
            LDA   #$7F               ; Delete character
            INY                      ; Balance first DEY
:WORD00ALL  DEY                      ; Back up one character
            BEQ   :WORD00LP          ; Beginning of line
            JSR   OSWRCH             ; Print DELETE
            JMP   :WORD00ALL         ; Loop to delete all
:WORD00INS  STA   (OSTEXT),Y         ; Store the character
            CMP   #$0D
            BEQ   :WORD00CR          ; CR - Done
            CPY   MAXLEN
            BCS   :WORD00BELL        ; Too long, beep
            CMP   MINCHAR
            BCC   :WORD00ECHO        ; <MINCHAR, don't step to next
            CMP   MAXCHAR
            BCC   :WORD00NEXT        ; <MAXCHAR, step to next
            BEQ   :WORD00NEXT        ; =MAXCHAR, step to next
            BCS   :WORD00ECHO        ; >MAXCHAR, don't step to next

:WORD00CR   JSR   OSNEWL
;           JSR   CALLNET            ; Call Econet Vector with A=13
:WORD00ESC  LDA   ESCFLAG            ; Get Escape flag
            ROL   A                  ; Carry=Escape state
            RTS

* OSWORD &01 - Read elapsed time
* OSWORD &02 - Write elapsed time
* OSWORD &03 - Read countdown timer
* OSWORD &04 - Write countdown timer
************************************
* On entry, (OSCTRL)=>control block
*           Y=0

WORD01      TYA              ; Dummy, just return zero
:WORD01LP   STA   (OSCTRL),Y
            INY
            CPY   #$05
            BCC   :WORD01LP
WORD04
WORD03
WORD02      RTS              ; Dummy, do nothing

* OSWORD &05 - Read I/O memory
* OSWORD &06 - Write I/O memory
***********************************
* On entry, (OSCTRL)+0 address
*           (OSCTRL)+4 byte read or written
*           Y=0, A=(OSCTRL)

WORD05      JSR   :GETADDR     ; Point to address, set X and Y
; needs to switch to main memory
            LDA   (OSINTWS)    ; Get byte
; needs to switch back
            STA   (OSCTRL),Y   ; Store it
            RTS
WORD06      JSR   :GETADDR     ; Point to address, set X and Y
            LDA   (OSCTRL),Y   ; Get byte
; needs to switch to main memory
            STA   (OSINTWS)    ; Store it
; needs to switch back
            RTS
:GETADDR    STA   OSINTWS+0    ; (OSINTWS)=>byte to read/write
            INY
            LDA   (OSCTRL),Y
            STA   OSINTWS+1
            LDY   #$04         ; Point Y to data byte
            RTS

* KERNEL/BWMISC.S
*****************
* Here until tidied


BYTE00      LDX   #$0A                       ; $00 = identify Host
            RTS

BYTE7C      LDA   ESCFLAG                    ; $7C = clear escape condition
            AND   #$7F                       ; Clear MSbit
            STA   ESCFLAG
            RTS

BYTE7D      ROR   ESCFLAG                    ; $7D = set escape condition
            RTS

BYTE7E      LDA   ESCFLAG                    ; $7E = ack detection of ESC
            AND   #$7F                       ; Clear MSB
            STA   ESCFLAG
            LDX   #$FF                       ; Means ESC condition cleared
            RTS

BYTE7F      PHY                              ; $7F = check for EOF
            JSR   CHKEOF
            PLY
            RTS

                     ; $80 = read ADC or get buf stat
BYTE80      CPX   #$00                       ; X<0 => info about buffers
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

BYTE81      JSR   GETKEY                     ; $81 = Read key with time lim
            RTS

BYTE82      LDY   #$00                       ; $82 = read high order address
            LDX   #$00                       ; $0000 for language processor
            RTS

BYTE83      LDY   #$0E                       ; $83 = read bottom of user mem
            LDX   #$00                       ; $0E00
            RTS

BYTE84      LDY   #$80                       ; $84 = read top of user mem
            LDX   #$00
            RTS

BYTE85      LDY   #$80                       ; $85 = top user mem for mode
            LDX   #$00
            RTS

BYTE86      LDY   ROW                        ; $86 = read cursor pos
            LDX   COL
            RTS

BYTE8B      LDA    #$00                      ; $8B = *OPT
            JMP    ((FSCV))                  ; Hand over to filing system

BYTEDA      RTS                              ; $DA = clear VDU queue

BYTEEA      LDX   #$00                       ; No tube
            RTS                              ; $EA = Tube presence

UNSUPBYTWRD
            LDA   #<OSBYTEM
            LDY   #>OSBYTEM
            CPX   #7
            BEQ   UNSUPGO
            LDA   #<OSWORDM
            LDY   #>OSWORDM
UNSUPGO     JSR   PRSTR
            LDA   OSAREG
            JSR   OUTHEX
            LDA   #<OSBM2
            LDY   #>OSBM2
            JMP   PRSTR

OSBYTEM     ASC   'OSBYTE($'
            DB    $00
OSWORDM     ASC   'OSWORD($'
            DB    $00
OSBM2       ASC   ').'
            DB    $00

BYTEVAR     LDX   #$00
            LDY   #$00
BYTE87
WORDE0      RTS

* KERNEL/MISC.S
***************

* OSWRCH handler
* All registers preserved
WRCHHND     PHA
            PHX
            PHY
* TODO Check any output redirections
* TODO Check any spool output
            JSR   OUTCHAR
* TODO Check any printer output
            PLY
            PLX
            PLA
            RTS

* OSRDCH handler
* All registers preserved except A,Cy
* Read a character from the keyboard
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
            BPL   :L1
            LDA   OLDCHAR                    ; Erase cursor
            JSR   PRCHRC
            LDA   $C000
            AND   #$7F
            STA   $C010                      ; Clear strobe
            PLY
            PLX
            CMP   #$1B                       ; Escape pressed?
            BNE   :S5
            SEC                              ; Return CS
            ROR   ESCFLAG
            SEC
            RTS
:S5         CLC
            RTS
CURS        DW    $0000                      ; Counter
CSTATE      DB    $00                        ; Cursor on or off
OLDCHAR     DB    $00                        ; Char under cursor

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

***********************************************************
* Helper functions
***********************************************************

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

* Print string pointed to by X,Y to the screen
OUTSTR      TXA

* Print string pointed to by A,Y to the screen
PRSTR       STA   OSTEXT+0                  ;  String in A,Y
            STY   OSTEXT+1
:L1         LDA   (OSTEXT)                  ; Ptr to string in ZP3
            BEQ   :S1
            JSR   OSASCI
            INC   OSTEXT
            BNE   :L1
            INC   OSTEXT+1
            BRA   :L1
:S1         RTS

* Print XY in hex
OUT2HEX     TYA
            JSR   OUTHEX
            TAX                             ; Continue into OUTHEX

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

**********************************************************
* Interrupt Handlers, MOS redirection vectors etc.
**********************************************************

* IRQ/BRK handler
IRQBRKHDLR
            PHA
            >>>   WRTMAIN
            STA   $45                        ; A->$45 for ProDOS IRQ handlers
            >>>   WRTAUX
            TXA
            PHA
            CLD
            TSX
            LDA   $103,X                     ; Get PSW from stack
            AND   #$10
            BEQ   :IRQ                       ; IRQ
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

:IRQ        >>>   XF2MAIN,A2IRQ
IRQBRKRET
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

