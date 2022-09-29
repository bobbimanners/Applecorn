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


* Remove value from buffer or examine buffer (REMV)
* On entry: X is buffer number, V=1 if only examination is requested
* On exit: If examination, A next byte, X preserved, Y=offset to next char
*          Removal: A undef, X preserved, Y value of byte removed
*          If buffer already empty C=1, else C=0
REMHND      PHP                              ; Save flags, turn off interrupts
            SEI
            LDA   STARTINDICES,X             ; Output pointer for buf X
            CMP   ENDINDICES,X
            BEQ   :EMPTY                     ; Buffer is empty
            TAY                              ; Buffer pointer into Y
            JSR   GETBUFADDR                 ; Buffer address into OSINTWS
            LDA   (OSINTWS),Y                ; Read byte from buffer
            PHA                              ; Stash for later
            BVS   :EXAM                      ; If only examination, done
            INY                              ; Next byte
            CPY   #16
            BNE   :NOTEND                    ; See if it's the end
            LDY   #0                         ; If so, wraparound
:NOTEND     TYA
            STA   STARTINDICES,X             ; Set output pointer
            PLY                              ; Char read from buffer
            PLP
            CLC                              ; Success
            RTS
:EXAM       PLA                              ; Char read from buffer
            PLP
            CLC                              ; Success
            RTS
:EMPTY      PLP
            SEC                              ; Buffer already empty
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
* Called at 100Hz
ENSQIRQ     INC   COUNTER                   ; Increment centisecond timer
            INC   :CNT                      ; Find every 5th cycle
            CMP   #5
            BNE   :NOT20HZ
            STZ   :CNT
            LDX   #3                        ; Process four audio queues
:L1         LDA   OSCTIMES,X                ; Time remaining on current note
            BEQ   :NONOTE                   ; No note playing
            DEC   OSCTIMES,X
            BRA   :NOTE
:NONOTE     LDY   #$00                      ; Zero volume
            LDA   #$00                      ; Zero freq
            JSR   ENSQNOTE                  ; Silence channel Y
:NOTE       CLV                             ; Means remove from queue
            JSR   REMHND                    ; Remove byte from queue
            BCS   :EMPTY                    ; Nothing in queue
            PHY                             ; Amplitude
            JSR   REMHND                    ; Remove byte from queue
            PHY                             ; Frequency
            JSR   REMHND                    ; Remove byte from queue
            TYA                             ; Duration
            STA   OSCTIMES,X
            PLA                             ; Recover frequency
            PLY                             ; Recover amplitude
            JSR   ENSQNOTE                  ; Start note playing
:EMPTY	    DEX
            BNE   :L1                       ; Next audio queue
:NOT20HZ
* TODO: Envelope processing on all cycles (AT 100Hz)
:RTS        RTS
:CNT        DB    $00                       ; Used to determine 20Hz cycles
COUNTER     DW    $0000                     ; Centisecond counter

* Time remaining for current note, in 1/20th of second
OSCTIMES    DB    $00
            DB    $00
            DB    $00
            DB    $00


* Initialize Ensoniq
ENSQSNDCTL  EQU   $C03C
ENSQSNDDAT  EQU   $C03D
ENSQADDRL   EQU   $C03E
ENSQADDRH   EQU   $C03F

* Initialize Ensoniq
* Setup wavetable - one period of a square wave
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
                                            ; Fall through
* Silence all channels
ENSQSILENT  LDY   #$00                      ; Amplitude
            LDA   #$80                      ; Frequency
            LDX   #$03
:L1         JSR   ENSQNOTE                  ; Initialize channel Y
            STZ   OSCTIMES,X                ; No note playing
            DEX
            BPL   :L1
            RTS


* Configure Ensoniq oscillator
* On entry: X - oscillator number 0-3 , A - frequency, Y - amplitude
* Preserves all registers
* TODO: ALWAYS USES OSCILLATOR CHANNEL 0 FOR NOW
ENSQNOTE    PHA
            PHX
            PHY
            LDX   #$00                      ; DOC register $00 (Freq Lo)
            TAY                             ; Frequency value LS byte
            JSR   ENSQWRTDOC
            LDX   #$20                      ; DOC register $20 (Freq Hi)
            LDY   #$00                      ; Frequency value MS byte
            JSR   ENSQWRTDOC
            LDX   #$40                      ; DOC register $40 (Volume)
            PLY                             ; Amplitude value
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
            PLY
            PLX
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

