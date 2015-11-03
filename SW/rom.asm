; ROM
;
; This is the very start of the EPNET ROM
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
                org 0c000h
;
                db	"EXOS_ROM"		;ROM header
                dw	device.devices-8000h	; Page 1 pointer to device desc
		jp	entry			; ROM entry point from EXOS
;
;
; These locations in the ROM are non-standard, but fixed for EPNET
;
; Normally EPNET finds it's i/o from it's ROM segment number. But if this byte
; is non-zero, it specifies the I/O to use instead
io:		db	0		; Card I/O address; 0=>use ROM/2
;
; The MAC address is here. It must be different for each EPNET card!
mac:		db	00h,00h,0f6h,42h,42h,00h	; Our MAC address
;
;
entry:		ld	iy,vars
;
		ld	a,c
		dec	a
		jr	z,cold_reset	; Action code 1: cold reset
;
		dec	a		; Action code 2: command string
                jp	z,command.command
;
		dec	a		; Action code 3: HELP string
                jp	z,command.help
;
		dec	a		; Action code 4: EXOS variable
		dec	a		; Action code 5: Explain error code
		jp	z,exos.explain
;
                ret
;
cold_reset:	call	util.varszero	; Initialize private RAM area
		ld	c,1		; Preserve 1 action code
		ret
;
;
		include	main.asm
;
                DS 65536-$,255
;
;
                END
