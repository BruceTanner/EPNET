; PING
;
; This module implements an interface to the WIZ W5300 that provides a
; 'ping' command.
;
		module	ping
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
; You would think they would make it easy to implement this most basic of
; commands but unfortunately it is necessary to open a WIZ socket in "IP raw"
; mode and construct ICMP packets to do this.
;
; The ping ICMP packet format (from RFC 792) is:
;
; Echo or Echo Reply Message
;
;    0                   1                   2                   3
;    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
;   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;   |     Type      |     Code      |          Checksum             |
;   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;   |           Identifier          |        Sequence Number        |
;   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;   |     Data ...
;   +-+-+-+-+-
;
;   IP Fields:
;
;   Addresses
;
;      The address of the source in an echo message will be the
;      destination of the echo reply message.  To form an echo reply
;      message, the source and destination addresses are simply reversed,
;      the type code changed to 0, and the checksum recomputed.
;
;   IP Fields:
;
;   Type
;
;      8 for echo message;
;
;      0 for echo reply message.
;
;   Code
;
;      0
;
;   Checksum
;
;      The checksum is the 16-bit ones's complement of the one's
;      complement sum of the ICMP message starting with the ICMP Type.
;      For computing the checksum , the checksum field should be zero.
;      If the total length is odd, the received data is padded with one
;      octet of zeros for computing the checksum.  This checksum may be
;      replaced in the future.
;
;   Identifier
;
;      If code = 0, an identifier to aid in matching echos and replies,
;      may be zero.
;
OUR_ID		equ	4242h
;
;   Sequence Number
;
;      If code = 0, a sequence number to aid in matching echos and
;      replies, may be zero.
;
;   Description
;
;      The data received in the echo message must be returned in the echo
;      reply message.
;
;      The identifier and sequence number may be used by the echo sender
;      to aid in matching the replies with the echo requests.  For
;      example, the identifier might be used like a port in TCP or UDP to
;      identify a session, and the sequence number might be incremented
;      on each echo request sent.  The echoer returns these same values
;      in the echo reply.
;
;      Code 0 may be received from a gateway or a host.
;
;==============================================================================
; init
;
; In:  vars.ping.ip contains IP address
; Out: Cy=>error occured
init:
		xor	a		; Always use socket 0
		SOCKET_GET_BASE
;
		; We have to set SnPROTOR to the IP protocol number
		; 01 (ICMP). SnPROTOR is a byte register that is half of
		; 16-bit SnPORTOR (look carefully, one is PROT and one is PORT!) 
		; The other half of SnPORTOR is SnKPALVTR and it is not clear
		; if we have to preserve this for when this socket is re-used in
		; TCP mode. So just in case we read SnKPALVTR first and write
		; it back along with our new value for SnPROTOR.
		ld	a,w5300.Sn_PORTOR
		call	socket.read_reg	; H=SnKPALVTR, L=SnPROT
		ld	l,1		; 1=>ICMP
		ld	a,w5300.Sn_PORTOR
		call	socket.write_reg
;
		ld	de,owner_str	; Our name
		ld	(vars.ping.seq),a
		call	ipraw.open_0	; Open socket in IP RAW mode
		jr	c,.end
;
		ld	b,5		; Do 5 pings/attempts
.loop		push	bc
		 call	do_ping
		pop	bc
		jr	c,.end
;
		djnz	.loop
;
.end:		push	af		; Save error indication in Cy
		 call	socket.close_0
		pop	af
;
		ret
;
;
;
; Out: Cy=>error or STOP key
do_ping:
		ld	de,trace.ping.pinging
		call	io.str		; "Pinging a.b.c.d..."
		ld	hl,vars.ping.ip
		call	io.ip
		call	trace.dots
;
		; Normally send would return an error (Cy) if the IP address
		; does not exist (the WIZ chip does ARP stuff) but here we
		; just ignore an error return and let the timeout/retry
		; mechanism retry it
		call	build		; Build ping packet
;
		call	status.start	; Start waiting indicator
;
		ld	bc,(vars.ticks)	; Wait for start of tick
.wait:		ld	hl,(vars.ticks)
		or	a
		sbc	hl,bc
		jr	z,.wait
;
		add	hl,bc
		ld	(vars.ping.start_ticks),hl	; Save ticks at start
;
		ld	hl,vars.ping.ip	; HL->ip address
		call	ipraw.send_0	; Send packet on socket 0
		jr	nc,.loop	; Go if no error
;
		call	exos.is_stop	; See if it was due to stop key
		jr	c,.ret		; Return with Cy if yes
;
		jr	.timeout	; Else print timeout & continue
;
		; Now wait for a reply for up to a second
.loop:		call	socket.available_0; Packet received?
		jr	nz,.gotreply
;
		call	status.waiting	; Show waiting indicator
;
		call	exos.is_stop	; STOP key?
		jr	c,.ret		; Go with C if yes
;
		ld	hl,(vars.ticks)		; HL=current ticks
		ld	de,(vars.ping.start_ticks); DE=start ticks
		or	a
		sbc	hl,de		; HL=elapsed time in ticks
		ld	de,TICKS_1s	; See if >= 1s timeout
		or	a
		sbc	hl,de
		jr	c,.loop		; Keep waiting if no timeout
;
.timeout:	ld	de,trace.timeout_str
.okret:		call	io.str		; Print ok or timeout
		or	a		; NC cos not a fatal error
.ret:		push	af		; Save Cy
		call	status.stop	; Turn off waiting indicator
		pop	af		; Restore Cy error indicator
		ret
;
.gotreply:	ld	hl,(vars.ticks)
		ld	(vars.ping.end_ticks),hl
;
		call	ipraw.header_0	; Read header
;
		ld	hl,vars.icmp.ip
		ld	de,vars.ping.ip
		call	util.ipcmp
		scf
		jr	nz,.rejectheader

		ld	hl,(vars.icmp.size); Make sure enough bytes received
		ld	bc,vars.ping.packet_size
		or	a
		sbc	hl,bc
		jr	c,.rejectheader		; Go with Cy if not enough
;
		ld	hl,vars.ping.packet	; Read packet start
		ld	bc,vars.ping.packet_size
;
		call	socket.read_0		; Read packet
;
		ld	hl,(vars.icmp.size)
		ld	bc,vars.ping.packet_size
		or	a
		sbc	hl,bc			; HL=amount left to read
;
.rejectheader:
.readrest:	push	af
		 call	socket.read_flush_0	; Read remainder of packet
		pop	af
		jp	c,.loop			; Reject header
;
		ld	hl,vars.ping.packet
		ld	bc,vars.ping.packet_size
		call	checksum
		ld	a,h
		or	l
		jp	nz,.loop		; Ignore packet
 
		ld	a,(vars.ping.packet.type)
		or	a			; Type should be 0 for reply
		jp	nz,.loop		; Ignore packet
;
		ld	a,(vars.ping.packet.code)
		or	a			; Code should be 0 for reply
		jp	nz,.loop		; Ignore packet
;
		ld	hl,(vars.ping.packet.id); Check it's our id
		ld	de,OUR_ID
		sbc	hl,de
		ld	a,h
		or	l
		jp	nz,.loop
;
		ld	bc,(vars.ping.start_ticks)
		ld	hl,(vars.ping.end_ticks)
		or	a
		sbc	hl,bc			; HL=# ticks elapsed
		ld	de,lt20mS_str
		jr	z,.printmS		; Print "<20mS" if ticks=0
;
		inc	hl			; x20 to get mS, 1=>40, 2=>80 etc
		add	hl,hl			; ticks*2
		ld	c,l
		ld	b,h			; BC=ticks*2
		add	hl,hl			; ticks*4
		add	hl,hl			; ticks*8
		add	hl,bc			; ticks*10
		add	hl,hl			; ticks*20
		call	io.int			; Print it
		ld	de,mS_str
.printmS:	jp	.okret
;
lt20mS_str:	db	"<20"		; No null as includes next string
mS_str:		db	"mS",CR,LF,0

;
;------------------------------------------------------------------------------
build:		ld	de,vars.ping.packet
		push	de
		 ld	hl,packet
		 ld	bc,packet_size
		 ldir				; Copy fixed packet to buffer
;
		 ld	hl,vars.ping.seq	; Put sequence # in packet
		 inc	(hl)
		 ld	a,(hl)
		 ld	(vars.ping.packet.seq+1),a; Use network byte order!
;
		pop	hl			; HL->packet
		push	hl
;
		 ld	bc,vars.ping.packet_size
		 push	bc
		  call	checksum
		  ld	a,h
		  ld	h,l
		  ld	l,a
		  ld	(vars.ping.packet.csum),hl
		 pop	bc			; BC=byte count
;
		pop	hl			; HL->data
;
		push	bc
		 call	socket.write_0
		pop	hl			; HL=bytes sent
;
		ret
;
packet:		db	8			; Type 8 = echo
		db	0			; Code always 0
		dw	0			; Checksum 0 for now
		dw	OUR_ID			; Identifier
		db	0, 0			; Sequence 0
packet_size	equ	$-packet
;
;------------------------------------------------------------------------------
; checksum
;
; Calculates a checksum for a ICMP packet.
;
; "The checksum is the 16-bit one's complement of the one's complement sum of
; the ICMP message starting with the ICMP type".
;
; In:  HL->data
;      BC=byte count but must be even
checksum:	ex	de,hl		; DE->data
		or	a
		sbc	hl,hl		; Initial checksum
.loop:		inc	de		; Do low byte first
		ld	a,(de)
		add	a,l
		ld	l,a
;
		dec	de		; Then high byte
		ld	a,(de)
		adc	a,h
		ld	h,a
;
		inc	de		; Move on to next word
		inc	de
;
		dec	bc
		dec	bc
		ld	a,b
		or	c
		jr	nz,.loop
;
		ex	de,hl		; DE=checksum
		sbc	hl,hl		; HL=0
		sbc	hl,de		; HL=2s complement
		dec	hl		; HL=1s complement
		ret
;
;
owner_str:	db	"PING",0
;
;
;
		endmodule
