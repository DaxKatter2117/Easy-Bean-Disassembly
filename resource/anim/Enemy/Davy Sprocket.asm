Davy_Anims:
	dc.l Davy_Idle
	dc.l Davy_Winning
	dc.l Davy_Losing
	dc.l Davy_Defeated

Davy_Idle:
	dc.w $78
	dc.l MapEni_DavySprocket_0
	dc.w 8
	dc.l MapEni_DavySprocket_1
	dc.w 8
	dc.l MapEni_DavySprocket_0
	dc.w 8
	dc.l MapEni_DavySprocket_1
	dc.w $FF00

Davy_Winning:
	dc.w 8
	dc.l MapEni_DavySprocket_2
	dc.w 8
	dc.l MapEni_DavySprocket_3
	dc.w $FF00

Davy_Losing:
	dc.w $A
	dc.l MapEni_DavySprocket_4
	dc.w $A
	dc.l MapEni_DavySprocket_5
	dc.w $FF00

Davy_Defeated:
	dc.w $32
	dc.l MapEni_DavySprocket_Defeated
	dc.w $FF00
