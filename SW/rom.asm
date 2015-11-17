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
                org	0c000h
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
entry:	
		ld	a,c
		cp	7		; Action code 7, RAM allocation?
		jr	z,ram_allocation; Go if yes
;
		exx
		ld	c,ep.P1		; C' always->P1
		in	b,(c)		; B' always=our seg
		ld	e,b		; E' always=socket seg
		ld	d,B		; d' always=tcp seg
		ld	iy,vars		; IY always->our variables
		exx
;
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
;------------------------------------------------------------------------------
; Here we need to get a RAM segment from EXOS for our variables. Our variables
; do not need a whole segment, but they *do* need to be at a fixed address,
; and the only way to guarantee this is to ask for a whole segment, otherwise
; EXOS could try and share the segement with another device and our
; variables could end up anywhere within the segment. We can't quite get the
; entire segment though because EXOS keeps it's internal pointers etc in the
; first 6 bytes.
;
; At this point our usual variable pointer in IY and paging vars in B'and C'
; are not setup.
;
ram_allocation:	ld	bc,0200h	; C=0=>RAM needed; B=2=>page 1 RAM
		ld	de,4000h-exos.DEVICE_SEG_START	; Get a whole segment
		ret
;
;
;------------------------------------------------------------------------------
;
		; The main code
		include	main.asm	; All the main code files
;
		; Miss RAM on H/W V1
;		ASSERT	$<0f000h

		; Pad to end of ROM
                ds	65536-$,0ffh	; Pad to end of ROM with FF
;
		output	nul		; We don't want variables in ROM output
		include	vars.asm	; Include variable declarations
;
;
;
                END
