* MAINMEM.MISC.S
* (c) Bobbi 2021 GPLv3
*
* Miscellaneous routines used by main memory code.

* Copy a block of main memory
* A1L/A1H: Start address
* A2L/A2H: End address
* A4L/A4H: Destination start address
MEMCPY       LDA   (A1L)
             STA   (A4L)
             LDA   A1H
             CMP   A2H
             BNE   :S1
             LDA   A1L
             CMP   A2L
             BNE   :S1
:DONE        RTS
:S1          INC   A1L
             BNE   :S2
             INC   A1H
:S2          INC   A4L
             BNE   :S3
             INC   A4H
:S3          BRA   MEMCPY

* Copy 512 bytes from BLKBUF to AUXBLK in aux LC
COPYAUXBLK   >>>   ALTZP          ; Alt ZP & Alt LC on
             LDY   #$00
             STA   $C005          ; Write aux mem
:L1          LDA   BLKBUF+$000,Y
             STA   AUXBLK+$000,Y
             LDA   BLKBUF+$100,Y
             STA   AUXBLK+$100,Y
             INY
             BNE   :L1
             STA   $C004          ; Write main mem
:S2          >>>   MAINZP         ; Alt ZP off, ROM back in
RTSINSTR     RTS

* Search FILEREFS for value in A
* On return, buffer number is in X (or $FF if no bufs)
FINDBUF      LDX   #$00
:L1          CMP   FILEREFS,X
             BEQ   :END
             INX
             CPX   #$04
             BNE   :L1
             LDX   #$FF           ; $FF for not found
:END         RTS

* Obtain I/O buffer address
* On entry: buffer number in X
* On exit: buffer address in AY
*          Carry set if no bufs, clear otherwise
BUFADDR      CPX   #$00
             BNE   :S1
             LDA   #<IOBUF1
             LDY   #>IOBUF1
             BRA   :EXIT
:S1          CPX   #$01
             BNE   :S2
             LDA   #<IOBUF2
             LDY   #>IOBUF2
             BRA   :EXIT
:S2          CPX   #$02
             BNE   :S3
             LDA   #<IOBUF3
             LDY   #>IOBUF3
             BRA   :EXIT
:S3          CPX   #$03
             BNE   :NOBUFS
             LDA   #<IOBUF4
             LDY   #>IOBUF4
:EXIT        CLC
             RTS
:NOBUFS      SEC
             RTS


* Check if file exists
* Returns A=0 if doesn't exist, A=1 file, A=2 dir
EXISTS       LDA   #<MOSFILE
             STA   GINFOPL+1
             LDA   #>MOSFILE
             STA   GINFOPL+2
             JSR   GETINFO        ; GET_FILE_INFO
             LDA   #$00
             BCS   :EXIT          ; Any error -> $00
             LDA   GINFOPL+7      ; Storage type
             CMP   #$0D
             LDA   #$01           ; File -> $01
             ADC   #$00           ; Dir. -> $02
:EXIT        RTS


* Copy FILEBLK to OSFILECB in aux memory
* Preserves A
COPYFB       PHA
             LDX   #$11           ; 18 bytes in FILEBLK
             STA   $C005          ; Write to aux mem
:L1          LDA   FILEBLK,X
             STA   OSFILECB,X
             DEX
             BPL   :L1
             STA   $C004          ; Write to main mem again
             PLA
             RTS

* Get file info
GETINFO      JSR   MLI
             DB    GINFOCMD
             DW    GINFOPL
             RTS

* Set file info
SETINFO      LDA   #$07           ; SET_FILE_INFO 7 parms
             STA   GINFOPL
             JSR   MLI
             DB    SINFOCMD
             DW    GINFOPL        ; Re-use PL from GFI
             LDA   #$0A           ; GET_FILE_INFO 10 parms
             STA   GINFOPL
             RTS

* Create disk file
* Uses filename in MOSFILE
CRTFILE      JSR   MLI            ; GET_TIME
             DB    GTIMECMD
             LDA   #<MOSFILE
             STA   CREATEPL+1
             LDA   #>MOSFILE
             STA   CREATEPL+2
             LDA   #$C3           ; Open permissions
             STA   CREATEPL+3
             LDA   PRODOSDATE     ; Current date
             STA   CREATEPL+8
             LDA   PRODOSDATE+1
             STA   CREATEPL+9
             LDA   PRODOSTIME     ; Current time
             STA   CREATEPL+10
             LDA   PRODOSTIME+1
             STA   CREATEPL+11
             JSR   MLI
             DB    CREATCMD
             DW    CREATEPL
             RTS

* Open disk file
OPENMOSFILE  LDA   #<MOSFILE      ; Open filename in MOSFILE
             STA   OPENPL+1
             LDA   #>MOSFILE
             STA   OPENPL+2
OPENFILE     JSR   MLI
             DB    OPENCMD
             DW    OPENPL
             RTS

* Close disk file
CLSFILE      JSR   MLI
             DB    CLSCMD
             DW    CLSPL
             RTS

* Read 512 bytes into BLKBUF
RDFILE       JSR   MLI
             DB    READCMD
             DW    READPL
             RTS

* Write data in BLKBUF to disk
WRTFILE      JSR   MLI
             DB    WRITECMD
             DW    WRITEPL
             RTS

* Put ProDOS prefix in PREFIX
GETPREF      JSR   MLI
             DB    GPFXCMD
             DW    GPFXPL
             RTS

* Map of file reference numbers to IOBUF1..4
FILEREFS     DB    $00,$00,$00,$00







