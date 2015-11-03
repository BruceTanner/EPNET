; DEVICE
;
; This module contains the EXOS device drivers
;
		module	device
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
; This is the data kept in EXOS channel RAM.
;
; EXOS channel RAM is accessed at (ix-1), (ix-2)...etc so our data here is
; accessed with (ix-1-<item>) eg (ix-1-channel.socket)
;
; Other devices (eg. FTP:, HTTP: may need to keep other information in channel
; RAM but they all start with this so that common code can be used.
;
		struct	channel		; Variables in EXOS channel RAM
socket		 byte			; WIZ socket # for this channel
		ends
;
;
; FTP DEVICE
;
; The FTP device allows an EXOS user to open an EXOS channel to "FTP:xxx" and
; then to read and write to a file.
;
		dw	tcp_descriptor-8000h	; XX_NEXT Next device in P1
		dw	-2		; XX_RAM	No RAM required
ftp_type:	db	0		; DD_TYPE
		db	20h		; DD_IRQFLAG (50Hz)
		db	0		; DD_FLAGS
		dw	ftp_entry-8000h	; DD_TAB in page 1
		db	0		; DD_TAB_SEG
		db	0		; DD_UNIT_COUNT
		db	3,"FTP"		; DD_NAME
devices:
ftp_descriptor:	db	$-ftp_type	; XX_SIZE
;
ftp_entry:	dw	ftp_interrupt
		dw	ftp_open
		dw	ftp_create
		dw	ftp_close
		dw	ftp_close	; destroy
		dw	ftp_read_byte
		dw	ftp_read_block
		dw	ftp_write_byte
		dw	ftp_write_block
		dw	ftp_read_status
		dw	write_status
		dw	special
		dw	init
		dw	moved
;
;------------------------------------------------------------------------------
; ftp_interrupt
;
; The device driver interrupt routine
;
ftp_interrupt:	ld	iy,vars
;
		ld	hl,(vars.ticks)
		inc	hl
		ld	(vars.ticks),hl
;
		ld	hl,vars.status.ticks
		inc	(hl)
		jr	nz,.doneticks
;
		ld	(hl),status.DELAY
.doneticks:
;
		jp	dhcp.interrupt
;
;
;------------------------------------------------------------------------------
; ftp_open
;
; In:  DE->filename, length byte first. Could be zero length. Uppercase.
;       C=unit number
ftp_open:
		push	de		; Save->filename
		 ld	de,ftp.ftp_channel	; Allocate our channel RAM
		 EXOS	exos.FN_BUFF
		pop	de		; DE->filename
		ret	nz
;
		ld	a,1		; Socket 1
		jp	ftp.device_open
;
;
;------------------------------------------------------------------------------
; ftp_create
;
; In:  DE->filename, length byte first. Could be zero length. Uppercase.
;       C=unit number
ftp_create:
		push	de		; Save->filename
		 ld	de,ftp.ftp_channel	; Allocate our channel RAM
		 EXOS	exos.FN_BUFF
		pop	de		; DE->filename
		ret	nz
;
		ld	a,1		; Socket 1
		jp	ftp.device_create
;
;
;------------------------------------------------------------------------------
; ftp_close
;
ftp_close:
		ld	a,1		; Socket 1
		jp	ftp.device_close
;
;
;------------------------------------------------------------------------------
; ftp_read_byte
;
ftp_read_byte:
		ld	a,1		; Socket 1
		jp	ftp.device_read_byte
;
;
;------------------------------------------------------------------------------
; read_block
;
; In:  DE->buffer within user's paging
;      BC=byte count, could be 0
; Out: 
ftp_read_block:
		ld	a,1		; Socket 1
		jp	ftp.device_read_block
;
;
;------------------------------------------------------------------------------
; write_byte
;
ftp_write_byte:
		ld	a,1		; Socket 1
		jp	ftp.device_write_byte
;
;
;------------------------------------------------------------------------------
; write_block
;
; In:  DE->buffer within user's paging
;      BC=byte count, could be 0
ftp_write_block:
		ld	a,1		; Socket 1
		jp	ftp.device_write_block
;
;
;------------------------------------------------------------------------------
; read_status
;
ftp_read_status:
		ld	a,1		; Socket 1
		jp	ftp.device_status
;
;
;==============================================================================
; TCP DEVICE
;
; The TCP device allows an EXOS user to eg OPEN #42:"TCP:192.168.1.100:666"
; to open a TCP link to the specified IP address and port.
;
		dw	http_descriptor-8000h	; XX_NEXT Next device in P1
		dw	-2		; XX_RAM	No RAM required
tcp_type:	db	0		; DD_TYPE
		db	00h		; DD_IRQFLAG (50Hz)
		db	0		; DD_FLAGS
		dw	tcp_entry-8000h	; DD_TAB in page 1
		db	0		; DD_TAB_SEG
		db	0		; DD_UNIT_COUNT
		db	3,"TCP"		; DD_NAME
tcp_descriptor:	db	$-tcp_type	; XX_SIZE
;
tcp_entry:	dw	interrupt
		dw	tcp_open
		dw	tcp_create
		dw	close
		dw	close		; destroy
		dw	read_byte
		dw	read_block
		dw	write_byte
		dw	write_block
		dw	read_status
		dw	write_status
		dw	special
		dw	init
		dw	moved
;
;
TCP_SOCKET	equ	2
;
;
;------------------------------------------------------------------------------
;
; tcp_open
;
; In:  DE->filename, length byte first. Could be zero length. Uppercase.
;       C=unit number
tcp_open:
		push	iy
		 ld	iy,vars
;
		 push	de		; Save->filename
		  ld	de,channel	; Channel RAM required
		  EXOS	exos.FN_BUFF
		 pop	de		; DE->filename
		 jr	nz,.ret
;
		 ld	hl,vars.device.ip
		 call	util.get_ip_port; HL=port, vars.device.ip filled in
		 sbc	a,a
		 and	exos.ERR_BADIP
		 jr	nz,.ret
;
		 push	hl		; Save dest port
		  ld	a,TCP_SOCKET
		  ld	(ix-1-channel.socket),a
		  ld	hl,42		; Source port
		  ld	de,tcp_owner_str; Our name
		  call	tcp.open
		 pop	hl		; HL=dest port
		 ld	de,vars.device.ip; DE->ip address
		 ld	a,TCP_SOCKET
		 call	nc,tcp.connect
		 sbc	a,a
		 and	exos.ERR_NOCON
;
.ret:		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; tcp_create
;
; In:  DE->filename, length byte first. Could be zero length. Uppercase.
;       C=unit number
tcp_create:
		push	de		; Save->filename
		 ld	de,channel	; Channel RAM required
		 EXOS	exos.FN_BUFF
		pop	de		; DE->filename
		ret	nz
;
		ld	(ix-1-channel.socket),TCP_SOCKET
		ret
;
;
;==============================================================================
; HTTP DEVICE
;
; The HTTP device allows an EXOS user to eg OPEN #42:"HTTP:192.168.1.100/file"
; to open a TCP link to the specified IP address and read the file.
;
		dw	0		; XX_NEXT 0=>no more devices in ROM
		dw	-2		; XX_RAM	No RAM required
http_type:	db	0		; DD_TYPE
		db	00h		; DD_IRQFLAG (50Hz)
		db	0		; DD_FLAGS
		dw	http_entry-8000h; DD_TAB in page 1
		db	0		; DD_TAB_SEG
		db	0		; DD_UNIT_COUNT
		db	4,"HTTP"	; DD_NAME
http_descriptor:db	$-http_type	; XX_SIZE
;
http_entry:	dw	interrupt
		dw	http_open
		dw	nofn		; Create
		dw	close
		dw	close		; Destroy
		dw	read_byte
		dw	read_block
		dw	nofn		; write_byte
		dw	nofn		; write_block
		dw	read_status
		dw	write_status
		dw	special
		dw	init
		dw	moved
;
;
;------------------------------------------------------------------------------
;
; http_open
;
; In:  DE->filename, length byte first. Could be zero length. Uppercase.
;       C=unit number
http_open:
		push	iy
		 ld	iy,vars
;
		 push	de		; Save->filename
		  ld	de,http.http_channel	; Channel RAM required
		  EXOS	exos.FN_BUFF
		 pop	de		; DE->filename
		 jr	nz,.ret
;
		 ; First skip leading /s to allow HTTP://...
		 ld	a,(de)		; Get length byte
		 ld	b,a		; B=length byte
		 inc	b		; To skip initial dec b
.slash.loop:	 dec	b
		 jr	z,.slash.done
;
		 inc	de
		 ld	a,(de)
		 cp	'/'
		 jr	z,.slash.loop
		 cp	"\\"
		 jr	z,.slash.loop
;
		 ; Save host name in vars.device.host
.slash.done:	 push	de		; Save->URL
		 push	bc		; Save length in B
		  ld	hl,vars.device.host	; Copy host name to here
		  inc	b
		  jr	.host.djnz

.host.loop:	  ld	a,(de)
		  inc	de
		  cp	'/'
		  jr	z,.host.done
		  cp	"\\"
		  jr	z,.host.done
;
		  ld	(hl),a
		  inc	hl
.host.djnz:	  djnz	.host.loop
;
		  ;inc	b
.host.done:	  ;dec	b		; Skip /
		  ld	(hl),0		; Null-terminate host name
		 pop	bc		; B=length of URL
		 pop	de		; DE->URL
;
		 ld	hl,vars.device.ip	; Read IP address to here
		 call	util._get_ip	; vars.device.ip=IP; DE->filename, B=len
		 sbc	a,a
		 and	exos.ERR_BADIP
		 jr	nz,.ret
;
		 call	http.device_open
;
.ret:		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; http_create
;
; In:  DE->filename, length byte first. Could be zero length. Uppercase.
;       C=unit number
http_create:
		ld	a,exos.ERR_NOFN
		ret
;
;
;==============================================================================
; GENERAL DEVICE ROUTINES
;
; The follwoing routines are general EXOS device routines suitable for most
; of the EXOS devices we implement. But some devices may require different
; routines eg. FTP: close closes the FTP data channel, not the control channel.
;
; The socket number is saved in the first byte of channel RAM at (ix-1) which
; allows different devies to use common same code.
;
;
; block
;
; This function implements a device's read_block and write_block.
;	
; DE points to the user's buffer. The buffer could cross segment boundaries so
; we must split the read/write up into chunks and use the user's paging which is
; stored in EXOS's variable area. It could also be an odd number of bytes
; in length which is a pain for the 16-bit WIZ chip. In fact even if it's
; even in length, it could be an odd number of bytes to the end of the segment.
;
; Here the main loop just does the splitting up of the block into
; single-segment reads/writes. We leave it to the TCP code to handle odd
; lengths, multiple TCP fragments and flushing any final odd byte.
;
; In:  IX->EXOS channel RAM, channel.socket=socket number
;      HL->tcp.read_block or tcp.write block
;      DE->user's buffer
;      BC=byte count
; Out: Cy=>error, A=return code (see tcp.read_block/tcb.write_block)
;
block:
		call	status.start	; Start activity indicator
;
.loop:
		ld	a,b	; See if byte count=0
		or	c
		jr	z,.ret	; All done!
;
		push	hl	; Save read/write func

		 ld	l,c
		 ld	h,b	; HL=user's byte count
		 ; Negating (2s-complement) a segment offset gives us the
		 ; remaining bytes to ffff; anding with 3f then gives us the
		 ; remaining bytes to end of segment
		 ld	a,e
		 cpl
		 ld	c,a
		 ld	a,d
		 cpl
		 and	3fh	; Turn pointer into seg offset
		 ld	b,a
		 inc	bc	; BC=amount left in segment, ie propsed read
;
		 or	a	; So deduct from user's total byte count
		 sbc	hl,bc	; HL=updated user's byte count after read
		 jr	nc,.bcok
;
		 add	hl,bc	; Oops it went -ve so get back user's remainder
		 ld	c,l
		 ld	b,h	; BC=user's remainder size to read
		 or	a
		 sbc	hl,hl	; User's byte count now 0
.bcok:
		; So now:
		; HL=updated user's byte count, 0 if none left to read
		; DE=user's buffer pointer not yet updated
		; BC=read size
		ex	(sp),hl	; HL->read/write function, (SP)=updated  count
		 push	de	; Save user's current pointer
		 push	bc	; Save amount we're about to read/write
;
		  ld	a,(ix-1-channel.socket)	; Get socket #
		  ex	af,af	; Save socket number in A'
		  in	a,(ep.P1); Save our page 1 as that's where we do the read
		  push	af
		   push	hl	; Save read/write func
		    ld	a,d	; Get user's buffer Hi
		    rlca
		    rlca
		    and	3	; A=z80 page 0-3
		    add	a,LOW exos.USR_P0
		    ld	l,a
		    ld	h,HIGH exos.USR_P0	; HL->user's page in EXOS var
		    ld	a,(hl)
		    out	(ep.P1),a; Put user's page corresponding to (DE) into P1
		    ld	a,d	; Adjust user's pointer to be a P1 pointer
		    and	3fh
		    or	40h
		    ld	d,a
		   pop	hl	; HL->read or write func
;
		   ; So now:
		   ; User's buffer is paged into page 1
		   ; DE->user's buffer adjusted to point in page 1
		   ; BC=amount to read
		   ; HL->read/write func to call
		   ld	a,b
		   or	c
		   push	hl	; Save read/write func
		    jr	z,.skipjphl
		    ex	af,af	; Get back socket in A
		    call jphl	; Read/write it
.skipjphl:	    ex	af,af	; Save error code
		   pop	de	; DE=read/write func
		  pop	af	; A=our P1
		  out	(ep.P1),a	; Restore our paging
;
		 pop	bc	; BC=amount just read
		 pop	hl	; HL=user's buffer
;
		 add	hl,bc	; Update user's pointer
		 ex	de,hl	; DE=updated user's buffer, HL=read/write func
		pop	bc	; BC=updated user's byte count
		ex	af,af	; Get back error code
		jr	nc,.loop
;
.ret:		push	af
	 	 call	status.stop		; Stop activity indicator
		pop	af
		ret
;
;
;------------------------------------------------------------------------------
; read_byte
;
read_byte:
		push	iy
		 ld	iy,vars
;
		 call	status.start		; Start activity indicator
;
		 ld	de,vars.device.byte	; 1 byte buffer
		 ld	bc,1			; Read 1 byte
		 ld	a,(ix-1-channel.socket)	; Get socket #
		 call	tcp.read_block		; Read 1 byte
		 ld	b,(iy+vars.device._byte); Return 1 byte in B
;
		 jr	read_ret
;
;
;------------------------------------------------------------------------------
; read_block
;
; In:  DE->buffer within user's paging
;      BC=byte count, could be 0
; Out: 
read_block:
		push	iy
		 ld	iy,vars
;
		 call	status.start	; Start activity indicator
;
		 ld	hl,tcp.read_block
		 call	block
;
read_ret:	 push	af
	 	  call	status.stop		; Stop activity indicator
		 pop	af
;
		pop	iy
		ret	nc
;
		sub	2
		ld	a,exos.ERR_EOF
		ret	m		; Code 1=>socket closed
;
		ld	a,exos.ERR_STOP
		ret	z		; Code 2=>STOP pressed
;
		ld	a,exos.ERR_TIMEOUT	; Code 3=>timeout
		ret
;;
;
;------------------------------------------------------------------------------
; write_byte
;
write_byte:
		push	iy
		 ld	iy,vars
;
		 call	status.start	; Start activity indicator
;
		 ld	de,vars.device.byte	; 1 byte buffer
		 ld	a,b
		 ld	(de),a
		 ld	bc,1
		 ld	a,(ix-1-channel.socket)	; Get socket #
		 call	tcp.write_block		; Write 1 byte
		 ld	a,(ix-1-channel.socket)	; Get socket #
		 call	nc,tcp.send
		 jr	writeret
;;
;
;------------------------------------------------------------------------------
; write_block
;
; In:  DE->buffer within user's paging
;      BC=byte count, could be 0
write_block:
		push	iy
		 ld	iy,vars
;
		 call	status.start	; Start activity indicator
;
		 ld	hl,tcp.write_block
		 call	block
		 ld	a,(ix-1-channel.socket)	; Get socket #
		 call	nc,tcp.send
;
writeret:	 sbc	a,a			; Cy->FF, NC->0
		 and	exos.ERR_TIMEOUT	; Cy->error code, 0 if no error
		 ret	nz
;
		 push	af
	 	  call	status.stop		; Stop activity indicator
		 pop	af
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; read_status
;
read_status:
		push	iy
		 ld	iy,vars
;
		 ld	a,(ix-1-channel.socket)	; Get socket #
		 call	tcp.status
		 ld	c,a		; 0=>char ready, FF=>EOF, 1=>no char
		 xor	a		; No error
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; write_status
;
write_status:
nofn:
		ld	a,exos.ERR_NOFN
		ret
;
;
;------------------------------------------------------------------------------
; special
;
special:
		ld	a,exos.ERR_NOFN
		ret
;
;
;------------------------------------------------------------------------------
; init
;
init:		xor	a
		ld	(vars.init),a		; Pretend not initialised
		ret
;
;
;------------------------------------------------------------------------------
; moved
;
moved:
interrupt:
		ret
;
;
;------------------------------------------------------------------------------
; close
;
close:
		push	iy
		 ld	iy,vars
;		 
		 call	status.start
;
		 ld	a,(ix-1-channel.socket)	; Get socket #
		 call	tcp.close	; Close it
;
		 call	status.stop
;
		 xor	a		; No error
		pop	iy
		ret
;
;
tcp_owner_str:	db	"TCP:"
;
;
;
		endmodule
