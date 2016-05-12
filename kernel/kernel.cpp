/* kernel.c - The kernel of project asiago, it's the heart the OS! */
/* Copyright (C) 2016   Chris Smith */

/* This program is free software: you can redistribute it and/or modify */
/* it under the terms of the GNU General Public License as published by */
/* the Free Software Foundation, either version 3 of the License, or */
/* (at your option) any later version. */

/* This program is distributed in the hope that it will be useful, */
/* but WITHOUT ANY WARRANTY; without even the implied warranty of */
/* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the */
/* GNU General Public License for more details. */

/* You should have received a copy of the GNU General Public License */
/* along with this program.  If not, see <http://www.gnu.org/licenses/>. */

#include "../boot/multiboot.h"

#include "../utils/utils.h"

#include "log.cpp"

#include "gdt.cpp"
#include "idt.cpp"

#include "memory.cpp"
#include "../modules/clock/clock.cpp"
#include "../modules/screen/screen.cpp"
#include "../modules/keyboard/keyboard.cpp"

#include "../implementation/implementation.cpp"

#include "ports.cpp"

extern "C" void kernel_main(multiboot_info_t* mbd) {
	cli();

	memory_init(mbd);

	screen_terminal_initialize();

	log("Setting up GDT");
	gdt_init();

	log("Setting up IDT");
	init_idt();

	log("Setting up clock");
	clock_initialize();

	log("Setting up keyboard");
	keyboard_initialize();

//log("Initializing ACPI");
//initAcpi();

	sti();

	log("Welcome to Aura!");

	//implementation();

	// returning from here will clear interrupts, halt the system, and enter a jmp loop (boot.s)
	crash("We have just returned from the implmentation :(");
}

void crash(String message){
	fault(message);
	sti();
	asm("hlt");
}