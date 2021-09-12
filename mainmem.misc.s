* MAINMEM.MISC.S
* (c) Bobbi 2021 GPLv3
*
* Miscellaneous routines used by main memory code.

* Copy 512 bytes from BLKBUF to AUXBLK in aux LC
COPYAUXBLK  >>>   ALTZP          ; Alt ZP & Alt LC on
            LDY   #$00
:L1         LDA   BLKBUF,Y
            STA   $C005          ; Write aux mem
            STA   AUXBLK,Y
            STA   $C004          ; Write main mem
            CPY   #$FF
            BEQ   :S1
            INY
            BRA   :L1
:S1         LDY   #$00
:L2         LDA   BLKBUF+$100,Y
            STA   $C005          ; Write aux mem
            STA   AUXBLK+$100,Y
            STA   $C004          ; Write main mem
            CPY   #$FF
            BEQ   :S2
            INY
            BRA   :L2
:S2         >>>   MAINZP         ; Alt ZP off, ROM back in
            RTS

* Search FILEREFS for value in A
FINDBUF     LDX   #$00
:L1         CMP   FILEREFS,X
            BEQ   :END
            INX
            CPX   #$04
            BNE   :L1
            LDX   #$FF           ; $FF for not found
:END        RTS

* Check if file exists
* Return A=0 if doesn't exist, A=1 file, A=2 fir
EXISTS      LDA   #<MOSFILE
            STA   GINFOPL+1
            LDA   #>MOSFILE
            STA   GINFOPL+2
            JSR   GETINFO        ; GET_FILE_INFO
            BCS   :NOEXIST
            LDA   GINFOPL+7      ; Storage type
            CMP   #$0D
            BCS   :DIR           ; >= $0D
            LDA   #$01           ; File
            RTS
:DIR        LDA   #$02
            RTS
:NOEXIST    LDA   #$00
            RTS

* Copy FILEBLK to AUXBLK in aux memory
* Preserves A
COPYFB      PHA
            LDX   #$00
:L1         LDA   FILEBLK,X
            TAY
            >>>   ALTZP          ; Alt ZP and LC
            TYA
            STA   AUXBLK,X
            >>>   MAINZP         ; Back to normal
            INX
            CPX   #18            ; 18 bytes in FILEBLK
            BNE   :L1
            PLA
            RTS

* Get file info
GETINFO     JSR   MLI
            DB    GINFOCMD
            DW    GINFOPL
            RTS

* Set file info
SETINFO     LDA   #$07           ; SET_FILE_INFO 7 parms
            STA   GINFOPL
            JSR   MLI
            DB    SINFOCMD
            DW    GINFOPL        ; Re-use PL from GFI
            LDA   #$0A           ; GET_FILE_INFO 10 parms
            STA   GINFOPL
            RTS

* Create disk file
* Uses filename in MOSFILE
CRTFILE     JSR   MLI            ; GET_TIME
            DB    GTIMECMD
            LDA   #<MOSFILE
            STA   CREATEPL+1
            LDA   #>MOSFILE
            STA   CREATEPL+2
            LDA   #$C3           ; Open permissions
            STA   CREATEPL+3
            LDA   $BF90          ; Current date
            STA   CREATEPL+8
            LDA   $BF91
            STA   CREATEPL+9
            LDA   $BF92          ; Current time
            STA   CREATEPL+10
            LDA   $BF93
            STA   CREATEPL+11
            JSR   MLI
            DB    CREATCMD
            DW    CREATEPL
            RTS

* Open disk file
OPENFILE    JSR   MLI
            DB    OPENCMD
            DW    OPENPL
            RTS

* Close disk file
CLSFILE     JSR   MLI
            DB    CLSCMD
            DW    CLSPL
            RTS

* Read 512 bytes into BLKBUF
RDFILE      JSR   MLI
            DB    READCMD
            DW    READPL
            RTS

* Write data in BLKBUF to disk
WRTFILE     JSR   MLI
            DB    WRITECMD
            DW    WRITEPL
            RTS

* Put ProDOS prefix in PREFIX
GETPREF     JSR   MLI
            DB    GPFXCMD
            DW    GPFXPL
            RTS

* Map of file reference numbers to IOBUF1..4
FILEREFS    DB    $00,$00,$00,$00
















