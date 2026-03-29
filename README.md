# FPGA 2048 Game

## Overview
This project implements the classic 2048 game on FPGA using Verilog.  
The system handles user input, game logic, and real-time VGA display, demonstrating digital design and hardware system integration.

## Features
- Full implementation of 2048 game logic (tile movement and merging)
- Real-time VGA display output
- Button-based user input control
- Random tile generation using LFSR
- Modular hardware design for scalability

## System Architecture
Button Input → Game Logic → Board Update → VGA Display

## Technologies
- Verilog HDL
- FPGA (Vivado)
- VGA Display
- LFSR (Random number generation)

## Project Structure
- `DEMO/` : demo files or project presentation
- `2048.xpr` : Vivado project file
- `Divider_Clock.v` : clock divider for system timing
- `Pattern.v` : game logic and tile control
- `Top_vga.v` : top module integrating system components
- `VGAControll.v` : VGA display controller
- `EGo1.xdc` : FPGA pin constraints

## How to Run
1. Open `2048.xpr` in Vivado
2. Synthesize and implement the design
3. Generate the bitstream
4. Program the FPGA board
5. Use buttons to control the game and view output on VGA display

## Result
- Real-time game interaction on FPGA
- Smooth tile movement and merging behavior
- VGA display shows updated game board instantly

## Demo
https://drive.google.com/file/d/1P3UjsAK0TmJTQwda9dtw_CHRdUI8Gaqi/view?usp=sharing

