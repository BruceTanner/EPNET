; TCP
;
; Implements an interface to the sockets of the WIZ chip in TCP mode
;
		module tcp
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
; Opens a WIZ socket in TCP client mode
;
; In:  A=socket number
;     HL=our port number
;     DE->owner string
; Out: Carry set if error
;
open:
		ld	bc,(w5300.Sn_MR_TCP or w5300.Sn_MR_ND)*256+                                                              w5300.Sn_SSR_INIT
		jp	socket.open		; Open socket in TCP client mode
;
;
;------------------------------------------------------------------------------
; header
;
; Starts reading a packet from an open socket
;
; In:  A=socket number
; Out: NC=>no error
;       Z=>nothing to read
;      HL=no bytes in packet (0 if nothing read)
;      DE=socket base register
header:		SOCKET_GET_BASE
_header:	call	socket._available; See if any bytes available to read
		ret	z		; Z=>nope
;
; A packet has been received. First 2 bytes are PACKET_INFO: just 
; packet size for TCP mode
;
		; We rely on the w5300 behaving here - if there's some data
		; there must be at least a PACKET_INFO header here
		ld	bc,vars.tcp.header_size	; Header 1 word for TCP mode
		ld	hl,vars.tcp.header
		push	de
		 call	socket.read_header	; Read header
		pop	de			; DE=base reg
;
		ld	hl,vars.tcp.size
		call	socket.byteswapword
;
		ld	a,socket.vars.rx_size
		call	socket.set_word		; Set up per-socket vars
;
 		bit	vars.trace.socket,(iy+vars._trace)
		jr	z,.ret
;
		push	de			; Save socket base reg
		 call	socket._trace
;
		 ld	de,trace.tcp.rx
		 call	io.str
;
		 ld	hl,(vars.tcp.size)
		 call	trace.bytes
		 call	io.space
		pop	de			; DE=socket base reg
;
.ret:		ld	hl,(vars.tcp.size)
		ld	a,h
		or	l			; NC=>no error, NZ=>bytes ready
		ret
;
;
;------------------------------------------------------------------------------
; read_block
;
; This is called from the EXOS device to read a block of data into the user's
; buffer. It must cope with odd-length reads and multiple TCP packets.
;
; In:  A=socket number
;     DE->buffer
;     BC=total number of bytes to read, >0
; Out: NC & A=0 if no error
;      Cy=>error, A=1 => socket closed, A=2 => STOP pressed, A=3 => timeout
;
read_block:
		ex	de,hl		; HL->user's buffer
		SOCKET_GET_BASE		; DE=socket base register
;
.loop:
		ld	a,b		; See if byte count == 0
		or	c
		ret	z		; All done
;		
		; First we look to see if we have an odd byte buffered and,
		; if we have, put this in the user's buffer
		push	hl		; Save ->buffer
		 SOCKET_GET_VAR socket.vars.rx_inhand
		 ld	a,(hl)		; FF=>buffered byte, 0=>none
		 inc	a
		 jr	nz,.no_inhand	; Go if no byte inhand
;
		 ld	(hl),a		; No byte buffered now
		 inc	hl
		 ld	a,(hl)		; Get buffered byte
		pop	hl		; HL->user's buffer
;
.putbyte:	ld	(hl),a		; Put byte into user's buffer
		inc	hl		; Adjust ->user's buffer
		dec	bc		; Adjust total byte count
		jr	.loop		; Repeat but now we know no byte buffered
;
.no_inhand:	pop	hl		; HL->user's buffer
;
		; Now we definitely need one or more bytes from a packet, so
		; see if we have started reading from one
		push	hl
		push	bc
		 SOCKET_GET_VAR socket.vars.rx_size
		 ld	c,(hl)
		 inc	hl
		 ld	b,(hl)		; BC=amount available
		 ld	a,b
		 or	c
		 jr	nz,.got_packet	; Go if packet waiting
;
		 ; Here we need to read more but we have exhausted the current
		 ; packet, so we need to wait until RSR indicates that there
		 ; is something available and then read the PACKET_INFO of
		 ; the next packet (if there is one)
		 ;
		 ; We need to check for a packet ready *before* checking to
		 ; see if the socket is closed, as the other end may well
		 ; send lots of packets then close the link before we have
		 ; read them all
;
		 ld	hl,(vars.ticks)	; Setup timout timer
		 ld	(vars.tcp.start),hl
;
.wait:		 call	_header		; See if packet arrived
		 jr	nz,.got_packet	; Go and read it if yes
;
		 call	socket._is_closed; Other end closed connection
		 ld	a,1
		 jr	z,.ret		; Return with A=1 if yes
;
		 call	status.waiting	; Flash waiting indicator
;
		 call	_send		; Send 0 bytes to update TCP/IP window
;
		 call	exos.is_stop	; Stop key pressed?
		 ld	a,2
		 jr	c,.ret		; Return with A=2 if yes
;
		 ld	bc,(vars.tcp.start)
		 ld	hl,(vars.ticks)
		 or	a
		 sbc	hl,bc		; HL=duraction in ticks
		 ld	bc,TICKS_1m
		 sbc	hl,bc		; See if timed out (1 S)
		 jr	c,.wait		; Keep waiting if not
;
		 ld	a,3		; Return with A=3 if timed out
;
.ret:		pop	bc
		pop	hl
		scf			; Cy=>error
		ret
;
.got_packet:	pop	bc
		pop	hl
;
		; Here there is a packet buffered and we need one or more
		; bytes from it
		; HL->user's buffer
		; BC=total bytes needed
		; DE=socket base
;
		; First we read as many even bytes as we can from the packet
		push	bc	; Save total byte count
		 push	hl	; Save->user's buffer
		  res	0,c	; Only doing even bytes (could == 0!)
		  push	bc	; Save # even bytes required
		   SOCKET_GET_VAR socket.vars.rx_size
		   ld	c,(hl)
		   inc	hl
		   ld	b,(hl)	; BC=amount available
		   res	0,c	; Only doing even bytes (could == 0!)
		  pop	hl	; HL=#even bytes required
		  or	a
		  sbc	hl,bc	; HL=remainder after read
		  jr	nc,.all	; Go if amount in packet < required
;
		  add	hl,bc	; HL=amount to read from packet
		  ld	c,l
		  ld	b,h	; BC=amount for this read
;
.all:		 pop	hl	; HL->user's buffer

		 ; Now BC   = number of even bytes to read from packet
		 ;     HL   ->user's buffer
		 ;     (SP) = total bytes required
;
		 ld	a,b
		 or	c	; A=0 => no even bytes to read
		 jr	z,.odd
;
		 push	hl	; Save ->user's buffer
		  add	hl,bc	; HL->user's buffer updated
		 ex	(sp),hl	; HL->user's buffer, (SP)->buffer updated
		  push	bc	; Save amount to read
		   call	socket._read	; Read the bytes; HL->rx_size
;
		   ld	a,(hl)
		   inc	hl
		   or	(hl)	; See if we've read everything
		   call	z,socket._send_end	; Indicate end of read if we have
		  pop	bc	; BC=amount just read
		 pop	hl	; HL->user's buffer updated
		ex	(sp),hl	; HL=total byte count, (SP)=buffer updated
		 or	a
		 sbc	hl,bc	; Total bytes required -= amount just read
		 ld	c,l
		 ld	b,h	; BC=new total byte count
		pop	hl	; HL->new user's buffer
;
		jp	.loop
;
.odd:		pop	bc	; BC=total byte count
;
		; We now have a packet and have read as many even bytes as we
		; can from it. If we end up here either a) it's an odd-length
		; read and we need the last odd byte, or b) we have an
		; odd-length packet and we need to read the last byte from it
;
		; HL->user's buffer
		; BC=bytes still required
;
		; When doing a byte read we normally read a word and buffer
		; the second byte in rx_inhand. But if it's the last byte of
		; an odd-length packet we have to discard the second byte as
		; it's a dummy!
;
		push	hl
		push	bc
		 SOCKET_GET_VAR socket.vars.rx_inhand	; Read 2 bytes to here
		 ld	bc,2	; Read 2 bytes
		 push	hl	; Save->rx_inhand
		  call	socket._read	; Read 1 word; Cy=>past last byte
		  push	af	; Save last byte flag
		   ld	a,(hl)	; Check rx_size to see if we've read everything
		   inc	hl
		   or	(hl)	; See if we've read everything
		   call	z,socket._send_end ; Indicate end of read if we have
		  pop	af	; Cy=>read past last byte
		 pop	hl	; HL->rx_inhand
		 ccf		; NC=>last byte, Cy=>not last byte
		 sbc	a,a	; A= 0=>last byte, ff=>not last byte
		 ld	b,(hl)	; B=first of the two bytes
		 ld	(hl),a	; FF=>buffered byte, 0=>no buffered byte
		 ld	a,b	; A=byte to put in user's buffer
		pop	bc	; BC=total byte count
		pop	hl	; HL->user's buffer
		jp	.putbyte; Put byte in user's buffer & update HL & BC
;
;
;------------------------------------------------------------------------------
; write_block
;
; This is called from the EXOS device to write a block of data from the user's
; buffer. It must cope with odd-length writes and splitting large blocks into
; multiple TCP packets.
;
; In:  A=socket number
;     DE->buffer
;     BC=total number of bytes to read, >0
; Out: Cy=>error
;
write_block:
		ex	de,hl		; HL->user's buffer
		SOCKET_GET_BASE		; DE=socket base register
;
		; First we look to see if we have an odd byte buffered from
		; the previous write and, if we have, take first byte from
		; the current write to form a word with it, and write it
		push	hl		; Save ->buffer
		 SOCKET_GET_VAR socket.vars.tx_inhand+1
		 ld	a,(hl)		; FF=>buffered byte, 0=>none
		 or	a		; NC
		 inc	a
		 jr	nz,.nobuf	; Go with NC if no byte inhand
;
		 ex	(sp),hl		; (SP)->tx_inhand+1, HL->user's buffer
		 ld	a,(hl)		; Get user's first data byte
		 inc	hl
		 ex	(sp),hl		; (SP)->user's data, HL->tx_inhand+1
		 ld	(hl),a		; tx_inhand now = next word to write
		 dec	hl		; HL->tx_inhand
		 dec	bc		; User's byte count now 1 less
		 push	bc
		  push	hl		; Save ->tx_inhand
		   ld	bc,2		; Write 1 word
		   call	_write_block
		  pop	hl		; HL->tx_inhand
		  inc	hl
		  ld	(hl),0		; 0 => no buffered byte
		 pop	bc		; BC=remaining bytes to write
.nobuf:		pop	hl		; HL->user's data
		ret	c		; Error
;
		; Now we write the even words
		; HL->user's buffer
		; BC=byte count (could now be 0, could still be odd)
		; DE=socket base
		push	hl		; Save ->user's buffer
		 push	bc		; Save byte count
		  res	0,c		; We'll do odd bytes l8r
		  ld	a,b
		  or	c		; NC as well as testing BC
		  call	nz,_write_block
		 pop	bc		; BC=byte count jusrt written
		pop	hl		; HL->user's buffer
;
		ret	c		; Error from _write_block
;
		bit	0,c		; An odd #bytes?
		ret	z		; We're done if not
;
		; If there's an odd byte at the end, save it in tx_inhand for
		; the next write
		add	hl,bc		; Adjust ->buffer for write
		dec	hl		; ->last odd byte
		ld	a,(hl)
		push	af		; Save odd byte
		 SOCKET_GET_VAR socket.vars.tx_inhand
		pop	af		; A=last odd byte
		ld	(hl),a		; Save last byte in tx_inhand
		inc	hl
		ld	(hl),0ffh	; FF->got a buffered byte in hand
		or	a		; NC=>no error
		ret
;
;
; _write_block
;
; write_block (above) deals with odd bytes, so here we just write a block given
; an even byte count. However it could be a large block so we might have to
; split it up into separate WIZ sends ( ie. separate TCP packets)
;
; In:  HL->bufer
;      BC=word byte, >0
;      DE=socket register base
; Out: DE preserved
;      Cy=>error
;
_write_block:
;
		; First see if it's time to send a packet
		push	hl		; Save ->data
		 push	bc		; Save byte count
.loop:		  call	socket.read_FSR	; HL=space available (in bytes)
		  ld	a,h
		  or	l
		  jr	nz,.donesend
;
		  call	tcp._send	; Send if WIZ buffer full
		  jr	nc,.loop
;
		 pop	bc
		pop	hl
		ret

;
.donesend:	  ld	c,l
		  ld	b,h		; BC=no bytes to write this time
		 pop	hl		; HL=total byte count to write
		 or	a
		 sbc	hl,bc		; HL=remainder after this write
		 jr	nc,.notlast
;
		 add	hl,bc		; HL=amount to write this time
		 ld	c,l
		 ld	b,h		; BC=#bytes to write this time

		 or	a
		 sbc	hl,hl		; HL=0, #bytes to write next time
;
.notlast:
		 ; HL=remaining byte count
		 ; BC=byte count this time
		 ; (SP)->data
		ex	(sp),hl		; (SP)=remaining bytes, HL->data
		 push	bc		; Save # byte about to be written
		  push	de		; Save socket base register
		   call	socket.write_FIFO; Write data; HL=updated ->data
		  pop	de		; DE=socket register base
		 ex	(sp),hl		; (SP)->data, HL=#bytes just written
		  ld	c,l
		  ld	b,h
		  call	socket.add_tx_size	; Add on to tx_size
		 pop	hl		; HL->data
		pop	bc		; BC=#bytes remaining
		ld	a,b
		or	c
		jr	nz,_write_block	; Do it again if more to write
;
		ret			; NC =>no error
;
;
;------------------------------------------------------------------------------
; status
;
; This is called from EXOS devices to determine whether there is a byte
; ready to be read or not.
;
; In:  A=socket number
; Out: A=0=>byte ready, FF=>end of file, 1 otherwise
;      Note: flags may not be set according to A!
;
status:	
		SOCKET_GET_BASE		; DE=socket base register
;
		; First see if we have a byte buffered
		SOCKET_GET_VAR socket.vars.rx_inhand
		ld	a,(hl)		; FF=>buffered byte, 0=>none
		inc	a
		ret	z		; Return with A=0 if byte buffered
;
		SOCKET_GET_VAR socket.vars.rx_size
		ld	a,(hl)		; See if any packet read started
		inc	hl
		or	(hl)
		call	z,socket._available; Or any packet waiting
		ld	a,0
		ret	nz		; Return with A=0 if yes
;
		call	socket._is_closed
		ld	a,0ffh
		ret	z		; FF=>EOF if socket closed (or closing)
;
		ld	a,1
		ret
;
;
;------------------------------------------------------------------------------
; keepalive
;
; Sets the Keep Alive timer so the session does not time out
;
;keepalive:	SOCKET_GET_BASE		; DE=socket base register
;
;		ld	a,w5300.Sn_PORTOR	; Timer is in Port Options Reg
;		ld	hl,(60/5)*256+0	; H=1 min, L=0 not used in TCP mode
;		jp	socket.write_reg
;
;
;------------------------------------------------------------------------------
; send
;
; Sends data that has already been written to the tx FIFO.
;
; In:  A=socket number
;
send:		SOCKET_GET_BASE
_send:
		bit	vars.trace.socket,(iy+vars._trace)
		jp	z,socket._send
;
		call	socket._trace
;
		push	de
		 ld	de,trace.tcp.tx
		 call	io.str
		pop	de
;
		push	de
		 ld	a,socket.vars.tx_size
		 call	socket.get_word
		 call	trace.bytes
		 call	trace.dots
		pop	de
;
		jp	socket._send	; Do the send
;
;
;------------------------------------------------------------------------------
; connect
;
; Attempts to open a socket in client TCP mode ie attempts to open a TCP/IP
; link with a remote server
;
; In:   A=socket number
; Out: NC=>no error
connect:	call	socket.connect	; Attempt t connect
		ret	c		; Error occured
;
		SOCKET_GET_VAR socket.vars.tcp_connected; HL->tcp.connected
		ld	(hl),0ffh	; NZ=>we are connected
		or	a		; NC=>no error
		ret
;
;
;------------------------------------------------------------------------------
; disconnect
;
; Attempts to disconnect a TCP/IP link.
;
; In:  A=socket number
; Out: NC=>no error
;
disconnect:	SOCKET_GET_BASE
_disconnect:
		call	.readall	; Make we have a rx window<>0
;
		SOCKET_GET_VAR socket.vars.tcp_connected
		ld	(hl),0		; 0=>not connected any more
;
		call	socket._disconnect	; Send disconnect
;
.readall:	ld	a,socket.vars.rx_size
		call	socket.get_word	; HL=no. bytes left to read
		ld	a,h
		or	l		; See if we've started a read
		call	nz,socket._read_end	; Flush & finish if yes
;
		call	_header		; See if more packets waiting
		jr	nz,.readall	; Read them if yes
;
		or	a		; No error
		ret
;
;
;------------------------------------------------------------------------------
; close
;
; Closes the socket
;
; In:  A=socket number
close:
		push	af
		 SOCKET_GET_BASE
;
		 ; If there's an odd byte waiting to be written it needs to
		 ; be flushed, so we write a final dummy byte but decrement
		 ; the byte count after so it doesn't actually get sent
		 SOCKET_GET_VAR socket.vars.tx_inhand+1
		 ld	a,(hl)		; FF=>bufered byte
		 inc	a
		 jr	nz,.doneinhand
;
		 ld	(hl),a		; Final dummy byte, 0 =>nothing inhand
		 dec	hl		; Point to last user byte
		 ld	bc,2
		 call	_write_block	; Write final byte+dummy
;		
		 SOCKET_GET_VAR socket.vars.tx_size
		 ld	a,(hl)
		 dec	(hl)		; Dec tx_size so dummy isn't written
		 or	a
		 jr	nz,.doneinhand	; If LSB was 0 then must dec MSB
;
		 inc	hl
		 dec	(hl)
.doneinhand:
		 ; Any odd byte at the end that was buffered in tx_inhand has
		 ; now been dealt with. Now need to actually send any bytes
		 ; that have been written to the WIZ chip but not yet sent
		 SOCKET_GET_VAR socket.vars.tx_size
		 ld	a,(hl)
		 inc	hl
		 or	(hl)
		 call	nz,_send	; Ignore errors 'cos we're closing
;
		 SOCKET_GET_VAR socket.vars.tcp_connected; Currently connected?
		 ld	a,(hl)		; NZ=>connected
		 or	a
		 push	de
		  call	nz,_disconnect	; Disconnect before closing if yes
		 pop	de
		pop	af
;
		call	socket.close
;
		bit	vars.trace.socket,(iy+vars._trace)
		ret	z
;
		jp	trace.ok
;
;
		endmodule
