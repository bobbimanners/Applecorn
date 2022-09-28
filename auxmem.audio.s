* AUXMEM.AUDIO.S
* (c) Bobbi 2022 GPLv3
*
* Applecorn audio code
*

SNDBUFSZ   EQU   16                          ; All audio buffers are 16 bytes

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
* On exit: A, X preserved. C clear on success.
INSHND      PHP                              ; Save flags, turn off interrupts
            SEI
            PHA
            LDY   ENDINDICES,X               ; Get input pointer
            INY                              ; Next byte
            CPY   #SNDBUFSZ
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
            PLP                              ; Restore flags
            CLC                              ; Exit with carry clear
            RTS
:FULL       PLA                              ; Restore A
            PLP                              ; Restore flags
            SEC                              ; Exit with carry set
            RTS

