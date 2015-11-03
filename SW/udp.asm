; UDP
;
; Impements an interface to the sockets of the WIZ chip in UDP mode
;
		module	udp
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
; Opens a WIZ socket in UDP mode
;
; In: A=socket number
;     HL=port number
;     DE->owner string
; Out: Carry set if error
open_0:		xor	a
open:
		ld	bc,w5300.Sn_MR_UDP*256+w5300.Sn_SSR_UDP
		jp	socket.open		; Open socket in UDP mode
;
;
;------------------------------------------------------------------------------
; header:
;
; Starts reading a packet from an open socket - we have to read the WIZ
; PACKET_INFO first and this is what this does.
;
; In:  A=socket number
; Out: NC=>no error
;       Z=>nothing to read
;      HL=no bytes in packet (0 if nothing read)
;      vars.upd.header filled if HL<>0
;
header_0:	xor	a
header:		call	socket.available; See if any bytes available to read
		ret	z		; Nope
;
; A packet has been received. First 8 bytes are PACKET_INFO: ip address, port
; and packet size
.gotdata:	; We rely on the w5300 behaving here - if there's some data
		; there must be at least a UDP header there
		ld	bc,vars.udp.header_size	; Header = 4 words
		ld	hl,vars.udp.header
		push	de
		 call	socket.read_header	; Read header
		pop	de			; DE=base reg
;
		ld	hl,vars.udp.port	; Update header byte orders
		call	socket.byteswapword
;
		ld	hl,vars.udp.size
		call	socket.byteswapword
;
		ld	a,socket.vars.rx_size
		call	socket.set_word		; Set up per-socket vars
;
 		bit	vars.trace.socket,(iy+vars._trace)
		jr	z,.ret
;
		call	socket._trace
;
		ld	de,trace.udp.rx
		call	io.str
;
		ld	hl,vars.udp.ip
		ld	bc,(vars.udp.port)
		call	io.ip_port
;
		ld	hl,(vars.udp.size)
		call	trace.bytes
		call	io.space
;
.ret:		ld	hl,(vars.udp.size)
		ld	a,h
		or	l
		ret
;
;
;------------------------------------------------------------------------------
; send
;
; Having written the data with one or more calls to write(), this actually
; sends the packet. The destination ip address and port are in vars.udp.ip and
; vars.udp.port.
;
; In:  A=socket number
;      vars.udp.ip = dest IP address to send to
;      vars.udp.port = dest port no.
; Out: NC=>ok
send_0:		xor	a
send:		bit	vars.trace.socket,(iy+vars._trace)
		jr	z,.notrace
;
		push	af		; Save socket no
		 call	socket.trace

		 ld	de,trace.udp.tx
		 call	io.str
;
		 ld	hl,vars.udp.ip
		 ld	bc,(vars.udp.port)
		 call	io.ip_port	; Print dest ip address & port
		pop	af		; A=socket number
;
		push	af		; Save socket number
		 SOCKET_GET_BASE
		 ld	a,socket.vars.tx_size
		 call	socket.get_word
		 call	trace.bytes
		 call	trace.dots
		pop	af		; A=socket no
;
.notrace:
		ld	hl,vars.udp.ip		; Set up dest IP address
		call	socket.write_DIPR	; Sets DE=base reg
;
		ld	hl,(vars.udp.port)	
		call	socket.write_DPORTR	; Set up dest port #
;
		jp	socket._send		; Do the send
;
;
		endmodule
