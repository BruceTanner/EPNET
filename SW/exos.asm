; EXOS
;
; This module contains EXOS-specific things
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
		macro EXOS n
		 rst 30H
		 db  n
		endm
;
		module	exos
;
;------------------------------------------------------------------------------
;
;		        EXOS FIXED VARIABLES
;		      ========================
;
;
USR_P3		equ	0BFFFh	;Four segments which were in Z-80 space
USR_P2		equ	0BFFEh	; when EXOS was last called.
USR_P1		equ	0BFFDh
USR_P0		equ	0BFFCh

STACK_LIMIT	equ	0BFFAh	;Bottom limit of stack for devices.

RST_ADDR	equ	0BFF8h	;Warm reset address

ST_POINTER	equ	0BFF6h	;Address of status line RAM
LP_POINTER	equ	0BFF4h	;Address of start of video LPT.

PORTB5		equ	0BFF3h	;Current contents of Z-80 port 0B5h.

FLAG_SOFT_IRQ	equ	0BFF2h	;Flag <>0 to cause software interrupt.

SEC_COUNTER	equ	0BFF0h	;16-bit second counter

CR_DISP		equ	0BFEEh	;Flag <>0 to supress signon display

USER_ISR	equ	0BFEDh	;User's interrupt routine address.
;
;
;------------------------------------------------------------------------------
;
;			FUNCTION CODES
;		      ==================
;
;
FN_RESET	equ	0		; Reset system
FN_OPEN		equ	1		; Open channel
FN_CREATE	equ	2		; Create channel
FN_CLOSE	equ	3		; Close channel
FN_DEST		equ	4		; Destroy channel
FN_RDCH		equ	5		; Read character
FN_RDBLK	equ	6		; Read block
FN_WRCH		equ	7		; Write character
FN_WRBLK	equ	8		; Write block
FN_RSTAT	equ	9		; Read status
FN_SSTAT	equ	10		; Set channel status 
FN_SFUNC	equ	11		; Special function
FN_EVAR		equ	16		; Set/read/toggle EXOS variable
FN_CAPT		equ	17		; Capture channel
FN_REDIR	equ	18		; Re-direct channel
FN_DDEV		equ	19		; Set default device
FN_SYSS		equ	20		; Return system status
FN_LINK		equ	21		; Link device
FN_READB	equ	22		; Read EXOS boundary
FN_SETB		equ	23		; Set USER boundary
FN_ALLOC	equ	24		; Allocate segment
FN_FREE		equ	25		; Free segment
FN_ROMS		equ	26		; Locate ROMs
FN_BUFF		equ	27		; Allocate channel buffer
FN_ERRMSG	equ	28		; Return error message.
FN_LD		equ	29		; Load module
FN_REL		equ	30		; Load relocatable module
FN_STIME	equ	31		; Set time
FN_RTIME	equ	32		; Read time
FN_SDATE	equ	33		; Set date
FN_RDATE	equ	34		; Read date




;******************************************************************************
;
;
;			ERROR CODES
;		     =================
;
;
;	General errors returned by the EXOS kernel 
;
ERR_IFUNC	equ	0FFh	;Invalid function code
ERR_ILLFN	equ	0FEh	;EXOS function call not allowed
ERR_INAME	equ	0FDh	;Invalid name string
ERR_STACK	equ	0FCh	;Insufficient stack
;
ERR_ICHAN	equ	0FBh	;Channel does not exist.
ERR_NODEV	equ	0FAh	;Device does not exist  (OPEN/CREATE)
ERR_CHANX	equ	0F9h	;Channel already exists (OPEN/CREATE)
ERR_NOBUF	equ	0F8h	;No ALLOCATE BUFFER call made (OPEN/CREATE)
ERR_NORAM	equ	0F7h	;Insufficient RAM for buffer.
ERR_NOVID	equ	0F6h	;Insufficient video RAM.
;
ERR_NOSEG	equ	0F5h	;No free segments (ALLOCATE SEG)
ERR_ISEG	equ	0F4h	;Invalid segment (FREE SEGequ SET BOUNDARY)
ERR_IBOUN	equ	0F3h	;Invalid user boundary (SET USER BOUND)
ERR_IVAR	equ	0F2h	;Invalid EXOS variable number 
ERR_IDESC	equ	0F1h	;Invalid device descriptor type (LINK DEV)
;
ERR_NOSTR	equ	0F0h	;String not recognized by ROMs.
ERR_ASCII	equ	0EFh	;Not a valid enterprise module header
ERR_ITYPE	equ	0EEh	;Un-recognized module type
ERR_IREL	equ	0EDh	;Invalid relocatable file 
ERR_NOMOD	equ	0ECh	;End of file module found
;
ERR_ITIME	equ	0EBh	;Invalid time or date 
;               
;               
;               
;	errors rturned by various devices
;              
ERR_ISPEC	equ	0EAh	;Invalid special function code
ERR_CH2ND	equ	0E9h	;Attempt to open second channel
ERR_IUNIT	equ	0E8h	;Invalid unit number specified for OPEN/CRTE
ERR_NOFN	equ	0E7h	;Function not supported
ERR_ESC	equ	0E6h	;Invalid escape character
ERR_STOP	equ	0E5h	;Stop key pressed
ERR_EOF	equ	0E4h	;Unexpected end of file
ERR_PROT	equ	0E3h	;Protection violation
;
;
;
;	Keyboard errors

ERR_KFSPC	equ	0E2h	;Run out of function key space
;                               
;                               
;                               
;	Sound errors            
;                               
ERR_SENV	equ	0E1h	;Envelope is too big or number 255.
ERR_SENBF	equ	0E0h	;Not enough room to define envelope
ERR_SQFUL	equ	0DFh	;Sound queue is full (and WAIT_SND <> 0)
;                               
;                               
;                               
;	Video errors            
;                               
ERR_VSIZE	equ	0DEh	;Invalid X or Y size to OPEN
ERR_VMODE	equ	0DDh	;Invalid video mode to OPEN
ERR_VDISP	equ	0DCh	;Naff parameter to DISPLAY
ERR_VLOAD	equ	0DBh	;Invalid file to LOAD
;        
ERR_VROW	equ	0DAh	;Invalid row number to scroll
ERR_VCURS	equ	0D9h	;Attempt to move cursor off page
ERR_VBEAM	equ	0D8h	;Attept to move beam off page
;                               
;                               
;                               
;	Serial/Network erors
;                               
ERR_SEROP	equ	0D7h	;Serial device open - cannot use network
ERR_NOADR	equ	0D6h	;ADDR_NET not set up
ERR_NETOP	equ	0D5h	;Network link already exists
;                               
;                               
;                               
;	Editor errors           
;                               
ERR_EVID	equ	0D4h	;Video channel error
ERR_EKEY	equ	0D3h	;Keyboard channel error
ERR_EDINV	equ	0D2h	;Editor - invalid LOAD file
ERR_EDBUF	equ	0D1h	;Editor - Buffer full in LOAD
;                               
;                               
;                               
;	Cassette errors         
;                               
ERR_CCRC	equ	0D0h	;CRC error from cassette driver
;
;
;
;	EPNET errors
;
ERR_LAST	equ	06fh		;Last EPNET error code number
;
ERR_DHCP	equ	ERR_LAST-0	;Timeout trying to get IP values via DHCP
ERR_NONET	equ	ERR_LAST-1	;Cannot communicate with WIZ chip
ERR_BADIP	equ	ERR_LAST-2	;Invalid IP address
ERR_BADOPT	equ	ERR_LAST-3	;Invalid command option
ERR_NOCON	equ	ERR_LAST-4	;Cannot open connection
ERR_TIMEOUT	equ	ERR_LAST-5	;No response from server
ERR_FTP		equ	ERR_LAST-6	;Unexpected FTP error
ERR_NOFIL	equ	ERR_LAST-7	;File not found
ERR_NOTIME	equ	ERR_LAST-8	;Cannot get time
ERR_DUPIP	equ	ERR_LAST-9	;Duplicate IP address on network
ERR_FTPDATA	equ	ERR_LAST-10	;Cannot open data connection
ERR_BADHTTP	equ	ERR_LAST-11	;Invalid HTTP response
ERR_SOCK	equ	ERR_LAST-12	;No free sockets
;
ERR_FIRST	equ	ERR_LAST-12
;
;
;------------------------------------------------------------------------------
;
;		  WARNING CODES
;		=================
;
ERR_SHARE	equ	07Fh		;Shared segment allocated
;
;
;
;******************************************************************************
;
;
;			  EXOS VARIABLE NUMBERS
;			=========================
;
;
;
;
VAR_IRQ_ENABLE	equ	0	; Interrupt enable bits.
;
VAR_FLAG_SIRQ	equ	1	; Flag to cause a software interrupt.
VAR_CODE_SIRQ	equ	2	; Software Interrupt code.
;
VAR_DEF_TYPE	equ	3	; Type of default device.
VAR_DEF_CHAN	equ	4	; Default channel number.
;
VAR_TIMER	equ	5	; 1Hz down counter.
;
VAR_LOCK_KEY	equ	6	; Keyboard lock status.
VAR_CLICK_KEY	equ	7	; Key click enable/disable.
VAR_STOP_IRQ	equ	8	; Software interrupt on STOP key.
VAR_KEY_IRQ	equ	9	; Software interrupt on any key press.
VAR_RATE_KEY	equ	10	; Keyboard auto-repeat rate.
VAR_DELAY_KEY	equ	11	; Delay before auto-repeat starts.
;
VAR_TAPE_SND	equ	12	; Tape sound enable/dispable.
;
VAR_WAIT_SND	equ	13	; Sound driver waiting if buffer full
VAR_MUTE_SND	equ	14	; Sound mute enable/disable.
VAR_BUF_SND	equ	15	; Sound envelope storage size.
;
VAR_BAUD_SER	equ	16	; Serial baud rate.
VAR_FORM_SER	equ	17	; Serial word format.
VAR_ADDR_NET	equ	18	; Network address of this machine
VAR_NET_IRQ	equ	19	; Software interrupt on network.
VAR_CHAN_NET	equ	20	; Channel for network block.
VAR_MACH_NET	equ	21	; Source machine for network block.
;
VAR_MODE_VID	equ	22	; Video mode.
VAR_COLR_VID	equ	23	; Video colour mode.
VAR_X_SIZ_VID	equ	24	; Video X page size.
VAR_Y_SIZ_VID	equ	25	; Video Y page size.
;
VAR_ST_FLAG	equ	26	; Status line displayed flag.
VAR_BORD_VID	equ	27	; Border colour.
VAR_BIAS_VID	equ	28	; Fixed bias colour.
;
VAR_VID_EDIT	equ	29	; Video channel number.
VAR_KEY_EDIT	equ	30	; Keyboard channel number.
VAR_BUF_EDIT	equ	31	; Size of edit buffer.
VAR_FLG_EDIT	equ	32	; Editor control flags
;
VAR_SP_TAPE	equ	33	; Cassette I/O speed.
VAR_PROTECT	equ	34	; Cassette protection control
VAR_LV_TAPE	equ	35	; Cassette level control
VAR_REM1	equ	36	; Cassette remote 1
VAR_REM2	equ	37	; Cassette remote 2
;
VAR_SPRITE	equ	38	; Sprite colour priority
;
VAR_RANDOM	equ	39	; Random interrupt counter
;
;
;
;******************************************************************************
;
;
;		SOFTWARE INTERRUPT CODES
;	      ============================
;
;
INT_FKEY	equ	10h		;Function keys 10h...1Fh
INT_STOP	equ	20h		;Stop key
INT_KEY		equ	21h		;'any key' 21h
;
INT_NET		equ	30h		;Network data received.
;
INT_TIME	equ	40h		;TIMER reached zero
;
;
;
;------------------------------------------------------------------------------
;
;
;		SPECIAL FUNCTION CODES
;	      ==========================
;
;
FN_VID_DISP	equ	01h		; VIDEO - Display page
FN_VID_SIZE	equ	02h		; VIDEO - Return page size & mode
FN_VID_ADDR	equ	03h		; VIDEO - Return page address
FN_VID_FONT	equ	04h		; VIDEO - Initialise character font
;
FN_KEY_FKEY	equ	08h		; KEYBOARD - Program function key
FN_KEY_JOY	equ	09h		; KEYBOARD - Read joystick
;
FN_NET_FLSH	equ	10h		; NETWORK  - Flush buffer
FN_NET_CLR	equ	11h		; NETWORK  - Clear buffers
;
FN_ED_MARG	equ	18h 		; EDITOR   - Set margins
FN_ED_CHLD	equ	19h		; EDITOR   - Load document file
FN_ED_CHSV	equ	1Ah		; EDITOR   - Save document file
;
;
;
;------------------------------------------------------------------------------
;
;
;		ROM ACTION CODES
;	      ====================
;
;
ACT_NULL	equ	00h		;Do nothing.
ACT_COLD	equ	01h		;Cold restart.
ACT_STR		equ	02h		;Pass user string
ACT_HELP	equ	03h		;Help string
ACT_EVAR	equ	04h		;Unknown EXOS variable
ACT_ERR		equ	05h		;Explain error code
ACT_LOAD	equ	06h		;Load module of given type
ACT_RAM		equ	07h		;Claim RAM 
ACT_INIT	equ	08h		;Initialise ROM
;
;
;
;------------------------------------------------------------------------------
;
;
;		LOAD MODULE HEADER TYPES
;	      ============================
;
;
MOD_ASCII	equ	00h		;ASCII file 
MOD_4TH		equ	01h		;FORTH
MOD_REL		equ	02h		;Relocatable module
MOD_XBAS	equ	03h		;Multiple BASIC program
MOD_BAS		equ	04h		;Single BASIC program
MOD_APP		equ	05h		;New applications program
MOD_XABS	equ	06h		;Absolute system extension
MOD_XREL	equ	07h		;Relocatable system extension
MOD_EDIT	equ	08h		;Editor document file
MOD_LISP	equ	09h		;Lisp memory image
MOD_EOF		equ	0Ah		;End of file module 
MOD_VID		equ	0Bh		;Video page file.
;
;
;------------------------------------------------------------------------------
; is_stop
;
; Returns with Cy set if the stop key is pressed. Nothing else corrupted.
;
is_stop:	push	af
		ld	a,(exos.FLAG_SOFT_IRQ)
		cp	20h		; STOP key
		jr	z,.scfret
;
		pop	af
		or	a
		ret

.scfret:	pop	af
		scf
		ret
;
;
; check_stop
;
; Called with an error code in A, returns ERR_STOP instead (and Cy) if the stop ; key has been pressed.
;
check_stop:	call	is_stop
		ccf
		ret	c
;
		ld	a,ERR_STOP
		scf
		ret
;
;
;------------------------------------------------------------------------------
;
explain:	ld	a,b
;
		sub	ERR_FIRST	; A=0-based error code if ours
		ret	c		; Ret if error code < our lowest
;
		cp	ERR_LAST-ERR_FIRST+1
		ret	nc		; Ret if erro code > our highest
;
		ld	hl,messages	; HL->table of message addresses
		ld	e,a
		ld	d,0		; DE=offset into table
		add	hl,de
		add	hl,de		; HL->message for error code
		ld	e,(hl)
		inc	hl
		ld	d,(hl)		; DE->message
;
		in	a,(ep.P3)	; Get page containing message
		ld	b,a		; B=page, DE->message
		ld	c,0		; C=0=>explained
		ret
;

messages:				; Same order as error codes, lowest first!
		dw	SOCK_str
		dw	BADHTTP_str
		dw	FTPDATA_str
		dw	DUPIP_str
		dw	NOTIME_str
		dw	NOFIL_str
		dw	FTP_str
		dw	TIMEOUT_str
		dw	NOCON_str
		dw	BADOPT_str
		dw	BADIP_str
		dw	NONET_str
		dw	DHCP_str
;
;                                             1         2         3         4
;                    screen col:     1        0         0         0         0
;                                    |--------|---------|---------|---------|
;                                    *** 
SOCK_str	db	SOCK_str_lem,	"No free sockets"
SOCK_str_len	equ	$-SOCK_str-1	; -1 to exclude length byte itself
;
DHCP_str:	db	DHCP_str_len,	"Cannot get IP address etc with DHCP"
DHCP_str_len	equ	$-DHCP_str-1	; -1 to exclude length byte itself
;
NONET_str:	db	NONET_str_len,	"Cannot communicate with EPNET"
NONET_str_len	equ	$-NONET_str-1	; -1 to exclude length byte itself
;
BADIP_str:	db	BADIP_str_len,	"Invalid IP address"
BADIP_str_len	equ	$-BADIP_str-1	; -1 to exclude length byte itself
;
BADOPT_str:	db	BADOPT_str_len,	"Invalid option"
BADOPT_str_len	equ	$-BADOPT_str-1	; -1 to exclude length byte itself
;
NOCON_str:	db	NOCON_str_len,	"Cannot connect"
NOCON_str_len	equ	$-NOCON_str-1	; -1 to exclude length byte itself
;
TIMEOUT_str:	db	TIMEOUT_str_len,"No response from server"
TIMEOUT_str_len	equ	$-TIMEOUT_str-1	; -1 to exclude length byte itself
;
FTP_str:	db	FTP_str_len,	"Unexpected FTP error"
FTP_str_len	equ	$-FTP_str-1	; -1 to exclude length byte itself
;
NOFIL_str:	db	NOFIL_str_len,	"File not found or access denied"
NOFIL_str_len	equ	$-NOFIL_str-1	; -1 to exclude length byte itself
;
NOTIME_str:	db	NOTIME_str_len,	"Cannot get time & date with NTP"
NOTIME_str_len	equ	$-NOTIME_str-1	; -1 to exclude length byte itself
;
DUPIP_str:	db	DUPIP_str_len,	"Duplicate IP address on network"
DUPIP_str_len	equ	$-DUPIP_str-1	; -1 to exclude length byte itself
;
FTPDATA_str:	db	FTPDATA_str_len, "Cannot open FTP data session"
FTPDATA_str_len	equ	$-FTPDATA_str-1	; -1 to exclude length byte itself
;
BADHTTP_str	db	BADHTTP_str_len, "Unexpected HTTP response"
BADHTTP_str_len	equ	$-BADHTTP_str-1	; -1 to exclude length byte itself
;
;
;
		endmodule
