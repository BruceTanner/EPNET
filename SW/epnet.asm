; EPNET
;
; This is the entry point for the IS-DOS app version. It fakes up the command
; line to look like EXOS's.

                org	100H
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
		ld	iy,vars
		call	vars.zero
;
		ld	de,hellostr
		call	io.str
;
; The command line buffer is now at 0080: len space char char ... 00
; So de-space and adjust len
		ld	de,80h	; Length byte
		ld	a,(de)
		ld	b,a
		call	command.unspace
;
		ld	c,1	; NZ to allow check for unrecognized command
		ld	hl,helpstr
		call	command.compare
		jr	z,helpcommand
;
		call	command.command	; Not HELP so check for other command
;
badcommandchk:	inc	c
		dec	c
		jr	nz,badcommand
;
		or	a
		ret	z
;
		ld	de,errorstr
		jp	io.str
;
badcommand:
		ld	de,badcommandstr
		jp	io.str
	

helpcommand:
		ld	b,helpstr_len
		call	command.skip	; Skip 'HELP'
;
		call	command.help
		jr	badcommandchk
;
; 
is_stop:		xor	a
		ret
;
get_secs:	ld	hl,0
		ret

helpstr:	db 4,"HELP"
helpstr_len	equ $-helpstr-1 ; -1 for length byte
;
hellostr	db "Enterprise EPNET",13,10
;
errorstr	db "Error processing command",13,10
;
badcommandstr:	db "*** Invalid EPNET command",13,10
;

		include main.asm
;
		END
