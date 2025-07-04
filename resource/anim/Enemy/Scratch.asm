Scratch_Anims:
	dc.l Scratch_Idle
	dc.l Scratch_Winning
	dc.l Scratch_Losing
	dc.l Scratch_Defeated

Scratch_Idle:
	dc.w $32
	dc.l MapEni_Scratch_0
	dc.w $19
	dc.l MapEni_Scratch_1
	dc.w $FF00

Scratch_Winning:
	dc.w $32
	dc.l MapEni_Scratch_2
	dc.w $F
	dc.l MapEni_Scratch_3
	dc.w $FF00

Scratch_Losing:
	dc.w $32
	dc.l MapEni_Scratch_4
	dc.w $F
	dc.l MapEni_Scratch_5
	dc.w $FF00

Scratch_Defeated:
	dc.w $32
	dc.l MapEni_Scratch_Defeated
	dc.w $FF00
