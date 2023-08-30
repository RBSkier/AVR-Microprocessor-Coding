/*

contains definitions and function calls for delay/sleep

*/

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

.cseg
	jmp MAIN_CLOCK

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)

delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret

sleep_10ms:
	rcall sleep_5ms
	rcall sleep_5ms
	ret

sleep_50ms:
	rcall sleep_10ms
	rcall sleep_10ms
	rcall sleep_10ms
	rcall sleep_10ms
	rcall sleep_10ms
	ret

sleep_100ms:
	rcall sleep_50ms
	rcall sleep_50ms
	ret

sleep_1s:
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms

	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	ret

MAIN_CLOCK:
	nop