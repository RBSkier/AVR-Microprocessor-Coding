/*

code for enabling/disabling interrupts
as well as interrupt service routines

*/

jmp INTERRUPT_MAIN

; ISR for pb0 (push button 0)
pb_int0_isr:
	; pro
	push r16
	in r16, SREG
	push r16

	lds r16, pb0counter
	inc r16
	sts pb0counter, r16

	cpi r16, 2
	brlo _pb_int0_isr_end

	; body
	mov r16, r5
	enqueue west_q, MAX_QUEUE_SIZE, num_west, r16	 ; west_queue

	call lcd_simulation

	clr r16
	sts pb0counter, r16

	_pb_int0_isr_end:
	; epi
	pop r16
	out SREG, r16
	pop r16

	reti

; ISR for pb1 (push button 1)
pb_int1_isr:
	; pro
	push r16
	in r16, SREG
	push r16

	lds r16, pb1counter
	inc r16
	sts pb1counter, r16

	cpi r16, 3
	brlo _pb_int1_isr_end

	; body
	mov r16, r5
	enqueue east_q, MAX_QUEUE_SIZE, num_east, r16	 ; west_queue
	
	call lcd_simulation

	clr r16
	sts pb1counter, r16

	_pb_int1_isr_end:
	; epi
	pop r16
	out SREG, r16
	pop r16

	reti

; ISR for the simulation timer
simulation_timer_isr:
	/*
	- push conflict registers, status register
	- increment temporary_counter
	- check if temporary_counter == 250	
		-? increment three_sec_counter
			- if three_sec_counter == 3, call 'let_car_in'
		-? increment three_min_counter
			- if three_min_counter == 180, call 'reverse_traffic_flow'
	- for cars in the road, add their speed to their position
	- loop through cars in the road, check for collisions (collisions occur when array is no longer sorted)
		-? set emergency mode
	*/

	/*
		Save conflict registers and status register
	*/

	push r16
	in r16, SREG
	push r16

	; load and increment the temporary_counter
	lds r16, temporary_counter
	inc r16
	sts temporary_counter, r16

	; if temporary_counter == 250, then 1 second has passed
	cpi r16, 250
	brne _timer_end

	; 1 second has passed, first reset the temporary counter
	clr r16
	sts temporary_counter, r16

	; since 1 second has passed, increment the three second counter
	lds r16, three_sec_counter
	inc r16

	; if three_second_counter == 3, then let a car onto the road
	cpi r16, 3
	brne _update_three_second_counter

	call let_car_in
	clr r16

	_update_three_second_counter:
	sts three_sec_counter, r16

	; add one second to three_minute_timer
	lds r16, three_min_counter
	inc r16

	; if three_minute_timer == 180, then reverse the traffic flow
	cpi r16, 180
	brne _update_three_minute_counter

	call reverse_traffic_flow
	clr r16

	_update_three_minute_counter:
	sts three_min_counter, r16
	
	_timer_end:

	/*
		Restore conflict and status register
	*/

	pop r16
	out SREG, r16
	pop r16

	reti 
	

/*
Enable interrupts for INT0 and INT1
Enable interrupts for Timer0
*/
EXTERNAL_INTERRUPT_SETUP:
	push r16
	
	; setup interrupt to detect falling edge
	clr r16
	ldi r16, (2 << ISC10) | (2 << ISC00)
	sts EICRA, r16

	; enable interrupts for INT0 and INT1
	in r16, EIMSK
	ori r16, (1 << INT0) | (1 << INT1)
	out EIMSK, temp

	; enable interrupt for Timer0
	ldi temp, 0
	out TCCR0A, temp

	ldi temp, (1 << CS02) | (0 << CS00)		; prescaler value= 256
	out TCCR0B, temp

	ldi temp, 1 << TOIE0
	;sts TIMSK0, temp

	; enable global interrupts
	sei

	pop r16
	ret

INTERRUPT_MAIN:
	nop