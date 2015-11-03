; IO
;
; Various utillity functions to do I/O
;
		module io
;
;==============================================================================
;
; This file is part of the EPNET software
;
; Copyright (C) 2015  Bruce Tanner
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
; If you do use or modify this file, either for its original purpose or for
; something new, I'd love to hear about it! I can be contacted by email at:
;
; brucetanner@btopenworld.com
;
;==============================================================================
;
@CR		equ	13
@LF		equ	10
;
;
;------------------------------------------------------------------------------
; mac
;
; Outputs a MAC address at (HL) in ASCII
;
mac:		ld	b,6
;
.loop:		ld	a,(HL)
		inc	hl
		call	io.byte
		djnz	.loop
;
		ret
;
;
;------------------------------------------------------------------------------
; ip
;
; Outputs an IP address
;
; In:  HL->IP address
;
ip:		call	.num
		call	.dotnum
		call	.dotnum
.dotnum:	ld	a,'.'
		call	io.char
.num:		ld	a,(hl)
		inc	hl
		push	hl
		 call	io.short
		pop	hl
		ret
;
;
;------------------------------------------------------------------------------
; ip_port
;
; Outputs an IP address and port number
;
; In:  HL->IP address
;      BC=port no
;
ip_port:	push	bc		; Save port #
		 call	ip		; Output IP address
		 ld	a,':'
		 call	char
		pop	hl		; HL=port #
		jr	int		; Output it
;
;
;------------------------------------------------------------------------------
; short, int
;
; Outputs a byte or a word in decimal
;
; In:  short: A=byte to output; int: HL=word to output
; Out: B preserved, HL, DE, C, AF corrupted
;
short:		ld	l,a	; Just convert to 16-bit value in HL
		ld	h,0
;
int:		res	0,c	; 0=>no output yet (for leading 0 supression)
		ld	de,10000
		call	.divout	; Output 10,000s
		ld	de,1000
		call	.divout	; Output 1,000s
		ld	de,100
		call	.divout	; Output 100s
		ld	de,10
		call	.divout	; Output 10s
		ld	de,1
		set	0,c	; Output 1s with leading 0s in case first 0
.divout:	call	.div16	; C=ASCII dividend, HL=remainder
		cp	'0'
		jr	nz,.out	; Always output if not 0
;
		bit	0,c	; Else only output if not first digit
		ret	z
;
.out:		set	0,c	; Output a digit so don't supress 0s now
		jr	char
;
;
;
; HL<-remainder of HL/DE, A<-quotient in ASCII
.div16:		ld	a,'0'-1		; -1 for first time round loop
		or	a		; Loop operates with NC
.loop:		inc	a
		sbc	hl,de
		jr	nc,.loop
;
		add	hl,de		; Restore value from last iteration
		ret
;
;
;------------------------------------------------------------------------------
; word, byte, char
;
; Outputs HL in hex, A in hex and A as a character respectively. Only AF
; corrupted
;
word:		ld	a,h
		call	byte
		ld	a,l
		    ;
		    ;
		    ;
;
byte:		push	af
		rrca
		rrca
		rrca
		rrca
		call	nib
		pop	af
		   ;
		   ;
		   ;
;
nib:		and	0fh
		add	a,'0'
		cp	'9'+1
		jr	c,.nothex
;
		add	a,'A'-'9'-1
.nothex:
		    ;
		    ;
		    ;
;
char:		push	af
		push	bc
		push	de
		push	hl
		 ld	b,a
		 cp	CR
		 jr	z,.col0
;
		 cp	LF
		 jr	nz,.notcol0
;
.col0:		 ld	(iy+vars._io.col),-1	; Will inc to 0		
.notcol0:	 inc	(iy+vars._io.col)	; Next column
		 ld	a,0ffh	; Default channel
		 EXOS	exos.FN_WRCH
		pop	hl
		pop	de
		pop	bc
		pop	af
		ret
;
;
;------------------------------------------------------------------------------
;
ipcrlf:		call	str
		call	ip
;
start:		ld	a,(vars.io.col)
		or	a
		ret	z
;
crlf:		ld	a,CR
		call	char
		ld	a,LF
		jr	char
;
;
space:		ld	a,' '
		jr	char
;
;
tab:		ld	a,"\t"
		jr	char
;
;
;------------------------------------------------------------------------------
; str
;
; Outputs a null-terminated string at (DE).
;
; line
;
; Outputs a LF-terminated string at (DE).
;
; In:  DE->string
; Out: DE->next string (if LF-terminated) or null
;      BC and AF corrupted.
;      HL preserved
;
line:		ld	b,LF		; Stop at LF
		jr	_str

str:		ld	b,0
_str:		push	hl
		push	de		; Save ->start of string
		 ld	l,b		; L=string terminator
		 ld	bc,-1		; Zero length counter
		 jr	.start
;
.col0:		 ld	(iy+vars._io.col),-1	; Will inc to 0		
.loop:		 inc	(iy+vars._io.col)	; Next column
.start:		 ld	a,(de)
		 inc	de
		 inc	bc
		 cp	CR
		 jr	z,.col0
;
		 cp	l
		 jr	z,.end
;
		 cp	LF
		 jr	z,.col0
;
		 or	a
		 jr	nz,.loop
;
		 dec	de		; Point back to null
.end:		 ex	de,hl		; HL->end of string, DE=caller's HL
		ex	(sp),hl		; (SP)->end of string, HL->start
		 ex	de,hl		; DE->start of string, HL->caller's HL
;
		 ld	a,0ffh		; Default EXOS channel
		 EXOS	exos.FN_WRBLK
;
		pop	de		; DE->end of string
		pop	hl
		ret
;
;
;------------------------------------------------------------------------------
; cols
;
; Returns the number of display cols 
;
; We only output to the default channel so to find the number of cols we do a
; video "special function" call to each channel in turn until we get a non-error
; return, and assume this is the correct answer!
;
; Obviously this is a relatively time consuming process so the caller should
; do it once (or at least infrequently) and save the result.
;
; It's not a 100% reliable method as there could be multiple video channels
; which may or may not be actually displayed. But iof we find *any* 80 column
; channels then we assume 80, otherwise 40.
;
; Out:  A=number of cols on display
;      HL preserved
;
cols:		ld	b,0		; B=initial channel #
.loop:		ld	a,b		; Get channel
		push	bc		; Save channel
		 ld	b,exos.FN_VID_SIZE	; Return video: page size & mode
		 EXOS	exos.FN_SFUNC
		 ld	a,b		; A=# cols
		pop	bc		; B=channel
		jr	nz,.next	; Go if error (no a video channel)
;
		cp	80		; No error, so we've found a vid chan
		ret	nc		; Return if 80 (or above!) cols
;
.next:		djnz	.loop		; Try next channel
;
		ld	a,40		; Default to 40 if no 80 col channels
		ret
;
;
;------------------------------------------------------------------------------
; input
;
; Gets a line of input from the user.
;
; In:  DE->prompt string
;      HL->buffer for input
;       C=max length
; Out: Cy if error
;          buffer contains input, length byte first
;
input:
		push	bc	; Save max length
		 call	str	; Print prompt
;
		 ; Set EXOS editor flags to not return the prompt
		 ld	bc,1*256+exos.VAR_FLG_EDIT	; B=1=>write, C=var no.
		 ld	d,18h	; D= flags (NO_SOFT, NO_PROMPT)
		 EXOS	exos.FN_EVAR
;
		pop	bc	; C=max length
		ld	b,0	; B=current length
;
		push	hl	; Save -> start of buffer
		 inc	hl	; Point passed length byte
.loop:		 ld	a,0ffh	; Read a char from EXOS default channel
		 push	bc
		  EXOS	exos.FN_RDCH
		  ld	a,b	; Get char
		 pop	bc	; BC=count and limit
		 scf
		 jr	nz,.end	; Error
;
		 cp	CR	; End of input line?
		 jr	z,.end	; Go if yes
;
.notcr:		 ld	(hl),a	; Save char
		 ld	a,b
		 inc	a
		 cp	c	; Max chars reached?
		 jr	z,.loop	; Ignore char if yes
;
		 ld	b,a	; Save inc'd length
		 inc	hl	; Next buffer pos next time
		 jr	.loop
;
.end:		pop	hl	; HL-> start of buffer
		ld	(hl),b	; Length byte
		ret
;
;
		endmodule
