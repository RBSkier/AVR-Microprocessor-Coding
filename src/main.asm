;
; lab-template.asm
;
; Created: 10/28/2022 8:34:10 PM
; Author : Oscar Feng
;


; Replace with your application code

.include "m2560def.inc"

.def temp = r16

.equ MAX_QUEUE_SIZE = 8
.equ WEST_LIGHT = 0b00000001
.equ EAST_LIGHT = 0b00000010
.equ EMERGENCY = 0b00000100

.dseg
	west_q:				.byte MAX_QUEUE_SIZE		; keeps track of car speeds
	east_q:				.byte MAX_QUEUE_SIZE		; keeps track of car speeds

	num_west:			.byte 1		; number of cars in west queue
	num_east:			.byte 1		; number of cars in east queue

	passing_pos: 		.byte MAX_QUEUE_SIZE		; keeps track of the position of each car that is passing
	passing_speed:		.byte MAX_QUEUE_SIZE		; keeps track of the speed of each car that is passing


	num_passing:		.byte 1		; number of cars curring passing through the middle
									; also used to track the number of elements in passing_pos

	_num_passing:		.byte 1		; only used for tracking the number of elements in passing_speed

	three_min_counter:	.byte 1		; each time that the simulation timer ticks, it will increment this counter
									; once the counter reaches 180, we know 3 minutes has passed
									; and the direction of the traffic must be changed

	three_sec_counter:	.byte 1		; each time that the simulation timer ticks, it will increment this counter
									; once the counter reaches 3, we know 3 seconds has passed
									; and it is time for the next car in queue to enter the middle road

	temporary_counter:	.byte 1		; each time we receive an interrupt from the hardware timer,
									; we increment temporary_counter (assuming that prescaler is set to 256)
									; when temporary_counter == 250, then 1 second has passed

	traffic_flow:		.byte 1		; 1. Eastbound 2. Westbound 3. Emergency Mode
									; 0b0000 0001 west light green, eastbound traffic
									; 0b0000 0010 east light green, westbound traffic
									; 0b0000 0100 both lights red, emergency mode
	delayintrans:		.byte 1		;if delayintrans=1,it means it can't send car into road when empty the road after reversing traffic flow

	pb0counter:			.byte 1
	pb1counter:			.byte 1

; -----------------------------------------------------------------------

; takes in an array like west_q or east_q and adds an element to the end
; @0 -> array pointer			
; @1 -> array max capacity (immediate value)
; @2 -> array current size (stored in data space)
; @3 -> element to add to array
.macro enqueue
	push @3				; push element to stack for later	
	lds @3, @2			; load array size from data space

	cpi @3, @1
    brsh _enqueue_pop    ; array full

	; load indirect address with displacement
	ldi XH, high(@0)
	ldi XL, low(@0)
    adc XL, @3
	brcc _enqueue_update_size
	inc XH

	_enqueue_update_size:
	; increment array size
	; write updated array size to data space
	inc @3
	sts @2, @3

	; restore the element we want to insert
	; insert it
	pop @3
    st X, @3
	rjmp _enqueue_end

	_enqueue_pop:
	pop @3

	_enqueue_end:
.endmacro


; takes in an array like west_q or east_q and returns the first element
; @0 -> array pointer
; @1 -> array current size
; @2 -> register in which to place the result of dequeue
.macro dequeue
	; save conflict registers
	push r16
	push r17

	; load array current size from data space
	; check array size
	lds r16, @1
	cpi r16, 0
	breq dequeue_end

	; store dequeue'ed element in r31 return register
	lds r31, @0
	push r31

	; now shift every remaining element one spot to the left
	; for i = 1 to n 
	ldi r17, 1						; i <- 1
dequeue_left_shift_start:
	cp r17, r16						; if i == n
	breq dequeue_end
	
	; load A[i]
	ldi XH, high(@0)
	ldi XL, low(@0)
	adc XL, r17
	brcc _dequeue_shift_left
	inc XH
	
	_dequeue_shift_left:
	ld r31, X				
	st -X, r31						; A[i-1] <- A[i]

	inc r17							; i <- i + 1
	rjmp dequeue_left_shift_start
dequeue_end:
	pop r31
	pop r17
	pop r16

	mov @2, r31
.endmacro

/*
HOW TO USE ENQUEUE AND DEQUEU EXAMPLE:

ldi r16, 1
enqueue west_q, 8, num_west, r16

ldi r16, 'b'
enqueue west_q, 8, num_west, r16

dequeue west_q, num_west, r17
dequeue west_q, num_west, r18
*/

; ------------------------------------------------------------------------

.cseg

	jmp main
.org INT0addr
	jmp pb_int0_isr
.org INT1addr
	jmp pb_int1_isr
.org OVF0addr
	jmp simulation_timer_isr

.include "lcd.asm"
.include "led.asm"
.include "keypad.asm"
.include "button.asm"

.include "traffic.asm"
.include "interrupt.asm"

; -----------------------------------------------------------------------

main:
	/*
	car logic - haozheng, oscar
	emergency - haozheng, oscar
	lcd - 
	keypad -  

	push button - 
		uses external interrupts 
		whenever pb0 or pb1 is presed, an external interrupt is created 
		the interrupt service routine for each push button must be run
	led - haifeng 
		functions:
			set_west_light - turn west light on/off
			set_east_light - turn east light on/off
			set_emergency - turn emergency lights on (doesn't need to flash for now)

	*/

	; --------------------------------------------------------------------------
	; at the moment, LCD_RESET in lcd.asm is bugged, so don't use that function 
	; for now, just manually set up the lcd screen like below
	; LCD RESET/SETUP
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

	ser r16
	out DDRF, r16
	out DDRA, r16
	clr r16
	out PORTF, r16
	out PORTA, r16

	do_lcd_command 0b00111000 ; 2x5x7
	call sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	call sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command CMD_DISPLAY_OFF ; display off
	do_lcd_command CMD_CLEAR_DISPLAY ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, blink off

	; -------------------------------------------------------------
	
	call LED_RESET
	call KEYPAD_RESET
	call PB_RESET

	call EXTERNAL_INTERRUPT_SETUP
	call reset_simulation

	lds r16, num_west
	call lcd_write_register

keypad_loop:
	/*
	call keypad_read_input
	mov r5, r31

	; check if the keypress was '*'
	; if so, set emergency mode on
	rjmp keypad_loop
	*/
end:
	rjmp end

// ------------------------------------------------------

reset_simulation:
	push r16

	clr r16
	sts num_west, r16
	sts num_east, r16
	sts num_passing, r16
	sts _num_passing, r16
	sts delayintrans, r16

	ldi r16, WEST_LIGHT
	sts traffic_flow, r16

	pop r16
	ret