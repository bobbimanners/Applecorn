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
WORD07      LDA  (OSCTRL),Y                  ; Get channel number 0-3
            ORA  #$04                        ; Convert to buffer number 4-7
            TAX                              ; Into X
            INY                              ; Point to channel num MSB
            INY                              ; Point to amplitude LSB
            LDA  (OSCTRL),Y
            JSR  INSHND                      ; SHOULD CALL THIS THRU VECTOR INSV
            INY                              ; Point to amplitude MSB
            LDA  (OSCTRL),Y
            JSR  INSHND                      ; SHOULD CALL THIS THRU VECTOR INSV
            INY                              ; Point to pitch LSB
            LDA  (OSCTRL),Y
            JSR  INSHND                      ; SHOULD CALL THIS THRU VECTOR INSV
            INY                              ; Point to pitch MSB
            LDA  (OSCTRL),Y
            JSR  INSHND                      ; SHOULD CALL THIS THRU VECTOR INSV
            INY                              ; Point to duration LSB
            LDA  (OSCTRL),Y
            JSR  INSHND                      ; SHOULD CALL THIS THRU VECTOR INSV
            INY                              ; Point to duration MSB
            LDA  (OSCTRL),Y
            JMP  INSHND                      ; SHOULD CALL THIS THRU VECTOR INSV

