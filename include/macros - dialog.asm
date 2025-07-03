; ---------------------------------------------------------------------------
; Dialog Commands
; ---------------------------------------------------------------------------

end_scene:		macro

		dc.b 	$80						; End of Dialog
		
		endm

; ---------------------------------------------------------------------------

new_t_box_in:		macro x_position, y_position, frame_width, frame_height

		dc.b 	$81												; New Frame
		dc.b	frame_width+(frame_height*32) 					; Width	
		dc.w	$C000+(x_position*2-2)+$80*(y_position-1)		; Position
		
		endm

; ---------------------------------------------------------------------------

new_t_box_st:		macro x_position, y_position, frame_width, frame_height

		dc.b 	$81												; New Frame
		dc.b	frame_width+(frame_height*32) 					; Width	
		dc.w	$D200+(x_position*2-2)+$80*(y_position-1)		; Position
		
		endm

; ---------------------------------------------------------------------------

close_t_box:		macro

		dc.b 	$82						; Close Frame
		
		endm

; ---------------------------------------------------------------------------

pause_set:		macro time

		dc.b 	$83						; Pause
		dc.b	time 					; Time
		
		endm

; ---------------------------------------------------------------------------

anim_sonic: 		macro animation

		dc.b 	$84						; Arle Animation
		dc.b	animation 				; Animation
		
		endm

; ---------------------------------------------------------------------------

anim_opp: 		macro animation

		dc.b 	$85						; Enemy Animation
		dc.b	animation 				; Animation
		
		endm

; ---------------------------------------------------------------------------

NL	=	$86

new_line:		macro

		dc.b 	$86						; New Line
		
		endm

; ---------------------------------------------------------------------------

same_frame:			macro

		dc.b 	$87						; Same Frame
		
		endm

; ---------------------------------------------------------------------------

add_blank:		macro

		dc.b 	$89						; Add Whitespace (Blank Space)
		
		endm

; ---------------------------------------------------------------------------

play_sound:			macro sound

		dc.b 	$8A						; Play Sound
		dc.b 	sound					; Sound ID
		
		endm

; ---------------------------------------------------------------------------
