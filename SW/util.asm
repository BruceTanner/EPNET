; UTIL
;
; Various little utility functions
;
		module	util
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
; copystr
;
; Copies one null-terminated string to a buffer
;
; In:  HL->str to be copied, null terminated
;      DE->buffer
; Out: Corrupts BC too!
;      DE->terminating null
;
copystr:	ld	a,(hl)
		ldi
		or	a
		jr	nz,copystr
;
		dec	de		; Point back to null
		ret
;
;
;------------------------------------------------------------------------------
; copyarg
;
; Copies a length-byte-first string to a buffer, turning it into a null-
; terminated stirng. Only copies up to the first space
;
; In:  HL->arg to be copied, length byte first
;      DE->buffer
; Out: Corrupts BC too!
;      DE->terminating null
;
copyarg:	ld	a,(hl)		; Get length
		or	a
		jr	z,.ret
;
		inc	hl		; Point pased length byte
		ld	c,a
		ld	b,0		; BC=byte count
.loop:		ld	a,(hl)		; Only copy up to space if there is one
		cp	' '
		jr	z,.ret		; Stop if space found
;
		ldi			; Copy byte, inc HL & DE, dec & test BC
		jp	pe,.loop
;
.ret:		xor	a
		ld	(de),a		; Null terminate it
;
		ret
;
;
;------------------------------------------------------------------------------
; strlen
;
; Returns in BC the length of the string at (HL)
;
strlen:		ld	bc,-1
		push	hl
;
.loop:		ld	a,(hl)
		inc	hl
		inc	bc
		or	a
		jr	nz,.loop
;
		pop	hl
		ret
;
;
;------------------------------------------------------------------------------
; memset
;
; In:  HL->buffer
;      BC=#bytes (must be >1!)
;      A=fill value
; Out: HL->buffer
;
varszero:	ld	hl,vars
		ld	bc,vars.varsize
;
memzero:	xor	a
;
memset:		
		push	hl
		ld	d,h
		ld	e,l
		inc	de
		ld	(hl),a
		dec	bc	; We've just done the first byte!
		ldir
		pop	hl
;
		ret
;
;------------------------------------------------------------------------------
; memcmp
;
; Compares two blocks of memory
;
; Out: Z if (HL) = (DE) for B bytes
;
ipcmp:		ld	b,4
memcmp:		ld	a,(de)
		cp	(hl)
		ret	nz
;
		inc	de
		inc	hl
		djnz	memcmp
;
		ret
;
;------------------------------------------------------------------------------
; upper
;
; Upper cases A
;
upper:		cp	'a'
		ret	c
;
		cp	'z'+1
		ret	nc
;
		sub	'a'-'A'
		ret
;
;
;------------------------------------------------------------------------------
; get_ip_port
;
; Reads an ASCII IP address and port number at (DE) to a 4-byte buffer at (HL)
; and a 16-bit port number in HL. The format is aaa.bbb.ccc.ddd:ppppp
;
; In:  HL->buffer for ip
;      DE->command line, length first
; Out: Cy=>not a valid IP address
;      HL=port number
;
get_ip_port:	ld	a,(de)
		ld	b,a
		inc	de
		call	_get_ip
		ret	c
;
		ld	a,b		; Must be at least :<digit> following
		sub	2
		scf
		ret	m
;
		dec	b
		ld	a,(de)
		inc	de
		cp	'-'
		scf
		ret	nz
;
		call	_get_port
;
		ld	a,b		; Make sure nothing following
		or	a
		ret	z
;
		scf
		ret
;
;
_get_port:	or	a
		sbc	hl,hl		; HL=0 (16-bit accumulator)

.loop:		call	get_dig
		ccf
		ret	nc		; End of number, NC=>no error
		
		inc	de		; Digit ok - point to next
		push	bc
		 ; 16-bit accululator *= 10
		 add	hl,hl		; *2
		 ld	c,l
		 ld	b,h		; Save *2
		 add	hl,hl		; *4
		 add	hl,hl		; *8
		 add	hl,bc		; *10
		 ld	c,a
		 ld	b,0
		 add	hl,bc		; Add on digit
		pop	bc
		djnz	.loop
;
		ret
;
;
;------------------------------------------------------------------------------
; get_ip
;
; Reads an ASCII IP address at (DE) to a 4-byte buffer at (HL).
;
; In:  HL->buffer for ip
;      DE->command line, length first (length not used - see B)
;      B=length
; Out: Cy=>not a valid IP address
;
get_ip:		inc	de		; Skip length byte (use B instead)
		call	_get_ip
		ret	c
;
		ld	a,b		; Make sure nothing following
		or	a
		ret	z
;
		scf
		ret
;
;
_get_ip:	call	get_num8_dot
		inc	hl
		call	nc,get_num8_dot
		inc	hl
		call	nc,get_num8_dot
		inc	hl
		call	nc,get_num8
		ret
;
get_num8_dot:	call	get_num8
;
		dec	b
		scf
		ret	m
;
		ld	a,(de)
		inc	de
		cp	'.'
		ret	z
;
		cp	','	; Also allow , (for parsing FTP responses)
		ret	z

		scf
		ret
;
;
;------------------------------------------------------------------------------
; get_num8
;
; Reads an ASCII 8-bit number from a length-byte string
;
; In:  DE->string
;      HL->number
;       B=length of data at (DE)
; Out: DE->first non-numeric character
;      HL->number
;       B updated
;      Cy=>bad number
;
get_num8:	call	get_dig
		ret	c
;
		ld	(hl),0
.loop:		call	get_dig
		ccf
		ret	nc
;
		inc	de
		push	af
		ld	a,(hl)
		add	a,a
		ld	c,a
		add	a,a
		add	a,a
		add	a,c
		ld	c,a
		pop	af
		add	a,c
		ld	(hl),a
		djnz	.loop
;
		ret
;
;
get_dig:
		ld	a,(de)
isdig:		sub	'0'
		ret	c
		cp	10
		ccf
		ret
;
;
;------------------------------------------------------------------------------
; get_num16
;
; Reads an ASCII 16-bit number from a null-terminated string
;
; In:  DE->number
; Out: DE->first non-numeric character
;      HL=number
;      Cy=>bad number
;
get_num16:
		call	get_dig		; Must be at least 1 digit!
		ret	c		; C=>error
;
		or	a
		sbc	hl,hl		; HL=0 (16-bit accumulator)

.loop:		call	get_dig
		ccf
		ret	nc		; End of number, NC=>no error
		
		inc	de		; Digit ok - point to next
		; 16-bit accululator *= 10
		add	hl,hl		; *2
		ld	c,l
		ld	b,h		; Save *2
		add	hl,hl		; *4
		add	hl,hl		; *8
		add	hl,bc		; *10
		ld	c,a
		ld	b,0
		add	hl,bc		; Add on digit
		jr	.loop
;
;
;
		endmodule
