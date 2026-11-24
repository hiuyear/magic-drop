################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Magical Drop.
#
# Student 1: Hiu Yan Kwok, 1010969855
# Student 2: Name, Student Number (if applicable)
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

##############################################################################
# Mutable Data
##############################################################################
# 14 rows x 7 cols, each cell is one word:
# 0 = empty, 1 = pink, 2 = green, 3 = blue, 4 = yellow
BOARD:
    .space 392  # 14x7x4 bytes
PLAYER_COLUMN:
    .word 3  # start in the centre column (columns are 0-6)

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
    jal draw_background
    jal draw_board
    jal draw_player

    li $v0, 32
    li $a0, 16
    syscall

    # 5. Go back to Step 1
    j game_loop

##############################################################################
#1.
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
    sw $a0, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, -1
    bgtz $t1, random_board_loop

    jr $ra

##############################################################################
# check_keyboard
# handles a d and q
##############################################################################
check_keyboard:
    lw $t0, ADDR_KBRD
    lw $t1, 0($t0)
    beq $t1, 1, key_pressed
    jr $ra

key_pressed:
    lw $t2, 4($t0)
    beq $t2, 0x61, move_left
    beq $t2, 0x64, move_right
    beq $t2, 0x71, exit_program
    jr $ra

move_left:
    lw $t3, PLAYER_COLUMN
    beq $t3, $zero, keyboard_done
    addi $t3, $t3, -1
    sw $t3, PLAYER_COLUMN
    j keyboard_done

move_right:
    lw $t3, PLAYER_COLUMN
    li $t4, 6
    beq $t3, $t4, keyboard_done
    addi $t3, $t3, 1
    sw $t3, PLAYER_COLUMN

keyboard_done:
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

# exit after drawing the static scene
exit_program:
    li $v0, 10
    syscall
