RoleCallText:
	dc.l CastText_Arms
	dc.l CastText_Arms
	dc.l CastText_Arms
	dc.l CastText_Arms
	dc.l CastText_Arms
	dc.l CastText_Frankly
	dc.l CastText_Humpty
	dc.l CastText_Coconuts
	dc.l CastText_Davy
	dc.l CastText_Skweel
	dc.l CastText_Dynamight
	dc.l CastText_Grounder
	dc.l CastText_Spike
	dc.l CastText_SirFfuzzy
	dc.l CastText_DragonBreath
	dc.l CastText_Scratch
	dc.l CastText_Robotnik
	dc.l CastText_HasBean
	dc.l CastText_Cast
	dc.l CastText_And

CastText_Cast:
	dc.w 4
	dc.w $D724
	dc.b "CAST"
	dc.b $FF
	even

CastText_And:
	dc.w 6
	dc.w $D720
	dc.b "AND..."
	dc.b $FF
	even

CastText_Arms:
	dc.w 4
	dc.w $D724
	dc.b "ARMS"
	dc.b $FF
	even
CastText_Frankly:
	dc.w 7
	dc.w $D722
	dc.b "FRANKLY"
	dc.b $FF
	even

CastText_Humpty:
	dc.w 6
	dc.w $D722
	dc.b "HUMPTY"
	dc.b $FF
	even

CastText_Coconuts:
	dc.w 8
	dc.w $D722
	dc.b "COCONUTS"
	dc.b $FF
	even

CastText_Davy:
	dc.w $D
	dc.w $D722
	dc.b "DAVY SPROCKET"
	dc.b $FF
	even

CastText_Dynamight:
	dc.w 9
	dc.w $D722
	dc.b "DYNAMIGHT"
	dc.b $FF
	even

CastText_Skweel:
	dc.w 6
	dc.w $D722
	dc.b "SKWEEL"
	dc.b $FF
	even

CastText_Grounder:
	dc.w 8
	dc.w $D722
	dc.b "GROUNDER"
	dc.b $FF
	even

CastText_Spike:
	dc.w 5
	dc.w $D722
	dc.b "SPIKE"
	dc.b $FF
	even

CastText_SirFfuzzy:
	dc.w $10
	dc.w $D722
	dc.b "SIR FFUZZY-LOGIK"
	dc.b $FF
	even

CastText_DragonBreath:
	dc.w $D
	dc.w $D722
	dc.b "DRAGON BREATH"
	dc.b $FF
	even

CastText_Scratch:
	dc.w 7
	dc.w $D722
	dc.b "SCRATCH"
	dc.b $FF
	even

CastText_Robotnik:
	dc.w $C
	dc.w $D722
	dc.b "DR. ROBOTNIK"
	dc.b $FF
	even

CastText_HasBean:
	dc.w 8
	dc.w $D71E
	dc.b "HAS BEAN"
	dc.b $FF
	even