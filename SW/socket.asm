; SOCKET
;
; This module implements an interface to the WIZ socket registers. It is used
; by the protocol modules UDP.ASM, TCP.ASM and IPRAW.ASM.
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
; The protocol interfaces take socket numbers as parameters, which need
; to be converted to WIZ socket register numbers, which are offsets from
; a socket base register. To do this efficiently this module identifies its
; sockets as a socket base number in DE. The top two bits of E are the
; bottom 2 bits of the socket number, and the bottom bit of D is the the top
; bit of the socket number. Bit 1 of D is set. This means when the bottom
; 6 bits of E are the socket register offset (the WIZ Sn_xxx constant), DE
; is the correct WIZ register number.
;
; Ie. the socket number->base address mapping is:
;
; Socket    W5300 Base                D	       E (xxxxxx=WIZ Sn_xxx contant)
; 00000000->00000010 00000000 (200h)  00000010 00xxxxxx
; 00000001->00000010 01000000 (240h)  00000010 01xxxxxx
; 00000010->00000010 10000000 (280h)  00000010 10xxxxxx
; 00000011->00000010 11000000 (2c0h)  00000010 11xxxxxx
; 00000100->00000011 00000000 (300h)  00000011 00xxxxxx
; 00000101->00000011 01000000 (340h)  00000011 01xxxxxx
; 00000110->00000011 10000000 (380h)  00000011 10xxxxxx
; 00000111->00000011 11000000 (3c0h)  00000011 11xxxxxx
;
;
; We also need to keep some per-socket variables and need to be able to
; index into this efficiently. So we keep all the per-socket variables in one
; 256-byte page (so 32 bytes/socket available). Thus we need to shift the
; offset to the socket variable left and then shift DE right to get the low
; byte of the address of the desired variable:
;
; Socket    LO RAM Address  D	     E       
; 00000000->00000000 (00h)  00000010 00xxxxxx
; 00000001->00100000 (20h)  00000010 01xxxxxx
; 00000010->01000000 (40h)  00000010 10xxxxxx
; 00000011->01100000 (60h)  00000010 11xxxxxx
; 00000100->10000000 (80h)  00000011 00xxxxxx
; 00000101->10100000 (a0h)  00000011 01xxxxxx
; 00000110->11000000 (c0h)  00000011 10xxxxxx
; 00000111->11100000 (e0h)  00000011 11xxxxxx
;
;
; This macro convers a socket number in A to the base number in DE
;
;
		macro	SOCKET_GET_BASE
		 ld	de,0100h
		 rrca
		 rr	e
		 rrca
		 rr	e
		 rrca
		 rl	d
		endm
;
;
; The same but for fixed socket 0 - more efficient
;
		macro	SOCKET_GET_BASE_0
		 ld	de,0200h
		endm
;
;
;------------------------------------------------------------------------------
; This macro converts from the base number in DE and offset in A to a RAM
; pointer in HL
		macro	SOCKET_GET_RAM
		 add	a,a
		 or	e
		 ld	l,a
		 ld	a,d
		 rrca
		 rr	l
		 ld	h,high vars.sockets
		endm
;
; Same but takes a fixed offset as a parameter
		macro	SOCKET_GET_VAR var
		 if	(var)=0
		  ld	a,e
		 else
		  ld	a,(var)*2
		  or	e
		 endif
		 ld	l,a
		 ld	a,d
		 rrca
		 rr	l
		 ld	h,high vars.sockets
		endm
;
; 
		module	socket
;
;
; Structure of variables in per-socket RAM. DPORTR is a copy of the Sn_DPORTR
; w5300 register that is necessary because a bug in the w5300 means its
; SnDPORTR register cannot be read correctly
;
		struct	vars
owner		 word		; ->owner string
tcp_connected	 byte		; NZ=>connected to remote party
rx_size		 word
rx_inhand	 word		; First byte FF => second byte buffered
tx_size		 word
tx_inhand	 word		; Second byte FF => first byte buffered!
DPORTR		 word		; Copy of Sn_DPORTR
		ends
;
;
;------------------------------------------------------------------------------
; read_reg
;
; Reads a 16-bit socket register - as wiz.read_reg but for socket registers.
;
; In:  DE: W5300 socket base register
;       A: Sn_xxx offset
; Out: HL=value read
;      DE,B preserved
;
read_reg:	ld	c,(iy+vars._io)	; Address Register H
;
		out	(c),d
		inc	c		; Address Register L
;
 		or	e
		out	(c),a
		inc	c		; Data register H
;
		in	h,(c)
		inc	c		; Data Register L
;
		in	l,(c)
;
		ret
;
;------------------------------------------------------------------------------
; write_reg
;
; Writes a 16-bit socket register - as wiz.write_reg but for socket registers.
;
; In:  DE: W5300 socket base register
;       A: Sn_xxx offset
;      HL: value to write
; Out: HL=value read
;      HL,DE,B preserved
;
write_reg:	ld	c,(iy+vars._io)	; Address Register H
;
		out	(c),d
		inc	c		; Address Register L
;
		or	e
		out	(c),a
		inc	c		; Data register H
;
		out	(c),h
		inc	c		; Data register L
;
		out	(c),l
;
		ret
;
;------------------------------------------------------------------------------
;
; read_FIFO
;
; Reads a block of words from a wiz rx fifo
;
; In:  E':HL->block
;         DE=w5300 socket base register
;         BC=byte count
;         C'->P1
;         B'=our seg
; Out: All main set input registers corrupted
;
_read_FIFO:
;
; This version sets up B so that we can use INI's decrementing and testing 
; of B, which is quicker, for an inner loop and D for an outer loop. We need to
; fiddle the byte count registers a little, eg (all counts must be even!):
;
;   BC	 B (inner)	D (outer)
; ----   ---------      ---------
; 0001		01		1
; 00fe		fe		1
; 0100		00		1
; 0101		01		2
; 01fe		fe		2
; 0200		00		2
; 0201		01		3
;
; We also need to arrange the loops so that inc & dec of c, the i/o port, does
; not corrupt the B loop count = 0 flag that INI puts in the overflow flag.
;
		call	status.activity

		dec	bc		; So BC=xx00 has correct outer loop count
		ld	a,c		; A=inner loop count-1

		ld	c,(iy+vars._io)	; Address Register H

		out	(c),d		; Output Address Register H
		inc	c		; C->Address Register L

		ld	d,b		; D=outer loop count-1
		inc	d		; D=outer loop count
		ld	b,a		; B=inner loop count-1
		inc	b		; B=inner loop count

		ld	a,w5300.Sn_RX_FIFOR
		or	e		; A=Sn_xxx register number
		out	(c),a		; Output address register L
		inc	c		; C->Data register H
;
		exx
		out	(c),e		; Page in data buffer
		exx
;
		inc	c		; Compensate for initial dec c
.loop:		dec	c		;  4
		ini			; 16
		inc	c		;  4
		ini			; 16
		jp	nz,.loop	; 10
					; --
					; 50

		dec	d		;  4
		jr	nz,.loop	; 10
;
		exx
		out	(c),b		; Restore paging
		exx
;
		jp	status.inactivity
;
;
;------------------------------------------------------------------------------
; write_FIFO
;
; Writes a block of words to a wiz tx fifo
;
; In:  E':HL ->block
;         DE =wiz FIFO register number
;         BC =byte count (must be even)
;          C'->P1
;          B'=our seg
; Out: HL->next word in black
;      All main input registers corrupted
;
_write_FIFO:
		call	status.activity

		dec	bc		; So BC=xx00 has correct outer loop count
		ld	a,c		; A=inner loop count-1

		ld	c,(iy+vars._io)	; Address Register H

		out	(c),d		; Output Address Register H
		inc	c		; C->Address Register L

		ld	d,b		; D=outer loop count-1
		inc	d		; D=outer loop count
		ld	b,a		; B=inner loop count-1
		inc	b		; B=inner loop count

		ld	a,w5300.Sn_TX_FIFOR
		or	e		; A=Sn_xxx register number
		out	(c),a		; Output address register L
		inc	c		; C->Data register H
;
		exx
		out	(c),e		; Page in data buffer
		exx
;
		inc	c		; Compensate for initial dec c
.loop:		dec	c		;  4 C->Data Register L
		outi			; 16
		inc	c		;  4
		outi			; 16
		jp	nz,.loop	; 10
					; --
					; 50
;
		dec	d		;  4
		jr	nz,.loop	; 10
;
		exx
		out	(c),b		; Restore paging
		exx
;
		jp	status.inactivity
;
;
;------------------------------------------------------------------------------
; read_FIFO
;
; Reads the WIZ FIFO into a memory buffer.
;
; This is where raw trace mode is implemented. If raw mode is on the words are
; output in a hex dump (but as bytes of course!)
;
; A lot of pushing and popping is required for trace mode, so for speed the
; code is arranged to avoid this if trace mode is off.
;
; read_header is used to read the WIZ PACKET_INFO that is put in front of the
; real data. It is the same as read_FIFO but in raw trace mode the output
; bytes are followed by (header) to indicate they are WIZ-added data and
; not actually part of the packet. The PACKET_INFO contains the actual
; number of bytes in the following packet (Sn_RX_RSR also contains the number
; of bytes but is always even, including a "dummy" byte at the end if the
; packet is odd). Unfortunately the position of the byte count in PACKET_INFO
; varies according to the protocol (UDP, TCP, IPRAW etc) (thanks WIZ!) so
; it is up to the caller to save this in the per-socket variable. We could
; read the protocol type here and act accordingly but as the caller knows their
; own protocol it is easier just to do it there.
;
; For read_FIFO E' contains the buffer segment, but read_header only ever reads
; into our own memory so it sets up E' here.
;
; In: E':HL->block
;        BC=byte count
;        DE=reg base
;         C'->P1
;         B'=our seg
;
read_header_0:	SOCKET_GET_BASE_0
read_header:	exx
		ld	e,b	; Data buffer is in our own seg
		exx
;
		bit	vars.trace.raw,(iy+vars._trace)
		jr	z,_read_FIFO
;
		ld	a,'H'
		jr	rd_FIFO
;
;
read_FIFO_0:	SOCKET_GET_BASE_0
read_FIFO:	bit	vars.trace.raw,(iy+vars._trace)
		jr	z,_read_FIFO
;

		ld	a,'R'
rd_FIFO:	push	af
		push	hl	; Save regs so we can dump buffer later
		push	de
		push	bc
;
		 call	_read_FIFO
;
		pop	bc
		pop	de			; Restore base reg
		pop	hl
		pop	af
;
; Here A contains the dump type (R or T, Receive or Transmit)
; HL->buffer, BC=byte count
dump:		bit	0,(iy+vars._socket.flushing)	; Supress raw output
		ret	nz
;
		call	exos.is_stop; Check BEFORE printing anything as this may
		ret	c	;   get called several times after STOP

		push	bc
		push	de
		push	hl
;
		 push	af	; Start with new line but save dump type
		  call	io.start
		 pop	af
		 call	io.char
;
		 ld	a,d	; Work out socket number from DE
		 or	e	; Bit 0=socket(7),bits 6,7=socket(0,1)
		 rlca
		 rlca
		 and	7
		 add	a,'0'
		 call	io.char	; Print socket number
		 ld	a,':'
		 call	io.char
;
		 exx
		 ld	a,e		; Get segment
		 exx
		 call	io.byte
		 ld	a,':'
		 call	io.char
		 call	io.word	; Print address
		 call	io.space
;
		 ; If there are loads of bytes we only output a few and then
		 ; print +n at end of line. The max is chosen so the
		 ; dump and +n fit nicely on the screen depending on the
		 ; number of columns
		 push	hl		; Save ->data
		  ld	l,c		; HL=number of bytes to dump
		  ld	h,b
		  ld	de,16		; 16 bytes max on an 80 col screen
		  ld	a,(vars.trace.cols)
		  cp	80
		  jr	nc,.gotcols
;
		  ld	e,8		; 8 bytes max on a 40 col screen
.gotcols:	  or	a
		  sbc	hl,de
		  ld	b,e		; B=max in case
		  jr	nc,.ge		; Go if yes, HL=remaining, B=no.
;
		  ld	hl,0		; Otherwise no remaining
		  ld	b,c		; B=no. to dump
;
.ge:		  ; So now (SP)->buffer, B=no. bytes to dump, HL=remaining
		 ex	(sp),hl		; HL->buffer, (SP)=remaining
		  push	hl
		  push	bc
		   call	trace.dumpbytes
		  pop	bc
		  pop	hl
		  jr	c,.stop
;
		  ; Only output ASCII version of bytes if 80 col screen
		  ld	a,(vars.trace.cols)
		  cp	80
		  ccf			; NC (=> not STOP) if <80
		  call	c,trace.dumpchars	; Returns C if STOP
.stop:		 pop	hl		; HL=remaining words not dumped
;
		 jr	c,.done		; Stop key pressed
;
		 ld	a,h
		 or	l
		 jr	z,.done		; Don't print +n if n=0
;
		 ld	a,'+'
		 call	io.char
		 call	io.int
		 call	io.crlf
;
.done:		pop	hl
		pop	de
		pop	bc
;
		ret
;
;
;------------------------------------------------------------------------------
; write_FIFO
;
; Writes the WIZ FIFO from a memory buffer
;
; In: E':HL ->block
;        BC =byte count
;        DE =reg base
;         C'->P1
;         B'=our seg
; Out:   DE preserved.
;        All othermain registers corrupted
;
write_FIFO:	push	de
;
		ld	a,'T'
		bit	vars.trace.raw,(iy+vars._trace)
		call	nz,dump
;
		call	_write_FIFO
;
		pop	de
		ret
;
;
;------------------------------------------------------------------------------
; tomask
;
; Converts a socket number in A (not socket base!) to a bit mask 01h, 02h etc
tomask:		ld	hl,masktab
		add	a,l
		ld	l,a
		ld	a,(hl)
		ret
;
		align	8
masktab:	db	01h,02h,04h,08h,10h,20h,40h,80h
;
;
;
;------------------------------------------------------------------------------
; open
;
; opens a WIZ socket.
;
; For TCP mode, SnDIPR and SnDPORTR must already be set up.
;
; The WIZ Sn_MR mode register needs different values for different modes.
; Similarly once the open command has been issued different responses are
; expected in SnSSR, as follows:
;
; Mode:    UDP        TCP         IPRAW
; -------------------------------------------
; Sn_MR:   Sn_MR_UDP  Sn_MR_TCP   Sn_MR_IPRAW
; Sn_SSR:  Sn_SSR_UDP Sn_SSR_INIT Sn_SSR_IPRAW
;
; These values are passed in BC
;
; In:   A= socket number
;       B= Sn_MR_UDP  or Sn_MR_TCP   as appropriate (see above)
;       C= Sn_SSR_UDP or Sn_SSR_INIT as appropriate (see above)
;      HL= our (source) port number
;      DE->owner string
; Out: Carry set if error
;
open:
		res	0,(iy+vars._socket.flushing)	; Stop supress raw output
;
		bit	vars.trace.socket,(iy+vars._trace)
		jr	z,.tracedone
;
		push	af			; Save socket number
		push	bc			; Save Sn_ values
		push	hl			; Save port number
;
		 push	de			; Save owner string
		  ld	de,trace.socket.open	; "  :Open "
		  push	bc
		   call	trace_msg		; "Sn"
		  pop	bc
;
		  ld	a,b
		  and	0fh
		  ld	de,trace.socket.udp	;         "UDP"
		  cp	w5300.Sn_MR_UDP
		  jr	z,.protocol
;
		  ld	de,trace.socket.ipraw	;         "IP"
		  cp	w5300.Sn_MR_IPRAW
		  jr	z,.protocol
;
		  ld	de,trace.socket.tcp	;         "TCP"
		  cp	w5300.Sn_MR_TCP
		  jr	z,.protocol
;
		  ld	de,trace.socket.unknown	;         "UNKNOWN"
.protocol:	  call	io.str
;
		  ld	de,trace.socket.port	; 	         " port "
		  call	io.str
;
		  call	io.int			; Print port

		  ld	de,trace.socket.by	;                        " by "
		  call	io.str
		 pop	de			; DE->owner
;
		 push	de			; Save owner
		  call	io.str			; Print ownser
		  call	trace.dots
		 pop	de
;
		pop	hl
		pop	bc			; BC=Sn_xxx values
		pop	af			; A=socket number
.tracedone:
;
		push	hl
		push	bc
		 push	de			; Save owner string
		  SOCKET_GET_BASE
;
		  SOCKET_GET_VAR 0		; HL->socket memory
 		  ld	bc,vars.socket_size	; BC=size of socket memory
		  push	de
		   call	util.memzero		; Initialise socket memory to 0
		  pop	de
		 pop	hl			; HL->owner string
		 ld	a,vars.owner
		 call	set_word
		pop	bc
		pop	hl
;
		push	bc			; Save command & status values
		 ld	a,w5300.Sn_PORTR
		 call	write_reg		; Set port number
		pop	bc			; BC=command & status values
;
		push	bc
		 ld	a,w5300.Sn_MR
		 ld	l,b
		 ld	h,0			; HL=command register value
		 call	write_reg		; Set mode
		pop	bc			; C=expected status
;
		ld	hl,w5300.Sn_CR_OPEN	; Issue open command
		call	write_CR
		jr	nc,.ok
;
		ld	hl,w5300.Sn_CR_CLOSE	; Error - make sure it's closed
		ld	c,w5300.Sn_SSR_CLOSED
		call	write_CR
		scf
;
.ok:		bit	vars.trace.socket,(iy+vars._trace)
		ret	z
;
		jp	trace.is_timeout
;
;
;------------------------------------------------------------------------------
; connect
;
; This is called after open for a TCP socket, and it puts the socket in client
; TCP mode ie attempts to open a TCP/IP socket with a server
;
; This routine is really only for the TCP module - other users should call
; tcp.connect.
;
; In:   A=socket number
;      HL=dest (server) port no
;      DE->dest (server) IP address
; Out: Cy=>error
;
connect:
		bit	vars.trace.socket,(iy+vars._trace)
		jr	z,.tracedone
;
		push	af		; Save socket number
		push	hl		; Save port no
		push	de		; Save ->IP address
		 ld	de,trace.socket.connect	; "  :Connect to "
		 call	trace_msg			; "Sn"
		 ld	c,l
		 ld	b,h		; BC=port number
		pop	hl		; HL->IP address
		push	hl		; Save ->IP address
		 call	io.ip_port
		 call	trace.dots
		pop	de		; DE->IP address
		pop	hl		; HL=port no
		pop	af		; A=socket number
;
.tracedone:
		push	hl		; Save our port no.
		 ex	de,hl		; HL->IP adress
		 call	write_DIPR	; Write dest IP address, DE=reg base
		pop	hl		; HL=dest port no
;
		call	write_DPORTR	; Write dest port no.
;
		ld	hl,w5300.Sn_CR_CONNECT	; Issue connect command
		ld	c,w5300.Sn_SSR_ESTAB
		call	write_CR
		jr	c,.error	; Go if error occured
;
.error:		bit	vars.trace.socket,(iy+vars._trace)
		ret	z

		push	de		; Save socket reg base
		call	 trace.is_error
		pop	de
		ret
;
;
;------------------------------------------------------------------------------
; disconnect
;
; In TCP mode this disconnects the TCP/IP link with the remote party.
;
; This routine is really only for the TCP module - other users should call
; tcp.disconnect.
;
; Unlike for the other protocols, if the WIZ socket is in TCP mode we must
; disconnect before closing. If we don't, the WIZ socket is closed but the
; TCP connection remains open (but unusable)!
;
; In:  A=socket no.
;
disconnect:
		SOCKET_GET_BASE
;
_disconnect:
		bit	vars.trace.socket,(iy+vars._trace)
		jr	z,.donetrace
;
		push	de
		 call	_trace
;
		 ld	de,trace.socket.disconnect
		 call	io.str
		pop	de
.donetrace:		
;
		ld	hl,w5300.Sn_CR_DISCON	; HL=Disconnect command
;		ld	c,w5300.Sn_SSR_CLOSED	; C=expected response
		ld	c,w5300.Sn_SSR_FIN_WAIT	; C=expected response
		call	write_CR		; Send Disc
;
.donedisc:	bit	vars.trace.socket,(iy+vars._trace)
		ret	z			; Return if not tracing

		jp	trace.is_error		; Else print ok/error
;
;
;------------------------------------------------------------------------------
; write_CR
;
; Writes to the socket's CR register and waits for the expected response
;
; In:  HL=Sn_CR_xxx command to write
;      DE=WIZ socket base register
;      C=Sn_SSR_xxx expected status response
; Out: C=>timeout waiting for w5300
;
write_CR:
		push	bc		; Save expected response in C
		 ld	a,w5300.Sn_CR
		 call	write_reg	; Write command
		pop	bc		; C=expected response
;
.loop:		push	bc		; Save expected response
		 ld	a,w5300.Sn_SSR
		 call	read_reg
		pop	bc		; C=expected response
		ld	a,l
;
		cp	c
		ret	z		; SSR as expectd, NC
;
		cp	w5300.Sn_SSR_CLOSED	; See if socket has closed
		jr	nz,.wait	; Keep waiting if not
;
		ld	a,c		; A=expected state
		cp	w5300.Sn_SSR_FIN_WAIT	; Closed also ok!
		ret	z
;
		scf			; If it's closed it'll never change!
		ret

.wait:		call	status.waiting	; Flash status line waiting indicator
;
		call	exos.is_stop	; See if stop key pressed
		ret	c		; Ret with C if yes
;	
		jr	.loop		; Wait a bit longer
;
;
;------------------------------------------------------------------------------
; available
;
; Returns the number of bytes available to read on an open socket
;
; In:  A=socket number
; Out: HL=number of bytes available to read
;      DE=socket base reg
;       Z set according to HL
;
available_0:	xor	a
available:	SOCKET_GET_BASE
;
		; Just read Sn_RX_RSR. We don't check the high word because we
		; have configured the RX memory to be 8k so larger packets
		; amounts cannot be received
_available:	ld	a,w5300.Sn_RX_RSR2
		call	read_reg
;
		ld	a,h
		or	l
		ret			; Return with Z set appropriately
;
;
;------------------------------------------------------------------------------
; is_closed
;
; Sees if a socket has been closed. 
;
; In:  A=socket number
; Out: Z if socket has been closed
;
is_closed:	SOCKET_GET_BASE
;
_is_closed:	
		ld	a,w5300.Sn_SSR
		call	read_reg
		ld	a,l
;
		cp	w5300.Sn_SSR_CLOSED	; Socket has closed
		ret	z
;
		cp	w5300.Sn_SSR_WAIT	; FIN received from other end
		ret	z
;
		cp	w5300.Sn_SSR_FIN_WAIT	; In closing state
		ret	z
;
		cp	w5300.Sn_SSR_TIME_WAIT	; In closing state
		ret	z
;
		cp	w5300.Sn_SSR_LAST_ACK	; In closing state
		ret
;
;
;
;------------------------------------------------------------------------------
; read
;
; Reads from an open socket.
;
; read and _read are only called to read into our own buffer, so set up
; the paging for read_FIFO appropriately. _readx is called from the EXOS
; devices to read into user's memory, so set up E' before calling.
;
; We can only read words from the WIZ chip, not bytes, so to read the last
; byte of an odd-length packet we read the last byte and a dummy byte. We
; return Cy here if that is the case.
;
; In:   A=socket number
;      HL->bufer for data
;      BC=number of bytes to read
; Out: C=>we've read last byte
;      HL->rx_size
;      DE=socket base register
;
read_0		xor	a
read:		SOCKET_GET_BASE
;
_read:		exx
		ld	e,b		; Use our seg
		exx
;
_readx:		; E' must be set to page for buffer
		push	bc
		 inc	bc		; Round up to even number
		 res	0,c
		 ld	a,b
		 or	c
		 push	de
		  call	nz,read_FIFO	; Read data
		 pop	de
		pop	bc		; BC=bye count

		; Update size remaining
		SOCKET_GET_VAR	vars.rx_size	; HL->rx_size
;
		ld	a,(hl)		; rx_size -= BC
		sub	c
		ld	(hl),a
		inc	hl
;
		ld	a,(hl)
		sbc	a,b
		ld	(hl),a
		jr	nc,.donesize	; Go with NC if not gone -ve
;
		; This can happen if it's an odd-sized packet eg. we read the
		; last word (because we can only read words) but it is in fact
		; just a single byte because there's only one byte remaining
		; unread in the packet
		xor	a		; zero rx_size
		ld	(hl),a
		dec	hl
		ld	(hl),a
		inc	hl
		scf			; Cy=>read end
.donesize:	dec	hl		; HL->first byte of rx_size
;
		ret
;
;
;------------------------------------------------------------------------------
; read_byte
;
; This is a byte-by-byte read interface to a WIZ socket - a bit tricky
; because of the word-by-word nature of the WIZ interface
;
; In:  A=socket number
; Out: A=byte read
;      HL,DE,BC preserved
;      C=>no bytes were read
;
read_byte_0:	xor	a
read_byte:	push	de
		push	hl
;
		 SOCKET_GET_BASE
;
		 SOCKET_GET_VAR vars.rx_inhand	; HL->rx_inhand
;
		 ld	a,(hl)		; FF=>buffered byte, 0=>none
		 inc	a
		 jr	nz,.notgot
;
		 ld	(hl),a		; 0=>no buffered byte anymore
		 inc	hl
		 ld	a,(hl)		; Get byte
		 jr	.okret
;
.notgot:	 ld	a,vars.rx_size
		 call	get_word
		 ld	a,h
		 or	l
		 scf			; C=>nothing left to read
		 jr	z,.ret		; Byte count=0=>nothing left to read
;
		 push	bc
;
		  SOCKET_GET_VAR vars.rx_inhand	; HL->rx_inhand
;
		  push	hl
		   ld	bc,2
		   call	_read		; Read 2 bytes to rx_inhand
		  pop	hl
		  ld	a,(hl)		; Get first byte read
		  jr	c,.got1		; Go if only 1 byte was left to read
;
		  ld	(hl),0ffh	; Else ff=>byte buffered in following
.got1:		 pop	bc
.okret:		 or	a		; NC=>not end of packet
.ret:		pop	hl
		pop	de
		ret
;
;
;------------------------------------------------------------------------------
; read_flush
;
; The WIZ chip needs you to read every byte in the current packet, even if you
; don't actually want it. Or you can close the socket, but then you don't get
; any following packets.
;
; In:   A=socket number
; Out: DE=socket base register
;
read_flush_0:	xor	a
read_flush:	SOCKET_GET_BASE

_read_flush:	set	0,(iy+vars._socket.flushing)	; Supress raw output
;
		ld	a,vars.rx_size
		call	get_word	; HL=no.bytes remaining
;
		inc	hl		; Convert to even making sure we catch
		res	0,l		;   odd byte at end of odd length packets
;
.loop:		; In this loop HL=total # bytes to read (even!)
		; We read in chunks into the DHCP packet buffer
		ld	a,h
		or	l
		jr	z,.done		; No more to read
;		
		ld	bc,vars.dhcp.packet_size	; BC=buffer size (even!)
		or	a
		sbc	hl,bc		; HL=remainder after read
		jr	nc,.sizeok	; Go if still more after this read
;
		add	hl,bc		; Else get back original size
		ld	c,l
		ld	b,h		; BC=amount to read this time
		or	a
		sbc	hl,hl		; HL=amount to read next time (0)
.sizeok:	push	hl		; Save amount to read next time
		 ld	hl,vars.dhcp.packet	; Buffer to read to
		 exx
		 ld	e,b		; Use our segment
		 exx
		 push	de
		  call	read_FIFO
		 pop	de
		pop	hl		; HL=amount for next read
		jr	.loop
;
.done:		res	0,(iy+vars._socket.flushing)	; Stop supress raw output
;
		ld	a,vars.rx_inhand
		or	a
		sbc	hl,hl			; HL=0
		call	set_word		; No buffered byte
;
		ld	a,vars.rx_size
		or	a
		sbc	hl,hl
		jp	set_word
;
;
;------------------------------------------------------------------------------
; read_end
;
; Called when reading has finished. It can be called when we no longer want
; the packet, so it needs to call read_flush because the WIZ w5300 insists
; we read everything.
;
; _recv can be called to send the RECV command to the w5300 if we are
; certain everything has been read. (tcp.read_block does this because it
; doesn't want to loose any bytes buffered in rx_inhand).
;
; In:  A=socket number
; Out: DE=socket base register
;
read_end_0:	xor	a
read_end:	SOCKET_GET_BASE
;
_read_end:	call	_read_flush		; Read any unread words
;
_recv:		ld	hl,w5300.Sn_CR_RECV	; Received!
		ld	a,w5300.Sn_CR
		jp	write_reg
;
;
;------------------------------------------------------------------------------
; write
;
; Writes to a previously open socket
;
; In:   A=socket number
;      HL->data to write
;      BC=byte count
; Out: Cy=>error
;
write_0:	xor	a
write:		SOCKET_GET_BASE
;
_write:		exx
		ld	e,b	; Use our seg for buffer
		exx
;
		push	hl	; Save user's buffer ptr
		 call	read_FSR; Check FSR to make sure there's enough room 
		 or	a
		 sbc	hl,bc
		pop	hl
		ret	c	; Shouldn't happen!
;
.bigenough:	push	bc	; Save byte count
		 inc	bc	; Round up to even # bytes
		 res	0,c
		 call	write_FIFO
		pop	bc	; BC=byte count just written
;
add_tx_size:	SOCKET_GET_VAR vars.tx_size	; HL->tx_size
		ld	a,(hl)		; Add on amount just written
		add	a,c
		ld	(hl),a
		inc	hl
		ld	a,(hl)
		adc	a,b
		ld	(hl),a
;
		or	a	; NC=>no error
		ret
;
;
;------------------------------------------------------------------------------
; write_DIPR and wrte_DPORTR
;
; These are called prior to write() to set up the destination IP address
; (when in UDP and IPRAW modes) and DPORTR (when in UDP mode).
;
; In:   A=socket number
;      HL->IP address
; Out: DE=reg base
;
write_DIPR_0:	xor	a
write_DIPR:	SOCKET_GET_BASE
;
		push	hl		; Save ->IP address
		 ld	b,w5300.Sn_DIPR; Do first register
		 call	.doone
		pop	hl		; HL->IP address
;
		ld	b,w5300.Sn_DIPR2; Then second register
		inc	hl
		inc	hl
;
.doone:		ld	a,(hl)		; Repeat for 2nd word
		inc	hl
		ld	l,(hl)
		ld	h,a
		ld	a,b
		jp	write_reg
;
;
; Due to a bug in the w5300, DPORTR cannot be read. So here we save the value
; in per-socket RAM as well as actually write it to the w5300.
;
; In: DE=reg base, probably left over from call to write_DIPR
;     HL=port number
write_DPORTR:	push	hl		; Save value
		 ld	a,vars.DPORTR
		 call	set_word	; Save copy of DPORTR
		pop	hl
		ld	a,w5300.Sn_DPORTR
		jp	write_reg	; Write port #
;
;
;------------------------------------------------------------------------------
; read_DIPR and read_DPORTR
;
; These are called to get the IP address and socket number of an established
; copnnection.
;
; In:   A=socket number
;      HL->buffer for IP address
; Out: DE=socket reg base
read_DIPR:
		SOCKET_GET_BASE
;
		ld	a,w5300.Sn_DIPR
		call	.doone
;
		ld	a,w5300.Sn_DIPR2
.doone:		push	hl		; Save ->IP buffer
		 call	read_reg	; HL=2 bytes of IP
		 ld	c,l
		 ld	b,h		; BC=2 bytes of IP
		pop	hl		; HL->IP
		ld	(hl),b
		inc	hl
		ld	(hl),c
		inc	hl
		ret
;
;
; Due to a bug in the w5300, DPORTR cannot be read. So here we read the value
; that was saved in per-socket RAM instead of reading from the w5300.

; In:  DE=reg base, probably left over from call to read_DIPR
; Out: HL=port number
;
read_DPORTR:	ld	a,vars.DPORTR
		jp	get_word	; HL=port number
;
;
;------------------------------------------------------------------------------
; read_FSR
;
; Returns in HL the number of bytes of free tx memory o0n the WIZ chip
;
read_FSR:
		; Strictly speaking FSR is a 32-bit value but as we've
		; configured the w5300 tx memory to be 8k max on each socket,
		; here we're only checking the LSW.
		 ld	a,w5300.Sn_TX_FSR2; FSR is the high word, FSR2 the low
		 push	bc		; Save byte count
		  call	read_reg
		 pop	bc
		 ret
;
;
;------------------------------------------------------------------------------
; send
;
; Called after a series of writes to actually send the data.
;
; For UDP mode DIPR and DPORTR must be set up to indicate the destination
; IP and port.
;
;  In: DE=socket base register
; Out: Cy=>error
;      DE preserved
;
_send:
		or	a
		sbc	hl,hl
		ld	a,w5300.Sn_TX_WRSR	; Write #bytes
		call	write_reg
;
		ld	a,vars.tx_size
		call	get_word		; HL=no. bytes written
;
; Commented out for tcp.read_block sending 0 length packet to fix w5300 bug!
;		ld	a,h
;		or	l
;		jr	z,.end			; Nothing to send!
;
		ld	a,w5300.Sn_TX_WRSR2	; Tell WIZ
		call	write_reg
;
		ld	a,w5300.Sn_CR
		ld	hl,w5300.Sn_CR_SEND
		call	write_reg		; Send it!
;
; Here we wait till the send has finished. It would be more efficient to
; return and let the z80 get on with other things while it is being sent,
; and to check for sending complete on entry (and socket close?) but for now
; it is simpler and less error prone to wait here. 100MBps Ethernet doesn't
; take very long to send in 4MHz Z80 time ie. the Z80 would not be able to
; do much before the send had compketed!
;
.loop:		ld	a,w5300.Sn_IR
		call	read_reg
		ld	a,l
		and	w5300.Sn_IR_SENDOK
		jr	nz,.sendok
;
		ld	a,l
		and	w5300.Sn_IR_TIMEOUT
		jr	nz,.timeout
;
		call	_is_closed
		scf
		jr	z,.end

		call	status.waiting
;
		call	exos.is_stop	; Just in case we're looping forever
		jr	c,.end		;   (shouldn't happen!)
;
		jr	.loop

.timeout:	scf			; Return error
		ld	hl,w5300.Sn_IR_TIMEOUT
		jr	.ret
;
.sendok:	or	a		; NC=>No error
		ld	hl,w5300.Sn_IR_SENDOK
.ret:		push	af		; Save error flag
		 ld	a,w5300.Sn_IR
		 call	write_reg	; Clear interrupt
;
		 or	a
		 sbc	hl,hl		; HL=0
		 ld	a,vars.tx_size
		 call	set_word	; Reset tx count
		pop	af
;
.end:		bit	vars.trace.socket,(iy+vars._trace)
		ret	z
;
		push	de
		 call	trace.is_timeout
		pop	de
		ret
;
;
;------------------------------------------------------------------------------
; keepalive
;
; Sends a TCP/IP "keep alive" packet
;
; In:  A=socket number (or DE=socket base reg at _keepalive:)
;
;keepalive:	SOCKET_GET_BASE
;_keepalive:
;		; To manually send a Keep Alive, auto-Keep Alives have to be
;		; OFF so we save the current Keep Alive timer, set it to 0,
;		; send the Keep Alive, and then restore it
;		ld	a,w5300.Sn_PORTOR
;		call	read_reg
;		push	hl		; Save keep alive timer value
;
;		 ld	a,w5300.Sn_PORTOR
;		 or	a
;		 sbc	hl,hl		; H=Sn_KPALVTR=0, L=Sn_PROTOR=0
;		 call	write_reg	; Make sure auto-keep-alives are OFF
;
;		 ld	hl,w5300.Sn_CR_SEND_KEEP; HL=Send Keepalive command value
;		 ld	c,w5300.Sn_SSR_ESTAB	; C=expected status reg value
;		 call	write_CR	; Send command
;
;		pop	hl		; HL=old keep alive timer value
;		ld	a,w5300.Sn_PORTOR
;		jp	write_reg	; Restore keep alive timer register
;
;
;------------------------------------------------------------------------------
; close
;
; Closes a previously opened socket
;
; In:  A=socket number
;
close_0:	xor	a
close:		push	af		; Save socket no
		 SOCKET_GET_BASE	; DE=socket base reg
;
		 ld	a,w5300.Sn_IR
		 ld	hl,0ffh
		 call	write_reg	; Clear socket interrupt flags
		pop	af		; A=socket number
;
		push	af		; Save socket number
		 push	de		; Save reg base
		  call	tomask		; Get bitmask for socket
		  ld	l,a
		  ld	h,0
		  ld	de,w5300.IR
		  call	wiz.write_reg	; Clear this socket's interrupt flag
		 pop	de		; DE=reg base
		pop	af		; A=socket number
;
		push	af
		push	de
		 bit	vars.trace.socket,(iy+vars._trace)
		 ld	de,trace.socket.close
		 call	nz,trace_msg
		pop	de
		pop	af		; A=socket no
;
		ld	hl,w5300.Sn_CR_CLOSE
		ld	c,w5300.Sn_SSR_CLOSED	; C=expected response
		call	write_CR
;
		bit	vars.trace.socket,(iy+vars._trace)
		ret	z
;
		jp	trace.is_error
;
;
;------------------------------------------------------------------------------
; find
;
; Finds an unused socket
;
; Socket 0 is reserved for fixed sychronous protocols such as DHCP (it makes
; the code slightly easier to use fixed socket 0).
;
; Out: A=socket number of a free socket
;      Cy=>no free socket
;
find:		ld	hl,vars.socket.last	; Last socket opened
		ld	a,(hl)
.inc:		inc	a
		and	wiz.SOCKETS-1
		jr	z,.inc		; Ignore socket 0
;
		cp	(hl)		; Uh-oh, no free sockets
		scf
		ret	z
;
		call	status		; Get socket status
		cp	w5300.Sn_SSR_CLOSED	; Closed?
		jr	nz,.inc		; Check next if not
;
		ret			; Use this one (NC)
;
;
;------------------------------------------------------------------------------
; status
;
; Returns the open/closed status of a socket
;
; In:   A=socket number
; Out: HL=Sn_SSR value
;
status:		SOCKET_GET_BASE
;
		ld	a,w5300.Sn_SSR
		jp	read_reg	; HL=Sn_SSR value
;
;
;------------------------------------------------------------------------------
; status_str
;
; In:   A=Sn_SSR value
; Out:  A preserved
;      HL->string if NC
;      NC=>Sn_SSR value was found
;
status_str:
		ld	hl,.val_tab	; HL->table of values
		ld	bc,.val_tab_num	; BC=number of entries in table
		push	hl		; Save start of table
		 cpir			; Look for Sn_SSR value in table
		pop	bc		; BC=start of table
		scf
		ret	nz		; Return with Cy if not found
;
		dec	hl		; Point back to matching entry
		or	a
		sbc	hl,bc		; HL=offset into table
		ld	bc,.str_tab	; BC->table of string pointers
		add	hl,hl		; *2 cos addresses
		add	hl,bc		; HL->string pointer
		ld	c,(hl)
		inc	hl
		ld	h,(hl)
		ld	l,c		; HL->string
		or	a		; NC=>ok
		ret
;
.val_tab:	db	w5300.Sn_SSR_CLOSED
		db	w5300.Sn_SSR_INIT
		db	w5300.Sn_SSR_LISTEN
		db	w5300.Sn_SSR_ESTAB
		db	w5300.Sn_SSR_WAIT
		db	w5300.Sn_SSR_UDP
		db	w5300.Sn_SSR_IPRAW
		db	w5300.Sn_SSR_MACRAW
		db	w5300.Sn_SSR_PPPoE
		db	w5300.Sn_SSR_SYNSENT
		db	w5300.Sn_SSR_SYNRECV
		db	w5300.Sn_SSR_FIN_WAIT
		db	w5300.Sn_SSR_TIME_WAIT
		db	w5300.Sn_SSR_LAST_ACK
		db	w5300.Sn_SSR_ARP
;
.val_tab_num	equ	$-.val_tab
;
.str_tab:				; Same order as above!
		dw	.str_CLOSED
                dw	.str_INIT
                dw	.str_LISTEN
                dw	.str_ESTAB
                dw	.str_WAIT
                dw	.str_UDP
                dw	.str_IPRAW
                dw	.str_MACRAW
                dw	.str_PPPoE
                dw	.str_SYNSENT
                dw	.str_SYNRECV
                dw	.str_FIN_WAIT
                dw	.str_TIME_WAIT
                dw	.str_LAST_ACK
                dw	.str_ARP
;
.str_CLOSED:	db	"Closed",0
.str_INIT:	db	"Initialising",0
.str_LISTEN:	db	"Listening",0
.str_ESTAB:	db	"Connected",0
.str_WAIT:	db	"Closing",0
.str_UDP:	db	"UDP",0
.str_IPRAW:	db	"IP raw",0
.str_MACRAW:	db	"MAC raw",0
.str_PPPoE:	db	"PPPoE",0
.str_SYNSENT:	db	"SYN Sent",0
.str_SYNRECV:	db	"SYN Received",0
.str_FIN_WAIT:	db	"FIN Wait",0
.str_TIME_WAIT:	db	"Time Wait",0
.str_LAST_ACK:	db	"Last ACK",0
.str_ARP:	db	"ARP request",0
;
;
;------------------------------------------------------------------------------
; byteswapword
;
; Any WORDs that we read from the WIZ are in HILO order so need to be byte
; swapped before we can use them naturally on the Z80.
; In:  HL->word
; Out: word byte swapped and returned in HL
;
byteswapword:	ld	b,(hl)
		inc	hl
		ld	c,(hl)
		ld	(hl),b
		dec	hl
		ld	(hl),c
		ld	l,c
		ld	h,b
		ret
;
;
;------------------------------------------------------------------------------
; set_word
;
; Writes a 16-bit value to per-socket variable
;
; In:  A=var
;     DE=reg base
;     HL=value
;
set_word:	push	hl		; Save new value
		 SOCKET_GET_RAM		; HL->variable
		 ex	de,hl		; DE->variable, HL=reg base
		ex	(sp),hl		; HL=new value, (SP)=reg base
		 ex	de,hl		; HL->variable, DE=new value
		 ld	(hl),e		; Save new value
		 inc	hl
		 ld	(hl),d
		 pop	de		; DE=reg base
		ret
;
;
;------------------------------------------------------------------------------
; get_word
;
; Reads a 16-bit value to per-socket variable
; In:   A=var
;      DE=reg base
; Out: HL=value
;
get_rx_size:	SOCKET_GET_BASE
		ld	a,vars.rx_size
;
get_word:	SOCKET_GET_RAM
		ld	a,(hl)
		inc	hl
		ld	h,(hl)
		ld	l,a
		ret
;
;
;------------------------------------------------------------------------------
; get_owner
;
; Returns the name of the socket opener
;
; In:    A=socket number
; Out:  HL->owner string
;
get_owner:	SOCKET_GET_BASE
		ld	a,vars.owner
		jr	get_word
;
;
;------------------------------------------------------------------------------
; trace, trace_msg
;
; At the start of each trace line output, "Sn" is displayed (n is the port
; number).
;
; trace_msg is the same but prints the message at DE afterwards.
;
; In:  A=socket number
;     DE=->message to print
;
trace_msg:	push	de
		 call	trace
		pop	de
		jp	io.str
;		
trace:		SOCKET_GET_BASE
_trace:		call	io.start
		ld	a,'S'
		call	io.char
		ld	a,d		; Bit 0 = port bit 2
		and	1
		or	e		; Bits 6,7 = port bits 0,1
		rlca
		rlca			; Bits 0,1,2 = port bits 0,1,2
		add	a,'0'
		call	io.char
		ld	a,':'
		jp	io.char
;
;
;
		endmodule
		