* MAINMEM.WILD.S
* (c) Bobbi 2021 GPLv3
*
* Wildcard support

* Scan path in MOSFILE, break it into segments (ie: chunks delimited
* by '/'), and for each segment see if it contains wildcard chars.
* If so, pass it to SRCHDIR to expand the wildcard.  If not, just 
* append the segment as it is. Uses MFTEMP to build up the path.
* Returns with carry set if wildcard match fails, clear otherwise
WILDCARD
        STZ  :LAST
        LDX  #$00        ; Start with first char
        STX  MFTEMP      ; Clear MFTEMP (len=0)
        PHX
:L1     PLX
        JSR  SEGMENT     ; Extract segment of pathname
        BCC  :NOTLST
        DEC  :LAST
:NOTLST PHX
        LDA  SEGBUF      ; Length of segment
        BEQ  :L1         ; Handle zero-len initial segment
        JSR  HASWILD     ; See if it has '*'/'#'/'?'
        BCS  :WILD       ; It does
        JSR  APPSEG      ; Not wild: Append SEGBUF to MFTEMP
        BRA  :NEXT
:WILD   LDX  #<MFTEMP    ; Invoke SRCHDIR to look for pattern
        LDY  #>MFTEMP    ; in the directory path MFTEMP
        JSR  SRCHDIR
	BCS  :NOMATCH    ; Wildcard did not match anything
        JSR  APPSEG      ; Append modified SEGBUF to MFTEMP
:NEXT   LDA  :LAST
        BEQ  :L1
        PLX
        JSR  TMPtoMF     ; Copy the path we built to MOSFILE
        CLC
        RTS
:NOMATCH PLX
        SEC
        RTS
:LAST   DB   $00         ; Flag for last segment

* Copy a segment of the path into SEGBUF
* PREPATH makes all paths absolute, so always begins with '/'
* On entry: X contains index of first char in MOSFILE to process
* Set carry if no more segments, clear otherwise
SEGMENT LDY  #$00
:L1     CPX  MOSFILE    ; See if we are done
        BEQ  :NOMORE
        LDA  MOSFILE+1,X
        CMP  #'/'
        BEQ  :DONE
        STA  SEGBUF+1,Y
        INX
        INY
        BRA  :L1
:DONE   STY  SEGBUF     ; Record the length
        LDA  #$00
        STA  SEGBUF+1,Y ; Null terminate for MATCH
        INX             ; Skip the slash
        CLC             ; Not the last one
        RTS
:NOMORE STY  SEGBUF     ; Record the length
        LDA  #$00
        STA  SEGBUF+1,Y ; Null terminate for MATCH
        SEC             ; Last segment
        RTS

* See if SEGBUF contains any of '*', '#', '?'
* Set carry if wild, clear otherwise
HASWILD LDX  #$00
:L1     CPX  SEGBUF     ; At end?
        BEQ  :NOTWILD
        LDA  SEGBUF+1,X
        CMP  #'*'
        BEQ  :WILD
        CMP  #'#'
        BEQ  :WILD
        CMP  #'?'
        BEQ  :WILD
        INX
        BRA  :L1
:NOTWILD CLC
        RTS
:WILD   SEC
        RTS

* Append SEGBUF to MFTEMP
APPSEG  LDY  MFTEMP     ; Dest idx = length
        LDA  #'/'       ; Add a '/' separator
        STA  MFTEMP+1,Y
        INY
        LDX  #$00       ; Source idx
:L1     CPX  SEGBUF     ; At end?
        BEQ  :DONE
        LDA  SEGBUF+1,X
        STA  MFTEMP+1,Y
        INX
        INY
        BRA  :L1
:DONE   STY  MFTEMP     ; Update length
        RTS

* Read directory, apply wildcard match
* Inputs: directory name in XY (Pascal string)
* If there is a match, replaces SEGBUF with the first match and CLC
* If no match, or any other error, returns with carry set
SRCHDIR STX  OPENPL+1
        STY  OPENPL+2
        JSR  OPENFILE
        BCS  :NODIR
        LDA  OPENPL+5   ; File ref num
        STA  READPL+1
:L1     JSR  RDFILE     ; Read->BLKBUF
        BCC  :S1
        CMP  #$4C       ; EOF
        BEQ  :EOF
        BRA  :BADDIR
:S1     JSR  SRCHBLK    ; Handle one block
        BCS  :MATCH
        BRA  :L1
:MATCH  CLC
        PHP
        BRA  :CLOSE
:BADDIR
:EOF    SEC
        PHP
:CLOSE  LDA  OPENPL+5
        STA  CLSPL+1
        JSR  CLSFILE
        PLP
        RTS
:NODIR  SEC
        RTS

* Apply wildcard match to a directory block
* Directory block is in BLKBUF
* On exit: set carry if match, clear carry otherwise
SRCHBLK LDA  BLKBUF+4   ; Obtain storage type
        AND  #$E0       ; Mask 3 MSBs
        CMP  #$E0
        BNE  :NOTKEY
        LDX  #$01       ; Skip dir name
        BRA  :L1
:NOTKEY LDX  #$00
:L1     PHX
        JSR  MATCHENT
        PLX
        BCS  :MATCH
        INX
        CPX  #13        ; Number of dirents in block
        BNE  :L1
        CLC             ; Fell off end, no match
:MATCH  RTS

* Apply wildcard match to a directory entry
* On entry: X = dirent index in BLKBUF
* On exit: set carry if match, clear carry otherwise
MATCHENT LDA  #<BLKBUF+4  ; Skip pointers
        STA  A1L
        LDA  #>BLKBUF+4
        STA  A1H
:L1     CPX  #$00
        BEQ  :S1
        CLC
        LDA  #$27        ; Size of dirent
        ADC  A1L
        STA  A1L
        LDA  #$00
        ADC  A1H
        STA  A1H
        DEX
        BRA  :L1
:S1     LDY  #$00
        LDA  (A1L),Y     ; Length byte
        BEQ  :NOMATCH    ; Inactive entry
        INC  A1L         ; Inc ptr, skip length byte
        BNE  :S2
        INC  A1H
:S2     JSR  MATCH       ; Try wildcard match
        BCC  :NOMATCH
        LDA  A1L         ; Decrement ptr again
        BNE  :S3
        DEC  A1H
:S3     DEC  A1L
        LDY  #$00        ; If matches, copy matching filename
        LDA  (A1L),Y     ; Length of filename
        AND  #$0F        ; Mask out other ProDOS stuff
        STA  SEGBUF
        TAY
:L2     CPY  #$00
        BEQ  :MATCH
        LDA  (A1L),Y
        STA  SEGBUF,Y
        DEY
        BRA  :L2
:MATCH  SEC
        RTS
:NOMATCH CLC
        RTS

* From: http://6502.org/source/strings/patmatch.htm
* Input:  A NUL-terminated, <255-length pattern at address PATTERN.
*         A NUL-terminated, <255-length string pointed to by STR.
* Output: Carry bit = 1 if the string matches the pattern, = 0 if not.
* Notes:  Clobbers A, X, Y. Each * in the pattern uses 4 bytes of stack.

MATCH1  EQU '?'         ; Matches exactly 1 character
MATCHN  EQU '*'         ; Matches any string (including "")
PATTERN EQU SEGBUF+1    ; Address of pattern
STR     EQU A1L         ; Pointer to string to match

MATCH   LDX #$00        ; X is an index in the pattern
        LDY #$FF        ; Y is an index in the string
:NEXT   LDA PATTERN,X   ; Look at next pattern character
        CMP #MATCHN     ; Is it a star?
        BEQ :STAR       ; Yes, do the complicated stuff
        INY             ; No, let's look at the string
        CMP #MATCH1     ; Is the pattern caracter a ques?
        BNE :REG        ; No, it's a regular character
        LDA (STR),Y     ; Yes, so it will match anything
        BEQ :FAIL       ;  except the end of string
:REG    CMP (STR),Y     ; Are both characters the same?
        BNE :FAIL       ; No, so no match
        INX             ; Yes, keep checking
        CMP #0          ; Are we at end of string?
        BNE :NEXT       ; Not yet, loop
:FOUND  RTS             ; Success, return with C=1

:STAR   INX             ; Skip star in pattern
        CMP PATTERN,X   ; String of stars equals one star
        BEQ :STAR       ;  so skip them also
:STLOOP TXA             ; We first try to match with * = ""
        PHA             ;  and grow it by 1 character every
        TYA             ;  time we loop
        PHA             ; Save X and Y on stack
        JSR :NEXT       ; Recursive call
        PLA             ; Restore X and Y
        TAY
        PLA
        TAX
        BCS :FOUND      ; We found a match, return with C=1
        INY             ; No match yet, try to grow * string
        LDA (STR),Y     ; Are we at the end of string?
        BNE :STLOOP     ; Not yet, add a character
:FAIL   CLC             ; Yes, no match found, return with C=0
        RTS

SEGBUF  DS  65          ; For storing path segments (Pascal str)
                        ; Length needs to be >= 15
                        ; TODO: No overflow check

