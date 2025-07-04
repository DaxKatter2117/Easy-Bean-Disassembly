Grounder_Anims:
	dc.l Grounder_Idle
	dc.l Grounder_Winning
	dc.l Grounder_Losing
	dc.l Grounder_Defeated

Grounder_Idle:
	dc.w $78
	dc.l MapEni_Grounder_0
	dc.w 4
	dc.l MapEni_Grounder_1
	dc.w 7
	dc.l MapEni_Grounder_2
	dc.w 4
	dc.l MapEni_Grounder_1
	dc.w $FF00

Grounder_Winning:
	dc.w $3C
	dc.l MapEni_Grounder_3
	dc.w $A
	dc.l MapEni_Grounder_4
	dc.w $A
	dc.l MapEni_Grounder_3
	dc.w $A
	dc.l MapEni_Grounder_4
	dc.w $FF00

Grounder_Losing:
	dc.w $F
	dc.l MapEni_Grounder_5
	dc.w $50
	dc.l MapEni_Grounder_6
	dc.w $FF00

Grounder_Defeated:
	dc.w $32
	dc.l MapEni_Grounder_Defeated
	dc.w $FF00
