Robotnik_Anims:
	dc.l Robotnik_Idle
	dc.l Robotnik_Winning
	dc.l Robotnik_Losing
	dc.l Robotnik_Defeated

Robotnik_Idle:
	dc.w $50
	dc.l MapEni_DrRobotnik_0
	dc.w 5
	dc.l MapEni_DrRobotnik_1
	dc.w 5
	dc.l MapEni_DrRobotnik_2
	dc.w 5
	dc.l MapEni_DrRobotnik_1
	dc.w $FF00

Robotnik_Winning:
	dc.w 8
	dc.l MapEni_DrRobotnik_3
	dc.w 8
	dc.l MapEni_DrRobotnik_4
	dc.w $FF00

Robotnik_Losing:
	dc.w 5
	dc.l MapEni_DrRobotnik_5
	dc.w 5
	dc.l MapEni_DrRobotnik_6
	dc.w $FF00

Robotnik_Defeated:
	dc.w $32
	dc.l MapEni_DrRobotnik_Defeated
	dc.w $FF00
