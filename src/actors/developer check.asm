; =============== A C T O R =================================================
; Region lockout
; ---------------------------------------------------------------------------

	move.w	#0,aField26(a0)
	move.w	#$258,aField28(a0)
	jsr	(ActorBookmark).l
	move.b	#$80,d0
	cmpi.b	#$80,d0
	bne.s	.NoMatch
	tst.w	aField26(a0)
	beq.s	.CheckCode
	subq.w	#1,aField28(a0)
	bmi.s	.NoMatch

.CheckCode:
	lea	(p1_ctrl_hold).l,a1 ; Use P1 Controller
	lea	(LockoutBypassCode).l,a2
	move.w	aField26(a0),d0
	move.b	(a2,d0.w),d0
	cmpi.b	#$FF,d0
	beq.s	.BypassLockout
	move.b	1(a1),d1
	beq.s	.NoButton
	cmp.b	d0,d1
	bne.s	.NoMatch
	addq.w	#1,aField26(a0)

.NoButton:
	rts
; ---------------------------------------------------------------------------

.BypassLockout:
	move.b	#1,(init_done).l
	move.b	#0,(bytecode_disabled).l
	rts
	
; ---------------------------------------------------------------------------

.NoMatch:
	jsr	(ActorBookmark).l
	nop
	rts