* MAINMEM.MOCK.S
* (c) Bobbi 2022 GPLv3
*
* Mockingboard Driver.
* Simulates Hitachi SN76489 sound generator chip found in BBC Micro.
*
*
* I borrowed some ideas from Deater:
* https://github.com/deater/dos33fsprogs/blob/master/music/pt3_lib/pt3_lib_mockingboard_setup.s
*

* Mockingboard control registers
* ASSUMES SLOT 4
MOCK_6522_ORB1     EQU   $C400    ; 6522 #1 port b data
MOCK_6522_ORA1     EQU   $C401    ; 6522 #1 port a data
MOCK_6522_DDRB1    EQU   $C402    ; 6522 #1 data direction port B
MOCK_6522_DDRA1    EQU   $C403    ; 6522 #1 data direction port A
MOCK_6522_T1CL     EQU   $C404    ; 6522 #1 t1 low order latches
MOCK_6522_T1CH     EQU   $C405    ; 6522 #1 t1 high order counter
MOCK_6522_T1LL     EQU   $C406    ; 6522 #1 t1 low order latches
MOCK_6522_T1LH     EQU   $C407    ; 6522 #1 t1 high order latches
MOCK_6522_T2CL     EQU   $C408    ; 6522 #1 t2 low order latches
MOCK_6522_T2CH     EQU   $C409    ; 6522 #1 t2 high order counters
MOCK_6522_SR       EQU   $C40A    ; 6522 #1 shift register
MOCK_6522_ACR      EQU   $C40B    ; 6522 #1 auxilliary control register
MOCK_6522_PCR      EQU   $C40C    ; 6522 #1 peripheral control register
MOCK_6522_IFR      EQU   $C40D    ; 6522 #1 interrupt flag register
MOCK_6522_IER      EQU   $C40E    ; 6522 #1 interrupt enable register
MOCK_6522_ORANH    EQU   $C40F    ; 6522 #1 port a data no handshake
MOCK_6522_ORB2     EQU   $C480    ; 6522 #2 port b data
MOCK_6522_ORA2     EQU   $C481    ; 6522 #2 port a data
MOCK_6522_DDRB2    EQU   $C482    ; 6522 #2 data direction port B
MOCK_6522_DDRA2    EQU   $C483    ; 6522 #2 data direction port A

; AY-3-8910 commands on port B
MOCK_AY_RESET      EQU   $0
MOCK_AY_INACTIVE   EQU   $4
MOCK_AY_READ       EQU   $5
MOCK_AY_WRITE      EQU   $6
MOCK_AY_LATCH_ADDR EQU   $7


* Initialize Mockingboard
MOCKINIT    LDA   #$FF                      ; All VIA pins output
            STA   MOCK_6522_DDRB1
            STA   MOCK_6522_DDRA1
            STA   MOCK_6522_DDRB2
            STA   MOCK_6522_DDRA2

            LDA   #MOCK_AY_RESET            ; Reset left AY-3
            STA   MOCK_6522_ORB1
            LDA   #MOCK_AY_INACTIVE
            STA   MOCK_6522_ORB1

            LDA   #MOCK_AY_RESET            ; Reset right AY-3
            STA   MOCK_6522_ORB2
            LDA   #MOCK_AY_INACTIVE
            STA   MOCK_6522_ORB2

            LDA   #<MOCKISR                 ; Set up ISR with ALLOC_INTERRUPT
            STA   ALLOCPL+2
            LDA   #>MOCKISR
            STA   ALLOCPL+3
            JSR   MLI
            DB    ALLOCCMD
            DW    ALLOCPL

            PHP
            SEI
            LDA   #$40                      ; Configure VIA interrupt
            STA   MOCK_6522_ACR
            LDA   #$7F                      ; Clear all bits
            STA   MOCK_6522_IER
            LDA   #$C0                      ; Set bit 6
            STA   MOCK_6522_IFR
            STA   MOCK_6522_IER
            LDA   #$F4                      ; $27F4 => 100Hz
            STA   MOCK_6522_T1CL
            LDA   #$27
            STA   MOCK_6522_T1CH
            PLP

* Silence all channels
MOCKSILENT  LDX  #13                        ; Clear all 14 AY-3 regs
            LDA  #$00
:L0         JSR  MOCKWRT1
            JSR  MOCKWRT2
            DEX
            BPL  :L0
            LDA  #$38                       ; Turn off noise
            LDX  #07
            JSR  MOCKWRT1                   ; First AY-3
            LDA  #$14                       ; A,B=tone; C=noise
            JSR  MOCKWRT2                   ; Second AY-3
            RTS


* Stop Mockingboard interrupt
MOCKSTOP    JSR   MOCKSILENT
            LDA   #$7F                      ; Clear all bits
            STA   MOCK_6522_IER
            LDA   ALLOCPL+1                 ; Interrupt number
            STA   DEALLOCPL+1
            JSR   MLI                       ; Deallocate ISR
            DB    DEALLOCCMD
            DW    DEALLOCPL
            RTS


* Configure a Mockingboard oscillator to play a note
* On entry: X - oscillator number 0-3, A - frequency, Y - amplitude
* Preserves all registers
MOCKNOTE    PHA
            PHY
            TAY
            JSR   MOCKFREQ                  ; Set frequency
            PLY
            JSR   MOCKAMP                   ; Set amplitude
            PLA
            RTS


* Adjust frequency of note already playing
* On entry: X - oscillator number 0-3, Y - frequency to set
* Preserves X & Y
MOCKFREQ    PHX
            CPX   #$00                      ; Oscillator 0 is noise channel
            BEQ   :NOISE
            CPX   #$01                      ; Oscillator 1 controls noise freq
            BNE   :S0                       ; Not 1? Skip
            CMP   #$00                      ; If frequency is zero ..
            BEQ   :S0                       ; .. skip
            STA   :CH1NOTE                  ; Store frequency for noise gen
:S0         TXA
            DEC   A                         ; Subtract 1
            ASL                             ; Double to get fine register
            TAX
            LDA   MFREQLOW,Y                ; LSB of divider
            JSR   MOCKWRT1                  ; Write value to AY-3 register
            INX                             ; Add one for course register
            LDA   MFREQHIGH,Y               ; MSB of divider
            JSR   MOCKWRT1                  ; Write value to AY-3 register
            PLX
            RTS
:NOISE      TYA                             ; Parameter P
            AND   #$03                      ; Keep least significant 2 bits
            TAY
            LDA   :NOISENOTE,Y              ; Get value of note
            EOR   #$FF                      ; Negate
            INC   A
            CLC                             ; Add 255
            ADC   #$FF
            LSR                             ; Convert 0..255 to 0..31
            LSR
            LSR
            LDX   #6                        ; Noise period register
            JSR   MOCKWRT2                  ; Write value to AY-3 register
            PLX
            RTS
:NOISENOTE  DB    $FF                       ; BBC Micro note P=0 or 4
            DB    $80                       ; BBC Micro note P=1 or 5
            DB    $00                       ; BBC Micro note P=2 or 6
:CH1NOTE    DB    $00                       ; Note on channel 1


* Adjust amplitude of note already playing
* On entry: X - oscillator number 0-3, Y - amplitude to set
* Preserves X & Y
MOCKAMP     PHX
            CPX   #$00                      ; Noise channel
            BEQ   :NOISE
            TXA                             ; Add 7 to get register
            CLC
            ADC   #7
            TAX
            TYA                             ; Amplitude 0..255
            LSR                             ; Divide by 16
            LSR
            LSR
            LSR                             ; Now 0..15
            JSR   MOCKWRT1                  ; Write value to AY-3 register
            PLX
            RTS
:NOISE      LDX   #10                       ; Chan C
            TYA                             ; Amplitude 0..255
            LSR                             ; Divide by 16
            LSR
            LSR
            LSR                             ; Now 0..15
            JSR   MOCKWRT2                  ; Write value to AY-3 register
            PLX
            RTS


* Mockingboard interrupt service routine - just calls generic audio ISR
MOCKISR     CLD
            LDA   MOCK_6522_IFR            ; Interrupt flag register
            AND   #$40                     ; Bit 6
            BEQ   :NOTMB                   ; Wasn't Mockingboard IRQ
            BIT   MOCK_6522_T1CL           ; Clear interrupt
            JSR   AUDIOISR
            CLC                            ; CC indicates we serviced irq
            RTS
:NOTMB      SEC                            ; We did not handle irq
            RTS


**
** Private functions follow (ie: not part of driver API)
**

* Write to first AY-3
* On entry: A - value, X - register
* On exit: All regs preserved.
MOCKWRT1    PHY
            STX   MOCK_6522_ORA1            ; Latch the address
            LDY   #MOCK_AY_LATCH_ADDR
            STY   MOCK_6522_ORB1

            LDY   #MOCK_AY_INACTIVE         ; Go inactive
            STY   MOCK_6522_ORB1

            STA   MOCK_6522_ORA1            ; Write data
            LDY   #MOCK_AY_WRITE
            STY   MOCK_6522_ORB1

            LDY   #MOCK_AY_INACTIVE         ; Go inactive
            STY   MOCK_6522_ORB1
            PLY
            RTS


* Write to second AY-3
* On entry: A - value, X - register
* On exit: All regs preserved.
MOCKWRT2    PHY
            STX   MOCK_6522_ORA2            ; Latch the address
            LDY   #MOCK_AY_LATCH_ADDR
            STY   MOCK_6522_ORB2

            LDY   #MOCK_AY_INACTIVE         ; Go inactive
            STY   MOCK_6522_ORB2

            STA   MOCK_6522_ORA2            ; Write data
            LDY   #MOCK_AY_WRITE
            STY   MOCK_6522_ORB2

            LDY   #MOCK_AY_INACTIVE         ; Go inactive
            STY   MOCK_6522_ORB2
            PLY
            RTS

