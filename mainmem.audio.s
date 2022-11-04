* MAINMEM.AUDIO.S
* (c) Bobbi 2022 GPLv3
*
* Applecorn audio code
*

SYSCLOCK     DB    $00                       ; Centisecond counter (5 bytes)
             DB    $00
             DB    $00
             DB    $00
             DB    $00

* Sound buffers
* Four bytes are enqueued for each note, as follows:
*  - MS byte of channel number
*  - LS byte of channel number
*  - Frequency
*  - Duration
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

* Envelope buffers 0-15
ENVBUF0      DS   13                         ; 13 bytes not including env num
ENVBUF1      DS   13
ENVBUF2      DS   13
ENVBUF3      DS   13
ENVBUF4      DS   13
ENVBUF5      DS   13
ENVBUF6      DS   13
ENVBUF7      DS   13
ENVBUF8      DS   13
ENVBUF9      DS   13
ENVBUF10     DS   13
ENVBUF11     DS   13
ENVBUF12     DS   13
ENVBUF13     DS   13
ENVBUF14     DS   13
ENVBUF15     DS   13

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
* Does not include the release phase of the envelope (if any)
CHANTIMES   DB    $00
            DB    $00
            DB    $00
            DB    $00

* Envelope number for current note.  $FF if no envelope.
CHANENV     DB    $FF
            DB    $FF
            DB    $FF
            DB    $FF

* Envelope step counter for current note.
* This is used in order to invoke the envelope processing at the requested
* rate in 1/100th of a second.
CHANCTR     DB    $00
            DB    $00
            DB    $00
            DB    $00

* Pitch envelope section (0..4)
PITCHSECT   DB    $00
            DB    $00
            DB    $00
            DB    $00

* Step within pitch envelope section
PITCHSTEP   DB    $00
            DB    $00
            DB    $00
            DB    $00

* Current pitch
CURRPITCH   DB    $00
            DB    $00
            DB    $00
            DB    $00

* Amplitude envelope section (0..3)
* 0: Attack
* 1: Decay
* 2: Sustain
* 3: Release
AMPSECT     DB    $00
            DB    $00
            DB    $00
            DB    $00

* Current amplitude
CURRAMP     DB    $00
            DB    $00
            DB    $00
            DB    $00


* Get address of sound buffer
* On entry: X is buffer number (4..7)
* On exit: A1L,A1H points to start of buffer
* Called with interrupts disabled
GETBUFADDR  LDA   :BUFADDRL,X
            STA   A1L
            LDA   :BUFADDRH,X
            STA   A1H
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
            JSR   GETBUFADDR                 ; Buffer address into A1L,A1H
            PLA                              ; Get value to write back
            STA   (A1L),Y                    ; Write to buffer
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
* NOTE OS1.20 has a bug in the EXAMINE path
* On entry: X is buffer number, V=1 if only examination is requested
* On exit: If examination, A next byte, X preserved, Y=next byte
*          If removal, A undef, X preserved, Y=value of byte removed
*          If buffer already empty C=1, else C=0
REM         PHP                              ; Save flags, turn off interrupts
            SEI
            LDA   STARTINDICES,X             ; Output pointer for buf X
            CMP   ENDINDICES,X
            BEQ   :EMPTY                     ; Buffer is empty
            TAY                              ; Buffer pointer into Y
            JSR   GETBUFADDR                 ; Buffer address into A1L,A1H
            LDA   (A1L),Y                    ; Read byte from buffer
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
            TAY                              ; BUGFIX: Omitted on OS1.20
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
* On exit: A next byte, X preserved
PEEKAUDIO  PHX                               ; Preserve X
           TXA                               ; Audio channel X->A
           ORA   #$04                        ; Convert to queue number
           TAX                               ; Queue number ->X
           BIT   :RTS                        ; Set V, inspect queue
           JSR   REM
           PLX                               ; Recover original X
:RTS       RTS


* Release a suspended note by overwriting its sequence number with zero
* On entry: X is audio channel number
* On exit: X preserved
RELNOTE    PHX                               ; Preserve X
           TXA                               ; Audio channel X->A
           ORA   #$04                        ; Convert to queue number
           TAX                               ; Queue number ->X
           JSR   GETBUFADDR                  ; Buffer address into A1L,A1H
           LDA   STARTINDICES,X              ; Output pointer for buf X
           TAY
           LDA   (A1L),Y                     ; Obtain Hold/Sync byte
           AND   #$F0                        ; Set sync nybble to zero ..
           STA   (A1L),Y                     ; .. to release the note
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
           STZ   CHANTIMES-4,X               ; Set to zero time remaining
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
            JSR   RELNOTE                   ; Release the note
:NEXT2      DEX
            BPL   :L2                       ; Next audio queue
            BRA   :DONE
:SEQ        DB    $00                       ; Sequence number
:CNT        DB    $00                       ; Counter


* Called from Ensoniq interrupt handler - process audio queue
* Should be called at 100Hz
ENSQISR     INC   SYSCLOCK+0                ; Increment system clock
            BNE   :S1
            INC   SYSCLOCK+1
            BNE   :S1
            INC   SYSCLOCK+2
            BNE   :S1
            INC   SYSCLOCK+3
            BNE   :S1
            INC   SYSCLOCK+4

:S1         DEC   :CNT                      ; Find every 5th cycle
            BNE   :AT100HZ
            LDA   #5
            STA   :CNT

            LDX   #3                        ; Process four audio queues
:L1         LDA   CHANTIMES,X               ; Time remaining on current note
            BEQ   :NONOTE                   ; No note playing
            DEC   CHANTIMES,X
            BRA   :NEXT

:NONOTE     JSR   NONOTE                    ; Handle end note / release phase

:PEEK       JSR   PEEKAUDIO                 ; Inspect byte at head of queue
            BCS   :NEXT                     ; Nothing in queue
                                            ; NOTE: A contains HS byte of &HSFC
            TAY                             ; Stash for later
            AND   #$0F                      ; Mask out hold nybble
            BNE   :SYNCSET                  ; Do not play if sync != 0
            TYA                             ; HS byte
            AND   #$F0                      ; Mask out sync nybble
            BNE   :HOLDSET                  ; Handle hold function

            JSR   CHECK4BYTES               ; Check queue has a note
            BCS   :NEXT                     ; Less than 4 bytes, skip

            JSR   REMAUDIO                  ; Remove HS byte from queue
            JSR   REMAUDIO                  ; Remove amplitude byte from queue

            TYA                             ; Amplitude or envelope -> A
            DEC   A
            BPL   :HASENV                   ; If +ve, value was 1,2,3..
            INC   A
            EOR   #$FF                      ; Negate A
            INC   A                         ; ..
            ASL                             ; Multiply by 16
            ASL
            ASL
            ASL
            PHA                             ; Amplitude to stack
            LDA   #$FF                      ; $FF means 'no envelope'
            STA   CHANENV,X
            BRA   :S2
:HASENV     STA   CHANENV,X                 ; Store envelope number
            LDA   #$01
            STA   CHANCTR,X                 ; Set envelope step counter to 1
            STZ   PITCHSECT,X               ; Start on pitch section 0
            STZ   PITCHSTEP,X               ; Start on step 0
            STZ   AMPSECT,X                 ; Start on amplitude section 0
            LDA   #$00                      ; Initial amplitude is zero
            PHA                             ; Zero amplitude to stack

:S2         JSR   REMAUDIO                  ; Remove freq byte from queue
            PHY                             ; Frequency
            JSR   REMAUDIO                  ; Remove dur byte from queue
            TYA                             ; Duration
            DEC   A                         ; EXPERIMENT
            STA   CHANTIMES,X
            PLA                             ; Recover frequency
            STA   CURRPITCH,X               ; Store for pitch envelope
            PLY                             ; Recover amplitude
            JSR   ENSQNOTE                  ; Start note playing
:NEXT 	    DEX
            BPL   :L1                       ; Next audio queue

:AT100HZ                                    ; Here on every call (100Hz)
            LDX   #3                        ; Iterate through channels
:L2         LDA   CHANENV,X                 ; Envelope for this channel?
            BMI   :NOENV                    ; $FF means no envelope
            JSR   ENVTICKS                  ; Handle envelope tick counter
            BCC   :NOENV                    ; This cycle is not a tick
            JSR   PITCHENV                  ; Process pitch envelope
            JSR   ADSRENV                   ; Process amplitude envelope
:NOENV      DEX
            BPL   :L2                       ; Next audio queue
            CLC
            RTL
:HOLDSET    LDA   CURRAMP,X                 ; Get current amplitude
            BNE   :NEXT                     ; If non zero, hold
            JSR   REMAUDIO                  ; Dequeue four bytes
            JSR   REMAUDIO
            JSR   REMAUDIO
            JSR   REMAUDIO
            JMP   :PEEK                     ; Immediately dispatch next note
:SYNCSET    JSR   CHORD                     ; See if chord can be released
            BRA   :NEXT
:CNT        DB    $05                       ; Used to determine 20Hz cycles


* Helper function for ENSQISR - called when no note playing
* On entry: X is audio channel #
NONOTE      LDA   CHANENV,X                 ; See if envelope is in effect
            CMP   #$FF
            BNE   :RELEASE                  ; If envelope -> start rel phase
            STZ   CURRAMP,X                 ; Next env will start at zero vol
            LDY   #$00                      ; Zero volume
            LDA   #$00                      ; Zero freq
            JSR   ENSQNOTE                  ; Silence channel Y
            RTS
:RELEASE    LDA   #3                        ; Phase 3 is release phase
            STA   AMPSECT,X                 ; Force release phase
            RTS


* Helper function for ENSQISR
* On entry: X is audio channel #
* On return: CS if there are <= 4 bytes in queue, CC otherwise
* X is preserved
CHECK4BYTES PHX
            INX                             ; Convert audio channel to buf num
            INX
            INX
            INX
            CLV                             ; Ask to count buffer
            CLC                             ; Ask for space used
            JSR   CNP                       ; Go count it
            TXA
            PLX
            CMP   #3                        ; At least 4 bytes used?
            BMI   :NO
            CLC
            RTS
:NO         SEC
            RTS


* Handle envelope tick counter
* On entry: X is audio channel #
* On return: CS if this cycle is an envelope tick, CC otherwise.
* X is preserved
ENVTICKS    DEC   CHANCTR,X                 ; Decrement counter
            BEQ   :ZERO                     ; Expired
            CLC                             ; Not expired
            RTS
:ZERO       JSR   RSTTICKS                  ; Reset counter
            SEC                             ; Counter had expired
            RTS


* Reset envelope tick counter
* On entry: X is audio channel #
* On return: Sets CHANCTR,X to length of each step in 1/100ths
RSTTICKS    LDA   CHANENV,X                 ; Get envelope number
            TAY
            JSR   GETENVADDR                ; Envelope address in A1L,A1H
            LDY   #ENVT                     ; Parm for length of each step
            LDA   (A1L),Y                   ; Get value of parm
            AND   #$7F                      ; Mask out MSB
            STA   CHANCTR,X                 ; Reset counter
            RTS


* On entry: Y is envelope number
* On return: A1L,A1H point to start of buffer for this envelope
* X is preserved
GETENVADDR  LDA   #<ENVBUF0                 ; Copy ENVBUF0 to A1L,A1H
            STA   A1L
            LDA   #>ENVBUF0
            STA   A1H
:L1         CPY   #$00                      ; See if Y is zero
            BEQ   :DONE                     ; If so, we are done
            LDA   A1L                       ; Add 13 to A1L,A1H
            CLC
            ADC   #13
            STA   A1L
            LDA   A1H
            ADC   #00
            STA   A1H
            DEY                             ; Decr envelopes remaining
            BRA   :L1                       ; Go again
:DONE       RTS

            
* Process pitch envelope
* On entry: X is audio channel #
* X is preserved
PITCHENV    LDA   CHANENV,X                 ; Get envelope number
            TAY
            JSR   GETENVADDR                ; Addr of envelope -> A1L,A1H
            LDA   PITCHSECT,X               ; See what section we are in
            BEQ   :SECT1                    ; Section 1, encoded as 0
            CMP   #$01
            BEQ   :SECT2                    ; Section 2, encoded as 1
            CMP   #$02
            BEQ   :SECT3                    ; Section 3, encoded as 2
            RTS                             ; Other section, do nothing
:SECT1      LDY   #ENVPI1                   ; Parm: change pitch/step section 1
            LDA   (A1L),Y                   ; Get value of parm
            JSR   UPDPITCH                  ; Update the pitch
            LDY   #ENVPN1                   ; Parm: num steps in section 1
            LDA   (A1L),Y                   ; Get value of parm
            CMP   PITCHSTEP,X               ; Are we there yet?
            BEQ   :NXTSECT                  ; Yes!
            INC   PITCHSTEP,X               ; One more step
            RTS
:SECT2      LDY   #ENVPI2                   ; Parm: change pitch/step section 2
            LDA   (A1L),Y                   ; Get value of parm
            JSR   UPDPITCH                  ; Update the pitch
            LDY   #ENVPN2                   ; Parm: num steps in section 2
            LDA   (A1L),Y                   ; Get value of parm
            CMP   PITCHSTEP,X               ; Are we there yet?
            BEQ   :NXTSECT                  ; Yes!
            INC   PITCHSTEP,X               ; One more step
            RTS
:SECT3      LDY   #ENVPI3                   ; Parm: change pitch/step section 3
            LDA   (A1L),Y                   ; Get value of parm
            JSR   UPDPITCH                  ; Update the pitch
            LDY   #ENVPN3                   ; Parm: num steps in section 3
            LDA   (A1L),Y                   ; Get value of parm
            CMP   PITCHSTEP,X               ; Are we there yet?
            BEQ   :LASTSECT                 ; Yes!
            INC   PITCHSTEP,X               ; One more step
            RTS
:NXTSECT    INC   PITCHSECT,X               ; Next section
            STZ   PITCHSTEP,X               ; Back to step 0 of section
            RTS
:LASTSECT   LDY   #ENVT                     ; Parm: length/step + autorepeat
            LDA   (A1L),Y                   ; Get value of parm
            AND   #$80                      ; MSB is auto-repeat flag
            BEQ   :NXTSECT                  ; Not repeating
            STZ   PITCHSECT,X               ; Go back to section 1
            STZ   PITCHSTEP,X               ; Back to step 0 of section
            RTS
            

* Update pitch value. Called by PITCHENV.
* On entry: A - Change of pitch/step, X is audio channel #
* X is preserved
UPDPITCH    STX   OSCNUM
            CLC
            ADC   CURRPITCH,X               ; Add change to current
            STA   CURRPITCH,X               ; Update
            TAY
            JSR   ENSQFREQ                  ; Update Ensoniq regs
            RTS


* Process amplitude envelope
* On entry: X is audio channel #
* X is preserved
ADSRENV     LDA   CHANENV,X                 ; Get envelope number
            TAY
            JSR   GETENVADDR                ; Addr of envelope -> A1L,A1H
            LDA   AMPSECT,X                 ; See what section we are in
            BEQ   :ATTACK                   ; Attack, encoded as 0
            CMP   #$01
            BEQ   :DECAY                    ; Decay, encoded as 1
            CMP   #$02
            BEQ   :SUSTAIN                  ; Sustain, encoded as 2
            CMP   #$03
            BEQ   :RELEASE                  ; Release, encoded as 3
            RTS                             ; Otherwise nothing to do
:ATTACK     LDY   #ENVAA                    ; Parm: attack change/step
            LDA   (A1L),Y                   ; Get value of parm
            PHA
            LDY   #ENVALA                   ; Parm: level at end of attack
            LDA   (A1L),Y                   ; Get value of parm
            PLY
            JSR   ADSRPHASE                 ; Generic ADSR phase handler
            BCS   :NEXTSECT                 ; Phase done -> decay
            RTS
:DECAY      LDY   #ENVAD                    ; Parm: delay change/step
            LDA   (A1L),Y                   ; Get value of parm
            PHA
            LDY   #ENVALD                   ; Parm: level at end of delay
            LDA   (A1L),Y                   ; Get value of parm
            PLY
            JSR   ADSRPHASE                 ; Generic ADSR phase handler
            BCS   :NEXTSECT                 ; Phase done -> sustain
            RTS
:SUSTAIN    LDY   #ENVAS                    ; Parm: delay change/step
            LDA   (A1L),Y                   ; Get value of parm
            TAY
            LDA   #$00                      ; Target level zero
            JSR   ADSRPHASE                 ; Generic ADSR phase handler
            RTS
:RELEASE    LDY   #ENVAR                    ; Parm: attack change/step
            LDA   (A1L),Y                   ; Get value of parm
            TAY
            LDA   #$00                      ; Target level zero
            JSR   ADSRPHASE                 ; Generic ADSR phase handler
            BCS   :FINISH                   ; Level is zero
            RTS
:NEXTSECT   INC   AMPSECT,X                 ; Next section
            RTS
:FINISH     LDA   #$FF                      ; Finished with envelope
            STA   CHANENV,X
            RTS


* Handle any individual phase of the ADSR envelope. Called by ADSRENV.
* On entry: A - level at end of phase, X - audio channel, Y - change/step
* On return: CS if end of phase, CC otherwise.  X preserved.
ADSRPHASE   STX   OSCNUM
            STA   :TARGET                   ; Stash target level for later
            CPY   #$00                      ; Check sign of change/step
            BEQ   :DONE                     ; Change/step is zero
            BMI   :DESCEND                  ; Descending amplitude
:ASCEND     CMP   CURRAMP,X                 ; Compare tgt with current level
            BNE   :S1                       ; Not equal to target, keep going
            SEC                             ; CS to indicate phase is done
            RTS
:S1         TYA                             ; Change/step -> A
            CLC
            ADC   CURRAMP,X                 ; Add change to current amp
            CMP   :TARGET                   ; Compare with target
            BCS   :CLAMP                    ; If target < sum, clamp to target
            BRA   :UPDATE                   
:DESCEND    CMP   CURRAMP,X                 ; Compare tgt with current level
            BNE   :S2                       ; Not equal to target, keep going
            SEC                             ; CS to indicate phase is done
            RTS
:S2         TYA                             ; Change/step -> A
            CLC
            ADC   CURRAMP,X                 ; Add change to current amp
            CMP   :TARGET                   ; Compare with target
            BCC   :CLAMP                    ; If target >= sum, clamp to target
            BRA   :UPDATE                   
:CLAMP      LDA   :TARGET                   ; Recover target level
:UPDATE     STA   CURRAMP,X                 ; Store updated amplitude
            TAY                             ; Tell the Ensoniq
            JSR   ENSQAMP
:DONE       CLC                             ; CC to indicate phase continues
            RTS
:TARGET     DB    $00


*****************************************************************************
* Ensoniq DOC Driver for Apple IIGS Follows ...
*****************************************************************************

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

