; W5300
;
; All the constants required for using the WIZ W5300 chip
;
		module w5300
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
; Main directly-accessed registers
;
MR0		equ	0		;Mode Register
MR1		equ	1
;
MR0_WDF2	equ	20h		; Write Data Fetch time
MR0_WDF1	equ	10h
MR0_WDF0	equ	08h
;
MR1_RST		equ	80h		; Reset
MR1_MT		equ	20h		; Memory test mode
MR1_IND		equ	01h		; Indirect Bus I/F Mode
;
;
IDM_AR0		equ	2		; Indirect Mode Address Register
IDM_AR1		equ	3
;
IDM_DR0		equ	4		; Indirect Mode Data Register
IDM_DR1		equ	5
;
;
;------------------------------------------------------------------------------
; In Indirect Mode which EPNET uses, these are all accessed via AR and DR above
;
; COMMON registers
;
IR		equ	02h
IR0		equ	IR+0		; Interrupt Register
IR1		equ	IR+1
;
IMR		equ	04h
IMR0		equ	IMR+0		; Interrupt Mask Register
IMR1		equ	IMR+1
;
SHAR	  	equ	08h		; Source Hardware Address Register (MAC!)
SHAR0		equ	SHAR+0
SHAR1		equ	SHAR+1
SHAR2		equ	SHAR+2
SHAR3		equ	SHAR+3
SHAR4		equ	SHAR+4
SHAR5		equ	SHAR+5

GAR		equ	10h 		; Gateway Address Register
GAR0		equ	GAR+0
GAR1		equ	GAR+1
GAR2		equ	GAR+2
GAR3		equ	GAR+3

SUBR		equ	14h		; Subnet Mask Register
SUBR0		equ	SUBR+0
SUBR1		equ	SUBR+1
SUBR2		equ	SUBR+2
SUBR3		equ	SUBR+3

SIPR		equ	18h		; Source IP Address Register
SIPR0		equ	SIPR+0
SIPR1		equ	SIPR+1
SIPR2		equ	SIPR+2
SIPR3		equ	SIPR+3

RTR		equ	1ch		; Retransmission Timeout-value Register
RTR0		equ	RTR+0
RTR1		equ	RTR+1

RCR1		equ	1fh		; Retransmission Retry-count Register (RCR0 "reserved")

TMS01R		equ	20h
TMSR0		equ	TMS01R+0	; Transmit Memory Size Register Socket 0
TMSR1		equ	TMS01R+1	; Transmit Memory Size Register Socket 1
TMS23R		equ	TMS01R+2
TMSR2		equ	TMS23R+0	; Transmit Memory Size Register Socket 2
TMSR3		equ	TMS23R+1	; Transmit Memory Size Register Socket 3
TMS45R		equ	TMS23R+2
TMSR4		equ	TMS45R+0	; Transmit Memory Size Register Socket 4
TMSR5		equ	TMS45R+1	; Transmit Memory Size Register Socket 5
TMS67R		equ	TMS45R+2
TMSR6		equ	TMS67R+0	; Transmit Memory Size Register Socket 6
TMSR7		equ	TMS67R+1	; Transmit Memory Size Register Socket 7

RMS01R		equ	28h
RMSR0		equ	RMS01R+0	; Receive Memory Size Register Socket 0
RMSR1		equ	RMS01R+1	; Receive Memory Size Register Socket 1
RMS23R		equ	RMS01R+2
RMSR2		equ	RMS23R+0	; Receive Memory Size Register Socket 2
RMSR3		equ	RMS23R+1	; Receive Memory Size Register Socket 3
RMS45R		equ	RMS23R+2
RMSR4		equ	RMS45R+0	; Receive Memory Size Register Socket 4
RMSR5		equ	RMS45R+1	; Receive Memory Size Register Socket 5
RMS67R		equ	RMS45R+2
RMSR6		equ	RMS67R+0	; Receive Memory Size Register Socket 6
RMSR7		equ	RMS67R+1	; Receive Memory Size Register Socket 7

MTYPER  	equ	30h		; Memory Block Type Register
MTYPER0		equ	MTYPER+0
MTYPER1		equ	MTYPER+1

PATR0		equ	32h		; PPPoE Authentication Register
PATR1		equ	33h

PTIMER1		equ	37h		; PPP LCP Request Time Register

PMAGICR0	equ	38h		; PPP LCP Magic Number Register
PMAGICR1	equ	39h

PSIDR0		equ	3ch		; PPP Session ID Register
PSIDR1		equ	3dh

PDHAR0		equ	40h		; PPP Dest Hardware Address Register
PHARD1		equ	41h
PHARD2		equ	42h
PHARD3		equ	43h
PHARD4		equ	44h
PHARD5		equ	45h

UIPR0		equ	48h		; Unreachable IP Address Register
UIPR1		equ	49h
UIPR2		equ	4ah
UIPR3		equ	4bh

UPORTR0		equ	4ch		; Unreachable Port Number Register
UPORTR1		equ	4dh

FMTUR0		equ	4eh		; Fragmant MTU Register
FMTUR1		equ	4fh

P0_BRDYR1	equ	61h		; Pin BRDY0 Configure Register
P0_BDPTHR0 	equ	62h		; Pin BRDY0 Buffer Depth Register
P0_BDPTHR1 	equ	63h

P1_BRDYR1	equ	65h		; Pin BRDY1 Configure Register
P1_BDPTHR0 	equ	66h		; Pin BRDY1 Buffer Depth Register
P1_BDPTHR1 	equ	67h

P2_BRDYR1	equ	69h		; Pin BRDY2 Configure Register
P2_BDPTHR0 	equ	6ah		; Pin BRDY2 Buffer Depth Register
P2_BDPTHR1 	equ	6bh

P3_BRDYR1	equ	6dh		; Pin BRDY3 Configure Register
P3_BDPTHR0 	equ	6eh		; Pin BRDY3 Buffer Depth Register
P3_BDPTHR1 	equ	6fh
;
IDR     	equ	0feh		; W5300 ID Register
IDR0		equ	IDR
IDR1		equ	IDR+1
;
;
;------------------------------------------------------------------------------
; SOCKET registers
;
SOCKETS		equ	0x200		; First socket register

SOCKET0		equ	SOCKETS+0
SOCKET1		equ	SOCKET0+040h
SOCKET2 	equ	SOCKET1+040h
SOCKET3 	equ	SOCKET2+040h
SOCKET4 	equ	SOCKET3+040h
SOCKET5 	equ	SOCKET4+040h
SOCKET6 	equ	SOCKET5+040h
SOCKET7 	equ	SOCKET6+040h
;
;
; Offsets from socket base registers above
Sn_MR		equ	00h		; Socket Mode Register
Sn_MR0		equ	Sn_MR+0
Sn_MR1		equ	Sn_MR+1
Sn_MR_CLOSED	equ	00h
Sn_MR_TCP	equ	01h
Sn_MR_UDP	equ	02h
Sn_MR_IPRAW	equ	03h
Sn_MR_MACRAW	equ	04h
Sn_MR_PPPoE	equ	05h
Sn_MR_ND	equ	20h
;
Sn_CR		equ	02h		; Socket Command register
Sn_CR0		equ	Sn_CR+0
Sn_CR1		equ	Sn_CR+1
Sn_CR_OPEN	equ	01h
Sn_CR_LISTEN	equ	02h
Sn_CR_CONNECT	equ	04h
Sn_CR_DISCON	equ	08h
Sn_CR_CLOSE	equ	10h
Sn_CR_SEND	equ	20h
Sn_CR_SEND_MAC	equ	21h
Sn_CR_SEND_KEEP	equ	22h
Sn_CR_RECV	equ	40h
;
Sn_IMR		equ	04h		; Socket Interrupt Mask Register
Sn_IMR0		equ	Sn_IMR+0
Sn_IMR1		equ	Sn_IMR+1
;
Sn_IR		equ	06h		; Socket Interrupt Register
Sn_IR1		equ	Sn_IR+1		; (IR0 "reserved")
Sn_IR_PRECV	equ	80h
Sn_IR_PFAIL	equ	40h
Sn_IR_PNEXT	equ	20h
Sn_IR_SENDOK	equ	10h
Sn_IR_TIMEOUT	equ	08h
Sn_IR_RECV	equ	04h
Sn_IR_DISCON	equ	02h
Sn_IR_CON	equ	01h
;
Sn_SSR		equ	08h		; Socket Status Register
Sn_SSR1		equ	Sn_SSR+1	; (SSR0 "reserved")
Sn_SSR_CLOSED	equ	00h
Sn_SSR_INIT	equ	13h
Sn_SSR_LISTEN	equ	14h
Sn_SSR_ESTAB	equ	17h
Sn_SSR_WAIT	equ	1ch
Sn_SSR_UDP	equ	22h
Sn_SSR_IPRAW	equ	32h
Sn_SSR_MACRAW	equ	42h
Sn_SSR_PPPoE	equ	5fh
Sn_SSR_SYNSENT	equ	15h
Sn_SSR_SYNRECV	equ	16h
Sn_SSR_FIN_WAIT	equ	18h
Sn_SSR_TIME_WAIT equ	1bh
Sn_SSR_LAST_ACK	equ	1dh
Sn_SSR_ARP	equ	01h
;
Sn_PORTR	equ	0ah		; Socket Source Port Register
;
Sn_DHAR		equ	0ch		; Socket Dest Hardware Address Register
;
Sn_DPORTR	equ	12h		; Socket Destination Port Register
;
Sn_DIPR		equ	14h		; Socket Destination IP Address Register
Sn_DIPR2	equ	16h
;
Sn_MSSR		equ	18h		; Socket Maximum Segment Size Register
;
Sn_PORTOR	equ	1ah		; Socket Options Register
;
Sn_TOSR		equ	1ch		; Socket TOS Register
;
Sn_TTLR		equ	1eh		; Socket TTL Register
;
Sn_TX_WRSR	equ	20h		; Socket Write Size Register
Sn_TX_WRSR2	equ	22h
;
Sn_TX_FSR	equ	24h		; Socket Free Size Register
Sn_TX_FSR2	equ	26h
;
Sn_RX_RSR	equ	28h		; Socket Receive Size Register
Sn_RX_RSR2	equ	2ah
;
Sn_FRAGR	equ	2ch		; Socket Frag register
;
Sn_TX_FIFOR	equ	2eh		; Socket 0 Tx FIFO Register
;
Sn_RX_FIFOR	equ	30h		; Socket 0 Rx FIFO Register
;
;

		endmodule
