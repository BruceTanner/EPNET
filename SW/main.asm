; MAIN
;
; This is the main program file, and just includes all the other modules.
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
; At the heart of the program is socket.c, which talks to the WIZ chip socket
; interface. Protocol modules such as UDP, TCP and IPRAW in turn talk to
; socket.c. The higher-level protocols such as DHCP, PING and FTP then talk to
; the protocol modules.
;                                                                               
;  =============================================================               
; |                               EXOS                          |               
;  =============================================================                
;      ^             ^                            ^                             
;      |             |                            |                             
;      |             v                            |                             
;      |        ------------                      |                             
;      |       |  rom.asm   |                     |                             
;      |        -----------                       |                             
;      |             ^                            |                             
;      |             |                            |                             
;      v             v                            v                             
;  ---------------------------               -----------                        
; | device.asm | command.asm  |             |   io.asm  |                       
;  ---------------------------              | trace.asm |                       
;      ^            ^^^                      -----------                        
;      |           / | \                                                        
;      |          /  |  \                                                       
;      |         /   |   \                                                      
;      |        /    |    \                                                     
;      |       /     |     \                                                    
;      |      /      |      \                                                   
;      |     /       |       \                                                  
;      |    /        |        \                                                 
;      |   /         |         \                                                
;      v  v          v          v                                               
;  --------------------------------------                                       
; |         |    sntp.asm   |            |                                      
; | http.asm|    sntp.asm   |            |                                      
; |  ftp.asm|    dhcp.asm   |  ping.asm  |                                      
;  --------------------------------------                                       
;      ^            ^             ^                                             
;      |            |             |                                             
;      v            v             v                                             
;  --------------------------------------                                       
; | tcp.asm |    udp.asm    |  ipraw.asm |                                      
;  --------------------------------------                                       
;      ^            ^             ^                                             
;      |            |             |                                             
;      v            v             v                                             
;  --------------------------------------+----------------------                
; |             socket.asm               |      wiz.asm         |               
;  -------------------------------------------------------------                
;                   ^                               ^                           
;                   |                               |                           
;                   v                               v                           
;  =============================================================                
; | WIZ socket registers                 | WIZ common registers |               
;  =============================================================                
;
;
	include version.asm
	include	debug.asm
;
	include	ep.asm
;
	include command.asm
;
	include	exos.asm
	include	device.asm
	include io.asm
	include status.asm
	include	util.asm
	include trace.asm
;
	include w5300.asm
	include wiz.asm
	include socket.asm
	include ipraw.asm
	include udp.asm
	include	tcp.asm
	include dhcp.asm
	include ping.asm
	include	ntp.asm
	include	ftp.asm
	include http.asm
;
;	include vars.asm
