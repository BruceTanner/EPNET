; COMMAND
;
; This module implements the EXOS commands
;
		module command
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
; help
;
; Passed a command at (DE), looks to see if it is one of our commands and
; prints help text if it is.
;
; Most of our commands are of the form :NET <cmd>, so we have to deal with
; these sub-commands. eg. :NET STATUS. But some of our commands are also "top
; level" commands, eg :FTP, :PING so we have to cope with these too.
;
; :HELP			prints a general help line
; :HELP NET		prints a help page showing all the :NET commands
; :HELP NET <cmd>	prints specific help for :NET <cmd>
; :HELP <cmd>		prints specific help for top-level command <cmd>
;
; The top-level commands are also :NET commands eg :NET FTP, :NET PING work
;
; But there is also a :NET HELP command! This works the same way eg
;
; :NET HELP		same as :HELP NET
; :NET HELP <cmd>	same as :HELP NET <cmd>
;
; and, yes, you can also go :NET HELP NET <cmd> but it must print out the help
; for <cmd> assuming <cmd> is a :NET command, not a top level command.
; 
; In:  B=length. 0 if it's general help ie. just :HELP rather than :HELP <cmd>
;     DE->command
;
help:
		ld	a,b		; See if it's general or specific HELP
		or	a
		ld	hl,.nothelpnet	; :HELP <not-net-cmd> goes to here
		jr	nz,specific
;
		push	de		; General help so just print message
		push	bc
		 ld	de,version_str
		 call	io.str
		pop	bc
		pop	de
		ret			; Preserving DE and B
;		
.nothelpnet:	; Not :HELP NET (eg. :HELP FTP or :HELP PING) 
		ld	hl,main_tab	; Find command in our command table
		call	find		; HL=offset into command table
		ret	c		; Cy=>Not found
;
;
		ld	de,main_help_tab; Find help text ptr in help table
get_help:	add	hl,de
		ld	e,(hl)		; Get pointer to command help text
		inc	hl
		ld	d,(hl)
		jr	helpout		; Just print general NET help
;
helpnet:	ld	de,net_help_str	; HELP NET with no extra commands
helpout:	CALL	io.str
		xor	a
                ld	c,a		; C=0 => recognized
                ret
;
nethelp:	; This is :NET HELP
		jr	z,helpnet	; :NET HELP => :HELP NET!
;
		ld	hl,notnethelpnet; :NET HELP <cmd> goes to here
;
specific:	; :HELP <cmd> searches the top level commands for <cmd>
		; :NET HELP <cmd> searches the NET command table
		; :HELP NET <cmd> and :NET HELP NET <cmd> both do the same
		; so here HL->action if the next word is not NET
		push	hl
		 ld	hl,net_str	; :HELP NET or :NET HELP NET?
                 call	compare
		pop	hl
		jp	nz,jphl		; Go & check for other commands if not
;
		ld 	b,net_str_len	; Skip NET to find sub-command
		call	skip
;
		jr	z,helpnet	; Go if none
;
notnethelpnet:	ld	hl,net_tab	; Find command in our command table
		call	find		; HL=offset into command table
		jr	c,helpnet	; Go if not found
;
		ld	de,net_help_tab	; Find help text ptr in help table
		jr	get_help
;
;
;------------------------------------------------------------------------------
; command
;
; Passed a command at (DE), looks to see if it one of ours and executes it if so.
;
; In:  B=length
;     DE->command
; Out: C=0 and A=error code if command recognised, else B & DE preserved
;
command:
		ld	hl,main_tab	; Find command in our command table
		call	find		; HL=offset into command table
		ret	c		; Cy=>Not found
;
		push	af		; Save flags from find
		 ld	a,(vars.trace)	; If tracing is on set up _tab video cols
		 or	a		;   before jumping to command
		 call	nz,trace.set_cols
		pop	af		; F=result from find
;
		push	de
		 ld	de,main_cmd_tab
		 add	hl,de
		pop	de
jp_cmd:		ld	a,(hl)		; Get poointer to command routine
		inc	hl
		ld	h,(hl)
		ld	l,a
@jphl:		jp	(hl)		; Jump to command
;
;
;------------------------------------------------------------------------------
; compare
;
; Checks to see if the command at (DE) is the same as that at (HL).
; (HL) is length byte first; B is the length of the user's command
; In:  DE->user's command, length byte first
;       B=length of user's command (ie. first word)
;      HL->Command string in upper case, length byte first
;       Z=>command matches
;
compare:
 		ld	 a,b		; Compare length first
                cp	 (hl)
                ret	 nz		; Not the same so command does not match
;
                push	 bc		; Save length of command word
                push	 de		; And -> start of command
                 inc	 de
                 inc	 hl
.loop          	 ld	 a,(de)
		 call	 util.upper
                 sub	 (hl)		; See if chars the same
                 jr	 nz,.notequal	; Go with NZ if not
;
                 inc	 hl		; Else compare next char
                 inc	 de
                 djnz	 .loop		; Still Z when end
;
.notequal       pop	 de		; Return DE->command
                pop	 bc		; B=length
                ret
;
;
;------------------------------------------------------------------------------
; find
;
; Finds a command in table of commands that we understand
; 
; In:  DE->command
;       B=length of command (up to first space)
;      HL->table of command strings
; Out: DE not corrupted
;      BC not corrupted, except B=length of next word if found
;      Cy=>not found, else Z according to B
;      NZ=>not found
;      HL=offset into table if found
;
find:
		push	hl		; Save start of table
;
.loop:		 push	hl		; Save current entry pointer
;
		  ld	a,(hl)		; Get pointer to string from table in HL
		  inc	hl
		  ld	h,(hl)
		  ld	l,a
		  or	h
		  jr	z,.end		; 0 => end of table, A=0
;
		  call	compare		; See if string = command
		 pop	hl		; HL->back to table entry
		 jr	z,.gotcmd	; Got match
;
		 inc	hl		; Point to next table entry
		 inc	hl
		 jr	.loop		; Try next command in table

.end:		 pop	hl		; Drop current table pointer
		pop	hl		; Drop start of table pointer
		scf			; Cy=>not found
		ret
;
.gotcmd:	 ex	de,hl		; HL->command, DE->table entry
		 ex	(sp),hl		; (SP)->command, HL->start of table
		 ex	de,hl		; HL->table entry, DE->start of table
		 or	a
		 sbc	hl,de		; HL=offset into table
;
		pop	de		; DE->command
;
		push	hl
		 call	skip
		pop	hl
;
		ret
;
;
;------------------------------------------------------------------------------
; skip
;
; Takes an EXOS command string at (DE) and skips B chars, returning the length
; of the next word in B in EXOS-compatible manner.
;
; In:  DE->length byte of a command and is adjusted to skip B bytes
;       B=number of chars to skip
; Out: DE adjusted
;       B=length of the next word
;      AF=flags set according to B (ie. Z if no more command) and NC
;
skip:
		ex	de,hl		; HL->command
		push	hl		; Save start of command
		 ld	a,l		; Add on B bytes
		 add	a,b
		 ld	l,a
		 jr	nc,.skipinc
;
		 inc	h
.skipinc:
		 ex	(sp),hl		; (SP)=adjusted command ptr, HL->start
		 ld	a,(hl)		; Get and adjust length byte
		 sub	b
		 ld	b,a
		pop	hl		; HL=adjusted command ptr
		ex	de,hl		; Back in DE
		    ;
		    ;
		    ;
;
;------------------------------------------------------------------------------
; unspace
;
; Skips leading spaces from a command at (DE)
;
; In:  DE->buffer length byte of command but the length is actually in B
;       B=length of command
; Out: DE may have been incremented but a new length byte is at (DE)
;       B=length of the next word
;      AF=flags set according to B (ie. Z if no more command) and NC
;
unspace:
		inc	b		; Adjust for first time round loop
.loop:		inc	de		; Next char in command
		dec	b		; Dec length
		jr	z,.setlen
		ld	a,(de)
		cp	' '
		jr	z,.loop		; Skip if space
;
.setlen:	dec	de		; DE->length byte
		ld	a,b
		ld	(de),a		; New length byte

; To make it EXOS compatible we need the length of the first command in B
		ld	l,e		; HL->length byte of command
		ld	h,d
		ld	b,-1		; Count of chars in first word
.count:  	inc	hl
		inc	b		; B == length byte => end of line
		ld	a,(de)
		sub	b
		jr	z,.ret		; A=0
;
		ld	a,(hl)
		sub	' '
		jr	nz,.count
;
.ret:		or	b		; NC
		ret
;
;
;==============================================================================
; NET command
;
net:		jr	z,.nonet
;
		ld	hl,net_tab	; Find command in our command table
		call	find		; HL=offset into command table
		jr	c,.badnet	; Go if not found
;
		push	de
		 ld	de,net_cmd_tab
		 add	hl,de
		pop	de
		jp	jp_cmd		; Jump to command code
;
;
.badnet:	ld	a,exos.ERR_BADOPT
		ld	c,0
		ret
;
.nonet:		ld	de,net_help_str
		call	io.str
		xor	a
		ld	c,a
		ret
;
;
;------------------------------------------------------------------------------
; NET START and NET DIAG commands
;
; NET DIAG is exactly the same as NET START except that it enables diagnostic
; tracing.
;
net_diag:
		ld	l,(iy+vars._trace)
		push	hl		; Save trace flags
		 set	vars.trace.diag,(iy+vars._trace); Trace mode for diag
		 call	net_start	; Otherwise as :NET START
		pop	hl		; L=saved trace flags
		ld	(iy+vars._trace),l	; Restore trace flags
		ret
;
;
net_start:	res	vars.init.wiz,(iy+vars._init)	; Pretend not started
		    ;
		    ;
		    ;
;
;
; This is like net_start but is called from most other commands to make sure
; the network is started.
;
; Preserves DE and B.
; Returns C=0.
;
netstart:	push	de
		push	bc
		 call	wiz.init	; Attempt to initialise WIZ module
;
do_dhcp:	 sbc	a,a		; NC=>0, Cy=>ff
		 and	exos.ERR_NONET	; 0 or .ERR_NONET
		 jr	nz,.chk_stop	; Go if couldn't start

		 call	wiz.check_ip	; Check for duplicate IP address
		 sbc	a,a
		 and	exos.ERR_DUPIP
		 jr	nz,.ret
;	 
		 call	dhcp.init	; Attempt to initilaise DHCP
		 sbc	a,a		; A=0 if NC (& still NC)
		 and	exos.ERR_DHCP	; 0 or .ERR_DHCP
		 jr	z,.ret		; Go if no error
;
.chk_stop:	 ; An error was returned - see if due to the STOP key
		 call	exos.check_stop
.ret:		pop	bc
		pop	de
		ld	c,0		; Command recognised
		or	a		; Z or NZ according to error
		ret
;
;
;------------------------------------------------------------------------------
; FTP command
;
; Syntax:
;
;	:FTP
;	:FTP <ip> or <url>
;	:FTP DIR, :FTP CD etc etc
;
ftp:		jr	z,.noftp
;
		call	netstart	; Make sure the net is started
		ret	nz		; Return if couldn't
;		
		call	status.start	; Start waiting indicator
;
		ld	hl,ftp_tab	; Find FTP command in command table
		call	find		; HL=offset into command table
		jr	c,.badcmd	; Go if not found
;
		push	de		; Save command ptr
		 ld	de,ftp_cmd_tab
		 add	hl,de
		pop	de
		call	jp_cmd
;
		push	af
		call	status.stop	; Stop waiting indicator
		pop	af
		ret
;
.badcmd:	ld	a,exos.ERR_BADOPT
		ld	c,0
		ret
;
.noftp:		ld	de,ftp_help_str
		call	io.str
		xor	a
.ret:		ld	c,0
		ret
;
ftp_login:
					; ftp pathname
		ld	hl,vars.ftp.ip
		push	de
		push	bc
		 call	util.get_ip
		pop	bc
		pop	de
;
		ld	a,exos.ERR_BADIP	; Error if bad IP address
		jr	c,.ret
;
		call	skip		; DE->next arg
;
		ld	hl,vars.ftp.ip
		ld	a,1		; Always use socket 1
		push	de
		 call	ftp.open_control
		pop	de
		ld	a,exos.ERR_NOCON
		jr	c,.ret
;
		call	ftp.login
		ld	a,exos.ERR_NOCON
		jr	c,.ret


		xor	a
.ret:		push	af
		or	a
		ld	a,1
		call	nz,tcp.close	; Close if we're returning an error
		pop	af
		ld	c,0
		ret
;
;
ftp_logout:	ld	a,1
		call	ftp.logout
		ld	a,1
		call	tcp.close
		xor	a
		ld	c,a
		ret
;
ftp_status:	ld	a,1
		call	ftp.status
		ld	c,0
		ret
;
ftp_cd:		ld	a,1
		call	ftp.chdir
		ld	c,0
		ret
;
ftp_md:
		ld	a,1
		call	ftp.mkdir
		ld	c,0
		ret
;
ftp_rd:
		ld	a,1
		call	ftp.rmdir
		ld	c,0
		ret
;
ftp_del:
		ld	a,1
		call	ftp.del
		ld	c,0
		ret
;
;
ftp_ren:
		push	de		; Save ->first arg
		push	bc		; Save first arg length
		 call	skip
		pop	bc		; B=first arg length
		pop	hl		; HL->first arg
		ld	(hl),b		; Set proper length
;
		ex	de,hl		; DE->first arg, HL->second arg
		ld	a,1
		call	ftp.ren
		ld	c,0
		ret
;
ftp_dir:	ld	a,1
		call	ftp.dir
		ld	c,0
		ret
;
;
;------------------------------------------------------------------------------
; PING command
;
; eg. :NET PING 192.168.1.64
;
ping:
		jr	z,.noping	; No args - just print help text
;
		call	netstart	; Make sure the network is started
		ret	nz		; Ret if error starting
;
		push	bc
		push	de
		 ld	hl,vars.ping.ip
		 call	util.get_ip	; Read IP address from command line
		pop	de
		pop	bc
;
		ld	a,exos.ERR_BADIP
		jr	c,.ret		; Go if invalid
;
		call	skip		; Make sure nothing following
		ld	a,exos.ERR_BADIP
		jr	nz,.ret		; Go if there was
;
		ld	hl,vars.ping.ip
		call	ping.init	; Do ping
		sbc	a,a		; A=0 if NC (& still NC)
		jr	nc,.ret
;
		ld	a,exos.ERR_NONET
		call	exos.check_stop
.ret:		ld	c,0
		ret
;
.noping:	ld	de,ping_help_str
		call	io.str
		xor	a
		ld	c,a
		ret
;
;
;------------------------------------------------------------------------------
; TRACE command
;
; Use: TRACE [ON|RAW|OFF]* 
;
; eg. :NET TRACE		- Same as :NET TRACE ON
;     :NET TRACE ON		- Turns on protocol and socket tracing
;     :NET TRACE RAW		- As n:TRACE ON but additionally raw bytes
;     :NET TRACE OFF		- All tracing off
;
; So it is not possible to just have raw bytes.
;
; Currently all the EPNET code allows each protocol to be enabled separately,
; but this is over complicated for the user command so we just have ON and RAW.
;
trace:		ld	a,vars.trace.all_mask; ON (all but raw & diag)
		jr	z,.noarg	; Default to ON if no args
;
		ld	hl,trace_str_tab; Find trace command in command table
		call	find		; HL=offset into command table
		jr	c,.badcmd	; Go if not found
;
		ld	de,trace_value_tab
		srl	l		; /2 cos 1-byte table
		add	hl,de
		ld	a,(hl)
.noarg:		ld	(vars.trace),a
		xor	a		; No error
		ld	c,a		; Command recognized
		ret
;
.badcmd:	ld	a,exos.ERR_BADOPT
		ld	c,0
		ret
;
;
trace_str_tab:	dw	 on_str		; :TRACE <opt>
		dw	off_str
		dw	raw_str
		dw	0
;
trace_value_tab:db	low ~vars.trace.raw_mask; ON => all but raw bit on
		db	0			; 0  => all off
		db	0ffh			; RAW=> all on
;
;
; These need length bytes (for command table) AND terminating nulls (for
; printing)!
;
on_str:		db	2,"ON",0
off_str:	db	3,"OFF",0
raw_str:	db	3,"RAW",0
;
;
;------------------------------------------------------------------------------
; STATUS command
;
; The NET STATUS command. Prints out current IP address etc
;
status:		jr	z,.doit
;
		ld	hl,.surprise_str
		call	compare
		jr	nz,.badopt
;
		ld	de,.easteregg_str
		call	io.str
;
.ret:		xor	a
		ld	c,a
		ret
;
.badopt:	ld	a,exos.ERR_BADOPT
		ld	c,0
		ret

.doit:		call	netstart	; Make sure EPNET has started
		ret	nz		; Return if error starting
;
		call	wiz.get_MAC	; Print MAC address
		ld	de,.mac_str
		call	io.str
		call	io.mac
		call	io.crlf
;
		call	wiz.get_ip	; Print IP address
		ld	de,.ip_str
		call	io.ipcrlf
;
		call	wiz.get_subnet	; Print subnet mask
		ld	de,.subnet_str
		call	io.ipcrlf
;
		call	wiz.get_gateway	; Print gateway
		ld	de,.gateway_str
		call	io.ipcrlf
;
		; Print each socket status
		ld	de,.heading
		call	io.str
		xor	a		; Start with socket 0
.loop:		push	af		; Save socket number
		 call	io.short	; Print socket number
		 call	io.space
		pop	af		; A=socket number
;
		push	af		; Save socket number
		 call	socket.status	; HL=Sn_SSR value
		 ld	c,l		; Save status
		 ld	a,l		; A=Sn_SSR value, high byte ignored
		 cp	w5300.Sn_SSR_CLOSED
		 jr	z,.doneowner	; Don't print owner if closed
;
		pop	af		; A=socket number
		push	af		; Save socket number
		 push	bc		; Save status in C
		  call	socket.get_owner; HL->owner string
		  ex	de,hl		; DE->owner
		  call	io.str		; Print owner
		 pop	bc		; C=socket status
;
.doneowner:	 call	io.tab
		pop	af		; A=socket number
;
		push	af		; Save socket number
		 ld	a,c		; A=status value
		 push	af		; Save status value
		  call	socket.status_str	; HL->descriptive string
		  jr	c,.nostr	; Go with Cy if not found
;
		  ex	de,hl		; DE->string
		  call	io.str		; Print status description
		  or	a		; NC
.nostr:		  call	c,io.byte	; No string so print number
		 pop	af		; Get status value
		 cp	w5300.Sn_SSR_ESTAB
		 jr	nz,.doneone	; Go if not TCP ESTABLISHED state
;
		pop	af		; A=socket number
		push	af		; Save socket number
		 ld	hl,vars.command.ip	; HL->buffer for IP
		 push	hl		; Save->buffer for IP
		  call	socket.read_DIPR	; Read IP
		  call	socket.read_DPORTR	; HL=DPORTR
		  ld	c,l
		  ld	b,h		; BC=port number
		 pop	hl		; HL->ip address
;
		 push	bc		; Save port
		  ld	de,.to_str	; Print " to "
		  call	io.str
		 pop	bc		; BC=port
		 call	io.ip_port	; Print IP and port
.doneone:	 call	io.crlf
		pop	af		; A=socket number
		inc	a		; Next socket
		cp	wiz.SOCKETS	; Done all?
		jr	c,.loop		; Do next if not
;
		xor	a		; No error
		ld	c,a		; Command recognised
		ret
;
.easteregg_str:	db	"Written by BT 2015",CR,LF,0
;
.surprise_str:	db	2,"42"
;
.mac_str:	db	"MAC:\t",0
.ip_str:	db	"IP:\t",0
.subnet_str:	db	"Subnet:\t",0
.gateway_str:	db	"Gateway:",0
;
.heading:	db	CR,LF
		db	"S OWNER\tSTATE",CR,LF
		db	"--------------",CR,LF
		db	0
;
.to_str:	db	" to ",0
;
;
;------------------------------------------------------------------------------
; TIME command
;
; The NET TIME command. Gets the time and date from the network
;
time:		call	netstart
		ret	nz
;		
		call	ntp.init
		sbc	a,a		; A=0 if NC (& still NC)
		jr	nc,.ret
;
		ld	a,exos.ERR_NOTIME
		call	exos.check_stop
;
.ret:		ld	c,0		; Command recognised
		ret
;
;
;------------------------------------------------------------------------------
; special
;
; This is a special command that cannot be typed by the user. It is used by
; our ROM devices to find out our variable's RAM segment. This is allocated
; by this EXOS extension so EXOS tells us about it here, in fact pages it in
; to page 1 for us, but does not tell the devices about it, hence this call.
;
; Out:  B=RAM segment no.
;       C=I/O base address
;
special:	in	a,(ep.P1)	; Get RAM segment
		ld	b,a		; Return in B
;
		ld	a,(io)		; Get fixed ROM i/o address byte
		or	a		; Using fixed i/o?
		jr	nz,.gotio	; <>0 => yes
;
		in	a,(ep.P3)	; Else get our ROM seg no
		rrca			; /2 gives i/o base address
.gotio:		ld	e,a		; Return I/O in E
		xor	a
		ld	c,a
		ret
;
;
;------------------------------------------------------------------------------
; main commands - string table, help string table and jump table in same order!
;
main_tab:	dw	    net_str
		dw	    ftp_str
		dw	   ping_str
		dw	special_str
		dw	0
;
main_help_tab:	dw	    net_help_str	; Same order as above
		dw	    ftp_help_str
		dw	   ping_help_str
		dw	special_help_str
;
main_cmd_tab:	dw	net		; Same order as above
		dw	ftp
		dw	ping
		dw	special
;
;
;------------------------------------------------------------------------------
; NET sub-commands - string table, help string table and jump table in same order!
;
net_tab:	dw	 start_str
		dw	  diag_str
		dw	   ftp_str
		dw	 trace_str
		dw	  ping_str
		dw	status_str
		dw	  time_str
		dw	  help_str
		dw	0
;
net_help_tab:	dw	 start_help_str	; Same order as above
		dw	  diag_help_str
		dw	   ftp_help_str
		dw	 trace_help_str
		dw	  ping_help_str
		dw	status_help_str
		dw	  time_help_str
		dw	  help_help_str
;
net_cmd_tab:	dw	net_start	; Same order as above
		dw	net_diag
		dw	ftp
		dw	trace
		dw	ping
		dw	status
		dw	time
		dw	nethelp
;
;
;------------------------------------------------------------------------------
; FTP sub-commands - string table and jump table, in same order!
;
ftp_tab:	dw	login_str
		dw	logout_str
		dw	status_str
		dw	dir_str
		dw	cd_str
		dw	del_str
		dw	era_str
		dw	erase_str
		dw	ren_str
		dw	rename_str
		dw	md_str
		dw	mkdir_str
		dw	rd_str
		dw	rmdir_str
		dw	0
;
ftp_cmd_tab:	dw	ftp_login	; :FTP LOGIN
		dw	ftp_logout	; :FTP LOGOUT
		dw	ftp_status	; :FTP STATUS
		dw	ftp_dir		; :FTP DIR
		dw	ftp_cd		; :FTP CD
		dw	ftp_del		; :FTP DEL
		dw	ftp_del		; :FTP ERA
		dw	ftp_del		; :FTP_ERASE
		dw	ftp_ren		; :FTP REN
		dw	ftp_ren		; :FTP RENAME
		dw	ftp_md		; :FTP MD
		dw	ftp_md		; :FTP MKDIR
		dw	ftp_rd		; :FTP RD
		dw	ftp_rd		; :FTP RMDIR
;
;
;
login_str:	db	5,"LOGIN"
logout_str:	db	6,"LOGOUT"
dir_str:	db	3,"DIR"
cd_str:		db	2,"CD"
del_str:	db	3,"DEL"
era_str:	db	3,"ERA"
erase_str:	db	5,"ERASE"
ren_str:	db	3,"REN"
rename_str:	db	6,"RENAME"
md_str:		db	2,"MD"
mkdir_str:	db	5,"MKDIR"
rd_str:		db	2,"RD"
rmdir_str:	db	5,"RMDIR"
;
;------------------------------------------------------------------------------
; HELP text
;
version_str:	db	"NET   version "
		db	version.major, ".", version.minor, version.revision,CR,LF
special_help_str: db	0
;
;
; All the help text below is designed to look OK on both a 40 and 80 column
; screen
;
; 40 col screen limit:	 |........|.........|.........|.........|
;
help_help_str:
net_help_str	db	"Available :NET commands:",CR,LF
		db	CR,LF
		db	"NET START  starts the network", CR,LF
		db	"NET DIAG   helps diagnose problems",CR,LF
		db	"NET FTP    FTP commands",CR,LF
		db	"NET PING   tests network communication",CR,LF
		db	"NET TRACE  sets diagnostic tracing",CR,LF
		db	"NET STATUS shows network status",CR,LF
		db	"NET TIME   sets the system time & date",CR,LF
		db	CR,LF
		db	"Type :HELP NET <cmd> for specific help",CR,LF
		db	CR,LF
		db	"Several EXOS devices are available",CR,LF
		db	"eg. load \"HTTP:192.168.1.1/demo.bas\"",CR,LF
		db	"    load \"FTP:demo.bas\"",CR,LF
		db	"    open #1:\"TCP:192.168.1.64-80\"",CR,LF
		db	0
;
diag_help_str	db	"NET DIAG is the same as NET START "
		db	"but with diagnostic messages",CR,LF,0
;
start_help_str	db	"NET START starts the network and "
		db	"gets the IP address etc. using DHCP",CR,LF
		db	0
;
ftp_help_str	db	"NET FTP connects to a remote FTP server "
		db	"and provides various commands:",CR,LF
		db	CR,LF
		db	"FTP LOGIN <host> connects to a server",CR,LF
		db	"FTP LOGOUT disconnects from a server",CR,LF
		db	"FTP STATUS displays server information",CR,LF
		db	"FTP DIR    lists remote directory",CR,LF
		db	"FTP CD     changes remote directory",CR,LF
		db	"FTP DEL    deletes remote files",CR,LF
		db	"FTP REN    renames remote file",CR,LF
		db	"FTP MD     makes remote directory",CR,LF
		db	"FTP RD     removes remote directory",CR,LF
		db	CR,LF
		db	"After using :FTP LOGIN the EXOS FTP: "
		db	"device can be used",CR,LF
		db	"eg. :FTP LOGIN 192.168.1.1",CR,LF
		db	"    LOAD \"ftp:demo.bas\"",CR,LF 
		db	0
;
ping_help_str	db	"NET PING <host> tests communication "
		db	"with other computers on the network",CR,LF
		db	"eg. :NET PING 192.168.1.1",CR,LF
		db	0
;
trace_help_str	db	"NET TRACE [ON|RAW|OFF] sets diagnostic "
		db	"network trace options:",CR,LF
		db	CR,LF
		db	"NET TRACE     Turns tracing on",CR,LF
		db	"NET TRACE RAW As ON but also raw bytes",CR,LF
		db	"NET TRACE OFF Turns off all tracing",CR,LF
		db	0
;
status_help_str:db	"NET STATUS shows MAC and IP addresses "
		db	"and status of all sockets",CR,LF
		db	0
;
time_help_str:	db	"NET TIME updates the system time and "
		db	"date from the network using NTP",CR,LF
		db	0
;
net_str		db	3,"NET"
net_str_len	equ	$-net_str-1
ftp_str		db	3,"FTP"
diag_str:	db	4,"DIAG"
start_str:	db	5,"START"
ping_str:	db	4,"PING"
trace_str:	db	5,"TRACE"
status_str:	db	6,"STATUS"
time_str:	db	4,"TIME"
help_str:	db	4,"HELP"
;
special_str:	db	6,"EPNET",0ffh
;
;
;
		endmodule
