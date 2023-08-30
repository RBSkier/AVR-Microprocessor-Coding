/*

code for push buttons (PB0 and PB1) go in this file

*/

.include "m2560def.inc"

	jmp PB_MAIN

PB_RESET:
	push r16

	; set pins 0 and 1 of PORTD for input
	in temp, PORTD
	cbr temp, PIND0
	cbr temp, PIND1
	out PORTD, temp

	pop r16
	ret

PB_MAIN:
	nop