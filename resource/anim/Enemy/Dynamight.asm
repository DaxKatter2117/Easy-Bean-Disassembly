Dynamight_Anims:
	dc.l Dynamight_Idle
	dc.l Dynamight_Winning
	dc.l Dynamight_Losing
	dc.l Dynamight_Defeated

Dynamight_Idle:
	dc.w $14
	dc.l MapEni_Dynamight_0
	dc.w $14
	dc.l MapEni_Dynamight_1
	dc.w $FF00

Dynamight_Winning:
	dc.w 4
	dc.l MapEni_Dynamight_2
	dc.w 4
	dc.l MapEni_Dynamight_3
	dc.w 4
	dc.l MapEni_Dynamight_4
	dc.w 5
	dc.l MapEni_Dynamight_5
	dc.w 5
	dc.l MapEni_Dynamight_6
	dc.w $FF00

Dynamight_Losing:
	dc.w 4
	dc.l MapEni_Dynamight_7
	dc.w 4
	dc.l MapEni_Dynamight_8
	dc.w 4
	dc.l MapEni_Dynamight_9
	dc.w $FF00

Dynamight_Defeated:
	dc.w $32
	dc.l MapEni_Dynamight_Defeated
	dc.w $FF00
