	jsr	(Random).l		; Generate random byte
	andi.b	#15,d0			; Set left bit to 0
	cmpi.b	#2,d0			; Is 2 or less (these are Lessons)?
	bls.s 	SetDemoOpponent		; If so, generate another #
	move.b 	d0, level		; Load level # into RAM
	jsr (SetOpponent).l		; Set opponent.
	rts
