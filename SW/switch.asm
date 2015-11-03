; SWITCH
;
; Supports switching from one ROM segmnent to the other.
;
		module	switch
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
; Use:	call	other_rom
;	dw	addr
;
; This routine must exist identically and at the same address in both segments
; It can be called from either segment to call any routine in the other, and
; when that routine RETs it will return to the original calling ROM segment.
;
other_rom:
		ld	(saved_de),de
		ex	(sp),hl		; (SP)=caller's HL, HL->return address
		ld	e,(hl)		; DE=addr to call
		inc	hl
		ld	d,(hl)
		inc	hl		; HL=new return address
		ex	(sp),hl		; (SP)=new return addr, HL=caller's HL
;
		push	hl		; Save caller's HL
		ld	hl,toggle	; Called addr will return to here
		ex	(sp),hl		; (SP)->toggle, HL=caller's HL
;
		push	de		; Push so RET will jump to called addr
		ld	de,(saved_de)	; Restore caller's DE
;
		; So now (SP-4)=updated return addr of caller
		;        (SP-2)=addr of toggle:
		;        (SP  )=addr in other ROM to call
		; All regs as when originally called
;
		; Now we toggle P3 so the other ROM segment is paged in.
		; The other segment contains exactly the same code at the
		; same address so we carry on executing this routine. The RET
		; below will take us to the called addr in the other ROM.
		; Then a RET from the called addr will bring us back to here
		; to toggle the ROMs back to the original configuration.
		; Finally the RET below will take us back to the modified
		; return address of the caller.
;
toggle:		push	af		; Save caller's AF
		in	a,(P3)		; Toggle seg in P3
		xor	1
		out	(P3),a
		pop	af		; AF=caller's AF
		ret			; Go to addr
;
;
		endmodule
