; TRACE
;
; Provides routines for outputting diagnostic info when in trace mode
;
		module	trace
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
; diag.str
;
; Outputs a string if in diag trace mode
;
; In:  DE->string, null-terminated. First byte is trace module
;
diag.ok:	ld	de,ok_str
		jr	diag.str
;
diag.err:	ld	de,diag.errmsg
		jr	diag.str
;
diag.dots:	ld	de,dots_str
		jr	diag.str
;
diag.startstr:	call	diag.start
diag.str:	bit	vars.trace.diag,(iy+vars._trace)
		ret	z		; Trace not on for this module
;
		jp	io.str
;
;
; diag.start
;
; If in trace mode, outputs a CR, LF if we are not at the start of the line
diag.start:	bit	vars.trace.diag,(iy+vars._trace)
		ret	z
;
		ld	a,(vars.io.col)
		or	a
		ret	z
		    ;
		    ;
		    ;
;
;
; diag.crlf
;
; Outputs a CR and LFif in diag trace mode
;
diag.crlf:	ld	a,CR
		call	diag.char
		ld	a,LF
		    ;
		    ;
		    ;
;
;
; diag.char
;
; Outputs a hex byte if in diag trace mode
;
; In: A = byte
diag.char:	bit	vars.trace.diag,(iy+vars._trace)
		ret	z
;
		jp	io.char

;
;
; diag.byte
;
; Outputs a hex byte if in diag trace mode
;
; In: A = byte
diag.byte:	bit	vars.trace.diag,(iy+vars._trace)
		ret	z
;
		jp	io.byte

;
;
; diag.word
;
; Outputs a hex byte if in diag trace mode
;
; In: HL = byte
diag.word:	bit	vars.trace.diag,(iy+vars._trace)
		ret	z
;
		jp	io.word
;
;
; diag.mac
;
; Outputs a MAC address if in diag trace mode
;
; In: HL->MAC address
diag.mac:	bit	vars.trace.diag,(iy+vars._trace)
		ret	z
;
		jp	io.mac
;
;
; diag.ip
;
; Outputs an IP address if in diag trace mode
;
; In: HL->IP address
diag.ip:	bit	vars.trace.diag,(iy+vars._trace)
		ret	z
;
		jp	io.ip
;
;
;------------------------------------------------------------------------------
; Various little I/O routines called when in trace mode
;
bytes:		call	io.space
		call	io.int
		ld	de,bytes_str
		jp	io.str
;
dots:		ld	de,dots_str
		jp	io.str
;

is_timeout:	jr	c,timeout
is_error:	jr	c,error
ok:		ld	de,ok_str
		call	io.str
		or	a
		ret
;
;
timeout:	ld	de,timeout_str
		jr	err
error:		ld	de,error_str
err:		call	exos.is_stop
		jr	nc,.notstop
;
		ld	de,stop_str
.notstop:	call	io.str
		scf
		ret
;
;
;------------------------------------------------------------------------------
; dumpbytes, dumpchars
;
; In:  E':HL->memory to dump
;          B=number of bytes
;          C'->P1
;          B'=our segment
;
dumpbytes:
.loop:		call	exos.is_stop
		ret	c		; Return with Cy if STOP key presed
;
		exx
		out	(c),e		; Page in data segment
		exx
		ld	a,(hl)		; Get byte
		exx
		out	(c),b		; Page our seg back in
		exx
		inc	hl
		call	io.byte		; Print it
		call	io.space	; Followed by a space
		djnz	.loop
;
		or	a		; NC=>STOP not pressed
		ret
;
;
dumpchars:
.loop:		call	exos.is_stop
		ret	c		; Return with Cy if STOP key presed
;
		exx
		out	(c),e		; Page in data seg
		exx
		ld	a,(hl)		; Get byte
		exx
		out	(c),b		; Page our seg back in
		exx
		inc	hl
		cp	0a0h		; Chars >=A0 are editor control chars
		jr	nc,.dot
;
		cp	' '		; Chars < space are control chars
		jr	nc,.ascii
;
.dot:		ld	a,'.'		; Turn control chars into .
.ascii:		call	io.char
		djnz	.loop
;
		or	a		; NC=>STOP not pressed
		ret
;
;
;------------------------------------------------------------------------------
; set_cols
;
; Sets the number of output columns. This is a relatively time
; consuming process so we don't do it frequently
;
; Out: Preserved HL, DE, BC
;
set_cols:
		push	de
		push	bc
		call	io.cols		; Find & save # output cols
		pop	bc
		pop	de
		ld	(vars.trace.cols),a
		ret
;
;
; Trace strings - strings output during trace
;
; diag
diag.reset		db	"Reset WIZ at I/O port ",0
diag.id			db	"Read ID ",0
diag.writemac		db	"Set MAC address ",0
diag.writeip		db	"Set IP address ",0
diag.subnet		db	"Set Subnet mask ",0
diag.gateway		db	"Set Default Gateway ",0
diag.errmsg:		db	"DIAG ERROR",0
diag.memory:		db	"Test WIZ memory...",0
diag.memerr:		db	"read ",0
diag.expected:		db	" expected ",0
diag.at:		db	" at ",0
diag.timeout:		db	"TIMEOUT ERROR",0
diag.dhcp:		db	"Getting IP parameters via DHCP...",0
diag.ntp:		db	"Getting current time via NTP...",0
;
socket.connect:		db	"Connect to ",0
socket.disconnect:	db	"Disconnect...",0
socket.close:		db	"Close...",0
socket.open:		db	"Open ",0
socket.udp:		db	"UDP",0
socket.ipraw:		db	"IP",0
socket.tcp:		db	"TCP",0
socket.unknown:		db	"???",0
socket.port:		db	" port ",0
socket.by:		db	" by ",0
;
udp.rx:			db	"UDP rx from ",0
udp.tx:			db	"UDP tx to ",0
udp.errmsg:		db	"UDP ERROR",CR,LF,0
;
tcp.rx:			db	"TCP rx",0
tcp.tx:			db	"TCP tx",0
;
ipraw.rx:		db	"IPRAW rx from ",0
ipraw.tx:		db	"IPRAW tx to ",0
;
;
dhcp.start:		db	"DHCP:start...",0
dhcp.discover:		db	"DHCP:tx Discover ",0
dhcp.request:		db	"DHCP:tx Request ",0
dhcp.rx:		db	"DHCP:rx ",0
dhcp.gotip:		db	" IP=",0
dhcp.gotsubnet:		db	" subnet=",0
dhcp.gotgateway:	db	" gateway=",0
dhcp.gotserver:		db	" server=",0
dhcp.gotlease:		db	" lease=",0
dhcp.gotdns:		db	" DNS=",0
dhcp.gotntp:		db	" NTP=",0
;
dhcp.offer:		db	"Offer ",0
dhcp.decline:		db	"Decline ",0
dhcp.ack:		db	"Ack ",0
dhcp.nak:		db	"Nak ",0
dhcp.type:		db	" bad Type ",0
dhcp.end:		db	"DHCP:finished",CR,LF,0
dhcp.errmsg:		db	"DHCP ERROR",0
dhcp.small:		db	"TOO SMALL",0
dhcp.port:		db	"BAD PORT",0
dhcp.op:		db	"BAD OP",0
dhcp.addr:		db	"BAD ADDR",0
dhcp.xid:		db	"BAD XID",0
dhcp.cookie:		db	"BAD COOKIE",0
dhcp.eop:		db	"BAD PACKET",0
;
ping.pinging:		db	"Pinging ",0
;
ntp.tx:			db	"NTP:tx request to ",0
ntp.rx:			db	"NTP:rx...",0
;
;
http.open:		db	"Connect to ",0
http.tx:		db	"Tx ",0
http.rx:		db	"Rx ",0
http.code:		db	"Code=",0
http.size:		db	"Size=",0
;
;
ftp.open:		db	"Connect to ",0
ftp.login:		db	"Login...",0
ftp.tx:			db	"Tx ",0
ftp.rx:			db	"Rx ",0
ftp.close:		db	"Close",0
ftp.pasv:		db	"pasv=",0
ftp.code:		db	"code=",0
ftp.error_str:		db	"FTP ERROR",0
;
;
ok_str:			db	"OK",CR,LF,0
timeout_str:		db	"TIMEOUT",CR,LF,0
error_str:		db	"ERROR",CR,LF,0
stop_str:		db	"STOP",CR,LF,0
dots_str:		db	"...",0
bytes_str:		db	" bytes",0
;



		endmodule
