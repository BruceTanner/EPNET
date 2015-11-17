; STATUS
;
; This module provides routines for controlling the status line activity 
; display.
;
		module	status
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
; "waiting" is indicated by an alternating large and small blue blob.
; Network "activity" is indicated by the blob turning red.
;
STATUS_POS	equ	39		; Position on status line of indicator
;
STATUS_BLOB_L	equ	1fh		; Char used for big blob
STATUS_BLOB_S	equ	0eh		; Char used for small blob
;
DELAY		equ	16		; Time in ticks before status flashing
;
;
;------------------------------------------------------------------------------
; start & stop
;
; Starts & stops the status line display. (Saves the current char on the
; bit of the status line we use)
;
;  stop: restores the status line under the blob immediately.
; start: starts the flashing blob but after a shot delay. This rtesults in a
;        cleaner display, and brief operations do not even show a blob.
;
; Out:  Only AF corrupted
;
stop:
		push	hl			; Save caller's HL
		 ld	hl,vars.status.byte	; HL->saved status line char
		 ld	a,(hl)			; Get saved byte
		 ld	(hl),0			; Not waiting now
		pop	hl			; HL=caller's HL
		or	a
		jr	nz,blob			; Put it back
;
		ret
;
start:
		push	hl			; Save caller's HL
		 ld	hl,(exos.ST_POINTER)	; HL->status line
		 ld	a,l
		 add	a,STATUS_POS
		 ld	l,a			; HL->our position on status line
		 ld	(vars.status.pos),hl	; Save it for efficiency
;
		 ld	a,(hl)			; Get current char there
		 ld	(vars.status.byte),a	; Save it
;
		 ld	(iy+vars.status._ticks),0; Zero ticks so blob does
		pop	hl			;   not show initially
		ret
;
;
; waiting
;
; Shows the "waiting" indicator on the status line. (blue blob).
;
; This is called repeatedly in wait loops, and uses the interrupt tick counter
; to alternate the blue blob between small and large blob.
;
; Out:  Only AF corrupted
;
waiting:
		ld	a,(vars.status.byte)	; See if status.start called
		or	a
		ret	z			; Do nothing if not
;
		ld	a,(vars.status.ticks)	; A=interrupt tick count
		cp	DELAY			; Time to flash blob?
		ret	c			; Return if not
;
		; Here Cy=>red, NC=>blue blob
blob:		sbc	a,a			; A= Cy=>FF, NC=>0
		and	80h			; A=80h (red) or 0 (blue)
		or	STATUS_BLOB_S		; Assume small blob
		bit	3,(iy+vars.status._ticks); Time for big blob? (~1/4 sec)
		jr	nz,blob_char		; Go with A=small blob if not
;
		xor	STATUS_BLOB_L xor STATUS_BLOB_S	; Toggle to big blob
blob_char:	push	hl			; Save caller's HL
		 ld	hl,(vars.status.pos)	; HL->our position on status line
		 ld	(hl),a			; Put big or small blob there
		pop	hl			; HL=caller's HL
		ret
;
;
; activity
;
; Shows the "activity" indicator on the status line. (Red blob).
;
; It is called at the start of the low-level WIZ FIFO reading and writing loops
; and displays a red blob immediately. It might be thus called without
; status.start being called first, in which case it does nothing.
;
; Out:  Only AF corrupted
;
activity:
		ld	a,(vars.status.byte)	; See if status.start called
		or	a
		ret	z			; Do nothing if not
;
		scf				; Cy=>red blob
		jr	blob
;
;
inactivity:
		ld	a,(vars.status.byte)	; See if status.start called
		or	a
		ret	z			; Do nothing if not
;
		jr	waiting			; Remove red blob
;
;
;
		endmodule
