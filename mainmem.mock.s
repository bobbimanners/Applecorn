* MAINMEM.MOCK.S
* (c) Bobbi 2022 GPLv3
*
* Mockingboard Driver.
*

* Mockingboard control registers

* Initialize Mockingboard
MOCKINIT                                    ; TODO
            RTS


* Silence all channels
MOCKSILENT                                  ; TODO
            RTS


* Configure a Mockingboard oscillator to play a note
* On entry: X - oscillator number 0-3 , A - frequency, Y - amplitude
* Preserves all registers
MOCKNOTE                                    ; TODO
            RTS


* Adjust frequency of note already playing
* On entry: Y - frequency to set
* Preserves X & Y
MOCKFREQ                                    ; TODO
            RTS


* Adjust amplitude of note already playing
* On entry: Y - amplitude to set
* Preserves X & Y
MOCKAMP     PHX
            PHY                             ; Gonna need it again
                                            ; TODO
            PLY
            PLX
            RTS


