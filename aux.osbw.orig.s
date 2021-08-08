
* OSWORD HANDLER
* On entry, A=action
*           XY=>control block
* On exit,  All preserved (except OSWORD 0)
*           control block updated
WORDHND     STX   OSCTRL+0     ; Point to control block
            STY   OSCTRL+1
            CMP   #$00         ; OSWORD 0 read a line
            BNE   :S01
            JMP   OSWORD0
:S01        CMP   #$01         ; OSWORD 1 read system clock
            BNE   :S02
            JMP   OSWORD1
:S02        CMP   #$02         ; OSWORD 2 write system clock
            BNE   :S05
            JMP   OSWORD2
:S05        CMP   #$05         ; OSWORD 5 read I/O memory
            BNE   :S06
            JMP   OSWORD5
:S06        CMP   #$06         ; OSWORD 6 write I/O memory
            BNE   :UNSUPP

:UNSUPP     PHA
            LDA   #<:OSWORDM   ; Unimplemented, print msg
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
:RDLNLP1    LDA   (OSCTRL),Y   ; Copy MAXLEN, MINCH, MAXCH to workspace
            STA   :MAXLEN-2,Y
            DEY
            CPY   #$02
            BCS   :RDLNLP1
:RDLNLP2    LDA   (OSCTRL),Y   ; (ZP2)=>line buffer
            STA   ZP2,Y
            DEY
            BPL   :RDLNLP2
            INY
            BRA   :L1

:BELL       LDA   #$07         ; BELL
:R1         DEY
:R2         INY                ; Step to next character
:R3         JSR   OSWRCH       ; Output character

:L1         JSR   OSRDCH
            BCS   :EXIT
            CMP   #$08         ; Backspace
            BEQ   :RDDEL
            CMP   #$7F         ; Delete
            BEQ   :RDDEL
            CMP   #$15         ; Ctrl-U
            BNE   :S2
            INY                ; Balance first DEY
:RDCTRLU    DEY                ; Back up one character
            BEQ   :L1          ; Beginning of line
            LDA   #$7F         ; Delete
            JSR   OSWRCH
            JMP   :RDCTRLU
:RDDEL      TYA
            BEQ   :L1          ; Beginning of line
            DEY                ; Back up one character
            LDA   #$7F         ; Delete
            BNE   :R3          ; Jump back to delete

:S2         STA   (ZP2),Y
            CMP   #$0D         ; CR
            BEQ   :S3
            CPY   :MAXLEN
            BCS   :BELL        ; Too long, beep
            CMP   :MINCH
            BCC   :R1          ; <MINCHAR, don't step to next
            CMP   :MAXCH
            BEQ   :R2          ; =MAXCHAR, step to next
            BCC   :R2          ; <MAXCHAR, step to next
            BCS   :R1          ; >MAXCHAR, don't step to next

:S3         JSR   OSNEWL
:EXIT       LDA   ESCFLAG
            ROL
            RTS
:MAXLEN     DB    $00
:MINCH      DB    $00
:MAXCH      DB    $00

* OSWORD1 - Read system clock
OSWORD1     LDA   #$00
            LDY   #$00
:L1         STA   (OSCTRL),Y
            INY
            CPY   #$05
            BNE   :L1
            RTS

* OSWORD2 - Write system clock
OSWORD2     RTS                ; Nothing to do

* OSWORD5 - Read I/O Processor memory
OSWORD5     LDA   (OSCTRL)     ; Fetch pointer into ZP2
            STA   ZP2
            LDY   #$01
            LDA   (OSCTRL),Y
            STA   ZP2+1
            LDA   (ZP2)        ; Now read byte
            LDY   #$04         ; Save byte to XY+4
            STA   (OSCTRL),Y
            RTS

* OSWORD6 - Write I/O Processor memory
OSWORD6     LDA   (OSCTRL)     ; Fetch pointer into ZP2
            STA   ZP2
            LDY   #$01
            LDA   (OSCTRL),Y
            STA   ZP2+1
            LDY   #$04         ; Byte to be written XY+4
            LDA   (OSCTRL),Y
            STA   (ZP2)
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
            CMP   #$00         ; $00 = identify MOS version
            BNE   :S02
            LDX   #$0A
            RTS

:S02        CMP   #$02         ; $02 = select input stream
            BNE   :S03
            RTS                ; Nothing to do

:S03        CMP   #$03         ; $03 = select output stream
            BNE   :S0B
            RTS                ; Nothing to do

:S0B        CMP   #$0B         ; $0B = set keyboard delay
            BNE   :S0C
            RTS                ; Nothing to do

:S0C        CMP   #$0C         ; $0C = set keyboard rate
            BNE   :S0F
            RTS                ; Nothing to do

:S0F        CMP   #$0F         ; $0F = flush buffers
            BNE   :S7C
            RTS                ; Nothing to do

:S7C        CMP   #$7C         ; $7C = clear escape condition
            BNE   :S7D
            LDA   ESCFLAG
            AND   #$7F         ; Clear MSbit
            STA   ESCFLAG
            RTS

:S7D        CMP   #$7D         ; $7D = set escape condition
            BNE   :S7E
            ROR   ESCFLAG
            RTS

:S7E        CMP   #$7E         ; $7E = ack detection of ESC
            BNE   :S7F
            LDA   ESCFLAG
            AND   #$7F         ; Clear MSB
            STA   ESCFLAG
            LDX   #$FF         ; Means ESC condition cleared
            RTS

:S7F        CMP   #$7F         ; $7F = check for EOF
            BNE   :S80
            PHY
            JSR   CHKEOF
            PLY
            RTS

:S80        CMP   #$80         ; $80 = read ADC or get buf stat
            BNE   :S81
            CPX   #$00         ; X<0 => info about buffers
            BMI   :S80BUF      ; X>=0 read ADC info
            LDX   #$00         ; ADC - just return 0
            LDY   #$00         ; ADC - just return 0
            RTS
:S80BUF     CPX   #$FF         ; Kbd buf
            BEQ   :S80KEY
            CPX   #$FE         ; RS423
            BEQ   :NONE
:ONE        LDX   #$01         ; For outputs, 1 char free
            RTS
:S80KEY     LDX   $C000        ; Keyboard data/strobe
            AND   #$80
            BEQ   :NONE
            BRA   :ONE
:NONE       LDX   #$00         ; No chars in buf
            RTS

:S81        CMP   #$81         ; $81 = Read key with time lim
            BNE   :S82
            JSR   GETKEY
            RTS

:S82        CMP   #$82         ; $82 = read high order address
            BNE   :S83
            LDY   #$FF         ; $FFFF for I/O processor
            LDX   #$FF
            RTS

:S83        CMP   #$83         ; $83 = read bottom of user mem
            BNE   :S84
            LDY   #$0E         ; $0E00
            LDX   #$00
            RTS

:S84        CMP   #$84         ; $84 = read top of user mem
            BNE   :S85
            LDY   #$80
            LDX   #$00
            RTS

:S85        CMP   #$85         ; $85 = top user mem for mode
            BNE   :S86
            LDY   #$80
            LDX   #$00
            RTS

:S86        CMP   #$86         ; $86 = read cursor pos
            BNE   :S8B
            LDY   ROW
            LDX   COL
            RTS

:S8B        CMP   #$8B         ; $8B = *OPT
            BNE   :S8E
* TODO: Could implement some FS options here
*       messages on/off, error behaviour
            RTS                ; Nothing to do (yet)

:S8E        CMP   #$8E         ; $8E = Enter language ROM
            BNE   :SDA

            LDA   #$09         ; Print language name at $8009
            LDY   #$80
            JSR   PRSTR
            JSR   OSNEWL
            JSR   OSNEWL

            CLC                ; TODO: CLC or SEC?
            LDA   #$01
            JMP   AUXADDR

:SDA        CMP   #$DA         ; $DA = clear VDU queue
            BNE   :SEA
            RTS

:SEA        CMP   #$EA         ; $EA = Tube presence
            BNE   :UNSUPP
            LDX   #$00         ; No tube
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

