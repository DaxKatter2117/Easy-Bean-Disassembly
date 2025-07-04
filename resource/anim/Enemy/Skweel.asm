Skweel_Anims:
	dc.l Skweel_Idle
	dc.l Skweel_Winning
	dc.l Skweel_Losing
	dc.l Skweel_Defeated

Skweel_Idle:
	dc.w $3A
	dc.l MapEni_Skweel_0
	dc.w 5
	dc.l MapEni_Skweel_1
	dc.w 5
	dc.l MapEni_Skweel_2
	dc.w 5
	dc.l MapEni_Skweel_1
	dc.w $FF00

Skweel_Winning:
	dc.w 9
	dc.l MapEni_Skweel_3
	dc.w 8
	dc.l MapEni_Skweel_4
	dc.w 9
	dc.l MapEni_Skweel_3
	dc.w 8
	dc.l MapEni_Skweel_5
	dc.w $FF00

Skweel_Losing:
	dc.w 5
	dc.l MapEni_Skweel_6
	dc.w 5
	dc.l MapEni_Skweel_7
	dc.w 5
	dc.l MapEni_Skweel_8
	dc.w 6
	dc.l MapEni_Skweel_9
	dc.w 7
	dc.l MapEni_Skweel_10
	dc.w 5
	dc.l MapEni_Skweel_11
	dc.w $FF00

Skweel_Defeated:
	dc.w $32
	dc.l MapEni_Skweel_Defeated
	dc.w $FF00
