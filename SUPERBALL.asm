.segment "STARTUP"
;******************************************************************
; SUPERBALL
; Simulates a superball, bouncing around
; 
; The gravity acting on the ball is calculated using a lookup table
;******************************************************************


.segment "ZEROPAGE"
;******************************************************************
; The KERNAL and BASIC reserve all the addresses from $0080-$00FF. 
; Locations $00 and $01 determine which banks of RAM and ROM are  
; visible in high memory, and locations $02 through $21 are the
; pseudoregisters used by some of the new KERNAL calls
; (r0 = $02+$03, r1 = $04+$05, etc)
; So we have $22 through $7f to do with as we please, which is 
; where .segment "ZEROPAGE" variables are stored.
;******************************************************************

;.org $0022
; Zero Page
SPRITE_X:            .res 2   ; current X co-ordiinate
SPRITE_Y:            .res 2   ; current Y co-ordiinate
SPRITE_TIME:         .res 1   ; used to calculate the distance travelled
SPRITE_XVEL:         .res 1   ; Current X Velocity
SPRITE_XDIR:         .res 1   ; Pos/Neg direction of travel
SPRITE_YDIR:         .res 1   ; Pos/Neg direction of travel

.segment "INIT"
.segment "ONCE"
.segment "CODE"
;.org $080D

   jmp start

.include "..\INC\x16.inc"

VRAM_BALL    = $04560 ; the location of the ball sprite data in memory 
SPRITE1_ATTR = $1FC08 ; the start of the attribute registers for sprite 1

; PETSCII
SPACE             = $20
CHAR_O            = $4f
CLR               = $93
HOME              = $13
CHAR_Q            = $51
CHAR_G            = $47
CHAR_ENTER        = $0D
       

start:

    ; clear screen
    lda #CLR
    jsr CHROUT

    ; set initial mouse cursor sprite frame
    stz VERA_ctrl
    VERA_SET_ADDR SPRITE1_ATTR, 1 

    lda VERA_dc_video
    ora #%01000000                      ; Turn Sprites On
    sta VERA_dc_video

    stz VERA_ctrl                       ; set the VRAM address for the sprite to be stored
    lda #($10 | ^VRAM_BALL)     
    sta VERA_addr_bank              
    lda #>VRAM_BALL            
    sta VERA_addr_high              
    lda #<VRAM_BALL            
    sta VERA_addr_low               

    ldx #0               
@asset_loop:                           ; load the sprite into VRAM
    lda ag_ball,x              
    sta VERA_data0             
    inx
    cpx #32                    
    bne @asset_loop            

; Set starting location of sprite
    lda #$FF
    sta SPRITE_X
    stz SPRITE_X + 1
    ; top of the screen
    lda #$00
    stz SPRITE_Y
    stz SPRITE_Y + 1


    lda #($10 | ^SPRITE1_ATTR)  ; set the eight sprite attribute registers
    sta VERA_addr_bank  
    lda #>SPRITE1_ATTR          ;
    sta VERA_addr_high
    lda #<SPRITE1_ATTR          ; Bit 7 = mode; Bits 3 to 0 = Address (16:13)
    sta VERA_addr_low

    lda #<(VRAM_BALL >> 5)      ; low byte - Address (12:5)
    sta VERA_data0
    lda #>(VRAM_BALL >> 5)      ; high byte -  Bit 7 = mode; Bits 3 to 0 = Address (16:13)
    sta VERA_data0
    lda SPRITE_X                ; X co-ord (7:0)
    sta VERA_data0
    stz VERA_data0              ; X co-ord (9:8)
    lda SPRITE_Y                ; Y co-ord (7:0)
    sta VERA_data0
    stz VERA_data0              ; Y co-ord (9:8)
    lda #$0C  ; (00001100)      ; bits 7 to 4 = Collision mask; bits 3 to 2 = Z-Depth; bit 1 = V-flip; bit 0 = H-flip 
    sta VERA_data0
    lda #$01                    ; bits 7 to 6 = sprite height; bits 5 to 4 = sprite width; bits 3 to 0 = palette offset
    sta VERA_data0

    ;set Y direction
    lda #$00
    sta SPRITE_YDIR
    ;set X direction
    INC
    sta SPRITE_XDIR
    ;set initial X velocity
    lda #$0F
    sta SPRITE_XVEL

main_loop:
 ;   jmp main_loop

    ; Set the position of the sprite
    lda #($10 | ^SPRITE1_ATTR)
    sta VERA_addr_bank  
    lda #>SPRITE1_ATTR
    sta VERA_addr_high
    lda #<SPRITE1_ATTR
    sta VERA_addr_low
    
    lda #<(VRAM_BALL >> 5)
    sta VERA_data0
    lda #>(VRAM_BALL >> 5)
    sta VERA_data0
    lda SPRITE_X
    sta VERA_data0
    lda SPRITE_X + 1
    sta VERA_data0
    lda SPRITE_Y
    sta VERA_data0
    lda SPRITE_Y + 1
    sta VERA_data0

    jsr delay

    jsr doGrav          ; Calculate the next Y position
    jsr doHorizontal    ; Calculate the next X position

    jmp main_loop


doGrav:
; Calculate the next Y position
    lda SPRITE_YDIR
    bne @up             ; Are we going up or down?
@down:
    inc SPRITE_TIME     ; Increment the time counter (index for the Gravity lookup)
    ldx SPRITE_TIME
    cmp #$41
    beq @dnReverse      ; If past the end of the lookup, reverse
    clc
    lda SPRITE_Y
    adc GravTable,x     ; add the next lookup value (distance)
    sta SPRITE_Y
    lda SPRITE_Y + 1
    adc #$00
    sta SPRITE_Y + 1
    ;check if at bottom   
    cmp #$01            ; check MSB
    bcc @GravDone       ; islower
    lda SPRITE_Y
    cmp #$D8            ; check LSB
    bcc @GravDone       ; islower
@dnReverse:
    lda #$D8
    sta SPRITE_Y        ; set sprite to bottom of screen (could be below screen)
    ;Slow the ball down based on how high it's bouncing
    lda SPRITE_TIME
    lsr
    lsr
    sta SPRITE_XVEL
    ;Change direction
    lda #$FF
    sta SPRITE_YDIR
    bra @GravDone
@up:
    dec SPRITE_TIME     ; Deccrement the time counter (index for the Gravity lookup)
    ldx SPRITE_TIME
    beq @upReverse
    sec
    lda SPRITE_Y
    sbc GravTable,x     ; subtract the next lookup value (distance)
    sta SPRITE_Y
    lda SPRITE_Y + 1
    sbc #$00
    sta SPRITE_Y + 1
    ; Check if at the top
    cmp #$00            ; check MSB
    bne @GravDone       ; ishigher
    lda SPRITE_Y
    cmp #$00            ; check LSB
    bne @GravDone       ; ishigher
@upReverse:
    ;Change direction
    lda #$00
    sta SPRITE_YDIR
@GravDone: 
    rts


doHorizontal:
    lda SPRITE_XVEL
    beq @HDone          ; if Horizontal Velocity=0 then do nothing
    lda SPRITE_XDIR
    beq @HLeft          ; Are we going left or right?
@HRight:
    ; move right
    clc
    lda SPRITE_X
    adc SPRITE_XVEL
    sta SPRITE_X
    lda SPRITE_X + 1
    adc #$00
    sta SPRITE_X + 1

    ;check if at right   
    cmp #$02            ; check MSB
    bcc @HDone          ; islower
    lda SPRITE_X
    cmp #$78            ; check LSB
    bcc @HDone          ; islower 

    ;Change direction
    lda #$00
    sta SPRITE_XDIR
    bra @HDone    
@HLeft:
    ; move left
    sec
    lda SPRITE_X
    sbc SPRITE_XVEL
    sta SPRITE_X
    lda SPRITE_X + 1
    sbc #$00
    sta SPRITE_X + 1

    ;check if at right
    cmp #$00            ; check MSB
    bpl @HDone          ; ishigher
    lda SPRITE_X
    cmp #$00            ; check LSB

    bpl @HDone ; ishigher
    ;Change direction
    lda #$FF
    sta SPRITE_XDIR
@HDone:
    rts


delay:                  ; Standard issue delay loop
    lda #$7F
delayloop_outer:
    pha
    lda #$00
delayloop_inner:
    inc
    bne delayloop_inner
    pla
    inc   
    bne delayloop_outer
    rts


; graviity lookup table (index=time, value = distance travelled)
GravTable:  .byte $00,$00,$00,$01,$00,$00,$01,$00
            .byte $01,$00,$01,$01,$01,$01,$02,$01
            .byte $01,$02,$02,$02,$02,$03,$03,$03
            .byte $03,$04,$04,$04,$05,$05,$05,$06
            .byte $06,$06,$07,$07,$08,$08,$09,$09
            .byte $09,$0A,$0A,$0B,$0B,$0C,$0D,$0D
            .byte $0E,$0E,$0F,$0F,$10,$11,$11,$12
            .byte $13,$13,$14,$15,$15,$16,$17,$18


;Sprite definition
ag_ball:    .byte $00,$69,$95,$00
            .byte $05,$8b,$dc,$80
            .byte $26,$9e,$ff,$d2
            .byte $35,$ad,$ff,$c6
            .byte $24,$9c,$ef,$a5
            .byte $13,$69,$bb,$81
            .byte $01,$35,$77,$40
            .byte $00,$12,$21,$00    



