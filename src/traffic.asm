/*

code for simulating traffic flow and collision emergencies

*/

.cseg
	jmp TRAFFIC_MAIN

/*
Every 3 seconds, a car is allowed to enter the road from the queue with the green light
However, no car is permitted to enter if emergency mode is on. Similarly, if a 3 minute period 
has passed and the traffic direction is to be reversed, then no car is permitted to enter the road
until the road is cleared.
*/
let_car_in:
	/*
		Save conflict registers
	*/

	push r16
	push r17
	push XL
	push YL

	/*
		If delayintrans is set to 1, then we must wait until it returns to 0 before
		letting a car onto the road.
	*/

	; check if delayintrans == 1
	; if so, don't let any cars in
	lds r16, delayintrans
	ldi r17, 0
	cpse r16, r17			
	jmp _let_car_in_end			

	; check the direction of traffic flow
	; also check if emergency mode is on
	lds r16, traffic_flow
	cpi r16, WEST_LIGHT					; west light on -> eastbound traffic
	breq eastbound

	cpi r16, EAST_LIGHT					; east light on -> west bound traffic
	breq westbound	

	; emergency mode, no car in
	rjmp _let_car_in_end

	; to let a car onto the road, remove its speed from the west/east queue
	; then insert it into the road queue
	eastbound:
	dequeue west_q, num_west, r16									; remove a car from the west queue
	enqueue passing_speed, MAX_QUEUE_SIZE, _num_passing, r16		
	rjmp car_entering

	westbound:
	dequeue east_q, num_east, r16									; remove a car from the east queue
	enqueue passing_speed, MAX_QUEUE_SIZE, _num_passing, r16		

	car_entering:
	clr r17
	enqueue passing_pos, MAX_QUEUE_SIZE, num_passing, r17			; set its position in the road to 0

	_let_car_in_end:

	/*
		Restore conflict registers
	*/

	pop r17
	pop r16

	ret
	

/*
	Every 3 minutes, the flow of traffic should be reversed. This function sets the 
flow of traffic, and also sets delayintrans so that no cars can enter the road until
the road is empty.
*/
reverse_traffic_flow:
	/*
		Save conflict registers
	*/

	push r16
	push r17

	; check if emergency mode is on
	lds r16, traffic_flow
	cpi r16, EMERGENCY
	breq _reverse_traffic_flow_end

	; flip the traffic light
	ldi r17, WEST_LIGHT | EAST_LIGHT
	eor r16, r17

	; write to data space
	sts traffic_flow, r16

	; if there are still cars in the middle of the road,
	; then set delayintrans to 1
	lds r16, num_passing
	cpi r16, 0
	breq _reverse_traffic_flow_end

	ldi r16, 1
	sts delayintrans, r16

	_reverse_traffic_flow_end:

	/*
		Restore conflict registers
	*/

	pop r17
	pop r16

	ret

; turns on emergency mode
emergency_mode_on:
	push r16

	ldi r16, EMERGENCY
	sts traffic_flow, r16

	pop r16

	ret

emergency_mode_off:
	ret

/*
	Every second, this function is called in order to update the positions 
of each car currently in the road.
*/
update_passing_cars:
	/*
		Save conflict registers
	*/

	push r16
	push r17
	push r18
	push r19
	push r20
	push r21

	/*
		Update the state of the road
	*/

	lds r17, num_passing		; get the number of cars on the road
	clr r16						; clear loop counter i

	ldi XH, high(passing_pos)
	ldi XL, low(passing_pos)

	ldi YH, high(passing_speed)
	ldi YL, low(passing_speed)

	ldi r20, 0				; initial "previous" car position
	ldi r21, 0				; number of cars that will leave the road at
							; the end of the update process

	_car_update_loop:
	cp r16, r17				; while i < num_passing
	breq _car_update_end

	ld r18, X+				; get car position
	ld r19, Y+				; get car speed

	adc r18, r19			; update car position

	; if carry is set or the car's position >= 250
	; then that car should be removed from the road at the end
	brcc _calculate_off_road		; check if carry set
	rjmp _increment_exit_counter

	_calculate_off_road:			; check if position of car >= 250
	cpi r18, 250
	brlo _calculate_collision

	_increment_exit_counter:	
	inc r21		

	_calculate_collision:
	; if the position of the current car
	; is greater than the position of the car in front of it, then 
	; there is a collision

	cp r18, r20				
	brsh _car_collision
	
	mov r20, r18
	inc r16						; update loop counter
	rjmp _car_update_loop

	_car_collision:		; collision detected
	call emergency_mode_on

	_car_update_end:
	; if emergency mode is not on, then remove any cars
	; that have left the road
	lds r16, traffic_flow
	cpi r16, EMERGENCY
	breq _update_passing_cars_end

	_car_exit_loop:
	cpi r21, 0
	breq _update_passing_cars_end
	dequeue passing_pos, num_passing, r17
	dequeue passing_speed, _num_passing, r17
	dec r21
	rjmp _car_exit_loop

	_update_passing_cars_end:

	/*
		Restore conflict registers
	*/
	pop r21
	pop r20
	pop r19
	pop r18
	pop r17
	pop r16

	ret

TRAFFIC_MAIN:
	nop