; DHCP
;
; Attempts to get IP address, subnet mask etc using the DHCP protocol.
;
;
		module	dhcp
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
; For reference, this is the format of a DHCP packet (from RFC 2131):
;
;   0                   1                   2                   3
;   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
;   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;   |     op (1)    |   htype (1)   |   hlen (1)    |   hops (1)    |
;   +---------------+---------------+---------------+---------------+
;   |                            xid (4)                            |
;   +-------------------------------+-------------------------------+
;   |           secs (2)            |           flags (2)           |
;   +-------------------------------+-------------------------------+
;   |                          ciaddr  (4)                          |
;   +---------------------------------------------------------------+
;   |                          yiaddr  (4)                          |
;   +---------------------------------------------------------------+
;   |                          siaddr  (4)                          |
;   +---------------------------------------------------------------+
;   |                          giaddr  (4)                          |
;   +---------------------------------------------------------------+
;   |                          chaddr  (16)                         |
;   +---------------------------------------------------------------+
;   |                          sname   (64)                         |
;   +---------------------------------------------------------------+
;   |                          file    (128)                        |
;   +---------------------------------------------------------------+
;   |                          options (variable)                   |
;   +---------------------------------------------------------------+
;
;   FIELD      OCTETS       DESCRIPTION
;   -----      ------       -----------
;
;   op            1  Message op code / message type.
;                    1 = BOOTREQUEST, 2 = BOOTREPLY
;   htype         1  Hardware address type, see ARP section in "Assigned
;                    Numbers" RFC; e.g., '1' = 10mb ethernet.
;   hlen          1  Hardware address length (e.g.  '6' for 10mb
;                    ethernet).
;   hops          1  Client sets to zero, optionally used by relay agents
;                    when booting via a relay agent.
;   xid           4  Transaction ID, a random number chosen by the
;                    client, used by the client and server to associate
;                    messages and responses between a client and a
;                    server.
;   secs          2  Filled in by client, seconds elapsed since client
;                    began address acquisition or renewal process.
;   flags         2  Flags (see figure 2).
;   ciaddr        4  Client IP address; only filled in if client is in
;                    BOUND, RENEW or REBINDING state and can respond
;                    to ARP requests.
;   yiaddr        4  'your' (client) IP address.
;   siaddr        4  IP address of next server to use in bootstrap;
;                    returned in DHCPOFFER, DHCPACK by server.
;   giaddr        4  Relay agent IP address, used in booting via a
;                    relay agent.
;   chaddr       16  Client hardware address.
;   sname        64  Optional server host name, null terminated string.
;   file        128  Boot file name, null terminated string; "generic"
;                    name or null in DHCPDISCOVER, fully qualified
;                    directory-path name in DHCPOFFER.
;   options     var  Optional parameters field.  See the options
;                    documents for a list of defined options.
;
DHCP_OP.BOOTREQUEST	equ	1
DHCP_OP.BOOTREPLY	equ	2
;
DHCP_HTYPE.10MB		equ	1
DHCP_HTYPE.100MB	equ	2
;
DHCP_HLEN.ETHERNET	equ	6
DHCP.HOPS		equ	0
DHCP_FLAGS.BROADCAST	equ	8000h
;
;
; The "options" field is variable length and consists of zero or more options
; (from RFC 2132, options we don't use omitted):
;
; 3.1. Pad Option
;
; The pad option can be used to cause subsequent fields to align on
; word boundaries.
;
;   The code for the pad option is 0, and its length is 1 octet.
;
;    Code
;   +-----+
;   |  0  |
;   +-----+
;
DHCP_OPT.PAD		equ	0
;
;
; 3.2. End Option
;
;   The end option marks the end of valid information in the vendor
;   field.  Subsequent octets should be filled with pad options.
;
;   The code for the end option is 255, and its length is 1 octet.
;
;    Code
;   +-----+
;   | 255 |
;   +-----+
;
DHCP_OPT.END		equ	255
;
;
; 3.3. Subnet Mask
;
;   The subnet mask option specifies the client's subnet mask as per RFC
;   950 [5].
;
;   If both the subnet mask and the router option are specified in a DHCP
;   reply, the subnet mask option MUST be first.
;
;   The code for the subnet mask option is 1, and its length is 4 octets.
;
;    Code   Len        Subnet Mask
;   +-----+-----+-----+-----+-----+-----+
;   |  1  |  4  |  m1 |  m2 |  m3 |  m4 |
;   +-----+-----+-----+-----+-----+-----+
;
DHCP_OPT.SUBNET		equ	1
;
;
; 3.4. Time Offset
;
;   The time offset field specifies the offset of the client's subnet in
;   seconds from Coordinated Universal Time (UTC).  The offset is
;   expressed as a two's complement 32-bit integer.  A positive offset
;   indicates a location east of the zero meridian and a negative offset
;   indicates a location west of the zero meridian.
;
;   The code for the time offset option is 2, and its length is 4 octets.
;
;    Code   Len        Time Offset
;   +-----+-----+-----+-----+-----+-----+
;   |  2  |  4  |  n1 |  n2 |  n3 |  n4 |
;   +-----+-----+-----+-----+-----+-----+
;
; 3.5. Router Option
;
;   The router option specifies a list of IP addresses for routers on the
;   client's subnet.  Routers SHOULD be listed in order of preference.
;
;   The code for the router option is 3.  The minimum length for the
;   router option is 4 octets, and the length MUST always be a multiple
;   of 4.
;
;    Code   Len         Address 1               Address 2
;   +-----+-----+-----+-----+-----+-----+-----+-----+--
;   |  3  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
;   +-----+-----+-----+-----+-----+-----+-----+-----+--
;
DHCP_OPT.ROUTER		equ	3
;
;
; 3.6. Time Server Option
;
;   The time server option specifies a list of RFC 868 [6] time servers
;   available to the client.  Servers SHOULD be listed in order of
;   preference.
;
;   The code for the time server option is 4.  The minimum length for
;   this option is 4 octets, and the length MUST always be a multiple of
;   4.
;
;    Code   Len         Address 1               Address 2
;   +-----+-----+-----+-----+-----+-----+-----+-----+--
;   |  4  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
;   +-----+-----+-----+-----+-----+-----+-----+-----+--
;
;
; 3.7. Name Server Option
;
;   The name server option specifies a list of IEN 116 [7] name servers
;   available to the client.  Servers SHOULD be listed in order of
;   preference.
;
;   The code for the name server option is 5.  The minimum length for
;   this option is 4 octets, and the length MUST always be a multiple of
;   4.
;
;    Code   Len         Address 1               Address 2
;   +-----+-----+-----+-----+-----+-----+-----+-----+--
;   |  5  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
;   +-----+-----+-----+-----+-----+-----+-----+-----+--
;
;
; 3.8. Domain Name Server Option
;
;   The domain name server option specifies a list of Domain Name System
;   (STD 13, RFC 1035 [8]) name servers available to the client.  Servers
;   SHOULD be listed in order of preference.
;
;   The code for the domain name server option is 6.  The minimum length
;   for this option is 4 octets, and the length MUST always be a multiple
;   of 4.
;
;    Code   Len         Address 1               Address 2
;   +-----+-----+-----+-----+-----+-----+-----+-----+--
;   |  6  |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
;   +-----+-----+-----+-----+-----+-----+-----+-----+--
;
DHCP_OPT.DNS		equ	6
;
;
; 3.14. Host Name Option
;
;   This option specifies the name of the client.  The name may or may
;   not be qualified with the local domain name (see section 3.17 for the
;   preferred way to retrieve the domain name).  See RFC 1035 for
;   character set restrictions.
;
;   The code for this option is 12, and its minimum length is 1.
;
;    Code   Len                 Host Name
;   +-----+-----+-----+-----+-----+-----+-----+-----+--
;   |  12 |  n  |  h1 |  h2 |  h3 |  h4 |  h5 |  h6 |  ...
;   +-----+-----+-----+-----+-----+-----+-----+-----+--
;
DHCP_OPT.HOST		equ	12
;
;
; 3.17. Domain Name
;
;   This option specifies the domain name that client should use when
;   resolving hostnames via the Domain Name System.
;
;   The code for this option is 15.  Its minimum length is 1.
;
;    Code   Len        Domain Name
;   +-----+-----+-----+-----+-----+-----+--
;   |  15 |  n  |  d1 |  d2 |  d3 |  d4 |  ...
;   +-----+-----+-----+-----+-----+-----+--
;
DHCP_OPT.DOMAIN		equ	15
;
;
; 8.3. Network Time Protocol Servers Option
;
;   This option specifies a list of IP addresses indicating NTP [18]
;   servers available to the client.  Servers SHOULD be listed in order
;   of preference.
;
;   The code for this option is 42.  Its minimum length is 4, and the
;   length MUST be a multiple of 4.
;
;    Code   Len         Address 1               Address 2
;   +-----+-----+-----+-----+-----+-----+-----+-----+--
;   |  42 |  n  |  a1 |  a2 |  a3 |  a4 |  a1 |  a2 |  ...
;   +-----+-----+-----+-----+-----+-----+-----+-----+--
;
DHCP_OPT.NTP		equ	42
;
;
; 9.1. Requested IP Address
;
;   This option is used in a client request (DHCPDISCOVER) to allow the
;   client to request that a particular IP address be assigned.
;
;   The code for this option is 50, and its length is 4.
;
;    Code   Len          Address
;   +-----+-----+-----+-----+-----+-----+
;   |  50 |  4  |  a1 |  a2 |  a3 |  a4 |
;   +-----+-----+-----+-----+-----+-----+
;
DHCP_OPT.IP		equ	50
;
;
; 9.2. IP Address Lease Time
;
;   This option is used in a client request (DHCPDISCOVER or DHCPREQUEST)
;   to allow the client to request a lease time for the IP address.  In a
;   server reply (DHCPOFFER), a DHCP server uses this option to specify
;   the lease time it is willing to offer.
;
;   The time is in units of seconds, and is specified as a 32-bit
;   unsigned integer.
;
;   The code for this option is 51, and its length is 4.
;
;    Code   Len         Lease Time
;   +-----+-----+-----+-----+-----+-----+
;   |  51 |  4  |  t1 |  t2 |  t3 |  t4 |
;   +-----+-----+-----+-----+-----+-----+
;
DHCP_OPT.LEASE		equ	51
;
;
; 9.6. DHCP Message Type
;
;   This option is used to convey the type of the DHCP message.  The code
;   for this option is 53, and its length is 1.  Legal values for this
;   option are:
;
;           Value   Message Type
;           -----   ------------
;             1     DHCPDISCOVER
;             2     DHCPOFFER
;             3     DHCPREQUEST
;             4     DHCPDECLINE
;             5     DHCPACK
;             6     DHCPNAK
;             7     DHCPRELEASE
;             8     DHCPINFORM
;
;    Code   Len  Type
;   +-----+-----+-----+
;   |  53 |  1  | 1-9 |
;   +-----+-----+-----+
;
DHCP_OPT.TYPE		equ	53
;
DHCP_TYPE.DISCOVER	equ	1
DHCP_TYPE.OFFER		equ	2
DHCP_TYPE.REQUEST	equ	3
DHCP_TYPE.DECLINE	equ	4
DHCP_TYPE.ACK		equ	5
DHCP_TYPE.NAK		equ	6
DHCP_TYPE.RELEASE	equ	7
DHCP_TYPE.INFORM	equ	8
;
;
; 9.7. Server Identifier
;
;   This option is used in DHCPOFFER and DHCPREQUEST messages, and may
;   optionally be included in the DHCPACK and DHCPNAK messages.  DHCP
;   servers include this option in the DHCPOFFER in order to allow the
;   client to distinguish between lease offers.  DHCP clients use the
;   contents of the 'server identifier' field as the destination address
;   for any DHCP messages unicast to the DHCP server.  DHCP clients also
;   indicate which of several lease offers is being accepted by including
;   this option in a DHCPREQUEST message.
;
;   The identifier is the IP address of the selected server.
;
;   The code for this option is 54, and its length is 4.
;
;    Code   Len            Address
;   +-----+-----+-----+-----+-----+-----+
;   |  54 |  4  |  a1 |  a2 |  a3 |  a4 |
;   +-----+-----+-----+-----+-----+-----+
;
DHCP_OPT.SERVER		equ	54
;
;
; 9.8. Parameter Request List
;
;   This option is used by a DHCP client to request values for specified
;   configuration parameters.  The list of requested parameters is
;   specified as n octets, where each octet is a valid DHCP option code
;   as defined in this document.
;
;   The client MAY list the options in order of preference.  The DHCP
;   server is not required to return the options in the requested order,
;   but MUST try to insert the requested options in the order requested
;   by the client.
;
;   The code for this option is 55.  Its minimum length is 1.
;
;    Code   Len   Option Codes
;   +-----+-----+-----+-----+---
;   |  55 |  n  |  c1 |  c2 | ...
;   +-----+-----+-----+-----+---
;
DHCP_OPT.PARAM		equ	55
;
;
; 9.9. Message
;
;   This option is used by a DHCP server to provide an error message to a
;   DHCP client in a DHCPNAK message in the event of a failure. A client
;   may use this option in a DHCPDECLINE message to indicate the why the
;   client declined the offered parameters.  The message consists of n
;   octets of NVT ASCII text, which the client may display on an
;   available output device.
;
;   The code for this option is 56 and its minimum length is 1.
;
;    Code   Len     Text
;   +-----+-----+-----+-----+---
;   |  56 |  n  |  c1 |  c2 | ...
;   +-----+-----+-----+-----+---
;
;
; 9.11. Renewal (T1) Time Value
;
;   This option specifies the time interval from address assignment until
;   the client transitions to the RENEWING state.
;
;   The value is in units of seconds, and is specified as a 32-bit
;   unsigned integer.
;
;   The code for this option is 58, and its length is 4.
;
;    Code   Len         T1 Interval
;   +-----+-----+-----+-----+-----+-----+
;   |  58 |  4  |  t1 |  t2 |  t3 |  t4 |
;   +-----+-----+-----+-----+-----+-----+
;
DHCP_OPT.T1		equ	58
;
;
; 9.12. Rebinding (T2) Time Value
;
;   This option specifies the time interval from address assignment until
;   the client transitions to the REBINDING state.
;
;   The value is in units of seconds, and is specified as a 32-bit
;   unsigned integer.
;
;   The code for this option is 59, and its length is 4.
;
;    Code   Len         T2 Interval
;   +-----+-----+-----+-----+-----+-----+
;   |  59 |  4  |  t1 |  t2 |  t3 |  t4 |
;   +-----+-----+-----+-----+-----+-----+
;
DHCP_OPT.T2		equ	59
;
;
; 9.14. Client-identifier
;
;   This option is used by DHCP clients to specify their unique
;   identifier.  DHCP servers use this value to index their database of
;   address bindings.  This value is expected to be unique for all
;   clients in an administrative domain.
;
;   Identifiers SHOULD be treated as opaque objects by DHCP servers.
;
;   The client identifier MAY consist of type-value pairs similar to the
;   'htype'/'chaddr' fields defined in [3]. For instance, it MAY consist
;   of a hardware type and hardware address. In this case the type field
;   SHOULD be one of the ARP hardware types defined in STD2 [22].  A
;   hardware type of 0 (zero) should be used when the value field
;   contains an identifier other than a hardware address (e.g. a fully
;   qualified domain name).
;
;   For correct identification of clients, each client's client-
;   identifier MUST be unique among the client-identifiers used on the
;   subnet to which the client is attached.  Vendors and system
;   administrators are responsible for choosing client-identifiers that
;   meet this requirement for uniqueness.
;
;   The code for this option is 61, and its minimum length is 2.
;
;   Code   Len   Type  Client-Identifier
;   +-----+-----+-----+-----+-----+---
;   |  61 |  n  |  t1 |  i1 |  i2 | ...
;   +-----+-----+-----+-----+-----+---
;
DHCP_OPT.CLIENT		equ	61
;
;==============================================================================
;
DHCP_SERVER_PORT	equ	67	; Standard fixed port numbers used
DHCP_CLIENT_PORT	equ	68	;   for DHCP
;
;
;
; init
;
; Starts the whole DHCP process. If we have not yet been initialized, we do
; the DHCP process. If we have been initialized, we check whether the lease
; time has expired.
;
; Out: NC=>ok
init:
		bit	vars.init.dhcp,(iy+vars._init)	; Initialized?
		jr	z,.do_dhcp			; Go if not
;
		or	a
		bit	vars.init.lease,(iy+vars._init)	; Got a lease?
		ret	z				; Just return NC if not
;
		ld	hl,vars.dhcp.lease	; See if lease has expired
		ld	b,4
		xor	a
.loop:		or	(hl)
		ret	nz
;
		inc	hl
		djnz	.loop
;
		; Lease count has gone to 0 so renew DHCP params
;
.do_dhcp:	res	vars.init.dhcp,(iy+vars._init)	; Not initialized
		res	vars.init.lease,(iy+vars._init)	; No lease time

		ld	de,trace.diag.dhcp
		call	trace.diag.str
;
		bit	vars.trace.dhcp,(iy+vars._trace)
		jr	z,.donetrace
;		
		call	io.start
		ld	de,trace.dhcp.start
		call	io.str
.donetrace:
;
		call	status.start		; Start status line blob
;		
		xor	a			; We always start with xid=0
		sbc	hl,hl
		ld	(vars.dhcp.xid),hl
		ld	(vars.dhcp.xid+2),hl
;
		ld	(vars.dhcp.secs),hl
;
		ld	(vars.dhcp.retries),a
		jr	donetrace

restart:	call	socket.close_0
		jr	c,init.error

donetrace:	ld	hl,vars.dhcp.values	; Clear DHCP values
		ld	bc,vars.dhcp.values_size
		call	util.memzero
;
		ld	de,owner_str		; Our name
		ld	hl,DHCP_CLIENT_PORT	; Always use this port
		call	udp.open_0		; Open socket
		jr	nc,init.startok
;
init.error:	bit	vars.trace.dhcp,(iy+vars._trace)
		call	nz,trace.error
;
init.abort:	call	socket.close_0
		call	status.stop		; Restore status line
		scf
		ret
;
init.startok:	bit	vars.trace.dhcp,(iy+vars._trace)
		call	nz,trace.ok
;
start:		; Inc the current transaction id. But for simplicity we just
		; always use top word = 0
		ld	hl,(vars.dhcp.xid)	; We don't bother with the top
		inc	hl			;   word of 32-bit xid, always
		ld	(vars.dhcp.xid),hl	;   0
		or	a
		sbc	hl,hl
		ld	(vars.dhcp.xid+2),hl
;
		bit	vars.trace.dhcp,(iy+vars._trace)
		jr	z,.donetrace
;
		call	io.start
		ld	de,trace.dhcp.discover
		call	io.str
		ld	hl,(vars.dhcp.xid)
		call	io.int
		call	trace.dots
.donetrace:
;
		ld	a,(vars.dhcp.retries)
		inc	a
		ld	(vars.dhcp.retries),a
		cp	10
		jr	nc,init.error		; Try 10 times, then give up
;
		ld	a,DHCP_TYPE.DISCOVER
		call	send
		jr	c,init.error
;
		call	read
		jr	c,init.abort
;
		cp	DHCP_TYPE.OFFER
		jr	nz,restart
;
		ld	hl,(vars.dhcp.packet_xid)
		ld	(vars.dhcp.xid),hl
		ld	hl,(vars.dhcp.packet_xid+2); Use offer's xid
		ld	(vars.dhcp.xid+2),hl
;
		bit	vars.trace.dhcp,(iy+vars._trace)
		jr	z,.dontr2

		call	io.start
		ld	de,trace.dhcp.request
		call	io.str
		ld	hl,(vars.dhcp.xid)
		call	io.int
		call	trace.dots
.dontr2:
;
		ld	a,DHCP_TYPE.REQUEST
		call	send
		jp	c,init.error
;
		call	read
		jp	c,init.abort
;
		cp	DHCP_TYPE.ACK
		jp	nz,restart
;
		ld	de,trace.dhcp.end
		bit	vars.trace.dhcp,(iy+vars._trace)
		call	nz,io.str
;
		ld	hl,vars.dhcp.ip
		call	wiz.set_ip
;
		ld	hl,vars.dhcp.subnet
		call	nc,wiz.set_subnet
;
		ld	hl,vars.dhcp.gateway
		call	nc,wiz.set_gateway
;
		call	socket.close_0
;
		call	status.stop		; Restore status line
;		
		set	vars.init.dhcp,(iy+vars._init)	; Initialised!
;
		or	a
		ret
;
;
;------------------------------------------------------------------------------
; send
;
; Sends a DHCP packet
;
; In:  A=DHCP_TYPE.xxx
; Out: NC=>ok
send:		ex	af,af			; Save DHCP type in A'
;
		; Set up udp header with dest ip address & port
		ld	hl,vars.udp.ip
		ld	b,4
.loop:		ld	(hl),0xff		; Broadcast
		inc	hl
		djnz	.loop
;
		ld	hl,DHCP_SERVER_PORT	; Standard DHCP port
		ld	(vars.udp.port),hl
;
		; Construct a DHCP packet
		call	packet_init		; Zero packet buffer
;
		ld	(hl),DHCP_OP.BOOTREQUEST;
		inc	hl			; HL->packet.htype
		ld	(hl),DHCP_HTYPE.10MB;
		inc	hl			; HL->packet.hlen
		ld	(hl),DHCP_HLEN.ETHERNET
		inc	hl			; HL->packet.hops
		ld	(hl),DHCP.HOPS
		inc	hl			; HL->packet.xid
;
		; Copy in transaction id, byte swapping
		ld	de,(vars.dhcp.xid+2)
		ld	(hl),d
		inc	hl
		ld	(hl),e
		inc	hl
		ld	de,(vars.dhcp.xid)
		ld	(hl),d
		inc	hl
		ld	(hl),e
		inc	hl
;
		; secs has to be byte swapped too
		ld	de,(vars.dhcp.secs)
		ld	(hl),d
		inc	hl
		ld	(hl),e
		inc	hl
;
		ld	(hl),HIGH DHCP_FLAGS.BROADCAST
		inc	hl
		ld	(hl),LOW DHCP_FLAGS.BROADCAST
;
		; ciaddr, yiaddr, siaddr & giaddr already zeroed
;
		ld	hl,vars.dhcp.packet.chaddr	; Copy MAC adrdess to chaddr
		call	packet_mac	; Rest of packet.chaddr already 0
;
		ASSERT	(vars.dhcp.packet_size & 1) = 0
;
		ld	bc,vars.dhcp.packet_size
		call	packet_write	; Write packet upto & including chaddr
		jr	c,.error
;
		call	packet_init	; Zero packet buffer again
;
		; Write 32 bytes from zerod buffer for sname & file
		ld	b,6		; 6x32 bytes = 192
.writezeros:	push	bc
		ld	bc,32
		call	packet_write
		pop	bc
		jr	c,.error
;
		djnz	.writezeros
;
		; OPT - Magic cookie
		ld	(hl),99
		inc	hl
		ld	(hl),130
		inc	hl
		ld	(hl),83
		inc	hl
		ld	(hl),99
		inc	hl
.LEN_COOKIE	equ	4
;
		; OPT - Message type
		ld	(hl),DHCP_OPT.TYPE; Message type
		inc	hl
		ld	(hl),1		; One byte
		inc	hl
		ex	af,af		; Get back our message type
		ld	(hl),a
		inc	hl
		ex	af,af		; Save type again
.LEN_TYPE	equ	3
;
		; OPT - Client identifier
		ld	(hl),DHCP_OPT.CLIENT	; Client identifier
		inc	hl
		ld	(hl),7		; Length
		inc	hl
		ld	(hl),1		; Type 1 (hardware)
		inc	hl
		call	packet_mac
.LEN_CLIENT	equ	9
;
		push	hl		; Save ptr to end of mac
		 ; OPT - host name
		 ld	(hl),DHCP_OPT.HOST	; Host name
		 inc	hl
		 ld	(hl),2+(2*3)	; "EP" + 3 bytes from mac
		 inc	hl
		 ld	(hl),'E'
		 inc	hl
		 ld	(hl),'P'
		 inc	hl
;		 ld	(hl),'-'
;		 inc	hl
		pop	de		; DE->end of mac address
		dec	de		; Point to ;last 3 bytes of MAC address
		dec	de
		dec	de
		call	packet_byte
		call	packet_byte
		call	packet_byte
.LEN_HOST	equ	10
;
		; Write above OPTs
.packet_size	equ	.LEN_COOKIE+.LEN_TYPE+.LEN_CLIENT+.LEN_HOST
		ASSERT	(.packet_size & 1) = 0
;
		ld	bc,.packet_size
		call	packet_write
		jr	nc,.noerror
;
.error:
		bit	vars.trace.dhcp,(iy+vars._trace)
		ret	z
;
		jp	trace.error
;
.noerror:	ex	af,af		; Get back message type
		cp	DHCP_TYPE.REQUEST
		jr	nz,.notreq
;
		ld	(hl),DHCP_OPT.IP; Requested ip address
		inc	hl
		ld	de,vars.dhcp.ip
		call	packet_ip
;
		ld	(hl),DHCP_OPT.SERVER	; Server identifier
		inc	hl
		ld	de,vars.dhcp.server
		call	packet_ip
;
		ld	bc,2*(2+4)	; 2 lots of (type+length+ip)
		call	packet_write
		jr	c,.error
;
.notreq:
		ld	(hl),DHCP_OPT.PARAM	; Param Request
		inc	hl
		ld	(hl),7		; Number of params
		inc	hl
		ld	(hl),DHCP_OPT.SUBNET	; subnet mask
		inc	hl
		ld	(hl),DHCP_OPT.ROUTER	; routers on subnet
		inc	hl
		ld	(hl),DHCP_OPT.DNS	; DNS server
		inc	hl
		ld	(hl),DHCP_OPT.DOMAIN	; domain name
		inc	hl
		ld	(hl),DHCP_OPT.NTP	; Time server
		inc	hl
		ld	(hl),DHCP_OPT.T1
		inc	hl
		ld	(hl),DHCP_OPT.T2
		inc	hl
		ld	(hl),DHCP_OPT.END	; End option
		ld	bc,10		; #bytes written above
		call	packet_write
		jr	c,.error
;
		call	udp.send_0
		jr	c,.error
;
		bit	vars.trace.dhcp,(iy+vars._trace)
		ret	z
;
		jp	trace.ok
;
;
;------------------------------------------------------------------------------
; read
;
; Receives and parses a DHCP response
;
; Out: A=DHCP_TYPE.xx if valid response, else 0 or ff
;      Cy=>error
read:
		ld	hl,(vars.ticks)
		ld	(vars.dhcp.timeout),hl
		jr	.loop
;
.eop:		ld	de,trace.dhcp.eop
.badpacket:	bit	vars.trace.dhcp,(iy+vars._trace)
		call	nz,io.str
.retry:		call	socket.read_end_0
;
.loop:		call	udp.header_0
		jr	nz,.gotpacket
;
		call	status.waiting	; Flash status line blob
;
		call	exos.is_stop
		jr	c,.errret
;
		ld	de,(vars.dhcp.timeout)	; Start tick count
		ld	hl,(vars.ticks)		; Current tick count
		or	a
		sbc	hl,de		; HL=duration in ticks
		ld	de,TICKS_1s	; 1S timeout in ticks
		sbc	hl,de
		jr	c,.loop		; Not timed out yet
;
.errret:				; Cy=>error, or NC=>timeout
		push	af
		 call	socket.read_end_0
		pop	af
		sbc	a,a		; FF and carry or 0 and NC
		ret
;
;
.gotpacket:		; Got something - must be at least DHCP header long
		bit	vars.trace.dhcp,(iy+vars._trace)
		jr	z,.donetrace
;
		call	io.start
		ld	de,trace.dhcp.rx
		call	io.str
.donetrace:
;
		or	a
		ld	bc,vars.dhcp.packet_size
		sbc	hl,bc
		ld	de,trace.dhcp.small
		jr	c,.badpacket	; Too small - ignore
;
		ld	hl,vars.dhcp.packet
		ld	bc,vars.dhcp.packet_size
		call	socket.read_0		; Read start of DHCP packet
;
		; Check packet has come from the right port
		ld	hl,(vars.udp.port)
		ld	bc,DHCP_SERVER_PORT	; Standard server port
		or	a
		sbc	hl,bc
		ld	de,trace.dhcp.port
 jp	nz,.badpacket
;		jr	nz,.badpacket
;
		; Check it's the right sort of DHCP reply
		ld	a,(vars.dhcp.packet.op)
		cp	2		; BOOTREPLY
		ld	de,trace.dhcp.op
		jp	nz,.badpacket
;
		; Check chaddr has our mac address
		ld	hl,vars.dhcp.packet.chaddr
		ld	de,mac
		ld	b,6
		call	util.memcmp
		ld	de,trace.dhcp.addr
		jp	nz,.badpacket
;
		; Check xid. Top word MBZ as we always send it 0
		ld	hl,(vars.dhcp.packet.xid)
		ld	a,h
		or	l
.xiderrnz:	ld	de,trace.dhcp.xid
		jp	nz,.badpacket
;
		; Save packet's xid in vars.dhcp.packet_xid because we
		; reuse the packet buffer later
		ld	a,h		; Get it in Z80 order
		ld	h,l
		ld	l,a
		ld	(vars.dhcp.packet_xid+2),hl
;
		ld	hl,(vars.dhcp.packet.xid+2)
		ld	a,h		; Get it in Z80 order
		ld	h,l
		ld	l,a
		ld	(vars.dhcp.packet_xid),hl
		ld	de,(vars.dhcp.xid)
		ex	de,hl		; HL=our xid, DE=packet xid
		or	a
		sbc	hl,de		; Make sure it's <= current xid
		jr	c,.xiderrnz	; Also NZ if Cy
.xidok:	
;
		ld	de,vars.dhcp.ip	; Get the IP address
		ld	hl,vars.dhcp.packet.yiaddr
		ld	bc,4
		ldir
;
		; Now we need to skip to the options part
		; so read 6x32 bytes
		; This will trash the DHCP header!!
		ld	b,6
.readlots:	ld	hl,vars.dhcp.packet
		push	bc
		 ld	bc,32
		 call	socket.read_0
		pop	bc
		djnz	.readlots
;
		; Read the magic cookie
		ld	hl,vars.dhcp.packet
		ld	bc,4		; Read the magic cookie
		call	socket.read_0
;
		ld	hl,(vars.dhcp.packet+0)
		ld	de,130*256+99
		or	a
		sbc	hl,de
		jr	nz,.cookiebad
;
		ld	hl,(vars.dhcp.packet+2)
		ld	de,99*256+83
		or	a
		sbc	hl,de
		jr	z,.cookieok
;
.cookiebad:	ld	de,trace.dhcp.cookie
		jp	.badpacket

.cookieok:
		; Now read the variable-sized options
		xor	a		; Initialise DHCP type
		ex	af,af		; Save in AF'
;
		jr	.nextopt
;
.ret:		call	socket.read_end_0
		bit	vars.trace.dhcp,(iy+vars._trace)
		call	nz,trace.ok
		ex	af,af		; Get back saved DHCP type
		or	a		; NC=>no error
		ret
;
.nextopt:
		call	socket.read_byte_0
		jp	c,.eop		; Nothing left to read but no end opt
;
		; FF is the end of options
		; 00 is just padding
		; All others are (should be!) followed by a length byte

		cp	0ffh		; End option?
		jr	z,.ret
;
		or	a		; Padding?
		jr	z,.nextopt

		ld	c,a		; Save opt code
;
		call	socket.read_byte_0; Get length byte
		jp	c,.eop
;
		ld	b,a		; Save length
		ld	a,c		; Get back opt code
;
		cp	DHCP_OPT.TYPE	; Message type?
		jr	nz,.not53
;
		call	socket.read_byte_0; Get DHCP message type
		jp	c,.eop
;
		ld	b,a
		ex	af,af		; Save in AF for returning type
;
		bit	vars.trace.dhcp,(iy+vars._trace)
		jr	z,.nextopt
;
		ld	a,b		; Retrieve message type
		ld	de,trace.dhcp.offer
		cp	DHCP_TYPE.OFFER
		jr	z,.tracetype
;
		ld	de,trace.dhcp.decline
		cp	DHCP_TYPE.DECLINE
		jr	z,.tracetype
;
		ld	de,trace.dhcp.ack
		cp	DHCP_TYPE.ACK
		jr	z,.tracetype
;
		ld	de,trace.dhcp.nak
		cp	DHCP_TYPE.NAK
		jr	z,.tracetype
;
		call	io.short
		ld	de,trace.dhcp.type
.tracetype:	call	io.str		; Print message type
;
		ld	hl,(vars.dhcp.packet_xid)
		call	io.int		; Followed by xid...
		call	trace.dots
;
		ld	bc,vars.dhcp.ip
		ld	de,trace.dhcp.gotip
		call	traceip		; And the IP we received
;
		jr	.nextopt
.not53:
;
		cp	DHCP_OPT.SUBNET		; Subnet mask?
		jr	nz,.not1
;
		ld	hl,vars.dhcp.subnet
		call	read_ip
		jp	c,.eop
;
		ld	de,trace.dhcp.gotsubnet
		ld	bc,vars.dhcp.subnet
		call	traceip
;
		jr	.nextopt
.not1:		
;
		cp	DHCP_OPT.ROUTER		; Routers on subnet?
		jr	nz,.not3
;
		push	bc		; Save length
		 ld	hl,vars.dhcp.gateway
		 call	read_ip
		pop	bc
		jp	c,.eop
;
		push	bc
		 ld	de,trace.dhcp.gotgateway
		 ld	bc,vars.dhcp.gateway
		 call	traceip
		pop	bc
;
		jr	.skip4
.not3:
;
		cp	DHCP_OPT.DNS	; DNS server?
		jr	nz,.not6
;
		push	bc		; Save length
		 ld	hl,vars.dhcp.dns
		 call	read_ip
		pop	bc
		jp	c,.eop
;
		push	bc
		 ld	de,trace.dhcp.gotdns
		 ld	bc,vars.dhcp.dns
.traceip:	 call	traceip
		pop	bc
;
.skip4:		ld	a,b
		sub	4		; Allow for bytes just read
		ld	b,a
		jr	.skipopt	; Skip rest of option
.not6:
;
		cp	DHCP_OPT.NTP	; NTP server?
		jr	nz,.not42
;
		push	bc		; Save length
		 ld	hl,vars.dhcp.ntp
		 call	read_ip
		pop	bc
		jp	c,.eop
;
		push	bc
		 ld	de,trace.dhcp.gotntp
		 ld	bc,vars.dhcp.ntp
		jr	.traceip
.not42:
;
		cp	DHCP_OPT.SERVER	; Server identifier?
		jr	nz,.not54
;
		ld	hl,vars.dhcp.server
		call	read_ip
		jp	c,.eop
;
		ld	de,trace.dhcp.gotserver
		ld	bc,vars.dhcp.server
		call	traceip
;
		jp	.nextopt
.not54:
;
		cp	DHCP_OPT.LEASE	; IP lease time?
		jr	nz,.not51
;
		ld	hl,vars.dhcp.lease
		call	read_ip		; It's not an IP addr, but it is 4 bytes!
		jp	c,.eop
;
		or	a
		sbc	hl,hl
		ld	(vars.dhcp.ticks),hl		; Reset tick count
		set	vars.init.lease,(iy+vars._init)	; Got a lease time!
;
		ld	de,trace.dhcp.gotlease
		ld	bc,vars.dhcp.lease
		call	traceip
;
		jp	.nextopt
		
.not51:
;
					; Unrecognised option - just skip
.skipopt:	ld	a,b		; Get length byte
		or	a
		jr	z,.skipped
;
.skiploop:	call	socket.read_byte_0
		jp	c,.eop
;
		djnz	.skiploop
;
.skipped:	jp	.nextopt
;
;
;
; read_ip
;
; Calls udp.read_byte() 4 times to read an IP address
;
; In:  HL->buffer
;       B=length of parameter in packet
; Out: Cy=>error
read_ip:	ld	a,b		; Get #bytes to follow
		cp	4
		ret	c		; Not enough for an IP address!
;
		ld	b,4
.loop:		call	socket.read_byte_0
		ret	c
;
		ld	(hl),a
		inc	hl
		djnz	.loop
;
		ret
;
;
; DE->string
; BC->IP
; HL preserved
traceip:
		bit	vars.trace.dhcp,(iy+vars._trace)
		ret	z
;
		push	hl
		 push	bc
		  call	io.str
		 pop	hl		; HL->IP
;
		 call	io.ip
		 ld	a,','
		 call	io.char
		pop	hl
		ret
;
;
; packet_write
;
; Writes the data built up in dhcp.packet
;
; In:  BC=no.bytes in packet buffer
; Out: NC=>no error
;      HL->start of packet
packet_write:	ld	hl,vars.dhcp.packet
		push	hl
		 call	socket.write_0
		pop	hl
		ret
;
;
;
packet_init:	ld	hl,vars.dhcp.packet
		ld	bc,vars.dhcp.packet_size
		jp	util.memzero
;
;
; packet_mac
;
; Copies our MAC address into packet buffer
;
; In:  HL->packet buffer
; Out: HL updated
packet_mac:	ex	de,hl		; DE->buffer
		ld	hl,mac
		ld	bc,6
		ldir
		ex	de,hl
;
		ret
;
; packet_ip
;
; Puts a length byte and copies an IP address into packet buffer
;
; In:  HL->packet buffer
;      DE->IP address (4 bytes)
; Out: HL updated
packet_ip:	ld	(hl),4		; Length byte
		inc	hl
		ex	de,hl		; DE->buffer
		ld	bc,4
		ldir
		ex	de,hl
;
		ret
;
; packet_byte
;
; Puts a byte in ASCII into packet buffer
;
; In:  HL->packet buffer
;      DE->byte
; Out: HL and DE updated
;
packet_byte:	ld	a,(de)
		rrca
		rrca
		rrca
		rrca
		call	packet_nibble
		ld	a,(de)
		inc	de
;
packet_nibble:	and	0fh
		add	a,'0'
		cp	a,'9'+1
		jr	c,.done
;
		add	a,'A'-'9'-1
.done:		ld	(hl),a
		inc	hl
		ret
;
;
;------------------------------------------------------------------------------
; interrupt
;
; This is an interrupt routine that is called every tick (20mS). It divides
; ticks down into seconds, and then every second decrements the 32-bit lease
; time until it reaches 0.
;
interrupt:	; Increment lease tick count
		ld	hl,(vars.dhcp.ticks)
		inc	hl
		ld	(vars.dhcp.ticks),hl
;
		; See if it's reached 1S
		ld	de,TICKS_1s
		or	a
		sbc	hl,de
		ret	c
;
		; Reset the tick count back to 0
		; If it's just gone NC, HL should be 0!
		ld	(vars.dhcp.ticks),hl
;
		ld	hl,(vars.dhcp.secs)		; Inc seconds count
		inc	hl
		ld	(vars.dhcp.secs),hl

		bit	vars.init.lease,(iy+vars._init)	; Got a lease time?
		ret	z				; Return if not
;
		; Now decrement the 32-bit lease time a byte at a time,
		; starting with the LSB. If the byte is 0 before we decrement
		; it, it will decrement below 0 so we go on to do the next
		; byte. If this happens to the last byte, it's gone below 0
		; so the lease has expired
		ld	hl,vars.dhcp.lease+3
		ld	b,4
.loop:		ld	a,(hl)
		dec	(hl)
		or	a
		ret	nz
;
		dec	hl
		djnz	.loop
;
		; If we get here, it's gone -ve so set back to 0
		sbc	hl,hl
		ld	(vars.dhcp.lease),hl
		ld	(vars.dhcp.lease+2),hl
;
		ret
;
;
owner_str:	db	"DHCP",0
;
;
;
		endmodule
