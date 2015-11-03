; NTP
;
; Attempts to obtain the current date and time using the Simple Network Time
; Protocol
;
		module	ntp
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
; For reference, this is the interesting bit of RFC 4330:
;
;3.  NTP Timestamp Format
;
;   SNTP uses the standard NTP timestamp format described in RFC 1305 and
;   previous versions of that document.  In conformance with standard
;   Internet practice, NTP data are specified as integer or fixed-point
;   quantities, with bits numbered in big-endian fashion from 0 starting
;   at the left or most significant end.  Unless specified otherwise, all
;   quantities are unsigned and may occupy the full field width with an
;   implied 0 preceding bit 0.
;
;   Because NTP timestamps are cherished data and, in fact, represent the
;   main product of the protocol, a special timestamp format has been
;   established.  NTP timestamps are represented as a 64-bit unsigned
;   fixed-point number, in seconds relative to 0h on 1 January 1900.  The
;   integer part is in the first 32 bits, and the fraction part in the
;   last 32 bits.  In the fraction part, the non-significant low-order
;   bits are not specified and are ordinarily set to 0.
;
;      It is advisable to fill the non-significant low-order bits of the
;      timestamp with a random, unbiased bitstring, both to avoid
;      systematic roundoff errors and to provide loop detection and
;      replay detection (see below).  It is important that the bitstring
;      be unpredictable by an intruder.  One way of doing this is to
;      generate a random 128-bit bitstring at startup.  After that, each
;      time the system clock is read, the string consisting of the
;      timestamp and bitstring is hashed with the MD5 algorithm, then the
;      non-significant bits of the timestamp are copied from the result.
;
;   The NTP format allows convenient multiple-precision arithmetic and
;   conversion to UDP/TIME message (seconds), but does complicate the
;   conversion to ICMP Timestamp message (milliseconds) and Unix time
;   values (seconds and microseconds or seconds and nanoseconds).  The
;   maximum number that can be represented is 4,294,967,295 seconds with
;   a precision of about 232 picoseconds, which should be adequate for
;   even the most exotic requirements.
;
;                           1                   2                   3
;       0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
;      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;      |                           Seconds                             |
;      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;      |                  Seconds Fraction (0-padded)                  |
;      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;
;   Note that since some time in 1968 (second 2,147,483,648), the most
;   significant bit (bit 0 of the integer part) has been set and that the
;   64-bit field will overflow some time in 2036 (second 4,294,967,296).
;   There will exist a 232-picosecond interval, henceforth ignored, every
;   136 years when the 64-bit field will be 0, which by convention is
;   interpreted as an invalid or unavailable timestamp.
;
;      As the NTP timestamp format has been in use for over 20 years, it
;      is possible that it will be in use 32 years from now, when the
;      seconds field overflows.  As it is probably inappropriate to
;      archive NTP timestamps before bit 0 was set in 1968, a convenient
;      way to extend the useful life of NTP timestamps is the following
;      convention: If bit 0 is set, the UTC time is in the range 1968-
;      2036, and UTC time is reckoned from 0h 0m 0s UTC on 1 January
;      1900.  If bit 0 is not set, the time is in the range 2036-2104 and
;      UTC time is reckoned from 6h 28m 16s UTC on 7 February 2036.  Note
;      that when calculating the correspondence, 2000 is a leap year, and
;      leap seconds are not included in the reckoning.
;
;      The arithmetic calculations used by NTP to determine the clock
;      offset and roundtrip delay require the client time to be within 34
;      years of the server time before the client is launched.  As the
;      time since the Unix base 1970 is now more than 34 years, means
;      must be available to initialize the clock at a date closer to the
;      present, either with a time-of-year (TOY) chip or from firmware.
;
; 4.  Message Format
;
;   Both NTP and SNTP are clients of the User Datagram Protocol (UDP)
;   specified in RFC 768 [POS80].  The structures of the IP and UDP
;   headers are described in the cited specification documents and will
;   not be detailed further here.  The UDP port number assigned by the
;   IANA to NTP is 123.  The SNTP client should use this value in the UDP
;   Destination Port field for client request messages.  The Source Port
;   field of these messages can be any nonzero value chosen for
;   identification or multiplexing purposes.  The server interchanges
;   these fields for the corresponding reply messages.
;
;      This differs from the RFC 2030 specifications, which required both
;      the source and destination ports to be 123.  The intent of this
;      change is to allow the identification of particular client
;      implementations (which are now allowed to use unreserved port
;      numbers, including ones of their choosing) and to attain
;      compatibility with Network Address Port Translation (NAPT)
;      described in RFC 2663 [SRI99] and RFC 3022 [SRI01].
;
NTP_CLIENT_PORT		equ	123
NTP_SERVER_PORT		equ	123
;
;   Figure 1 is a description of the NTP and SNTP message format, which
;   follows the IP and UDP headers in the message.  This format is
;   identical to the NTP message format described in RFC 1305, with the
;   exception of the Reference Identifier field described below.  For
;   SNTP client messages, most of these fields are zero or initialized
;   with pre-specified data.  For completeness, the function of each
;   field is briefly summarized below.
;
;                           1                   2                   3
;       0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
;   0: +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;      |LI | VN  |Mode |    Stratum    |     Poll      |   Precision   |
;   4: +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;      |                          Root  Delay                          |
;   8: +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;      |                       Root  Dispersion                        |
;  12: +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;      |                     Reference Identifier                      |
;  16: +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;      |                                                               |
;      |                    Reference Timestamp (64)                   |
;      |                                                               |
;  24: +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;      |                                                               |
;      |                    Originate Timestamp (64)                   |
;      |                                                               |
;  32: +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;      |                                                               |
;      |                     Receive Timestamp (64)                    |
;      |                                                               |
;  40: +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;      |                                                               |
;      |                     Transmit Timestamp (64)                   |
;      |                                                               |
;  48: +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;      |                 Key Identifier (optional) (32)                |
;      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;      |                                                               |
;      |                                                               |
;      |                 Message Digest (optional) (128)               |
;      |                                                               |
;      |                                                               |
;      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
;
;                        Figure 1.  NTP Packet Header
;
;   Leap Indicator (LI): This is a two-bit code warning of an impending
;   leap second to be inserted/deleted in the last minute of the current
;   day.  This field is significant only in server messages, where the
;   values are defined as follows:
;
;      LI       Meaning
;      ---------------------------------------------
;      0        no warning
;      1        last minute has 61 seconds
;      2        last minute has 59 seconds
;      3        alarm condition (clock not synchronized)
;
;   On startup, servers set this field to 3 (clock not synchronized), and
;   set this field to some other value when synchronized to the primary
;   reference clock.  Once set to a value other than 3, the field is
;   never set to that value again, even if all synchronization sources
;   become unreachable or defective.
;
;   Version Number (VN): This is a three-bit integer indicating the
;   NTP/SNTP version number, currently 4.  If necessary to distinguish
;   between IPv4, IPv6, and OSI, the encapsulating context must be
;   inspected.
;
;   Mode: This is a three-bit number indicating the protocol mode.  The
;   values are defined as follows:
;
;      Mode     Meaning
;      ------------------------------------
;      0        reserved
;      1        symmetric active
;      2        symmetric passive
;      3        client
;      4        server
;      5        broadcast
;      6        reserved for NTP control message
;      7        reserved for private use
;
;   In unicast and manycast modes, the client sets this field to 3
;   (client) in the request, and the server sets it to 4 (server) in the
;   reply.  In broadcast mode, the server sets this field to 5
;   (broadcast).  The other modes are not used by SNTP servers and
;   clients.
;
;   Stratum: This is an eight-bit unsigned integer indicating the
;   stratum.  This field is significant only in SNTP server messages,
;   where the values are defined as follows:
;
;      Stratum  Meaning
;      ----------------------------------------------
;      0        kiss-o'-death message (see below)
;      1        primary reference (e.g., synchronized by radio clock)
;      2-15     secondary reference (synchronized by NTP or SNTP)
;      16-255   reserved
;
;   Poll Interval: This is an eight-bit unsigned integer used as an
;   exponent of two, where the resulting value is the maximum interval
;   between successive messages in seconds.  This field is significant
;   only in SNTP server messages, where the values range from 4 (16 s) to
;   17 (131,072 s -- about 36 h).
;
;   Precision: This is an eight-bit signed integer used as an exponent of
;   two, where the resulting value is the precision of the system clock
;   in seconds.  This field is significant only in server messages, where
;   the values range from -6 for mains-frequency clocks to -20 for
;   microsecond clocks found in some workstations.
;
;   Root Delay: This is a 32-bit signed fixed-point number indicating the
;   total roundtrip delay to the primary reference source, in seconds
;   with the fraction point between bits 15 and 16.  Note that this
;   variable can take on both positive and negative values, depending on
;   the relative time and frequency offsets.  This field is significant
;   only in server messages, where the values range from negative values
;   of a few milliseconds to positive values of several hundred
;   milliseconds.
;
;      Code       External Reference Source
;      ------------------------------------------------------------------
;      LOCL       uncalibrated local clock
;      CESM       calibrated Cesium clock
;      RBDM       calibrated Rubidium clock
;      PPS        calibrated quartz clock or other pulse-per-second
;                 source
;      IRIG       Inter-Range Instrumentation Group
;      ACTS       NIST telephone modem service
;      USNO       USNO telephone modem service
;      PTB        PTB (Germany) telephone modem service
;      TDF        Allouis (France) Radio 164 kHz
;      DCF        Mainflingen (Germany) Radio 77.5 kHz
;      MSF        Rugby (UK) Radio 60 kHz
;      WWV        Ft. Collins (US) Radio 2.5, 5, 10, 15, 20 MHz
;      WWVB       Boulder (US) Radio 60 kHz
;      WWVH       Kauai Hawaii (US) Radio 2.5, 5, 10, 15 MHz
;      CHU        Ottawa (Canada) Radio 3330, 7335, 14670 kHz
;      LORC       LORAN-C radionavigation system
;      OMEG       OMEGA radionavigation system
;      GPS        Global Positioning Service
;
;                     Figure 2.  Reference Identifier Codes
;
;   Root Dispersion: This is a 32-bit unsigned fixed-point number
;   indicating the maximum error due to the clock frequency tolerance, in
;   seconds with the fraction point between bits 15 and 16.  This field
;   is significant only in server messages, where the values range from
;   zero to several hundred milliseconds.
;
;   Reference Identifier: This is a 32-bit bitstring identifying the
;   particular reference source.  This field is significant only in
;   server messages, where for stratum 0 (kiss-o'-death message) and 1
;   (primary server), the value is a four-character ASCII string, left
;   justified and zero padded to 32 bits.  For IPv4 secondary servers,
;   the value is the 32-bit IPv4 address of the synchronization source.
;   For IPv6 and OSI secondary servers, the value is the first 32 bits of
;   the MD5 hash of the IPv6 or NSAP address of the synchronization
;   source.
;
;   Primary (stratum 1) servers set this field to a code identifying the
;   external reference source according to Figure 2.  If the external
;   reference is one of those listed, the associated code should be used.
;   Codes for sources not listed can be contrived, as appropriate.
;
;      In previous NTP and SNTP secondary servers and clients, this field
;      was often used to walk-back the synchronization subnet to the root
;      (primary server) for management purposes.  In SNTPv4 with IPv6 or
;      OSI, this feature is not available, because the addresses are
;      longer than 32 bits, and only a hash is available.  However, a
;      walk-back can be accomplished using the NTP control message and
;      the reference identifier field described in RFC 1305.
;
;   Reference Timestamp: This field is the time the system clock was last
;   set or corrected, in 64-bit timestamp format.
;
;   Originate Timestamp: This is the time at which the request departed
;   the client for the server, in 64-bit timestamp format.
;
;   Receive Timestamp: This is the time at which the request arrived at
;   the server or the reply arrived at the client, in 64-bit timestamp
;   format.
;
;   Transmit Timestamp: This is the time at which the request departed
;   the client or the reply departed the server, in 64-bit timestamp
;   format.
;
;   Authenticator (optional): When the NTP authentication scheme is
;   implemented, the Key Identifier and Message Digest fields contain the
;   message authentication code (MAC) information defined in Appendix C
;   of RFC 1305.
;
;------------------------------------------------------------------------------
; init
;
; Called to get the current time.
;
; dhcp.dns must contain the time server ip address.
;
; Out:  NC=>ok
;
init:
		ld	de,trace.diag.ntp	; Diag mode trace
		call	trace.diag.str
;
		xor	a
		ld	(vars.ntp.retries),a
;
		call	status.start	; Start waiting indicator
;
		ld	de,owner_str	; Our name
		ld	hl,NTP_CLIENT_PORT	; Always use this port
		call	udp.open_0	; Open socket
		jr	c,.error
;
		jr	.start
;
.error:		bit	vars.trace.ntp,(iy+vars._trace)
		call	nz,trace.error
;
.abort:		call	socket.close_0
		call	status.stop	; Stop waiting indicator
		scf
		ret
;
.start:
		ld	hl,vars.ntp.retries
		inc	(hl)
		ld	a,10
		cp	(hl)
		jr	c,.error	; Try 10 times, then give up
;
		call	send		; Send a time request
		jr	c,.error
;
		; Wait for a replay with timeout
		ld	hl,(vars.ticks)
		ld	(vars.ntp.timeout),hl
.loop:		call	udp.header_0
		jr	nz,.gotpacket
;
		call	status.waiting	; Flash status indicator
;
		call	exos.is_stop
		jr	c,.abort
;
		ld	de,(vars.ntp.timeout)
		ld	hl,(vars.ticks)
		or	a
		sbc	hl,de		; HL=duration so far
		ld	de,TICKS_1s	; 1S timout in ticks
		sbc	hl,de
		jr	c,.loop		; Keep waiting if not timed out
;
		bit	vars.trace.ntp,(iy+vars._trace)
		call	nz,trace.timeout
;
		jr	.start		; Timed out...send req again
;
.badpacket:	bit	vars.trace.ntp,(iy+vars._trace)
		call	nz,trace.error
		jr	.start
;
.gotpacket:
		bit	vars.trace.ntp,(iy+vars._trace)
		jr	z,.donetrace
;
		call	io.start
		ld	de,trace.ntp.rx
		call	io.str
.donetrace:
;
		or	a
		ld	bc,vars.ntp.packet_size
		sbc	hl,bc
		jr	c,.badpacket	; Too small - ignore
;
		ld	hl,vars.ntp.packet
		ld	bc,vars.ntp.packet_size
		call	socket.read_0	; Read start of NTP packet
		call	socket.read_end_0
;
		; Check packet has come from the right port
		ld	hl,(vars.udp.port)
		ld	bc,NTP_SERVER_PORT; Standard server port
		or	a
		sbc	hl,bc
		jr	nz,.badpacket
;
		bit	vars.trace.ntp,(iy+vars._trace)
		jr	z,.donetrace2
;
		ld	hl,vars.ntp.packet.transmit+3	; Time packet left server
		ld	e,(hl)
		dec	hl
		ld	d,(hl)
		dec	hl
		push	hl
		 ex	de,hl
		 call	io.int
		pop	hl
		ld	a,','
		call	io.char
		ld	e,(hl)
		dec	hl
		ld	d,(hl)
		ex	de,hl
		call	io.int

.donetrace2:
		call	socket.close_0
		call	status.stop	; Stop waiting indicator
		or	a		; NC=>no error
		ret
;
;
;------------------------------------------------------------------------------
; send
;
; Sends a request to the time server
;
; Out: NC=>ok
send:
		; If we got an NTP address via DHCP, we use that. Otherwise
		; we use the standard broadcast address
		ld	hl,vars.dhcp.ntp; HL->DHCP NTP IP adrdess
		ld	a,(hl)		; 0=>not set
		or	a
		jr	nz,.gotntp	; Go if got an IP address via DHCP
;
		ld	hl,broadcast_ip	; Else use standard broadcast
.gotntp:	ld	de,vars.udp.ip	; Copy IP to use to udp.ip
		ld	bc,4
		ldir
;
		ld	hl,NTP_SERVER_PORT	; Standard NTP port
		ld	(vars.udp.port),hl
;
		bit	vars.trace.ntp,(iy+vars._trace)
		jr	z,.donetrace
;
		call	io.start
		ld	de,trace.ntp.tx
		call	io.str
		ld	hl,vars.udp.ip
		call	io.ip
		ld	a,':'
		call	io.char
		ld	hl,(vars.udp.port)
		call	io.int
		call	trace.dots
.donetrace:
		; Construct a SNTP packet
		ld	hl,vars.ntp.packet
		ld	bc,vars.ntp.packet_size
		push	hl			; Save ->packet
		push	bc			; Save packet size
		 call	util.memzero		; Zero packet buffer
;
		 ld	(hl),11100011b		; LI, Version, mode
		 inc	hl			; HL->stratum
		 inc	hl			; HL->poll
		 ld	(hl),6			; Poll interval=6
		 inc	hl			; HL->Precision
		 ld	(hl),0ech
;
		 ld	hl,vars.ntp.packet.identifier
		 ld	(hl),49
		 inc	hl
		 ld	(hl),4eh
		 inc	hl
		 ld	(hl),49
		 inc	hl
		 ld	(hl),52
		pop	bc			; BC=packet size
		pop	hl			; HL->packet
		call	socket.write_0
;
		jp	udp.send_0
;
;broadcast_ip:	db	224,0,1,1	; Standard NTP default broadcast ip
broadcast_ip:	db	255,255,255,255	; Standard NTP default broadcast ip
;
;
owner_str:	db	"NTP",0
;
;
		endmodule
