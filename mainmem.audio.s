* MAINMEM.AUDIO.S
* (c) Bobbi 2022 GPLv3
*
* Applecorn audio code
*

COUNTER      DW    $0000                     ; Centisecond counter

* Sound buffers
SNDBUFSZ     EQU   21                        ; FOR 4 NOTES + spare byte
SNDBUF0      DS    SNDBUFSZ
SNDBUF1      DS    SNDBUFSZ
SNDBUF2      DS    SNDBUFSZ
SNDBUF3      DS    SNDBUFSZ

* Pointers for circular buffers
* Buffers 4-7 correspond to audio channels 0 to 3
* Buffers 0-3 are currently unused
SND0STARTIDX DB   $00                        ; Start indices for sound bufs
SND1STARTIDX DB   $00
SND2STARTIDX DB   $00
SND3STARTIDX DB   $00
STARTINDICES EQU  SND0STARTIDX - 4

SND0ENDIDX   DB   $00                        ; End indices for sound bufs
SND1ENDIDX   DB   $00
SND2ENDIDX   DB   $00
SND3ENDIDX   DB   $00
ENDINDICES   EQU  SND0ENDIDX - 4

* Envelope buffers 0-3
ENVBUF0      DS   13                         ; 13 bytes not including env num
ENVBUF1      DS   13
ENVBUF2      DS   13
ENVBUF3      DS   13

* Offsets of parameters in each envelope buffer
ENVT         EQU  0                          ; Len of step in 1/100 sec
ENVPI1       EQU  1                          ; Change pitch/step section 1
ENVPI2       EQU  2                          ; Change pitch/step section 2
ENVPI3       EQU  3                          ; Change pitch/step section 3
ENVPN1       EQU  4                          ; Num steps section 1
ENVPN2       EQU  5                          ; Num steps section 2
ENVPN3       EQU  6                          ; Num steps section 3
ENVAA        EQU  7                          ; Attack: change/step
ENVAD        EQU  8                          ; Decay: change/step
ENVAS        EQU  9                          ; Sustain: change/step
ENVAR        EQU  10                         ; Release: change/step
ENVALA       EQU  11                         ; Target at end of attack
ENVALD       EQU  12                         ; Target at end of decay

* Time remaining for current note, in 1/20th of second
OSCTIMES    DB    $00
            DB    $00
            DB    $00
            DB    $00

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


* Insert value into buffer (API same as Acorn MOS INSV)
* On entry: A is value, X is buffer number.
* On exit: A, X, Y preserved. C clear on success.
INS         PHP                              ; Save flags, turn off interrupts
            SEI
            PHY
            PHA
            LDY   ENDINDICES,X               ; Get input pointer
            INY                              ; Next byte
            CPY   #SNDBUFSZ
            BNE   :NOTEND                    ; See if it's the end
            LDY   #0                         ; If so, wraparound
:NOTEND     TYA                              ; New input pointer in A
            CMP   STARTINDICES,X             ; See if buffer is full
            BEQ   :FULL
            LDY   ENDINDICES,X               ; Current position
            STA   ENDINDICES,X               ; Write updated input pointer
            JSR   GETBUFADDR                 ; Buffer address into OSINTWS
            PLA                              ; Get value to write back
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


* Entry point to INS for code running in aux
MAININS     >>>   ENTMAIN
            PHY                              ; Y->X after transfer
            PLX
            JSR   INS
            PHP                              ; Flags->A before transfer back
            PLA
            >>>   XF2AUX,INSHNDRET


* Remove value from buffer or examine buffer (API same as Acorn MOS REMV)
* On entry: X is buffer number, V=1 if only examination is requested
* On exit: If examination, A next byte, X preserved, Y=offset to next char
*          If removal, A undef, X preserved, Y value of byte removed
*          If buffer already empty C=1, else C=0
REM         PHP                              ; Save flags, turn off interrupts
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
            CPY   #SNDBUFSZ
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

* Remove value from buffer according to audio channel (0-4)
* On entry: X is audio channel number
* On exit: A undef, X preserved, Y value of byte removed
REMAUDIO   PHX                               ; Preserve X
           TXA                               ; Audio channel X->A
           ORA   #$04                        ; Convert to queue number
           TAX                               ; Queue number ->X
           CLV                               ; Remove byte from queue
           JSR   REM
           PLX                               ; Recover original X
           RTS

* Inspect value in buffer according to audio channel (0-4)
* On entry: X is audio channel number
* On exit: A next byte, X preserved, Y offset to next char
PEEKAUDIO  PHX                               ; Preserve X
           TXA                               ; Audio channel X->A
           ORA   #$04                        ; Convert to queue number
           TAX                               ; Queue number ->X
           BIT   :RTS                        ; Set V, inspect queue
           JSR   REM
           PLX                               ; Recover original X
:RTS       RTS


* Count space in buffer or purge buffer (API same as Acorn MOS CNPV)
* On entry: X is buffer number. V set means purge, V clear means count.
*           C set means space left, C clear means entries used
* On exit: For purge, X & Y are preserved.
*          For count, value in X (Y=0).
*          A undef.  V,C flags preserved.
CNP        PHP                               ; Preserve flags
           BVS   :PURGE                      ; Purge if V set
           SEC                               ; Compute space used
           LDA   ENDINDICES,X
           SBC   STARTINDICES,X
           BPL   :POS                        ; No wrap-around
           CLC                               ; Wrap-around - add SNDBUFSZ
           ADC   #SNDBUFSZ
:POS       LDY   #$00                        ; MSB of count always zero
           PLP                               ; Recover flags
           BCS   :CNTREM                     ; If C set on entry, count remainder
           TAX                               ; Return value in X
           RTS
:CNTREM    EOR   #$FF                        ; Negate and add SNDBUFSZ
           SEC
           ADC   #SNDBUFSZ
           TAX                               ; Return value in X
           RTS
:PURGE     LDA   ENDINDICES,X                ; Eat all buffer contents
           STA   STARTINDICES,X
           STZ   OSCTIMES-4,X                ; Set to zero time remaining
           PLP                               ; Recover flags
           RTS


* Entry point to CNP for code running in aux
MAINCNP     >>>   ENTMAIN
            PHY                              ; Y->X after transfer
            PLX
            PHA                              ; A->flags after transfer
            PLP
            BVS   :PURGE
            JSR   CNP                        ; Count space
            PHX                              ; X->Y for transfer back
            PLY
            >>>   XF2AUX,CNPHNDRET1          ; Return for counting
:PURGE      JSR   CNP                        ; Purge buffer
            PHX                              ; X->Y for transfer back
            PLY
            >>>   XF2AUX,CNPHNDRET2          ; Return for purging


* Process releasing of notes once chord is complete.
* On entry: A chord sequence number, X audio channel
* Preserves all registers
CHORD       PHA
            PHX
            PHY
*
* Part 1: Count all notes at head of queues with seq number = A
*
            STA   :SEQ                      ; Sequence number looking for
            STZ   :CNT                      ; Initialize counter
            LDX   #3                        ; Process all audio queues
:L1         JSR   PEEKAUDIO                 ; See byte at head of queue
            BCS   :NEXT                     ; Empty queue
            AND   #$0F                      ; Mask out hold nybble
            CMP   :SEQ                      ; If matches ..
            BNE   :NEXT
            INC   :CNT                      ; .. count it
:NEXT       DEX
            BPL   :L1                       ; Next audio queue
*
* Part 2: If count = seq number + 1
*
            INC   :SEQ                      ; Seq number + 1
            LDA   :CNT                      ; Compare with counter
            CMP   :SEQ
            BEQ   :RELCHORD                 ; Release notes
:DONE       PLY
            PLX
            PLA
            RTS
*
* Part 3: Overwrite seq numbers with zero to release notes.
*
:RELCHORD   DEC   :SEQ                      ; Put seq back how it was
            LDX   #3                        ; All audio queues
:L2         JSR   PEEKAUDIO                 ; See byte at head of queue
            BCS   :NEXT2                    ; Empty queue
            AND   #$0F                      ; Mask out hold nybble
            CMP   :SEQ                      ; See if matches
            BNE   :NEXT2                    ; Nope, skip
            PHX
            TXA
            ORA   #$04                      ; Convert to buffer number
            TAX
            JSR   GETBUFADDR                ; Audio buf addr -> OSINTWS
            PLX
            LDA   #$00
            STA   (OSINTWS),Y               ; Zero sync nybble (+ hold nybble)
:NEXT2      DEX
            BPL   :L2                       ; Next audio queue
            BRA   :DONE
:SEQ        DB    $00                       ; Sequence number
:CNT        DB    $00                       ; Counter


* Called from Ensoniq interrupt handler - process audio queue
* Should be called at 100Hz
ENSQISR     INC   COUNTER+0                 ; Increment centisecond timer
            BNE   :S1
            INC   COUNTER+1
:S1         DEC   :CNT                      ; Find every 5th cycle
            BNE   :NOT20HZ
            LDA   #5
            STA   :CNT

            LDX   #3                        ; Process four audio queues
:L1         LDA   OSCTIMES,X                ; Time remaining on current note
            BEQ   :NONOTE                   ; No note playing
            DEC   OSCTIMES,X
            BRA   :NEXT
:NONOTE     LDY   #$00                      ; Zero volume
            LDA   #$00                      ; Zero freq
            JSR   ENSQNOTE                  ; Silence channel Y

            JSR   PEEKAUDIO                 ; Inspect byte at head of queue
            BCS   :NEXT                     ; Nothing in queue
                                            ; NOTE: A contains HS byte of &HSFC
            AND   #$0F                      ; Mask out hold nybble
            BNE   :SYNCSET                  ; Do not play if sync != 0

* The following is paranoid maybe. Perhaps can be removed once I am debugged.
            PHX
            PHY
            INX                             ; Convert audio channel to buf num
            INX
            INX
            INX
            CLV                             ; Ask to count buffer
            CLC                             ; Ask for space used
            JSR   CNP                       ; Go count it
            TXA
            PLY
            PLX
            CMP   #3                        ; At least 4 bytes used?
            BMI   :NEXT
* End paranoid section.

            JSR   REMAUDIO                  ; Remove byte from queue
            JSR   REMAUDIO                  ; Remove byte from queue
            PHY                             ; Amplitude
            JSR   REMAUDIO                  ; Remove byte from queue
            PHY                             ; Frequency
            JSR   REMAUDIO                  ; Remove byte from queue
            TYA                             ; Duration
            STA   OSCTIMES,X
            PLA                             ; Recover frequency
            PLY                             ; Recover amplitude
            JSR   ENSQNOTE                  ; Start note playing
:NEXT 	    DEX
            BPL   :L1                       ; Next audio queue
:NOT20HZ
*
* TODO: Envelope processing on all cycles (AT 100Hz)
*
            CLC
            RTL
:SYNCSET    JSR   CHORD                     ; See if chord can be released
            BRA   :NEXT
:CNT        DB    $05                       ; Used to determine 20Hz cycles


* Ensoniq control registers
ENSQSNDCTL  EQU   $C03C
ENSQSNDDAT  EQU   $C03D
ENSQADDRL   EQU   $C03E
ENSQADDRH   EQU   $C03F

* Initialize Ensoniq
* Setup wavetable - one period of a square wave
* Start timer on oscillator #4, silence oscillators 0 to 3
ENSQINIT    LDX   #3
            LDA   #$80                       ; Initialize sound queues
:L0         STZ   SND0STARTIDX,X
            STZ   SND0ENDIDX,X
            DEX
            BNE   :L0

            LDA   ENSQSNDCTL                ; Get settings
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

            LDA   #$5C                      ; GS IRQ.SOUND initialization
            STAL  $E1002C
            LDA   #<ENSQISR
            STAL  $E1002D
            LDA   #>ENSQISR
            STAL  $E1002E
            LDA   #$00                      ; Bank $00
            STAL  $E1002F

            LDX   #$E1                      ; DOC Osc Enable register $E1
            LDY   #10                       ; Five oscillators enabled
            JSR   ENSQWRTDOC
            LDY   #$00                      ; Amplitude for osc #4 (timer)
            LDA   #$20                      ; Frequency for osc #4 (timer)
            LDX   #$04
            JSR   ENSQNOTE                  ; Start oscillator 4
            LDX   #$A4                      ; Control register for osc #4
            LDY   #$08                      ; Free run, with IRQ, start
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


* Configure an Ensoniq oscillator to play a note
* On entry: X - oscillator number 0-3 , A - frequency, Y - amplitude
* Preserves all registers
ENSQNOTE    PHA
            PHX
            PHY
            STX   OSCNUM                    ; Stash oscillator number 0-3

            PHA                             ; Stash orig freq
            TAY
            LDA   FREQLOW,Y
            TAY                             ; Frequency value LS byte
            LDA   #$00                      ; DOC register base $00 (Freq Lo)
            JSR   ADDOSC                    ; Actual register in X
            JSR   ENSQWRTDOC

            PLA                             ; Get orig freq back
            TAY
            LDA   FREQHIGH,Y
            TAY                             ; Frequency value MS byte
            LDA   #$20                      ; DOC register base $20 (Freq Hi)
            JSR   ADDOSC                    ; Actual register in X
            JSR   ENSQWRTDOC

            PLY                             ; Amplitude value
            PHY
            LDA   #$40                      ; DOC register base $40 (Volume)
            JSR   ADDOSC                    ; Actual register in X
            JSR   ENSQWRTDOC

            LDY   #$00                      ; Wavetable pointer $00
            LDA   #$80                      ; DOC register base $80 (Wavetable)
            JSR   ADDOSC                    ; Actual register in X
            JSR   ENSQWRTDOC

            LDY   #$00                      ; Free run, no IRQ, start
            LDA   #$A0                      ; DOC register base $A0 (Control)
            JSR   ADDOSC                    ; Actual register in X
            JSR   ENSQWRTDOC

            LDY   #$00                      ; For 256 byte wavetable
            LDA   #$C0                      ; DOC register base $C0 (WT size)
            JSR   ADDOSC                    ; Actual register in X
            JSR   ENSQWRTDOC

            PLY
            PLX
            PLA
            RTS

* Add oscillator number to value in A, return sum in X
* Used by ENSQNOTE
ADDOSC      CLC
            ADC   OSCNUM
            TAX
            RTS
OSCNUM      DB    $00


* Wait for Ensoniq to be ready
ENSQWAIT    LDA   ENSQSNDCTL
            BMI   ENSQWAIT
            RTS

* Write to a DOC register
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

