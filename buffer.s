* BUFFER.S
* Buffer handling code, called by INSV, REMV, CNPV

* Location and sizes of buffers
* -----------------------------
BUF4	EQU	$0340
BUF4SZ	EQU	16
BUF5	EQU	$0350
BUF5SZ	EQU	16
BUF6	EQU	$0360
BUF6SZ	EQU	16
BUF7	EQU	$0370
BUF7SZ	EQU	16
BUF3	EQU	$0380
BUF3SZ	EQU	64
BUFBASE	EQU	$03C0		; Base of buffer workspace
BUF0	EQU	$03E0
BUF0SZ	EQU	32
BUF2	EQU	$0C00
BUF2SZ	EQU	192
BUF8	EQU	$0CC0
BUF8SZ	EQU	64
BUF1	EQU	$0D00
BUF1SZ	EQU	256


* The buffers are arranged so that an offset of &FF is the last entry, and
* incrementing to &00 passes the end of the buffer. A buffer is empty when
* BUFINP=BUFOUT, and is full when BUFINP+1=BUFOUT.

* BUFFER ADDRESS LOW BYTE LOOKUP TABLE
* ------------------------------------
*		 start+len
BUFLO	DB	(BUF0 + BUF0SZ - 256) AND 255	; keyboard
	DB	(BUF1 + BUF1SZ - 256) AND 255	; serial input
	DB	(BUF2 + BUF2SZ - 256) AND 255	; serial output
	DB	(BUF3 + BUF3SZ - 256) AND 255	; printer
	DB	(BUF4 + BUF4SZ - 256) AND 255	; sound 0
	DB	(BUF5 + BUF5SZ - 256) AND 255	; sound 1
	DB	(BUF6 + BUF6SZ - 256) AND 255	; sound 2
	DB	(BUF7 + BUF7SZ - 256) AND 255	; sound 3
	DB	(BUF8 + BUF8SZ - 256) AND 255	; speech
 
* BUFFER ADDRESS HIGH BYTE LOOKUP TABLE
* -------------------------------------
*		 start+len
BUFHI	DB	(BUF0 + BUF0SZ - 256) DIV 256	; keyboard
	DB	(BUF1 + BUF1SZ - 256) DIV 256	; serial input
	DB	(BUF2 + BUF2SZ - 256) DIV 256	; serial output
	DB	(BUF3 + BUF3SZ - 256) DIV 256	; printer
	DB	(BUF4 + BUF4SZ - 256) DIV 256	; sound 0
	DB	(BUF5 + BUF5SZ - 256) DIV 256	; sound 1
	DB	(BUF6 + BUF6SZ - 256) DIV 256	; sound 2
	DB	(BUF7 + BUF7SZ - 256) DIV 256	; sound 3
	DB	(BUF8 + BUF8SZ - 256) DIV 256	; speech

* BUFFER START ADDRESS OFFSET
* ---------------------------
*		    len
BUFOFF	DB	256-BUF0SZ
	DB	256-BUF1SZ
	DB	256-BUF2SZ
	DB	256-BUF3SZ
	DB	256-BUF4SZ
	DB	256-BUF5SZ
	DB	256-BUF6SZ
	DB	256-BUF7SZ
	DB	256-BUF8SZ

BUFNUM	EQU	BUFHI-BUFLO		; Number of buffers
BUFFLG	EQU	BUFBASE+0*BUFNUM	; Buffer flags
BUFINP	EQU	BUFBASE+1*BUFNUM	; Input pointers
BUFOUT	EQU	BUFBASE+2*BUFNUM	; Output pointers


* Get buffer base address
* -----------------------
* On entry, X=buffer number (not checked)
* On exit,  (OSINTWS)=>buffer base
BUFADDR	LDA	BUFLO,X
	STA	OSINTWS+0	; Get buffer base address low
	LDA	BUFHI,X
	STA	OSINTWS+1	; Get buffer base address high
	RTS


* REMV buffer remove
* ==================
* On entry, X =buffer number
*           VS=examine buffer
*           VC=remove from buffer
* On exit,  X =preserved
*           CS=buffer empty
*              A,Y corrupted
*           CC=buffer not empty
*              A=Y=byte from buffer
*           If called to remove from buffer, pointers updated
*
BUFREM	PHP			; Save flags
	SEI			; Disable IRQs
	CPX   #BUFNUM		; Valid buffer number?
	BCS   BUFFAIL		; No, return 'empty'
	LDA   BUFOUT,X		; Get output pointer for buffer X
	CMP   BUFINP,X		; Compare it to input pointer
	BEQ   BUFFAIL		; Equal, so buffer is empty
	TAY			; Y=output pointer
	JSR   BUFADDR		; Get buffer base address
	LDA   (OSINTWS),Y	; Get byte from buffer
	BVS   BUFREM2		; If VS, just examine buffer, return
	INY			; Otherwise, update buffer pointer
	BNE   BUFREM1		; Not zero, not reached end of buffer
	LDY   BUFOFF,X		; Get offset to start of buffer
BUFREM1	STY   BUFOUT,X		; Update the buffer output pointer
BUFREM2	TAY			; Return A=Y=byte from buffer
	PLP			; Restore IRQs
	CLC			; CLC=success
	RTS


* INSV buffer insert
* ==================
* On entry, X =buffer number
*           A =byte to be inserted
* On exit,  X =preserved
*           A =preserved
*           Y =corrupted
*           CS=buffer full, couldn't insert
*           CC=buffer wasn't full, insertion successful
*
BUFINS	PHP			; Save flags
	SEI			; Disable IRQs
	CPX   #BUFNUM		; Valid buffer number?
	BCS   BUFINS2		; No, sink it and return 'ok'
	PHA			; Save A
	LDY   BUFINP,X		; Get buffer input pointer
	INY			; Otherwise, update buffer pointer
	BNE   BUFINS1		; Not zero, not reached end of buffer
	LDY   BUFOFF,X		; Get offset to start of buffer
BUFINS1	TYA			; A=updated input pointer
	CMP   BUFOUT,X		; Compare with output pointer
	BEQ   BUFINS4		; Same, buffer is full, exit with 'failed'
	LDY   BUFINP,X		; Get unupdated input pointer back
	STA   BUFINP,X		; Store updated input pointer
	JSR   BUFADDR		; Get buffer base address
	PLA			; Get the byte back
	STA   (OSINTWS),Y	; And store it in buffer
BUFINS2	PLP			; Restore IRQs
	CLC			; CLC=success
	RTS

BUFINS4	PLA			; Restore A
BUFFAIL	PLP			; Restore IRQs
	SEC			; SEC=failed
	RTS


* CNPV count/purge buffer
* =======================
* On entry, X =buffer number
*           VC=purge (clear) buffer
*           VS=count buffer
*              CC=count used space
*              CS=count free space
* On exit,  XY=size counted
*           A =corrupted
*
BUFCNP	CPX   #BUFNUM		; Valid buffer number?
	BCS   BUFCNP1		; No, ignore it
	BVC   BUFCNT1		; VS, count buffer
	LDA   BUFOUT,X		; Set input=output, empty buffer
	STA   BUFINP,X
BUFCNP1	BVS   BUFCNT5		; Purged, exit
	LDX   #$00
	BEQ   BUFCNT4		; Count, return zero
  
BUFCNT1	PHP			; Save flags
	SEI			; Disable IRQs
	SEC			; Prepare for SBC
	LDA   BUFOUT,X		; Get output pointer
	SBC   BUFINP,X		; Subtract input pointer
	BCS   BUFCNT2		; No overflow, use it
	SEC			; Prepare for SBC
	SBC   BUFOFF,X		; Subtract buffer start offset
BUFCNT2	PLP			; Get flags back, also restore IRQs
	BCC   BUFCNT3		; CLC, exit with size counted
	CLC			; Prepare for ADC
	ADC   BUFOFF,X		; Add buffer offset to get NEG(bytes free)
	EOR   #&FF		; Invert it to get free space
BUFCNT3	TAX			; YX=count
BUFCNT4	LDY   #&00		; All our buffers are <256 bytes
BUFCNT5	RTS

