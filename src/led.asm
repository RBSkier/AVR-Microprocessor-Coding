/*

LED pins should be connected to PORTC pins

*/

.include "m2560def.inc"

.equ LED_PATTERN_1 = 0b00000011 ;west
.equ LED_PATTERN_2 = 0b11000000 ;east
.equ LED_PATTERN_3 = 0b00011000 ;imm


.macro	led_play 
	push r16

	ldi r16,@0
	out PORTC,r16
	pop r16

.endmacro


.macro led_blink ; try to blink may have bugs
	push r16
	
	ldi r16,@0
	out PORTC,r16
	call sleep_100ms ; push r24 and r25 here
	ser r16
	out PORTC, r16

	pop r25
	pop r24
	pop r16
	
.endmacro	

led_west:
	led_play LED_PATTERN_1
	rjmp led_simulation

led_east:
	led_play LED_PATTERN_2
	rjmp led_simulation

led_emergency: ; can be change as led_blink
	led_play LED_PATTERN_3
	rjmp led_simulation


led_simulation:
	push r17
	lds r17,traffic_flow

	cpi r17,WEST_LIGHT
	breq led_west

	cpi r17,EAST_LIGHT
	breq led_east

	cpi r17,EMERGENCY
	breq led_emergency
	
	pop r17
	ret


; initialises the DDRC register
; outputs a default display of all led lights on
LED_RESET:
	push r16

	; set pins in data direction register
	ser r16
	out DDRC, r16

	; default led pattern
	

	out PORTC, r16

	pop r16
	ret


; -----------------------------------

LED_MAIN:
	nop