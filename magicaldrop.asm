################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Magical Drop.
#
# Student 1: Hiu Yan Kwok, 1010969855
# Student 2: Minseok Kwag, 1009608444
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       4 pixels
# - Unit height in pixels:      4 pixels
# - Display width in pixels:    256 pixels
# - Display height in pixels:   256 pixels
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

# colours used by the scene
COLOR_PINK:
    .word 0xf4afc1
COLOR_GREEN:
    .word 0xb8d8ba
COLOR_BLUE:
    .word 0xafcbdf
COLOR_YELLOW:
    .word 0xf6e3a1
COLOR_BACKGROUND:
    .word 0xd9c2a7
COLOR_CREAM:
    .word 0xfff1d6
COLOR_DARK_BROWN:
    .word 0x5c4033

# Fixing flickering
NEEDS_REDRAW:
    .word 1

##############################################################################
# Mutable Data
##############################################################################
# 14 rows x 7 cols, each cell is one word:
# 0 = empty, 1 = pink, 2 = green, 3 = blue, 4 = yellow
BOARD:
    .space 392  # 14x7x4 bytes
PLAYER_COLUMN:
    .word 3  # start in the centre column (columns are 0-6)
HELD_COLOR:
    .word 0  # 0 means no bubble is held
HELD_COUNT:
    .word 0  # the number of bubbles that the player is holding
KEY_COUNT:
    .word 0  # row advances at 10

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialize the game
    jal initialize_board
    j game_loop

game_loop:
    # 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleep

    jal check_keyboard
    jal check_row_advance
    
    # Added this portion to fix flickering
    lw $t0, NEEDS_REDRAW # 1 if a key was pressed and a refresh is consequently needed
    beq $t0, $zero, skip_refresh
    sw $zero, NEEDS_REDRAW
    # when no key is being pressed

    jal draw_background
    jal draw_board
    jal draw_player
    jal draw_held

skip_refresh:
    li $v0, 32
    li $a0, 16
    syscall

    # 5. Go back to Step 1
    j game_loop

##############################################################################
# 1.
# initialize_board
# clears all 98 cells, then fills the top 5 rows (35 pixels) with random colours 1 to 4
##############################################################################

initialize_board:
    la $t0, BOARD
    li $t1, 98

clear_board_loop:
    sw $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bgtz $t1, clear_board_loop # clear all 98 cells

    # reset $t0 to point to first cell again
    la $t0, BOARD
    # prepares the to color the top 5x7 cells, (5 rows * 7columns)
    li $t1, 35

# random integar with UB
random_board_loop:
    li $v0, 42
    li $a0, 0
    li $a1, 4
    syscall

    addi $a0, $a0, 1
    addi $t2, $zero, 21
    bgt $t1, $t2, store_init_c
    lw $t3, -28($t0)
    lw $t4, -56($t0)
    bne $a0, $t3, store_init_c
    beq $a0, $t4, random_board_loop # identical logic as new_row_loop

store_init_c:
    sw $a0, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bgtz $t1, random_board_loop

    jr $ra

##############################################################################
# check_keyboard
# handles a (left), d (right), s (grab bubbles), w(throw_ bubble), 
# and q(exit program)
##############################################################################
check_keyboard:
    lw $t0, ADDR_KBRD
    lw $t1, 0($t0)
    beq $t1, 1, key_pressed
    jr $ra

key_pressed:
    lw $t2, 4($t0)
    sw $t9, NEEDS_REDRAW
    beq $t2, 0x61, move_left
    beq $t2, 0x64, move_right
    beq $t2, 0x73, grab_bubbles
    beq $t2, 0x77, throw_bubbles
    beq $t2, 0x71, exit_program
    jr $ra

move_left:
    lw $t6, KEY_COUNT
    addi $t6, $t6, 1
    sw $t6, KEY_COUNT
    lw $t3, PLAYER_COLUMN
    beq $t3, $zero, keyboard_done
    addi $t3, $t3, -1
    sw $t3, PLAYER_COLUMN
    j keyboard_done

move_right:
    lw $t6, KEY_COUNT
    addi $t6, $t6, 1
    sw $t6, KEY_COUNT
    lw $t3, PLAYER_COLUMN
    li $t4, 6
    beq $t3, $t4, keyboard_done
    addi $t3, $t3, 1
    sw $t3, PLAYER_COLUMN

keyboard_done:
    jr $ra

##############################################################################
# grab_bubbles
# grabs the bottom same-coloured chain in the current column
##############################################################################
grab_bubbles:
    lw $t6, KEY_COUNT
    addi $t6, $t6, 1
    sw $t6, KEY_COUNT
    lw $t0, PLAYER_COLUMN
    sll $t0, $t0, 2
    la $t1, BOARD
    addi $t1, $t1, 364
    add $t1, $t1, $t0
    li $t2, 14

find_bottom_bubble:
    lw $t3, 0($t1)
    bne $t3, $zero, bottom_bubble_found
    addi $t1, $t1, -28
    addi $t2, $t2, -1
    bgtz $t2, find_bottom_bubble
    jr $ra

bottom_bubble_found:
    lw $t4, HELD_COUNT
    lw $t5, HELD_COLOR
    bne $t4, $zero, check_held_color
    sw $t3, HELD_COLOR
    add $t5, $t3, $zero

check_held_color:
    bne $t3, $t5, grab_done

remove_bubble_loop:
    lw $t3, 0($t1)
    bne $t3, $t5, grab_done
    sw $zero, 0($t1)
    lw $t4, HELD_COUNT
    addi $t4, $t4, 1
    sw $t4, HELD_COUNT
    addi $t1, $t1, -28
    addi $t2, $t2, -1
    bgtz $t2, remove_bubble_loop

grab_done:
    jr $ra

##############################################################################
# check_row_advance
# pushes the board down after 10 gameplay keys
##############################################################################
check_row_advance:
    lw $t0, KEY_COUNT
    slti $t1, $t0, 10
    bne $t1, $zero, row_advance_done
    sw $zero, KEY_COUNT

    la $t0, BOARD
    addi $t0, $t0, 360
    addi $t1, $t0, 28
    li $t2, 91

shift_board_loop:
    lw $t3, 0($t0)
    sw $t3, 0($t1)
    addi $t0, $t0, -4
    addi $t1, $t1, -4
    addi $t2, $t2, -1
    bgtz $t2, shift_board_loop

    la $t0, BOARD
    addi $t0, $t0, 364
    li $t1, 7

check_bottom_row_loop:
    lw $t2, 0($t0)
    bne $t2, $zero, exit_program
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bgtz $t1, check_bottom_row_loop

    la $t0, BOARD
    li $t1, 7

new_row_loop:
    li $v0, 42
    li $a0, 0 
    li $a1, 4
    syscall
    addi $a0, $a0, 1

    # Hard-feature #4
    lw $t3, 28($t0) # loading the bubble one row below into $t3
    lw $t4, 56($t0) # loading the bubble two rows below into $t4
    bne $a0, $t3, store_new_c 
    beq $a0, $t4, new_row_loop # match 3 detected; going back to new_row_loop to generate new cell(s)

store_new_c:
    sw $a0, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bgtz $t1, new_row_loop

row_advance_done:
    jr $ra

##############################################################################
# draw_held
# draws one small marker for each held bubble
##############################################################################
draw_held:
    lw $t0, HELD_COUNT
    beq $t0, $zero, draw_held_done
    lw $t1, HELD_COLOR

    beq $t1, 1, held_pink
    beq $t1, 2, held_green
    beq $t1, 3, held_blue
    lw $t3, COLOR_YELLOW
    j held_color_ready

held_pink:
    lw $t3, COLOR_PINK
    j held_color_ready

held_green:
    lw $t3, COLOR_GREEN
    j held_color_ready

held_blue:
    lw $t3, COLOR_BLUE

held_color_ready:
    lw $t2, ADDR_DSPL
    addi $t2, $t2, 16064
    li $t4, 0

draw_held_loop:
    sw $t3, 0($t2)
    addi $t0, $t0, -1
    beq $t0, $zero, draw_held_done
    addi $t2, $t2, 4
    addi $t4, $t4, 1
    slti $t5, $t4, 14
    bne $t5, $zero, draw_held_loop
    addi $t2, $t2, -312
    li $t4, 0
    j draw_held_loop

draw_held_done:
    jr $ra

##############################################################################
# draw_background: paints all 64*64 bitmap units with the bg colour
##############################################################################
draw_background:
    lw $t0, ADDR_DSPL
    lw $t1, COLOR_BACKGROUND
    li $t2, 4096   #64x64 bitmap

draw_background_loop:
    sw $t1, 0($t0)
    addi $t0, $t0, 4
    addi $t2, $t2, -1
    bgtz $t2, draw_background_loop

    jr $ra

##############################################################################
# draw_board
# draws the 7x14 board. each board cell becomes a 4x4 bitmapnunit square
# board begins at bitmap col18(which centres it on the screen)
# $t0: current board cell
# $t1: start of the current display row
# $t2: board row (0-13)
# $t3: board column (0-6)
# $t4: current cell value
# $t5: colour for the current cell
# $t6: top left of the current tile
# $t7: row within the 4x4 tile
# $t8: loop condition
# $t9: current display row within the tile
##############################################################################
draw_board:
    la $t0, BOARD    
    lw $t1, ADDR_DSPL
    addi $t1, $t1, 72  #18 bitmap units x 4 bytes
    li $t2, 0 

draw_board_row_loop:
    li $t3, 0
    add $t6, $t1, $zero

draw_board_column_loop:
    lw $t4, 0($t0)    

    beq $t4, 1, use_pink
    beq $t4, 2, use_green
    beq $t4, 3, use_blue
    beq $t4, 4, use_yellow
    lw $t5, COLOR_DARK_BROWN
    j colour_selected # done filling that pixel on the display up

use_pink:
    lw $t5, COLOR_PINK
    j colour_selected

use_green:
    lw $t5, COLOR_GREEN
    j colour_selected

use_blue:
    lw $t5, COLOR_BLUE
    j colour_selected

use_yellow:
    lw $t5, COLOR_YELLOW

colour_selected:
    add $t9, $t6, $zero  # curr tile row addr
    li $t7, 0

draw_tile_row_loop:
    # draw four units across display ROW
    sw $t5, 0($t9)
    sw $t5, 4($t9)
    sw $t5, 8($t9)
    sw $t5, 12($t9)

    # move down one display row (64x4 bytes)
    addi $t9, $t9, 256
    addi $t7, $t7, 1
    slti $t8, $t7, 4
    bne $t8, $zero, draw_tile_row_loop

    # move to the next board cell   
    addi $t0, $t0, 4
    #move right four bitmap units
    addi $t6, $t6, 16
    addi $t3, $t3, 1
    slti $t8, $t3, 7
    bne $t8, $zero, draw_board_column_loop

    # move down four display row (4x256)bytes
    addi $t1, $t1, 1024
    addi $t2, $t2, 1
    slti $t8, $t2, 14
    bne $t8, $zero, draw_board_row_loop

    jr $ra

##############################################################################
# draw_player
# draws one 4x4 unit box below the current board column
##############################################################################
draw_player:
    lw $t0, ADDR_DSPL
    addi $t0, $t0, 15432  # bitmap position (col 18, row 60)
    lw $t3, PLAYER_COLUMN
    sll $t3, $t3, 4  # each board column is 16 display bytes wide
    add $t0, $t0, $t3 # move the player under its current column
    lw $t1, COLOR_CREAM

    # draw four rows with four units in each row
    sw $t1, 0($t0)
    sw $t1, 4($t0)
    sw $t1, 8($t0)
    sw $t1, 12($t0)
    sw $t1, 256($t0)
    sw $t1, 260($t0)
    sw $t1, 264($t0)
    sw $t1, 268($t0)
    sw $t1, 512($t0)
    sw $t1, 516($t0)
    sw $t1, 520($t0)
    sw $t1, 524($t0)
    sw $t1, 768($t0)
    sw $t1, 772($t0)
    sw $t1, 776($t0)
    sw $t1, 780($t0)
    jr $ra

##############################################################################
# throw_bubbles (Milestone 3b)
# throws all the bubbles the player currently has to the bottom of the bubbles
# in a column

# Temporary Register map:
# (will be added by the second demo)
##############################################################################
throw_bubbles:
    # (1) Saving return address
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)

    # (2) Fetching values that are needed
    lw $t0, HELD_COUNT
    beq $t0, $zero, throw_done

    lw $t6, KEY_COUNT
    addi $t6, $t6, 1
    sw $t6, KEY_COUNT

    # (3) Computing the location that the bubble should go
    lw $t0, PLAYER_COLUMN
    sll $t0, $t0, 2
    
    la $t1, BOARD
    addi $t1, $t1, 364
    add $t1, $t1, $t0

    li $t2, 13

# I liked the fact that you labelled loop portions of your code explicitly as game_loop; I will follow suit
find_landing_loop:
    lw $t3, 0($t1)
    bne $t3, $zero, landing_found
    addi $t1, $t1, -28
    addi $t2, $t2, -1
    bgez $t2, find_landing_loop

landing_found:
    addi $t1, $t1, 28
    addi $t2, $t2, 1

    lw $t3, HELD_COLOR
    lw $t4, HELD_COUNT
    li $s0, 0

place_bubbles_loop:
    # (4) Actually placing the bubble
    beq $t4, $zero, place_done
    li $t5, 14
  IF: 
    bge $t2, $t5, CASE0
    sw $t3, 0($t1)
    addi $t1, $t1, 28
    addi $t2, $t2, 1
    addi $t4, $t4, -1
    j place_bubbles_loop
  CASE0: 
    addi $s0, $zero, 1
    j place_done

place_done:
    sw $zero, HELD_COUNT
    sw $zero, HELD_COLOR

match_chain_loop:
    jal check_vertical_match # Scan & delete matches
    beq $v0, $zero, chain_done # If $v0 == 0 (no match), break out of the loop
    jal apply_gravity          
    j match_chain_loop              

chain_done:
    bne $s0, $zero, exit_program   # Game over by bubble overflowing

    lw $t0, PLAYER_COLUMN
    sll $t0, $t0, 2
    la $t1, BOARD
    addi $t1, $t1, 364
    add $t1, $t1, $t0
    lw $t3, 0($t1)
    bne $t3, $zero, exit_program
    
# Returning to game loop
throw_done: 
    lw $s0, 4($sp)
    lw $ra, 0($sp)
    addi $sp, $sp, 8
    jr $ra

##############################################################################
# check_vertical_match (Milestone 3c)
# see page 17 of the handout for details

# Temporary Register map:
  # t0: outer loop variable, representing the column index
  # t1: inner loop variable, representing the row index
  # t2: a pointer to the current cell in our 7x14 BOARD
  # t3: the colour of $t2
  # t4: the colour of the current vertical streak
  # t5: # of bubbles in the current streak
  # t6: memory addr. where the current streak
  # 7-9: reserved for future modifications
##############################################################################
check_vertical_match:
    # jr $ra # testing purpose
    addi $t0, $zero, 0
    li $v0, 0

match_column_loop: # OUter loop
    sll $t7, $t0, 2
    la $t2, BOARD
    add $t2, $t2, $t7
    addi $t1, $zero, 0
    addi $t4, $zero, 0
    addi $t5, $zero, 0
    move $t6, $t2   # Syntax: move $destination, $source; it's basically a copy function

match_row_loop: # Inner loop
    lw $t3, 0($t2)
    beq $t3, $zero, broken
    bne $t3, $t4, broken

    addi $t5, $t5, 1
    j next_row

broken:
    addi $t7, $zero, 3
    blt $t5, $t7, reset # Branch to reset if the streak has less than 3 bubbles of the same colour
    li $v0, 1
    
    clear_run_loop:
        sw $zero, 0($t6) # Reset the bubbles
        addi $t6, $t6, 28
        addi $t5, $t5, -1
        bgtz $t5, clear_run_loop

    # tracking a new streak
    reset: 
        move $t4, $t3
        move $t6, $t2
        li $t5, 0                 
        beq $t3, $zero, next_row # If empty, keep 0 and jump to next_row
        li $t5, 1

next_row:
    addi $t2, $t2, 28
    addi $t1, $t1, 1
    li $t7, 14
    blt $t1, $t7, match_row_loop

    li $t7, 3
    blt $t5, $t7, next_column

    li $v0, 1

clear_end_loop:
    sw $zero, 0($t6)
    addi $t6, $t6, 28
    addi $t5, $t5, -1
    bgtz $t5, clear_end_loop
    

next_column:
    addi $t0, $t0, 1
    li $t7, 7
    blt $t0, $t7, match_column_loop
    jr $ra

##############################################################################
# Gravity (Hard feature #3)
# A portion of bubble logic that deals with upward gravity; put it as a separate
# section due to complexity

# After bubbles disappear as a result of matching 3+, any bubbles that are no
# longer supported must float upward until there is no gap. 

# Temporary Register map:
  # t0: outer loop variable, representing the column index
  # t1: inner loop variable, representing the row index
  # t2: a pointer to the current cell in our BOARD
  # t3: the bubble colour being popped
  # t4: # of bubbles pushed onto the stack for this column
  # t5: a placeholder for anything
  # t6-9: reserved for future modifications
##############################################################################
apply_gravity:
    addi $t0, $zero, 0

gravity_column_loop: 
    sll $t5, $t0, 2

    # Making $t2 point to row 13 of column $t0
    la $t2, BOARD
    addi $t2, $t2, 364
    add $t2, $t2, $t5
    addi $t1, $zero, 13
    addi $t4, $zero, 0

gravity_push_loop:
    lw $t3, 0($t2)
    beq $t3, $zero, gravity_push_next

    # push $t3 onto the stack
    addi $sp, $sp, -4
    sw $t3, 0($sp)
    sw $zero, 0($t2)
    addi $t4, $t4, 1


gravity_push_next:
    addi $t2, $t2, -28
    addi $t1, $t1, -1
    bge $t1, 0, gravity_push_loop

    beq $t4, $zero, gravity_next_column # nothing was pushed, so we move onto the next column
    addi $t2, $t2, 28

gravity_pop_loop:
    # popping: reverse of line #648-649
    lw $t3, 0($sp)
    addi $sp, $sp, 4

    sw $t3, 0($t2)
    addi $t2, $t2, 28
    addi $t4, $t4, -1
    bgt $t4, 0, gravity_pop_loop
    
gravity_next_column:
    addi $t0, $t0, 1
    blt $t0, 7, gravity_column_loop
    jr $ra

# exit after drawing the static scene
exit_program:
    li $v0, 10
    syscall