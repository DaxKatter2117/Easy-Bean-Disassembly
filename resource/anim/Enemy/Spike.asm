Spike_Anims:
	dc.l Spike_Idle
	dc.l Spike_Winning
	dc.l Spike_Losing
	dc.l Spike_Defeated

Spike_Idle:
	dc.w $50
	dc.l MapEni_Spike_0
	dc.w 5
	dc.l MapEni_Spike_1
	dc.w 8
	dc.l MapEni_Spike_2
	dc.w 5
	dc.l MapEni_Spike_1
	dc.w $78
	dc.l MapEni_Spike_0
	dc.w 4
	dc.l MapEni_Spike_1
	dc.w 6
	dc.l MapEni_Spike_2
	dc.w 4
	dc.l MapEni_Spike_1
	dc.w 5
	dc.l MapEni_Spike_0
	dc.w 4
	dc.l MapEni_Spike_1
	dc.w 6
	dc.l MapEni_Spike_2
	dc.w 4
	dc.l MapEni_Spike_1
	dc.w $FF00

Spike_Winning:
	dc.w $64
	dc.l MapEni_Spike_3
	dc.w $C
	dc.l MapEni_Spike_4
	dc.w $C
	dc.l MapEni_Spike_3
	dc.w $C
	dc.l MapEni_Spike_4
	dc.w $FF00

Spike_Losing:
	dc.w $5A
	dc.l MapEni_Spike_5
	dc.w $A
	dc.l MapEni_Spike_6
	dc.w 6
	dc.l MapEni_Spike_5
	dc.w $A
	dc.l MapEni_Spike_6
	dc.w $FF00

Spike_Defeated:
	dc.w $32
	dc.l MapEni_Spike_Defeated
	dc.w $FF00
