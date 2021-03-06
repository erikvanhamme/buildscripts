/*
 * Copyright 2015 Erik Van Hamme
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

OUTPUT_FORMAT ("elf32-littlearm")
GROUP(-lgcc -lc)
ENTRY(Reset_Handler)

/* Memory map for STM32F303xc. */ 
MEMORY
{
	rom (rx)  : ORIGIN = 0x08000000, LENGTH = 256K
	ram (rwx) : ORIGIN = 0x20000000, LENGTH = 40K
    ccm (rwx) : ORIGIN = 0x10000000, LENGTH = 8K
}

_brom = ORIGIN( rom );
_eram = ORIGIN( ram ) + LENGTH( ram );

/* Section Definitions. */ 
SECTIONS {
	.text : {
		KEEP(*(.isr_vector .isr_vector.*))
		*(.text .text.* .gnu.linkonce.t.*)
		*(.glue_7t) *(.glue_7)
		*(.rodata .rodata* .gnu.linkonce.r.*)

		/* C++ Static constructors (elf) (static destructors are not needed for embedded app)  */
		. = ALIGN(4);
		KEEP(*(.init))

		. = ALIGN(4);
		__preinit_array_start = .;
		KEEP (*(.preinit_array))
		__preinit_array_end = .;

		. = ALIGN(4);
		__init_array_start = .;
		KEEP (*(SORT(.init_array.*)))
		KEEP (*(.init_array))
		__init_array_end = .;

		. = ALIGN(0x4);
		KEEP (*crtbegin.o(.ctors))
		KEEP (*(EXCLUDE_FILE (*crtend.o) .ctors))
		KEEP (*(SORT(.ctors.*)))
		KEEP (*crtend.o(.ctors))
	} > rom

	.ARM.extab : {
		*(.ARM.extab* .gnu.linkonce.armextab.*)
	} > rom

	.ARM.exidx : {
		__exidx_start = .;
		*(.ARM.exidx* .gnu.linkonce.armexidx.*)
		__exidx_end = .;
	} > rom

	. = ALIGN(4);
	_etext = .;
	_sidata = .;

	.data : AT (_etext) {
		_sdata = .;
		*(.data .data.*)
		. = ALIGN(4);
		_edata = . ;
	} > ram

	.bss (NOLOAD) : {
		_sbss = . ;
		*(.bss .bss.*)
		*(COMMON)
		. = ALIGN(4);
		_ebss = . ;
	} > ram

	_heap_start = .;

	/* 
	 * According to http://wwwold.ece.utep.edu/courses/web3376/Stack.html
	 * "The SP should [...] be initialized [...] to the last available address in RAM +1."
	 */
	_estack = _eram;

    .ccm (NOLOAD) : {
        . = ALIGN(4);
        _sccm = .;
        *(.ccm)
        . = ALIGN(4);      
    _eccm = .;
    } > ccm
	
	/* Only debugging information beyond this point. */
	.stab 0 (NOLOAD) : { *(.stab) }
	.stabstr 0 (NOLOAD) : { *(.stabstr) }
	/* DWARF debug sections.
	 * Symbols in the DWARF debugging sections are relative to the beginning
	 * of the section so we begin them at 0.  */
	/* DWARF 1 */
	.debug          0 : { *(.debug) }
	.line           0 : { *(.line) }
	/* GNU DWARF 1 extensions */
	.debug_srcinfo  0 : { *(.debug_srcinfo) }
	.debug_sfnames  0 : { *(.debug_sfnames) }
	/* DWARF 1.1 and DWARF 2 */
	.debug_aranges  0 : { *(.debug_aranges) }
	.debug_pubnames 0 : { *(.debug_pubnames) }
	/* DWARF 2 */
	.debug_info     0 : { *(.debug_info .gnu.linkonce.wi.*) }
	.debug_abbrev   0 : { *(.debug_abbrev) }
	.debug_line     0 : { *(.debug_line) }
	.debug_frame    0 : { *(.debug_frame) }
	.debug_str      0 : { *(.debug_str) }
	.debug_loc      0 : { *(.debug_loc) }
	.debug_macinfo  0 : { *(.debug_macinfo) }
	/* DWARF 2.1 */
	.debug_ranges   0 : { *(.debug_ranges) }
	/* SGI/MIPS DWARF 2 extensions */
	.debug_weaknames 0 : { *(.debug_weaknames) }
	.debug_funcnames 0 : { *(.debug_funcnames) }
	.debug_typenames 0 : { *(.debug_typenames) }
	.debug_varnames  0 : { *(.debug_varnames) }

	.note.gnu.arm.ident 0 : { KEEP (*(.note.gnu.arm.ident)) }
	.ARM.attributes 0 : { KEEP (*(.ARM.attributes)) }
	/DISCARD/ : { *(.note.GNU-stack) }
}
