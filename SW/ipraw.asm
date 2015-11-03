; IPRAW
;
; Implements an interface to the sockets of the WIZ chip in IPRAW mode
;
		module	ipraw
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
; open
;
; Opens a WIZ socket in IPRAW mode
;
; In: A=socket number
;     HL=port number
;     DE->owner string
; Out: Carry set if error
;
open_0:		xor	a
open:
		ld	bc,w5300.Sn_MR_IPRAW*256+w5300.Sn_SSR_IPRAW
		jp	socket.open		; Open socket in UDP mode
;
;
;------------------------------------------------------------------------------
; header
;
; Reads the WIZ's PACKET_INFO header for IPRAW mode
;
; In:  A=socket number
;
header_0:	xor	a
header:
		SOCKET_GET_BASE
;
		ld	hl,vars.icmp.header		; Read W5300 header
		ld	bc,vars.icmp.header_size	; No. bytes in header
		call	socket.read_header
;
		ld	hl,vars.icmp.size
		call	socket.byteswapword	; Byte swap
;
		ld	a,socket.vars.rx_size
		call	socket.set_word		; Save in per-socket variable
;
 		bit	vars.trace.socket,(iy+vars._trace)
		jr	z,.ret
;
		call	socket._trace
;		
		ld	de,trace.ipraw.rx
		call	io.str
;
		ld	hl,vars.icmp.ip
		call	io.ip
;
		ld	hl,(vars.icmp.size)
		call	trace.bytes
		call	io.space
;
.ret:		ld	hl,(vars.icmp.size)
		ld	a,h
		or	l
		ret
;
;
;------------------------------------------------------------------------------
; send
;
; Send whatever data has been writen to the Tx FIFO.
;
; In:  A=socket number
;     HL->ip address to send to
;      vars.icmp.ip = dest IP address to send to
; Out: NC=>ok
;
send_0:		xor	a
send:		bit	vars.trace.socket,(iy+vars._trace)
		jr	z,.notrace
;
		push	af		; Save socket no
		 push	hl		; Save ->ip address
		  call	socket.trace
;
		  ld	de,trace.ipraw.tx
		  call	io.str
		 pop	hl		; HL->ip address
		pop	af		; A=socket number
;
		push	af		; Save socket number
		 push	hl		; Save ->ip address
		  push	af		; Save socket number
		   call	io.ip		; Print dest ip address
		  pop	af		; A=socket number
;
		  SOCKET_GET_BASE
		  ld	a,socket.vars.tx_size
		  call	socket.get_word	; HL=tx_size
		  call	trace.bytes	; Print it
		  call	trace.dots
		 pop	hl		; HL->IP address
		pop	af		; A=socket no
;
.notrace:	call	socket.write_DIPR	; Also sets DE=base reg
;
		jp	socket._send	; Do the send
;
;
		endmodule
		