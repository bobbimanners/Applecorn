* MAINMEM.WILD.S
* (c) Bobbi 2021 GPLv3
*
* Wildcard support

* Performs wildcard matching for operations that only require the
* first match.  <*obj-spec*> in Acorn ADFS terminology.
WILDONE     CLC
            JSR   WILDCARD
            JSR   CLSDIR
            RTS

* Scan path in MOSFILE, break it into segments (ie: chunks delimited
* by '/'), and for each segment see if it contains wildcard chars.
* If so, pass it to SRCHBLK to expand the wildcard.  If not, just 
* append the segment as it is. Uses MFTEMP to build up the path.
* On entry: SEC to force leaf node lookup even if no wildcard,
*           CLC otherwise
* Returns with carry set if wildcard match fails, clear otherwise
WILDCARD    STZ   :ALWAYS       ; Set :ALWAYS if carry set
            BCC   :NORMAL
            DEC   :ALWAYS
:NORMAL     STZ   :LAST
            LDX   #$00          ; Start with first char
            STX   MFTEMP        ; Clear MFTEMP (len=0)
            PHX
:L1         PLX
            JSR   SEGMENT       ; Extract segment of pathname
            JSR   CLSDIR        ; Close open dir, if any
            LDA   #$F0          ; WILDIDX=$F0 denotes new search
            STA   WILDIDX
            BCC   :NOTLST
            DEC   :LAST
:NOTLST     PHX
            LDA   SEGBUF        ; Length of segment
            BNE   :S1           ; Check for zero length segments
            LDA   :LAST         ; If not the last segment ...
            BEQ   :L1           ; ... go again
:S1         JSR   HASWILD       ; See if it has '*'/'#'/'?'
            BCS   :WILD         ; It does
            LDA   :ALWAYS       ; Always do leaf-node lookup?
            BEQ   :S2
            LDA   :LAST         ; If it is the last segment do ..
            BNE   :WILD         ; .. wildcard lookup anyhow (for *INFO)
:S2         JSR   APPSEG        ; Not wild: Append SEGBUF to MFTEMP
            BRA   :NEXT
:WILD       LDX   #<MFTEMP      ; Invoke SRCHBLK to look for pattern
            LDY   #>MFTEMP      ; in the directory path MFTEMP
:AGAIN      JSR   SRCHBLK
            BCC   :NOMATCH      ; Wildcard did not match anything
            JSR   APPMATCH      ; Append MATCHBUF to MFTEMP
:NEXT       LDA   :LAST
            BEQ   :L1
            PLX
            JSR   TMPtoMF       ; Copy the path we built to MOSFILE
            CLC
            RTS
:NOMATCH    LDA   WILDIDX       ; See if there are more blocks
            CMP   #$FF
            BEQ   :AGAIN        ; Yes, go again
            PLX
            SEC
            RTS
:LAST       DB    $00           ; Flag for last segment
:ALWAYS     DB    $00           ; Flag to always lookup leafnode

* Obtain subsequent wildcard matches
* WILDCARD must have been called first
* Returns with carry set if wildcard match fails, clear otherwise
* Caller should check WILDIDX and call again if value is $FF
WILDNEXT    LDX   MFTEMP        ; Length of MFTEMP
:L1         CPX   #$00          ; Find final segment (previous match)
            BEQ   :AGAIN
            LDA   MFTEMP,X
            CMP   #'/'
            BNE   :S2
            DEX
            STX   MFTEMP        ; Trim MFTEMP
            BRA   :AGAIN
:S2         DEX
            BRA   :L1
:AGAIN      JSR   SRCHBLK
            BCC   :NOMATCH
            JSR   APPMATCH      ; Append MATCHBUF to MFTEMP
            JSR   TMPtoMF       ; Copy back to MOSFILE
            CLC
            RTS
:NOMATCH    LDA   WILDIDX       ; See if there are more blocks
            CMP   #$FF
            BEQ   :AGAIN        ; Yes, go again
            SEC
            RTS

* Different version of WILDNEXT which is used by the *INFO handler
* Because it needs to intercept each block.
* TO DO: Refactor/cleanup
WILDNEXT2   LDX   MFTEMP        ; Length of MFTEMP
:L1         CPX   #$00          ; Find final segment (previous match)
            BEQ   :AGAIN
            LDA   MFTEMP,X
            CMP   #'/'
            BNE   :S2
            DEX
            STX   MFTEMP        ; Trim MFTEMP
            BRA   :AGAIN
:S2         DEX
            BRA   :L1
:AGAIN      JSR   SRCHBLK
            BCC   :NOMATCH
            JSR   APPMATCH      ; Append MATCHBUF to MFTEMP
            JSR   TMPtoMF       ; Copy back to MOSFILE
            CLC
            RTS
:NOMATCH    SEC
            RTS

* Copy a segment of the path into SEGBUF
* PREPATH makes all paths absolute, so always begins with '/'
* On entry: X contains index of first char in MOSFILE to process
* Set carry if no more segments, clear otherwise
SEGMENT     LDY   #$00
:L1         CPX   MOSFILE       ; See if we are done
            BEQ   :NOMORE
            LDA   MOSFILE+1,X
            CMP   #'/'
            BEQ   :DONE
            JSR   TOUPPER
            STA   SEGBUF+1,Y
            INX
            INY
            BRA   :L1
:DONE       STY   SEGBUF        ; Record the length
            LDA   #$00
            STA   SEGBUF+1,Y    ; Null terminate for MATCH
            INX                 ; Skip the slash
            CLC                 ; Not the last one
            RTS
:NOMORE     STY   SEGBUF        ; Record the length
            LDA   #$00
            STA   SEGBUF+1,Y    ; Null terminate for MATCH
            SEC                 ; Last segment
            RTS

* Convert char in A to uppercase
TOUPPER     CMP   #'z'+1
            BCS   :DONE         ; > 'z'
            CMP   #'a'
            BCC   :DONE         ; < 'a'
            AND   #$DF          ; Clear $20 bits
:DONE       RTS

* See if SEGBUF contains any of '*', '#', '?'
* Set carry if wild, clear otherwise
HASWILD     LDX   #$00
:L1         CPX   SEGBUF        ; At end?
            BEQ   :NOTWILD
            LDA   SEGBUF+1,X
            CMP   #'*'
            BEQ   :WILD
            CMP   #'#'
            BEQ   :WILD
            CMP   #'?'
            BEQ   :WILD
            INX
            BRA   :L1
:NOTWILD    CLC
            RTS
:WILD       SEC
            RTS

* Append SEGBUF to MFTEMP
APPSEG      LDY   MFTEMP        ; Dest idx = length
            LDA   #'/'          ; Add a '/' separator
            STA   MFTEMP+1,Y
            INY
            LDX   #$00          ; Source idx
:L1         CPX   SEGBUF        ; At end?
            BEQ   :DONE
            LDA   SEGBUF+1,X
            STA   MFTEMP+1,Y
            INX
            INY
            BRA   :L1
:DONE       STY   MFTEMP        ; Update length
            RTS

* Append MATCHBUF to MFTEMP
APPMATCH    LDY   MFTEMP        ; Dest idx = length
            LDA   #'/'          ; Add a '/' separator
            STA   MFTEMP+1,Y
            INY
            LDX   #$00          ; Source idx
:L1         CPX   MATCHBUF      ; At end?
            BEQ   :DONE
            LDA   MATCHBUF+1,X
            STA   MFTEMP+1,Y
            INX
            INY
            BRA   :L1
:DONE       STY   MFTEMP        ; Update length
            RTS

* The following is required in order to be able to resume
* a directory search
WILDFILE    DB    $00           ; File ref num for open dir
WILDIDX     DB    $00           ; Dirent idx in current block

* Read directory block, apply wildcard match
* Inputs: directory name in XY (Pascal string)
* On exit: set carry if match, clear carry otherwise
* Leaves the directory open to allow resumption of search.
SRCHBLK     LDA   WILDIDX
            CMP   #$F0          ; Is it a new search?
            BEQ   :NEW
            CMP   #$FF          ; Time to load another blk?
            BEQ   :READ         ; Continue search in next blk
            BRA   :CONT         ; Continue search in curr blk
:NEW        STX   OPENPL+1
            STY   OPENPL+2
            JSR   OPENFILE
            BCS   :NODIR
            LDA   OPENPL+5      ; File ref num
            STA   WILDFILE      ; Stash for later
            STA   READPL+1
:READ       JSR   RDFILE        ; Read->BLKBUF
            BCC   :CONT
            CMP   #$4C          ; EOF
            BNE   :BADDIR
            STZ   WILDIDX       ; So caller knows not to call again
:EOF
:BADDIR
:NODIR
            CLC                 ; No match, caller checks WILDIDX ..
            RTS                 ; .. to see if another block

:CONT       JSR   SRCHBLK2      ; Handle one block
            RTS

* Close directory, if it was open
* Preserves A and flags
CLSDIR      PHP
            PHA
            LDA   WILDFILE      ; File ref num for open dir
            BEQ   :ALREADY      ; Already been closed
            STA   CLSPL+1
            JSR   CLSFILE
            STZ   WILDFILE      ; Not strictly necessary
:ALREADY    PLA
            PLP
            RTS

* Apply wildcard match to a directory block
* Directory block is in BLKBUF
* On exit: set carry if match, clear carry otherwise
SRCHBLK2    LDX   WILDIDX
            CPX   #$F0          ; Is it a new search?
            BEQ   :NEW
            BRA   :CONT
:NEW        LDA   BLKBUF+4      ; Obtain storage type
            AND   #$E0          ; Mask 3 MSBs
            CMP   #$E0
            BNE   :NOTKEY       ; Not key block
            LDX   #$01          ; Skip dir name
            BRA   :L1
:NOTKEY     LDX   #$00
:L1         PHX
            JSR   MATCHENT
            PLX
            BCS   :MATCH
:CONT       INX
            CPX   #13           ; Number of dirents in blk
            BNE   :L1
            LDX   #$FF          ; Reset index to -1 for nxt blk
            CLC                 ; Fell off end, no match
:MATCH      STX   WILDIDX       ; Record dirent idx for resume
            RTS

* Apply wildcard match to a directory entry
* On entry: X = dirent index in BLKBUF
* On exit: set carry if match, clear carry otherwise
MATCHENT    LDA   #<BLKBUF+4    ; Skip pointers
            STA   A1L
            LDA   #>BLKBUF+4
            STA   A1H
:L1         CPX   #$00
            BEQ   :S1
            CLC
            LDA   #$27          ; Size of dirent
            ADC   A1L
            STA   A1L
            LDA   #$00
            ADC   A1H
            STA   A1H
            DEX
            BRA   :L1
:S1         LDY   #$00
            LDA   (A1L),Y       ; Length byte
            BEQ   :NOMATCH      ; Inactive entry
            AND   #$0F
            TAY
            INY
            LDA   #$00
            STA   (A1L),Y       ; Null terminate filename for MATCH
            INC   A1L           ; Inc ptr, skip length byte
            BNE   :S2
            INC   A1H
:S2         JSR   MATCH         ; Try wildcard match
            PHP
            LDA   A1L           ; Decrement ptr again
            BNE   :S3
            DEC   A1H
:S3         DEC   A1L
            PLP
            BCC   :NOMATCH
            LDY   #$00          ; If matches, copy matching filename
            LDA   (A1L),Y       ; Length of filename
            AND   #$0F          ; Mask out other ProDOS stuff
            STA   MATCHBUF
            TAY
:L2         CPY   #$00
            BEQ   :MATCH
            LDA   (A1L),Y
            STA   MATCHBUF,Y
            DEY
            BRA   :L2
:MATCH      SEC
            RTS
:NOMATCH    LDA   #$00
            LDY   #$00
            STA   (A1L),Y       ; Pretend entry is deleted
            CLC
            RTS

* From: http://6502.org/source/strings/patmatch.htm
* Input:  A NUL-terminated, <255-length pattern at address PATTERN.
*         A NUL-terminated, <255-length string pointed to by STR.
* Output: Carry bit = 1 if the string matches the pattern, = 0 if not.
* Notes:  Clobbers A, X, Y. Each * in the pattern uses 4 bytes of stack.

MATCH1      EQU   '?'           ; Matches exactly 1 character
MATCH1A     EQU   '#'           ; Matches exactly 1 character (alternate)
MATCHN      EQU   '*'           ; Matches any string (including "")
STR         EQU   A1L           ; Pointer to string to match

MATCH       LDX   #$00          ; X is an index in the pattern
            LDY   #$FF          ; Y is an index in the string
:NEXT       LDA   SEGBUF+1,X    ; Look at next pattern character
            CMP   #MATCHN       ; Is it a star?
            BEQ   :STAR         ; Yes, do the complicated stuff
            INY                 ; No, let's look at the string
            CMP   #MATCH1       ; Is the pattern caracter a ques?
            BEQ   :QUEST        ; Yes
            CMP   #MATCH1A      ; Alternate pattern char (hash)
            BNE   :REG          ; No
:QUEST      LDA   (STR),Y       ; Yes, so it will match anything
            BEQ   :FAIL         ;  except the end of string
:REG        CMP   (STR),Y       ; Are both characters the same?
            BNE   :FAIL         ; No, so no match
            INX                 ; Yes, keep checking
            CMP   #0            ; Are we at end of string?
            BNE   :NEXT         ; Not yet, loop
:FOUND      RTS                 ; Success, return with C=1

:STAR       INX                 ; Skip star in pattern
            CMP   SEGBUF+1,X    ; String of stars equals one star
            BEQ   :STAR         ;  so skip them also
:STLOOP     TXA                 ; We first try to match with * = ""
            PHA                 ;  and grow it by 1 character every
            TYA                 ;  time we loop
            PHA                 ; Save X and Y on stack
            JSR   :NEXT         ; Recursive call
            PLA                 ; Restore X and Y
            TAY
            PLA
            TAX
            BCS   :FOUND        ; We found a match, return with C=1
            INY                 ; No match yet, try to grow * string
            LDA   (STR),Y       ; Are we at the end of string?
            BNE   :STLOOP       ; Not yet, add a character
:FAIL       CLC                 ; Yes, no match found, return with C=0
            RTS

SEGBUF      DS    65            ; For storing path segments (Pascal str)
MATCHBUF    DS    65            ; For storing match results (Pascal str)

















































