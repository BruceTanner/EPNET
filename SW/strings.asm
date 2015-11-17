; STRINGS
;
; These routines implement set and get routines for strings to support the
; :NET SET var=value command.
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
; The strings are kept in a table of pairs of null-terminated names and values.
; The end of the table is indicated by a null string name. ie:
;
; <name-1>,0, <value-1>,0
; <name-2>,0, <value-2>,0
;    :           :
;    :           :
; <name-n>,0, <value-n>,0
; 0
;
; Faster string searching could be implemented at the expense of compexity, but
; as we don't expect more than half a dozen strings this should be adequate.
;
		module	strings
;
;------------------------------------------------------------------------------
; set
;
; Sets a name and value pair.
;
; In:  DE->name
;      HL->value
;
set:		push	hl		; Save ->value
		 push	de		; Save ->name
		  call	get		; BC->start of string if found
		  jr	c,.notfound	; Go if not found, HL->end of strings
;
		  ; Found string which we must replace with new
		  ; So copy following strings down on top
		  call	find_end	; HL->past value to next string
		  ld	e,c
		  ld	d,b		; DE->start of string
.loop:		  ld	a,(hl)
		  ldi			; Copy name
		  or	a
		  jr	nz,.loop	; Till null at end of name
;
.loop2:		  ld	a,(hl)
		  ldi			; Copy value
		  or	a
		  jr	nz,.loop2	; Till null at end of value
;
		  ld	a,(hl)		; See if more strings
		  or	a
		  jr	nz,.loop	; Keep copying if yes
;
		  ex	de,hl		; HL->end of strings
;
.notfound:	  ; Now HL->null name at end of strings
		  ex	de,hl		; DE->end of names
		 pop	hl		; HL->name
.loop3:		 ld	a,(hl)
		 ldi			; Copy name to strings
		 or	a
		 jr	nz,.loop3
;
		pop	hl		; HL->value
.loop4:		ld	a,(hl)
		ldi			; Copy name to strings
		or	a
		jr	nz,.loop4
;
		ld	(hl),a		; Null name at end of strings
		ret
;
;
;------------------------------------------------------------------------------
; get
;
; Returns the value given a name.
;
; In:  DE->name
; Out: BC->start of name in table if found
;      DE unchanged
;      Cy=>name not found
;      HL->value if found, null at end of strings if not
;
get:
		ld	hl,vars.strings
;
		; See if current string at (HL)=string at (DE)
.loop1:		push	de		; Save ->start of user's string
		 ld	c,l
		 ld	b,h
.loop2:		 ld	a,(de)		; Get char from name
		 inc	de
		 cpi			; Compare with string name
		 jr	nz,.nextstr	; Go if string names do not match
;
		 or	a		; End of strings?
		 jr	nz,.loop2	; Keep checking if not
;
		pop	de		; DE->back to caller's name
		ret			; With NC and HL->value
;
.nextstr:	pop	de		; DE->start of caller's name string
		call	end		; HL->value in table
		call	end		; HL->next name
		ld	a,(hl)		; Null name=>end of strings
		or	a
		jr	nz,.loop1	; Compare next string if not end
;
		scf			; Cy=>string not found
		ret			; HL still -> last byte in table
;
;		
;------------------------------------------------------------------------------
; first
;
; Returns the name and value of the first string
;
; Out: DE->name, null string if none
;      HL->value
;      Cy=>no string in table
;
first:		ld	de,vars.strings	; DE->first name/value pair
;
		; Return HL->value of string at DE
value:		ld	l,e
		ld	h,d		; HL->name
		ld	a,(hl)		; See if end of table
		or	a
		scf
		ret	z		; Return if end of table
;
		; Return HL->byte after null at end of string at HL
end:		xor	a		; Find null at end of name
		ld	bc,vars.strings_size
		cpir			; HL->past null at and of name (ie value)
		ret			; With NC
;
;
;------------------------------------------------------------------------------
; next
;
; Given a string name, returns the next name/value pair
;
; In:  DE->name
; Out: DE->next name
;      HL->next value
;      Cy=>last string
;
next:		call	value		; HL->value
		call	end		; HL->past value (ie to next name)
		ld	e,l
		ld	d,h		; DE->next name
		ld	a,(de)		; See if last entry in table
		or	a
		jr	nz,end		; HL->past name to value if not
;
		scf
		ret
;
;
;
		endm
