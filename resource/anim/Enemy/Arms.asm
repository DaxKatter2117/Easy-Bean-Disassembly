Arms_Anims:
	dc.l Arms_Idle
	dc.l Arms_Winning
	dc.l Arms_Losing
	dc.l Arms_Defeated

Arms_Idle:
	dc.w $28
	dc.l MapEni_Arms_0
	dc.w 4
	dc.l MapEni_Arms_1
	dc.w 8
	dc.l MapEni_Arms_2
	dc.w 4
	dc.l MapEni_Arms_1
	dc.w $FF00

Arms_Winning:
	dc.w 8
	dc.l MapEni_Arms_3
	dc.w 4
	dc.l MapEni_Arms_4
	dc.w 8
	dc.l MapEni_Arms_5
	dc.w 4
	dc.l MapEni_Arms_4
	dc.w $FF00

Arms_Losing:
	dc.w 8
	dc.l MapEni_Arms_6
	dc.w 8
	dc.l MapEni_Arms_7
	dc.w $FF00

Arms_Defeated:
	dc.w $32
	dc.l MapEni_Arms_Defeated
	dc.w $FF00