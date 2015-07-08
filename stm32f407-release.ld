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

/* Memory map for STM32F407. */ 
MEMORY
{
	rom (rx)  : ORIGIN = 0x08000000, LENGTH = 1024K
	ram (rwx) : ORIGIN = 0x20000000, LENGTH = 128K
    ccm (rwx) : ORIGIN = 0x10000000, LENGTH = 64K
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
}
