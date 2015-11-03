; WIZ
;
; Basic functions for accessing and initialising the WIZ module
;
		module wiz
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
SOCKETS		equ	8
;
;
;------------------------------------------------------------------------------
; read_reg
;
; Reads a 16-bit wiz register. socket.asm contains an equivalent routine for
; reading a per-socket wiz register.
;
; In:  DE: W5300 register
; Out: HL=value read
;      B,DE preserved
;
read_reg:	ld	c,(iy+vars._io)	; Address Register H
;
		out	(c),d
		inc	c		; Address Register L
;
		out	(c),e
		inc	c		; Data register H
;
		in	h,(c)
		inc	c		; Data Register L
;
		in	l,(c)
;
		ret
;
;
;------------------------------------------------------------------------------
; write_reg
;
; Writes a 16-bit value to a wiz register. socket.asm contains an equivalent
; routine for writing to a per-socket wiz register.
;
; In:  DE: W5300 register
;      HL: value to write
;      B,DE preserved
;
write_reg:	ld	c,(iy+vars._io)	; Address Register H
;
		out	(c),d
		inc	c		; Address Register L
;
		out	(c),e
		inc	c		; Data register H
;
		out	(c),h
		inc	c		; Data register L
;
		out	(c),l
;
		ret
;
;
;------------------------------------------------------------------------------
; write_IP, write_MAC
;
; Reads a MAC/IP address from/to 3/2 successive WIZ registers
;
; In:  HL->MAC/IP address
;      DE=WIZ register
; Out: BC and all input registers corrupted
;
write_IP:	ld	b,4
		jr	writeloop
;
write_MAC:
		ld	b,6
writeloop:	ld	c,(iy+vars._io)	; Address Register H
;
		out	(c),d
		inc	c		; Address Register L
;
		out	(c),e
		inc	c		; Returnn pointing to data reg
;
		inc	e		; Next register next time
		inc	e
;
		outi
		inc	c
;
		outi
;
		jr	nz,writeloop
;
		ret
;
;
;------------------------------------------------------------------------------
; read_IP, read_MAC
;
; In:  HL->MAC/IP address
;      DE=WIZ register
; Out: BC and all input registers corrupted
;
read_IP:	ld	b,4
		jr	readloop
;
read_MAC:	ld	b,6
readloop:	ld	c,(iy+vars._io)	; Address Register H
;
		out	(c),d
		inc	c		; Address Register L
;
		out	(c),e
		inc	c		; Returnn pointing to data reg
;
		inc	e		; Next register next time
		inc	e

		ini
		inc	c
;
		ini
;
		jr	nz,readloop
;
		ret
;
;
;------------------------------------------------------------------------------
; init_mem
;
; Set up w5300 memory partitioning to 8k for receive and transmit for each
; socket. Although the documentation says this is the default, all source
; code I have seen does this and a WIZNET reply to a WIZNET forum post
; suggests that this is necessary anyway
;
init_mem:
		ld	hl,0808h
;
		ld	de,w5300.TMS01R	; Set up tx memory
		call	.write_x4
;
		ld	de,w5300.RMS01R	; Repeat for rx memory
.write_x4:	
		call	.write_x2
.write_x2:	call	.write_x1
.write_x1:	call	write_reg
		inc	e
		inc	e		; Next reg
;
		ret
;
;
;------------------------------------------------------------------------------
; init
;
; Initialises the W5300.
;
; Once initialised, just returns without doing anything. But :NET DIAG needs
; to re-initialise, so it resets the initialized flags before calling
;
; Out: C set if error
;
init:
		; Set up WIZ indirect mode and reset
		or	a		; NC=>ok
		bit	vars.init.wiz,(iy+vars._init)
		ret	nz		; Already initialized, NC
;
		xor	a
		ld	(vars.init),a	; Nothing initialised yet
;
		ld	de,trace.diag.reset
		call	trace.diag.str
;
		ld	a,(io)		; Get fixed ROM i/o address byte
		or	a		; Using fixed i/o?
		jr	nz,.gotio	; <>0 => yes
;
		in	a,(ep.P3)	; Else get our ROM seg no
		rrca			; /2 gives i/o base address
.gotio:		inc	a
		inc	a
		ld	(vars.io),a	; For efficiency we save the i/o+2
;
		dec	a
		dec	a
		push	af		; Save base i/o port
		 call	trace.diag.byte	; Print it
		 call	trace.diag.dots
		pop	af		; A=base i/o address
;
		ld	c,a		; C->w5300.MR0
		ld	a,w5300.MR0_WDF2 or w5300.MR0_WDF1 or w5300.MR0_WDF0
		out	(c),a		; Initialise mode register
;
		inc	c		; MR1
		ld	a,w5300.MR1_IND or w5300.MR1_RST
		out	(c),a		; Set up indirect mode & reset
;
		; Wait for at least 10mS for w5300's PLL to sync.
		call	delay

		ld	a,w5300.MR1_IND	; Make sure we're still in indirect mode
		out	(c),a
;
		; Clear Interrupt Mask Register (we don't use interrupts)
		ld	de,w5300.IMR
		ld	hl,0
		call	write_reg
;
		call	trace.diag.ok
;
		; Make sure we can read the ID
		ld	de,trace.diag.id
		call	trace.diag.str
		call	trace.diag.dots
;
		ld	de,w5300.IDR
		call	read_reg
;
		ld	a,h
		sub	53h		; Should get back 0x5300 for W5300
		jr	nz,.badid
;
		or	l
		jr	z,idok
;
.badid:		call	trace.diag.word
diagerr:	call	trace.diag.err
		scf			; :-(
		ret
;
diagtimeout:	ld	de,trace.diag.timeout
		call	trace.diag.str
		scf
		ret
;
idok:		call	trace.diag.ok
;
		call	init_mem	; Set up WIZ memory partitioning
;
;
		; Do memory test of WIZ memory
		ld	de,trace.diag.memory
		call	trace.diag.str
;
		ld	de,w5300.MTYPER
		ld	hl,00ffh	; Top byte Rx, bottom Tx
		call	write_reg
;	
		ld	c,(iy+vars._io)
		dec	c		; C->w5300.MR1
		ld	a,w5300.MR1_IND or w5300.MR1_MT
		out	(c),a		; Set up indirect mode & mem test
;
		ld	de,w5300.SOCKET0+w5300.Sn_MR
		ld	hl,w5300.Sn_MR_TCP	; Open socket 0 in TCP mode
		call	write_reg
;
		ld	de,w5300.SOCKET0+w5300.Sn_CR
		ld	hl,w5300.Sn_CR_OPEN
		call	write_reg	; Set OPEN command
;
		ld	e,w5300.Sn_SSR_INIT
		call	wait_SSR	; Wait for command to complete
		jr	c,diagtimeout
;

		; Now we test the WIZ memory but only in diag mode (for speed)
		bit	vars.trace.diag,(iy+vars._trace)
		jr	z,.finish	; NC
;
		; Now write test values to socket tx memory
		ld	hl,0		; Initial test value
		ld	bc,8192/2	; Word count
.wloop:		ld	de,w5300.SOCKET0+w5300.Sn_TX_FIFOR
		push	bc
		push	hl
		call	write_reg
		pop	hl
		pop	bc
		inc	h		; Test value next time
		inc	l
		dec	bc
		ld	a,b
		or	c
		jr	nz,.wloop
;
		; See if we can read them back
		ld	hl,0
		ld	bc,8192/2
.rloop:		ld	de,w5300.SOCKET0+w5300.Sn_TX_FIFOR
		push	bc
		push	hl
		call	read_reg
		pop	de
		pop	bc
		or	a
		sbc	hl,de
		jr	z,.rok
;
		add	hl,de		; DE=expected value, HL=actual
;
		push	bc
		push	de
		push	hl
		ld	de,trace.diag.memerr
		call	trace.diag.str
		pop	hl
		call	trace.diag.word	; Print actual
		ld	de,trace.diag.expected
		call	trace.diag.str
		pop	hl
		call	trace.diag.word	; Print expected
		ld	de,trace.diag.at
		call	trace.diag.str
		pop	hl
		call	trace.diag.word	; Print location
		ld	a,' '
		call	trace.diag.char
		scf
		jr	.finish
;
.rok:		ex	de,hl		; HL=test value
		inc	h
		inc	l
		dec	bc
		ld	a,b
		or	c
		jr	nz,.rloop
;
		or	a
;
.finish:	push	af		; C=>error
		ld	de,w5300.SOCKET0+w5300.Sn_CR
		ld	hl,w5300.Sn_CR_CLOSE
		call	write_reg
;
		ld	e,w5300.Sn_SSR_CLOSED
		call	wait_SSR
		jp	c,diagtimeout
;
		ld	c,(iy+vars._io)
		dec	c		; C->w5300.MR1
		ld	a,w5300.MR1_IND
		out	(c),a		; Set up indirect mode & no mem test
		pop	af
		jp	c,diagerr
;
		call	trace.diag.ok
;
;
		; Set the MAC address
		ld	de,trace.diag.writemac
		call	trace.diag.str
;
		ld	hl,mac
		call	trace.diag.mac
		call	trace.diag.dots
;
		ld	hl,mac
		ld	de,w5300.SHAR
		call	write_MAC
;
		; Read it back & verify
		call	get_MAC
		ex	de,hl		; DE->MAC address
;
		ld	hl,mac
		ld	de,vars.diag.buffer
		ld	b,6
.macloop:	ld	a,(de)
		inc	de
		cp	(hl)
		inc	hl
		jr	nz,.badmac
;
		djnz	.macloop
;
		call	trace.diag.ok
		jr	.macok
;
.badmac:	ld	hl,vars.diag.buffer
		call	trace.diag.mac
;
		jp	diagerr
;
.macok:		
;
		set	vars.init.wiz,(iy+vars._init)
		ret
;
;
;------------------------------------------------------------------------------
; check_ip
;
; Called to see if we have a duplicate IP address on the network
;
; Out: Cy=>IP address conflict
;
check_ip:	ld	de,w5300.IR0
		call	read_reg	; HL=IR0
		ld	a,h		; A=high IR0
		and	80h		; A=NZ if IPCF (IP conflict) bit set
		add	a,0ffh		; NZ=>Cy, Z=>NC
		ret
;
;
;------------------------------------------------------------------------------
; delay
;
; We must wait at least 10mS after resetting the WIZ chip to allow its PLL
; to lock on.
;
; The smallest resolution timer we have access to is the 20mS video interrupt.
; So we wait for one interrupt and then wait for the next to ensure we wait
; at least 20mS (it doesn't matter to the WIZ chip if we wait more than 10mS).
;
delay:		ld	de,(vars.ticks)
;
		; First wait for new tick
		inc	de
.loopstart:	ld	hl,(vars.ticks)
		or	a
		sbc	hl,de
		jr	c,.loopstart	; Wait for start of tick
;
		; Then wait for end of next tick
		inc	de
.loopend:	ld	hl,(vars.ticks)
		or	a
		sbc	hl,de
		jr	c,.loopend
;
		ret
;
;
;------------------------------------------------------------------------------
; Waits for socket open or close to complete
;
; IN:  E=SN_SSR_xxx command to wait for
; Out: C=>timeout
wait_SSR:
		ld	b,0		; Timeout, just in case
		; First wait for CR to become 0
.wait_CR:	push	de
		 ld	de,w5300.SOCKET0+w5300.Sn_CR
		 push	bc
		  call	read_reg
		 pop	bc
		pop	de
		ld	a,h
		or	l
		jr	z,.done_CR
;
		djnz	.wait_CR
;
		scf			; Timeout
		ret
.done_CR:
;
		ld	b,0		; Timeout, just in case
		; Now wait for expected value in SSR
.wait_SSR:	push	de
		 ld	de,w5300.SOCKET0+w5300.Sn_SSR
		 push	bc
		  call	read_reg
		 pop	bc
		pop	de
		ld	a,l
		cp	e
		ret	z		; NC=>ok
;
		djnz	.wait_SSR
;
		scf
		ret
;
;
;
get_MAC:	ld	de,w5300.SHAR
		ld	hl,vars.diag.buffer
		push	hl
		 call	read_MAC
		pop	hl
;
		ret
;
;
; In:  HL->IP address
; Out: Cy=>error

set_ip:		ld	de,trace.diag.writeip
		call	trace.diag.startstr
;
		ld	de,w5300.SIPR
		jr	setip
;
;
get_ip:		ld	de,w5300.SIPR
;
getip:		ld	hl,vars.diag.buffer
		push	hl
		 call	read_IP
		pop	hl
		ret
;
;
; In:  HL->IP address
; Out: Cy=>error
set_subnet:
		ld	de,trace.diag.subnet
		call	trace.diag.startstr
;
		ld	de,w5300.SUBR
		jr	setip
;
get_subnet:	ld	de,w5300.SUBR
		jr	getip
;
;
; In:  HL->IP address
; Out: Cy=>error
set_gateway:
		ld	de,trace.diag.gateway
		call	trace.diag.startstr
;
		ld	de,w5300.GAR
;
setip:		push	de		; DE=WIZ register
		push	hl		; HL->IP
		call	trace.diag.ip
		call	trace.diag.dots
		pop	hl
		pop	de
;
		push	hl
		push	de
		call	write_IP
		pop	de
		ld	hl,vars.diag.buffer
		call	read_IP
		pop	hl
;
		ld	de,vars.diag.buffer
		ld	b,4
.loop:		ld	a,(de)
		inc	de
		cp	(hl)
		inc	hl
		jr	nz,.badip
;
		djnz	.loop
;
		call	trace.diag.ok
;
		or	a		; No error
		ret
;
.badip:		ld	hl,vars.diag.buffer
		call	trace.diag.ip
;
		jp	diagerr
;
;
get_gateway:	ld	de,w5300.GAR
		jr	getip
;
;
;
		endmodule
