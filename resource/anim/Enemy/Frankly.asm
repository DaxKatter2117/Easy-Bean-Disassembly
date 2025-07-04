Frankly_Anims:
	dc.l Frankly_Idle
	dc.l Frankly_Winning
	dc.l Frankly_Losing
	dc.l Frankly_Defeated

Frankly_Idle:
	dc.w $14
	dc.l MapEni_Frankly_0
	dc.w $14
	dc.l MapEni_Frankly_1
	dc.w $FF00

Frankly_Winning:
	dc.w $32
	dc.l MapEni_Frankly_2
	dc.w $FF00

Frankly_Losing:
	dc.w $A
	dc.l MapEni_Frankly_3
	dc.w $A
	dc.l MapEni_Frankly_4
	dc.w $FF00

Frankly_Defeated:
	dc.w $32
	dc.l MapEni_Frankly_Defeated
	dc.w $FF00
