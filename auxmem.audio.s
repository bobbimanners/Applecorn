* AUXMEM.AUDIO.S
* (c) Bobbi 2022 GPLv3
*
* Applecorn audio code
*

* Sound buffers in aux LC for now
* Not sure where to move them to
SNDBUF0    DS    16
SNDBUF1    DS    16
SNDBUF2    DS    16
SNDBUF3    DS    16

* Get address of sound buffer
* On entry: X is buffer number
* On exit: OSIRQWS points to start of buffer
* Called with interrupts disabled
GETBUFADDR  LDA   :BUFADDRL,X
            STA   OSINTWS+0
            LDA   :BUFADDRH,X
            STA   OSINTWS+1
            RTS
:BUFADDRL   DB    $00
            DB    $00
            DB    $00
            DB    $00
            DB    <SNDBUF0
            DB    <SNDBUF1
            DB    <SNDBUF2
            DB    <SNDBUF3
            DB    $00
:BUFADDRH   DB    $00
            DB    $00
            DB    $00
            DB    $00
            DB    >SNDBUF0
            DB    >SNDBUF1
            DB    >SNDBUF2
            DB    >SNDBUF3
            DB    $00


* Insert value into buffer (INSV)
* On entry: A is value, X is buffer number.
* On exit: A, X, Y preserved. C clear on success.
INSHND      PHP                              ; Save flags, turn off interrupts
            SEI
            PHY
            PHA
            LDY   ENDINDICES,X               ; Get input pointer
            INY                              ; Next byte
            CPY   #16
            BNE   :NOTEND                    ; See if it's the end
            LDY   #0                         ; If so, wraparound
:NOTEND     TYA
            CMP   STARTINDICES,X             ; See if buffer is full
            BEQ   :FULL
            LDY   ENDINDICES,X               ; Current position
            STA   ENDINDICES,X               ; Write updated input pointer
            JSR   GETBUFADDR                 ; Buffer address into OSINTWS
            PLA                              ; Get value back
            STA   (OSINTWS),Y                ; Write to buffer
            PLY
            PLP                              ; Restore flags
            CLC                              ; Exit with carry clear
            RTS
:FULL       PLA                              ; Restore A
            PLY
            PLP                              ; Restore flags
            SEC                              ; Exit with carry set
            RTS


* OSBYTE &07 - Make a sound
* On entry: (OSCTRL),Y points to eight byte parameter block (2 bytes each for
*           channel, amplitude, pitch, duration)
WORD07      LDA   (OSCTRL),Y                 ; Get channel number 0-3
            ORA   #$04                       ; Convert to buffer number 4-7
            TAX                              ; Into X
            INY                              ; Point to channel num MSB
            INY                              ; Point to amplitude LSB
            LDA   (OSCTRL),Y
            JSR   INSHND                     ; Insert into queue X
            INY                              ; Point to amplitude MSB
            INY                              ; Point to pitch LSB
            LDA   (OSCTRL),Y
            JSR   INSHND                     ; Insert into queue X
            INY                              ; Point to pitch MSB
            INY                              ; Point to duration LSB
            JSR   INSHND                     ; Insert into queue X
            RTS

* OSBYTE &08 - Envelope
* On entry: (OSCTRL),Y points to 14 byte parameter block
WORD08
*           TODO: IMPLEMENT THIS!!!
            RTS

* Called from Ensoniq interrupt handler - process audio queue
*
ENSQIRQ
*           TODO: IMPLEMENT THIS!!!
            RTS

* Initialize Ensoniq
ENSQSNDCTL  EQU   $C03C
ENSQSNDDAT  EQU   $C03D
ENSQADDRL   EQU   $C03E
ENSQADDRH   EQU   $C03F

ENSQINIT    LDA   ENSQSNDCTL                ; Get settings
            ORA   #$60                      ; DOC RAM, autoincrement on
            STA   ENSQSNDCTL                ; Set it
            LDA   #$00
            STA   ENSQADDRL                 ; DOC RAM addr $0000
            STA   ENSQADDRH                 ; DOC RAM addr $0000
            LDA   #120                      ; High value of square wave
            LDX   #$00
:L1         STA   ENSQSNDDAT                ; 128 cycles of high value
            INX
            CPX   #128
            BNE   :L1
            LDA   #80                       ; Low value of square wave
:L2         STA   ENSQSNDDAT                ; 128 cycles of low value
            INX
            CPX   #0
            BNE   :L2
            LDX   #$E1                      ; DOC Osc Enable register $E1
            LDY   #8                        ; Four oscillators enabled
            JSR   ENSQWRTDOC
            LDX   #$00                      ; Amplitude
            LDA   #$80                      ; Frequency
            LDY   #$03
:L3         JSR   ENSQOSCIL                 ; Initialize channel Y
            DEY
            BPL   :L3
            RTS

* Configure Ensoniq oscillator
* On entry: Y - oscillator number 0-3 , A - frequency, X - amplitude
* Preserves all registers
* TODO: ALWAYS USES OSCILLATOR CHANNEL 0 FOR NOW
ENSQOSCIL   PHA
            PHY
            PHX
            LDX   #$00                      ; DOC register $00 (Freq Lo)
            TAY                             ; Frequency value LS byte
            JSR   ENSQWRTDOC
            LDX   #$20                      ; DOC register $20 (Freq Hi)
            LDY   #$00                      ; Frequency value MS byte
            JSR   ENSQWRTDOC
            LDX   #$40                      ; DOC register $40 (Volume)
            PLY                             ; Frequency value orig in X
            PHY
            JSR   ENSQWRTDOC
            LDX   #$80                      ; DOC register $80 (Wavetable)
            LDY   #$00                      ; Wavetable pointer $00
            JSR   ENSQWRTDOC
            LDX   #$A0                      ; DOC register $A0 (Control)
            LDY   #$00                      ; Free run, no IRQ, start
            JSR   ENSQWRTDOC
            LDX   #$C0                      ; DOC register $C0 (WT size)
            LDY   #$00                      ; For 256 byte wavetable
            JSR   ENSQWRTDOC
            PLX
            PLY
            PLA
            RTS

* Wait for Ensoniq to be ready
ENSQWAIT    LDA   ENSQSNDDAT
            AND   #$80
            BNE   ENSQWAIT
            RTS

* Write to DOC registers
* On entry: Value in Y, register in X
* Preserves all registers
ENSQWRTDOC PHA
           JSR   ENSQWAIT                   ; Wait for DOC to be ready
           LDA   ENSQSNDCTL
           AND   #$90                       ; DOC register, no autoincr
           ORA   #$0F                       ; Master volume maximum
           STA   ENSQSNDCTL
           STX   ENSQADDRL                  ; Select DOC register
           STZ   ENSQADDRH
           STY   ENSQSNDDAT                 ; Write data
           PLA
           RTS

