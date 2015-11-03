EPNET README.TXT

This file contains instructions on assembling the EPNET software.

==============================================================================

 This file is part of the EPNET software

 Copyright (C) 2015  Bruce Tanner

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

 If you do use or modify this file, either for its original purpose or for
 something new, I'd love to hear about it! I can be contacted by email at:

 brucetanner@btopenworld.com

==============================================================================

The ROM image is assembled by assembling ROM.ASM. No command line options are
necessary. ROM.ASM includes MAIN.ASM, which in turn includes everything else.
There is a useful big comment in MAIN.ASM about the structure of the program.

The source files were assembled with SJASM 0.42c, and they make use of a
few useful features of the assembler that other Z80 assemblers may
not support:

a) modules: Each module begins with

	module	<name>

  and ends with

	endmodule

Lables declared between the two are accessed from other modules as <name>.label
(unless they start with @).

b) Local labels: Labels declared as .<name> within a routine are local labels
and are only accessible until the next non-local label.

c) structs: a struct can be declared with

	struct <name>
	:
	ends

Labels declared between the two are accessed as <name>.label, and are offsets.
The <name> label itself is the size of the structure.
