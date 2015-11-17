; DEBUG
;
; Some useful macros for debugging. Comment out the fo0llowing line to
; assemble a non-debugging version:
;
		define	DEBUG
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
		ifdef	DEBUG
byte:		 push	af
		  rrca
		  rrca
		  rrca
		  rrca
		  call	nib
		 pop	af
;
nib:		 and	0fh
		 add	a,'0'
		 cp	'9'+1
		 jr	c,char
		 add	a,'A'-'9'-1
char:		 push	af
		 push	bc
		 push	de
		 push	hl
		  ld	b,a
		  ld	a,0ffh
		  rst	30h
		  db	exos.FN_WRCH
		 pop	hl
		 pop	de
		 pop	bc
		 pop	af
		 ret
		endif
;		
		macro POKE ch
		 ifdef	DEBUG
		  push	af
		  ld	a,ch
		  call	char
		  pop	af
		 endif
		endm
;
		macro POKEcc cond,ch
		 ifdef DEBUG
		  push	af
		  ld	a,ch
		  call	cond,char
		  pop	af
		 endif
		endm
;
		macro POKEBYTE reg
		 ifdef	DEBUG
		  push	af
		  ld	a,reg
		  call	byte
		  pop	af
		 endif
		endm
;
		macro POKEBYTEcc cond, reg
		 ifdef	DEBUG
		  push	af
		  ld	a,reg
		  call	cond,io.byte
		  pop	af
		 endif
		endm
