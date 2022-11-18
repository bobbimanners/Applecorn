* MAINMEM.ENSQ.S
* (c) Bobbi 2022 GPLv3
*
* Ensoniq DOC Driver for Apple IIGS.
*

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
            LDA   #33+1                     ; Freq G2+1/8 tone = 99.46Hz
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
            STZ   CHANTIMES,X               ; No note playing
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


* Adjust frequency of note already playing
* On entry: Y - frequency to set
* Preserves X & Y
ENSQFREQ    PHX
            PHY                             ; Gonna need it again
            LDA   FREQLOW,Y
            TAY                             ; Frequency value LS byte
            LDA   #$00                      ; DOC register base $00 (Freq Lo)
            JSR   ADDOSC                    ; Actual register in X
            JSR   ENSQWRTDOC
            PLY                             ; Get freq back
            PHY
            LDA   FREQHIGH,Y
            TAY                             ; Frequency value MS byte
            LDA   #$20                      ; DOC register base $20 (Freq Hi)
            JSR   ADDOSC                    ; Actual register in X
            JSR   ENSQWRTDOC
            PLY
            PLX
            RTS


* Adjust amplitude of note already playing
* On entry: Y - amplitude to set
* Preserves X & Y
ENSQAMP     PHX
            PHY                             ; Gonna need it again
            LDA   #$40                      ; DOC register base $00 (Freq Lo)
            JSR   ADDOSC                    ; Actual register in X
            JSR   ENSQWRTDOC
            PLY
            PLX
            RTS

* Ensoniq interrupt service routine - just calls generic audio ISR
ENSQISR     JMP   AUDIOISR


**
** Private functions follow (ie: not part of driver API)
**

* Add oscillator number to value in A, return sum in X
* Used by ENSQNOTE & ENSQFREQ
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

