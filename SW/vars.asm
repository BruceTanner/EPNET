; VARS
;
; Contains all the program RAM variables
;
		module	vars
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
prog_end:
;------------------------------------------------------------------------------
; vars
;
; These are all the variables, buffers etc.
;
; Throughout the program, IY points to the variables and the variables can
; be accessed either directly, as in LD A,(variable), or via IY as in
; LD C,(IY+offset to variable). This is particularly useful for global flags
; which can be tested with BIT n,(IY+offset), allowing a flag to be tested
; without corrupting A (or any other registers).
;
		org	4007h
;
@vars:
;
;
_trace		equ	$-vars		; Offset from @vars
trace		ds	1		; Trace flags, as follows:
trace.diag	equ	0		; Bits in trace
trace.socket	equ	1
trace.dhcp	equ	2
trace.ftp	equ	3
trace.ntp	equ	4
trace.http	equ	5
trace.raw	equ	7
;
trace.diag_mask	equ	01h		; Above bits as bitmasks
trace.socket_mask equ	02h
trace.dhcp_mask	equ	04h
trace.ftp_mask	equ	08h
trace.ntp_mask	equ	10h
trace.http_mask	equ	20h
trace.raw_mask	equ	80h
;
trace.all_mask	equ	low ~(trace.diag_mask or trace.raw_mask)
;
;
_io		equ	$-vars		; io as an offset from vars
io:		ds	1		; Our base I/O address+2
;
;
trace.cols	ds	1		; # cols on screen
;
;
_init		equ	$-vars
init		ds	1		; Initialization flags
;
init.wiz	equ	0		; Bits in init
init.dhcp	equ	1
init.lease	equ	2
;
init.wiz_mask	equ	01h		; Above bits as bitmasks
init.dhcp_mask	equ	02h
init.lease_mask	equ	04h
;
;
_socket.flushing equ	$-vars
socket.flushing	ds	1		;NZ=>don't dump, we're flushing (!)
socket.last:	ds	1		; Last socket opened
;
;
_io.col		equ	$-vars		; Offset from vars
io.col:		ds	1		; Output column
;
;
ticks:		ds	2		; 20mS tick count
dhcp.ticks:	ds	2
@TICKS_1s	equ	50		; No. ticks in 1s
@TICKS_1m	equ	TICKS_1s*60	; No ticks in 1m
;
;
status._ticks	equ	$-vars		; Offset from vars
status.ticks:	ds	1		; Tick count for timing flashing blob
status.pos:	ds	2		; ->our position on status line
status.byte:	ds	1		; Saved byte at our pos on status line
;
;
device._byte	equ	$-vars		; As offset from vars
device.byte	ds	1		; Single byte buffer for byte read/write
mem.seg		ds	1		; MEM: device segment
mem.rd		ds	2		; MEM: device read pointer
mem.wr		ds	2		; MEM: device write pointer
;
;
tcp.start:	ds	2		; Start tick count for timeouts
;
;
diag.buffer:	;ds	6		; Enough for a MAC address
					; Overlays buffer below!
;
command.ip:
device.ip:
icmp.header:				; ICMP header overlays UDP header
udp.header:
icmp.ip:
udp.ip:		ds	4		; IP address
icmp.size:
udp.port:	ds	2		; Port #
icmp.header_size equ	$-icmp.header
ping.start:				; Start time for timeouts
tcp.header:
tcp.size:
udp.size:	ds	2		; #bytes in body
udp.header_size equ	$-udp.header
tcp.header_size	equ	$-tcp.header
;
ntp.timeout:
ping.start_ticks:
dhcp.timeout:	ds	2		; Initial secs for timeout
ping.end_ticks:
ntp.retries:
dhcp.retries:	ds	1		; Retry count before giving up
;
dhcp.values:				; Parameters obtained via DHCP
dhcp.ip:	ds	4
dhcp.subnet:	ds	4
dhcp.gateway:	ds	4
dhcp.server:	ds	4
dhcp.dns:	ds	4
dhcp.ntp:	ds	4
dhcp.lease:	ds	4		; Lease duration
dhcp.start:	ds	4		; Start secs of lease
dhcp.values_size equ	$-dhcp.values
;
ping.ip:				; Overlays dhcp values
dhcp.xid:		ds	4		; Our current transaction id
dhcp.xid_len		equ	$-dhcp.xid
ping.seq:
dhcp.secs:		ds	2		; Seconds elapsed
dhcp.secs_len:		equ	$-dhcp.secs
dhcp.packet_xid:	ds	4	; Transaction xid from rx packet
;
;
ftp.ip:			ds	4
ftp.socket:		ds	1	; Socket for control session
ftp.start:		ds	2	; Starts secs fortimeout
ftp.data_ip:		ds	4	; IP address for data connection
ftp.data_port:		ds	2	; Port #for data connection
device.host:				; Host name
ftp.buffer:		ds	256	; Buffer for input line
ftp.buffer_size		equ	$-ftp.buffer
ftp.user:		ds	40
ftp.user_size		equ	$-ftp.user
ftp.pass:		ds	40
ftp.pass_size		equ	$-ftp.pass
;
;
; Per-socket variables, must be on a 256-byte page boundary.
; See socket.asm for access methods
;
			org	(vars AND 0ff00h)+200h
;
sockets:				; Per-socket variables
;
socket_size		equ	20h	; Size of each per-socket variable area
;
socket0:		ds	socket_size
socket1:		ds	socket_size
socket2:		ds	socket_size
socket3:		ds	socket_size
socket4:		ds	socket_size
socket5:		ds	socket_size
socket6:		ds	socket_size
socket7:		ds	socket_size
;
			ASSERT	socket.vars <= socket_size
;
;
; Packet buffer for tx/rx packets
;
http.packet:
ping.packet:				; Ping packet overlays DHCP packet!
dhcp.packet:				; Must not go over 256-byte page!
ntp.packet:				; NTP packet overlays FTP buffer
ping.packet.type:
ntp.packet.livnmode:
dhcp.packet.op:		ds	1	; Message type
ping.packet.code:
ntp.packet.stratum:
dhcp.packet.htype:	ds	1	; Hardware address type	
ping.packet.csum:
ntp.packet.poll:
dhcp.packet.hlen:	ds	1	; Hardware address length
ntp.packet.precision:
dhcp.packet.hops:	ds	1
ping.packet.id:
ntp.packet.delay:
dhcp.packet.xid:	ds	2	; Transaction id
ping.packet.seq:
dhcp.packet.xid2:	ds	2	; Transaction id
ping.packet_size	equ	$-ping.packet
ntp.packet.dispersion:
dhcp.packet.secs:	ds	2	; Secs elapsed since start of DHCP process
dhcp.packet.flags:	ds	2
ntp.packet.identifier:
dhcp.packet.ciaddr:	ds	4	; Client IP
ntp.packet.reference:
dhcp.packet.yiaddr:	ds	4	; Your IP (client's)
dhcp.packet.siaddr:	ds	4	; Next server IP
ntp.packet.originate:
dhcp.packet.giaddr:	ds	4	; Relay agent IP
dhcp.packet.chaddr:	ds	4	; Client hardware address (16 bytes)
ntp.packet.receive:	ds	8
ntp.packet.transmit:	ds	4
dhcp.packet_end:
dhcp.packet_size	equ	$-dhcp.packet
			ds	4
ntp.packet_end:
ntp.packet_size		equ	$-ntp.packet
;
		ASSERT	high $ = high dhcp.packet	; Must fit in a page
		ASSERT dhcp.packet_size > 32	; Used as a 32 byte buffer!
;
			ds	256-($-http.packet)
http.packet_size	equ	$-http.packet
;

;
;
varsize		equ	$-vars
;
		org	prog_end
;
;
;
		endmodule
