; DEVICE
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
; This is the data kept in EXOS device RAM.
;
; EXOS device RAM is accessed at (iy-4), (iy-5)...etc so our data here
; is accessed with (iy-4-<item>) eg (iy-4-device.seg)
;
		struct	device		; Variables in EXOS device RAM
seg		 byte			; Segment no. of our variables
		ends
;
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
		dw	-2-device	; XX_RAM
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
ftp_interrupt:	ld	a,(iy-4-device.seg)	; Get our variable's segment
		or	a
		ret	z
;
		out	(ep.P1),a		; Page it in
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
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
		 call	dhcp.interrupt
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; ftp_open
;
; In:  DE->filename, length byte first. Could be zero length. Uppercase.
;       C=unit number
;
ftp_open:
		ld	hl,ftp.ftp_channel	; Allocate our channel RAM
		xor	a		; No value for channel.socket yet
		call	opencreate
		ret	nz
;
		push	iy
		 ld	iy,vars		; Point IY at variables as usual
;
		 ld	a,1		; Socket 1
		 call	ftp.device_open
;
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; ftp_create
;
; In:  DE->filename, length byte first. Could be zero length. Uppercase.
;       C=unit number
;
ftp_create:
		ld	hl,ftp.ftp_channel	; Allocate our channel RAM
		xor	a		; No value for channel.socket yet
		call	opencreate
		ret	nz
;
		push	iy
		 ld	iy,vars		; Point IY at variables as usual
;
		 ld	a,1		; Socket 1
		 call	ftp.device_create
;
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; ftp_close
;
ftp_close:
		call	entry
;
		push	iy
		 ld	iy,vars		; Point IY at variables as usual
;
		 ld	a,1		; Socket 1
		 call	ftp.device_close
;
		exx
		out	(c),l		; Restore EXOS's paging
		exx
;
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; ftp_read_byte
;
ftp_read_byte:
		call	entry
;
		push	iy
		 ld	iy,vars		; Point IY at variables as usual
;
		 ld	a,1		; Socket 1
		 call	ftp.device_read_byte
;
		exx
		out	(c),l		; Restore EXOS's paging
		exx
;
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; read_block
;
; In:  DE->buffer within user's paging
;      BC=byte count, could be 0
; Out: 
;
ftp_read_block:
		call	entry
;
		push	iy
		 ld	iy,vars		; Point IY at variables as usual
;
		 ld	a,1		; Socket 1
		 call	ftp.device_read_block
;
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; write_byte
;
ftp_write_byte:
		call	entry
;
		push	iy
		 ld	iy,vars		; Point IY at variables as usual
;
		 ld	a,1		; Socket 1
		 call	ftp.device_write_byte
;
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; write_block
;
; In:  DE->buffer within user's paging
;      BC=byte count, could be 0
;
ftp_write_block:
		call	entry
;
		push	iy
		 ld	iy,vars		; Point IY at variables as usual
;
		 ld	a,1		; Socket 1
		 call	ftp.device_write_block
;
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; read_status
;
ftp_read_status:
		call	entry
;
		push	iy
		 ld	iy,vars		; Point IY at variables as usual
;
		 ld	a,1		; Socket 1
		 call	ftp.device_status
;
		pop	iy
		ret
;
;
;==============================================================================
; TCP DEVICE
;
; The TCP device allows an EXOS user to eg OPEN #42:"TCP:192.168.1.100:666"
; to open a TCP link to the specified IP address and port.
;
		dw	http_descriptor-8000h	; XX_NEXT Next device in P1
		dw	-2-device	; XX_RAM
tcp_type:	db	0		; DD_TYPE
		db	0		; DD_IRQFLAG
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
;
tcp_open:
		ld	hl,channel	; Channel RAM required
		ld	a,TCP_SOCKET	; Value for channel.socket
		call	opencreate
		ret	nz
;
		push	iy
		 ld	iy,vars		; Point IY at variables as usual
;
		 ld	hl,vars.device.ip
		 call	util.get_ip_port; HL=port, vars.device.ip filled in
		 sbc	a,a
		 and	exos.ERR_BADIP
		 jr	nz,.ret
;
		 push	hl		; Save dest port
		  ld	a,TCP_SOCKET
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
		ld	hl,channel	; Channel RAM required
		ld	a,TCP_SOCKET	; Value for channel.socket
		call	opencreate
		ret	nz
;
		push	iy
		 ld	iy,vars		; Point IY at variables as usual
;
		; !!! Code for create here ? !!!!
 ld a,1

		xor	a
		pop	iy
		ret
;
;
;==============================================================================
; HTTP DEVICE
;
; The HTTP device allows an EXOS user to eg OPEN #42:"HTTP:192.168.1.100/file"
; to open a TCP link to the specified IP address and read the file.
;
 DW 0
;		dw	mem_descriptor-8000h; XX_NEXT 0=>no more devices in ROM
		dw	-2-device	; XX_RAM
http_type:	db	0		; DD_TYPE
		db	0		; DD_IRQFLAG
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
		ld	hl,http.http_channel	; Channel RAM required
		call	opencreate
		ret	nz
;
		push	iy
		 ld	iy,vars		; Point IY at variables as usual
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
.slash.done:	 push	de		; Save->host/filename name
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
		 pop	bc		; B=length of host/filename
		 pop	de		; DE->host/filename
;
		 ld	hl,vars.device.ip	; Read IP address to here
		 call	util._get_ip	; vars.device.ip=IP; DE->filename, B=len
		 sbc	a,a
		 and	exos.ERR_BADIP
		 call	z,http.device_open
;
		pop	iy
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
/*
;==============================================================================
; MEM DEVICE
;
; The MEM: device allows temporary buffering in memory.
;
; The "filename" during create is the buffer size which is then allocated.
; Writes then just go to the allocated memory
; Open opens the memory file for reading
; Close closes it but does not free the memory - it can be opened again
; Destroy or a create filename of 0 frees the memory
;
		dw	0		; XX_NEXT Next device in P1
		dw	-2-device	; XX_RAM
mem_type:	db	0		; DD_TYPE
		db	0		; DD_IRQFLAG
		db	0		; DD_FLAGS
		dw	mem_entry-8000h	; DD_TAB in page 1
		db	0		; DD_TAB_SEG
		db	0		; DD_UNIT_COUNT
		db	3,"MEM"		; DD_NAME
mem_descriptor:	db	$-mem_type	; XX_SIZE
;
mem_entry:	dw	interrupt
		dw	mem_open
		dw	mem_create
		dw	mem_close
		dw	mem_destroy	; destroy
		dw	mem_read_byte
		dw	mem_read_block
		dw	mem_write_byte
		dw	mem_write_block
		dw	mem_read_status
		dw	write_status
		dw	mem_special
		dw	init
		dw	moved
;
;
;------------------------------------------------------------------------------
;
; mem_open
;
; In:  DE->filename, length byte first. Could be zero length. Uppercase.
;       C=unit number
;
mem_open:
		ld	a,(iy-4-device.seg)	; Get our variable's segment
		out	(ep.P1),a		; Page it in
;
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
		 or	a
		 sbc	hl,hl		; HL=0
		 ld	(vars.mem.rd),hl; Initial read pos = 0
;
		 ex	de,hl		; DE=0 (no channel RAM required)
		 EXOS	exos.FN_BUFF
;
.ret:		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; mem_create
;
; In:  DE->filename, length byte first. Could be zero length. Uppercase.
;       C=unit number
;
mem_create:
		ld	a,(iy-4-device.seg)	; Get our variable's segment
		out	(ep.P1),a		; Page it in
;
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
		 call	free_seg
		 jr	nz,.ret
;
		 EXOS	exos.FN_ALLOC	; Allocate a segment
		 jr	nz,.ret		; Go if error
;
.gotseg:	 ld	a,c		; A=allocated segment
		 ld	(vars.mem.seg),a; Save it
		 or	a
		 sbc	hl,hl		; HL=0
		 ld	(vars.mem.rd),hl; Initial pos = 0
		 ld	(vars.mem.wr),hl; Initial pos = 0
;
.ret:		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; mem_close
;
; If it's been open for writing, we don't free up our buffer memory.
; But if it's been open for reading, we do.
;
mem_close:
		ld	a,(iy-4-device.seg)	; Get our variable's segment
		out	(ep.P1),a		; Page it in
;
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
		 ld	hl,(vars.mem.rd); See if read pos is non-zero
		 ld	a,h
		 or	l
		 call	nz,free_seg	; Free seg once it's been read
;
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; mem_destroy
;
mem_destroy:
		ld	a,(iy-4-device.seg)	; Get our variable's segment
		out	(ep.P1),a		; Page it in
;
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
		 ld	a,(vars.mem.seg); See if any currently allocated seg
		 or	a
		 jr	z,.ret		; Go with A=0 if not
;
		 ld	c,a		; C=segment to free
		 EXOS	exos.FN_FREE	; Free it

.ret:		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; mem_read_byte
;
mem_read_byte:
		ld	a,(iy-4-device.seg)	; Get our variable's segment
		out	(ep.P1),a		; Page it in
;
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
		 call	have_seg		; See if we have a seg allocated
		 jr	nz,.ret			; Return error if not
;
		 call	next_read		; HL->current read pos
		 jr	nc,.ret			; Return if no more to read
;
		 set	6,h			; Make P1 pointer
		 ld	a,(vars.mem.seg)	; Get our segment
		 out	(ep.P1),a		; Put in page 1
		 ld	b,(hl)			; Get byte
		 xor 	a			; No error
;
.ret:		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; mem_read_block
;
mem_read_block:
		ld	a,(iy-4-device.seg)	; Get our variable's segment
		out	(ep.P1),a		; Page it in
;
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
		 call	have_seg		; See if we have a seg allocated
		 jr	nz,.ret			; Return error if not
;
		 jr	.ztest
;
.loop:		 push	de			; Save -> user buffer
		  call	next_read		; HL->current read pos
		 pop	de			; DE->user's buffer
		 jr	nc,.ret			; Go if no more to read
;
		 ld	a,(vars.mem.seg)	; Get our segment
		 out	(ep.P1),a		; Page it in to page 1
		 set	6,h			; Turn into P1 pointer
		 ld	a,(hl)			; A=byte from mem buffer
;
		 push	de			; Save -> user's buffer
		  push	af			; Save byte from mem buffer
		   call	users_page
		  pop	af			; A=byte from mem buffer
		  ld	(de),a			; Write to user's buffer
		 pop	de			; DE->user's buffer
		 inc	de			; Next buffer pos next time
		 dec	bc			; Done another byte
.ztest:		 ld	a,b			; Any more to do?
		 or	c
		 jr	nz,.loop		; Repeat if yes
;
.ret:		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; mem_write_byte
;
mem_write_byte:
		ld	a,(iy-4-device.seg)	; Get our variable's segment
		out	(ep.P1),a		; Page it in
;
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
		 call	have_seg		; See if we have a seg allocated
		 jr	nz,.ret			; Return error if not
;
		 call	next_write
		 jr	nz,.ret
;
		 set	6,h			; Make a P1 pointer
		 ld	a,(vars.mem.seg)	; Get our segment
		 out	(ep.P1),a		; Page it in
		 ld	(hl),b			; Write byte
		 xor 	a			; No error
;
.ret:		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; mem_write_block
;
mem_write_block:
		ld	a,(iy-4-device.seg)	; Get our variable's segment
		out	(ep.P1),a		; Page it in
;
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
		 call	have_seg		; See if we have a seg allocated
		 jr	nz,.ret			; Return error if not

		 jr	.ztest
;
.loop:		 call	next_write
		 jr	nz,.ret			; Return with error if yes
;
		 push	de			; Save -> user's buffer
		 push	hl			; Save -> our buffer
		  call	users_page
		  ld	a,(de)			; A=byte from user's buffer
		 pop	hl			; HL->our buffer
		 pop	de			; DE->user's buffer
		 inc	de			; Next pos next time
;
		 push	af			; Save byte from user's buffer
		  ld	a,(vars.mem.seg)	; Get our segment
		  out	(ep.P1),a		; Page it in to page 1
		  set	6,h			; Turn into P1 pointer
		 pop	af			; A=byte from user's buffer
		 ld	(hl),a			; Put in our buffer
;
		 dec	bc			; Done another byte
.ztest:		 ld	a,b			; Any more to do?
		 or	c
		 jr	nz,.loop		; Repeat if yes
;
		push	de
.popret:	pop	de
.ret:
popiyret:	pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; mem_read_status
;
mem_read_status:
		ld	a,(iy-4-device.seg)	; Get our variable's segment
		out	(ep.P1),a		; Page it in
;
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
		 call	have_seg		; See if we have a seg allocated
		 jr	nz,popiyret		; Return error if not
;
		 ld	de,(vars.mem.wr)	; DE->end of buffer
		 ld	hl,(vars.mem.rd)	; HL->current read pos
		 inc	hl			; Next pos
		 xor	a
		 sbc	hl,de			; NC=>next pos = buffer end
		 ccf				; Cy=>next pos = buffer end
		 sbc	a,a			; FF=>next pos = end, else 0
		 ld	c,a			; C=ff => end of file, 0=>ready
;
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; mem_special
;
mem_special:
		ld	a,(iy-4-device.seg)	; Get our variable's segment
		out	(ep.P1),a		; Page it in
;
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
		 ld	a,b		; Get sub-function
		 cp	exos.FN_MEM_SEG	; Our get segment fn?
		 ld	a,exos.ERR_ISPEC
		 jr	nz,.ret		; Return with error if not
;
		 ld	a,(vars.mem.seg); Get segment
		 ld	c,a		; Return in C
		 ld	de,(vars.mem.rd); Return DE->current read pos
;
		 xor	a		; No error
;
.ret:		pop	iy
		ret
;
;
;-----------------------------------------------
; users_page
;
; Takes a user's pointer in DE and turns it into a page 1 pointer with the
; currect page paged into page 1
;
; In:  DE->user's buffer anyhere in Z80 space
; Out: DE->page 1
;      P1=user's segment corresponding to original DE
;
users_page:
		ld	a,d			; A=high byte of user's buffer
		rlca
		rlca
		and	3			; A=Z80 page 0-3
		add	a,LOW exos.USR_P0
		ld	l,a
		ld	h,HIGH exos.USR_P0	; HL->user's page in EXOS var
		ld	a,(hl)			; Get user's segment
		out	(ep.P1),a		; Page it into page 1
		res	7,d			; Adjust user's pointer to P1
		set	6,d
		ret
;
;
;-----------------------------------------------
; Returns NC and error code in A if there's no more to read, else
; vars.mem.read has been updated and HL->current byte
;
next_read:	ld	de,(vars.mem.wr)	; DE->end of buffer
		ld	hl,(vars.mem.rd)	; HL->current read pos
		inc	hl			; Next pos
		or	a
		sbc	hl,de			; See if next pos = buffer end
		ld	a,exos.ERR_EOF
		ret	nc
;
		add	hl,de			; HL->next read pos
		ld	(vars.mem.rd),hl	; Save for next time
		dec	hl			; HL->back to current read pos
		scf				; No error
		ret
;
;
;-----------------------------------------------
; Increments the write pos but returns NZ and error code in A if no more
; room in buffer
;
next_write:
		ld	hl,(vars.mem.wr)	; HL->current end of buffer
		inc	hl			; HL->next pos
		bit	6,h			; See if overflowed segment
		ld	a,exos.ERR_MEMFULL
		ret	nz			; Return with error if yes
;
		ld	(vars.mem.wr),hl	; Save new pos
		dec	hl			; HL->back to current pos
		xor	a
		ret
;
;
;-----------------------------------------------
have_seg:
		ld	a,(vars.mem.seg); See if any currently allocated seg
		sub	1		; Cy=>was 0, else NC
		sbc	a,a		; FF=>was 0, else 0
		and	exos.ERR_NOMEM	; Error code or 0, NZ or Z
		ret
;
;
;-----------------------------------------------
free_seg:	ld	hl,vars.mem.seg
		ld	a,(hl)		; A=segment to free
		or	a
		ret	z		; Ret if we didn't have a seg
;		 
		ld	c,a		; C=segment to free
		ld	(hl),0		; Haven't got a seg any more
		EXOS	exos.FN_FREE	; Free it
		ret
;
*/
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
;------------------------------------------------------------------------------
; opencreate
;
; This is called from the devices's open and create. It allocates the channel
; RAM and sets up the paging registers appropriately.
;
; In:  HL=amount of channel RAM required
;      DE->filename, as per EXOS entry point
;       A=value for channel.socket once RAM allocated
; Out: NZ=>error
;
opencreate:
		push	af		; Save channel.socket value
		 ld	a,(iy-4-device.seg)	; Get our variable's segment
;
		 exx
		 ld	b,a		; B' always=our RAM seg
		 ld	e,a		; socket.asm seg
		 ld	d,a		; tcp.asm seg
		 ld	c,ep.P1		; C' always ->P1
		 exx
;
		 ex	de,hl		; DE=channel RAM required; HL->filename
		 EXOS	exos.FN_BUFF
		 ex	de,hl		; DE->filename
;
		pop	bc		; B=channel.socket value
		ld	(ix-1-channel.socket),b	; Save socket while paged in
;
		exx
		in	l,(c)		; Get our channel RAM page
		out	(c),b		; Page in our variables seg
		exx
		or	a		; Set Z according to error
		ret
;
;
;------------------------------------------------------------------------------
; entry
;
; This is called from all the devices's entry points except open/create. It
; sets up the paging registers appropriately.
;
; In:  As per EXOS entry registers
; Out: A=channel.socket
;
entry:
		ld	a,(iy-4-device.seg)	; Get our variable's segment
;
		exx
		ld	b,a		; B' always=our RAM seg
		ld	c,ep.P1		; C' always ->P1
		ld	a,(ix-1-channel.socket); Get socket while paged in
		in	l,(c)		; L' always channel RAM page
		out	(c),b		; Page in our seg
		ld	e,b		; socket.asm seg
		ld	d,b		; tcp.asm seg
		exx
		ret
;
;
;------------------------------------------------------------------------------
; read_byte
;
read_byte:
		call	entry
;		
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
		 push	af			; Save socket #
		  call	status.start		; Start activity indicator
		 pop	af			; A=socket number
;
		 ld	de,vars.device.byte	; 1 byte buffer
		 ld	bc,1			; Read 1 byte
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
		call	entry
;
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
		 push	af			; Save socket number
		  call	status.start		; Start activity indicator
		 pop	af			; A=socket number
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
		call	entry
;
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
		 push	af			; Save socket number
		  call	status.start		; Start activity indicator
;
		  ld	de,vars.device.byte	; 1 byte buffer
		  ld	a,b
		  ld	(de),a
		  ld	bc,1
		 pop	af			; Get socket #
;
		 push	af			; Save socket # again
		  call	tcp.write_block		; Write 1 byte
		 pop	bc			; B=socket number
		 ld	a,b			; A=socket number but F unchnaged
;
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
		call	entry
;
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
		 push	af			; Save socket number
		  call	status.start		; Start activity indicator
		 pop	af			; A=soclet number
;
		 push	af			; Save socket number
		  ld	hl,tcp.write_block
		  call	block
		 pop	bc			; B=socket number
		 ld	a,b			; A=socket number, F unchanged
;
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
		call	entry
;
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
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
; close
;
close:
		call	entry
;
		push	iy
		 ld	iy,vars			; Point IY at variables as usual
;
		 push	af			; Save socket number
		  call	status.start		; Start activity indicator
		 pop	af			; A=socket number
;
		 call	tcp.close	; Close it
;
		 call	status.stop
;
		 xor	a		; No error
		pop	iy
		ret
;
;
;------------------------------------------------------------------------------
; block
;
; This routine implements a device's read_block and write_block.
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
; In:  HL->tcp.read_block or tcp.write block
;      DE->user's buffer
;      BC=byte count
;       A=socket number
; Out: Cy=>error, A=return code (see tcp.read_block/tcb.write_block)
;
block:
		ex	af,af		; Save socket in A'
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
		; (sp)=read/write func
		ex	(sp),hl	; HL->read/write function, (SP)=updated  count
		 push	de	; Save user's current pointer
		 push	bc	; Save amount we're about to read/write
;
		  push	hl	; Save read/write func
		   ld	a,d	; Get user's buffer Hi
		   rlca
		   rlca
		   and	3	; A=z80 page 0-3
		   add	a,LOW exos.USR_P0
		   ld	l,a
		   ld	h,HIGH exos.USR_P0	; HL->user's seg in EXOS var
		   ld	a,(hl)	; Get user's seg
		   exx
		   ld	d,a	; Save user's seg for tcp.xxx routine
		   exx
		   ld	a,d	; Adjust user's pointer to be a P1 pointer
		   and	3fh
		   or	40h
		   ld	d,a
		  pop	hl	; HL->read or write func
;
		  ; So now:
		  ; A'=socket number
		  ; D'=user's segment
		  ; DE->user's buffer adjusted to point in page 1
		  ; BC=amount to read
		  ; HL->read/write func to call
		  ld	a,b
		  or	c
		  push	hl	; Save read/write func
		   jr	z,.skipjphl
		   ex	af,af	; Get back socket in A
		   push	af
		   ex	af,af	; Save socket in A' again
		   pop	af	; A=socket number
		   call jphl	; Read/write it; AF=error code/flag
.skipjphl:	  pop	de	; DE=read/write func
		 pop	bc	; BC=amount just read
		 pop	hl	; HL=user's buffer
;
		 push	af	; Save error flag around add,hl,bc
		  add	hl,bc	; Update user's pointer
		 pop	af	; AF=error code/flag
		 ex	de,hl	; DE=updated user's buffer, HL=read/write func
		pop	bc	; BC=updated user's byte count
		jr	nc,.loop
;
.ret:		push	af
	 	 call	status.stop		; Stop activity indicator
		pop	af
		ret
;
;
;------------------------------------------------------------------------------
; init
;
; All the devices have this initialisation routine. If we do not know our
; RAM varaiables segment it must query the EXOS extension with a special
; : command to get it and store it in device RAM.
;
; EXOS enters here with IY pointing to our device descriptor.
;
init:
		ld	a,(iy-4-device.seg)	; Get our variables segment
		or	a
		ret	nz			; Return if we've already got it
;
		ld	de,command.special_str	; Issue special command
		EXOS	exos.FN_ROMS
		ret	nz			; Oh no - error!
		
		ld	(iy-4-device.seg),b	; Save variables seg
;
		ld	a,b
		out	(ep.P1),a		; Page our variables in
;
		xor	a
		ld	(vars.init),a		; Not initialised
;
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
tcp_owner_str:	db	"TCP:"
;
;
;
		endmodule
