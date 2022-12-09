//////////////////////////
// E155 Final Project: 
//		Autofeeder FPGA
//
// Created by Cedar Turek 
// 		cturek@hmc.edu
//		December 1 2022
//
// Modified:
//////////////////////////

typedef enum logic [3:0] {RES, 
						  WRLD, WSTR, WRWT, 
						  FDTM, FSTR, FRWT, 
						  FAMT, ASTR, ARWT} statetype;
module top (
	input  logic reset,
	input  logic tag,					// Tag present for RFID
	input  logic [3:0] col, 			// Columns come in
	output logic [3:0] row, 			// Rows go out
	output logic [6:0] seg,				// Which character to display
	output logic L1, L2, L3, L4, LC, 	// Which LED to display on: L1 is leftmost, LC is center/colon
	output logic M1, M1B, M2, M2B,  	// Motor drivers
	output logic interrupt,
	output logic [2:0] EncodedState);	// State from main FSM
	
	logic clk, slwclk; // 6 and 1.5 MHz clocks
	logic [2:0] digit; // L1: digit = 1, L2: digit = 2, ... , LC: digit = 5
	logic ButtonPressed;
	logic [3:0] D1, D2, D3, D4, DC;
	logic [7:0] Button;
	logic RFID;
	
	// Defining a 6MHz clock
	HSOSC #(.CLKHF_DIV(2'b11)) hf_osc (.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk));
		
	// SPI
		
	// Choose what digit to display
	DisplaySel SelectFive(.clk, 
						  .digit, .L1, .L2, .L3, .L4, .LC);
	
	// Seven Segment Display
	SevenSegDisplay DisplayFive(.D1, .D2, .D3, .D4, .DC, .digit, 
								.seg);
	
	// Keypad FSM
	KeypadScanner ks(.clk, .reset, .col, 
					 .slwclk, .row, .ButtonPressed, .Button);
	
	// Main FSM
	FeedMachine fsm(.slwclk, .reset, .tag, .ButtonPressed, .Button,
					.D1, .D2, .D3, .D4, .DC, .M1, .M1B, .M2, .M2B, 
						.RFID, .interrupt, .EncodedState);

endmodule

////////////////////////////////////////////////////////////////////////////////////////////
//                                      FeedMachine                                      //
//////////////////////////////////////////////////////////////////////////////////////////

/*
Main FSM for autofeeder
*/

module FeedMachine(input  logic slwclk, reset, 
				   input  logic tag, ButtonPressed,
				   input  logic [7:0] Button,
				   output logic [3:0] D1, D2, D3, D4, DC,
				   output logic M1, M1B, M2, M2B, RFID,
				   output logic interrupt,
				   output logic [2:0] EncodedState);
	
	logic mode, edit, cfg;
	logic stinterrupt, rfinterrupt;
	logic [3:0] flashing;
	logic [11:0] InterCnt;
	logic [31:0] coloncnt;
	logic SecondInc, PrevF0, DigitPressed, feedstart;
	logic [2:0] cnt; // number of buttons already pushed
	logic [3:0] digit;
	
	logic [3:0] IT1, IT2, IT3, IT4; // Input World Time:	{IT1 IT2 : IT3 IT4}
	logic [3:0] WT1, WT2, WT3, WT4; // Current World Time: 	{WT1 WT2 : WT3 WT4}
	logic [3:0] PrevWT1, PrevWT2, PrevWT3, PrevWT4; // Previous World Time (for revert)
	logic [3:0] FT1, FT2, FT3, FT4; // Current Feed Time: 	{FT1 FT2 : FT3 FT4}
	logic [3:0] PrevFT1, PrevFT2, PrevFT3, PrevFT4; // Previous Feed Time (for revert)
	logic [3:0] RFIDFT1, RFIDFT2, RFIDFT3, RFIDFT4; // Internal Feed Times (for RFID mode only)
	logic [3:0] FA3, FA4; // Current Feed Amount : {Blank Blank FA3 FA4}
	logic [3:0] PrevFA3, PrevFA4; // Previous Feed Amount (for revert)
	
	// state declaration
	statetype state, nextstate;

	// state register
	always_ff @(posedge slwclk)
		if (~reset) state <= RES;
		else 		state <= nextstate;
			
	/////////////////////////////
	// User Input Definitions //
	///////////////////////////
	/*	8'b11100111 : Mode 		(A)
		8'b11010111 : Edit 		(B)
		8'b10110111 : Config	(C)
		8'b01110111 : N/A		(D)
		8'b01111110 : N/A		(*)
		8'b01111011 : N/A		(#) */
	assign mode = ButtonPressed & (Button == 8'b11100111);
	assign edit = ButtonPressed & (Button == 8'b11010111);
	assign cfg  = ButtonPressed & (Button == 8'b10110111);
	DigitButtonPressed dbp (.ButtonPressed, .Button, .DigitPressed, .digit);
	
	///////////////////////////////////////
	// Configuration and colon register //
	/////////////////////////////////////
	always_ff @(posedge slwclk) begin
		coloncnt <= coloncnt + 1;
		if (~reset) begin 
			RFID <= 0;
			flashing <= 4'b1110;
			rfinterrupt <= 0;
		end else if (coloncnt == 750000) begin 
			flashing <= 4'b1111;
			rfinterrupt <= 0;
		end else if (coloncnt == 1500000) begin
			flashing <= 4'b1110;
			coloncnt <= 0;
			rfinterrupt <= 0;
		end else if (cfg) begin
			RFID <= ~RFID;
			rfinterrupt <= 1;
		end else rfinterrupt <= 0;
	end
	
	always_ff @(posedge slwclk) PrevF0 <= flashing[0];
	
	assign SecondInc = (flashing[0] ^ PrevF0);
	
	/////////////////////
	// state encoding //
	///////////////////
	always_comb
		case (state)
			WRLD: if (RFID) EncodedState = 3'b001;
				  else 		EncodedState = 3'b000;
			WRWT: 			EncodedState = 3'b010;
			FDTM: 			EncodedState = 3'b011;
			FRWT: 			EncodedState = 3'b100;
			FAMT: 			EncodedState = 3'b101;
			ARWT: 			EncodedState = 3'b110;
			default: 		EncodedState = 3'b111;
		endcase
		
	///////////////////////
	// next state logic //
	/////////////////////
	always_comb 
		case (state)
			RES: 	begin				
						nextstate = WRLD;
						stinterrupt = 1;
					end
			// WORLD TIME
			WRLD:	if (mode) begin
						nextstate = FDTM;
						stinterrupt = 1;
					end else if (edit) begin
						nextstate = WSTR;
						stinterrupt = 1;
					end else begin			
						nextstate = WRLD;
						stinterrupt = 0;
					end
			WSTR: 	begin					
						nextstate = WRWT;
						stinterrupt = 0;
					end
			WRWT:	if (cnt == 4) begin
						nextstate = WRLD;
						stinterrupt = 1;
					end else begin
						nextstate = WRWT;
						stinterrupt = 0;
					end
					
			// FEED TIME
			FDTM:	if (mode) begin		
						nextstate = FAMT;
						stinterrupt = 1;
					end else if (edit) begin
						nextstate = FSTR;
						stinterrupt = 1;
					end else begin	
						nextstate = FDTM;
						stinterrupt = 0;
					end
			FSTR:	begin
						nextstate = FRWT;
						stinterrupt = 0;
					end
			FRWT: 	if (cnt == 4) begin	
						nextstate = FDTM;
						stinterrupt = 1;
					end else begin			
						nextstate = FRWT;
						stinterrupt = 0;
					end
					
			// FEED AMOUNT
			FAMT: 	if (mode) begin		
						nextstate = WRLD;
						stinterrupt = 1;
					end else if (edit) begin 
						nextstate = ASTR;
						stinterrupt = 1;
					end else begin
						nextstate = FAMT;
						stinterrupt = 0;
					end
			ASTR: 	begin
						nextstate = ARWT;
						stinterrupt = 0;
					end
			ARWT: 	if (cnt == 2) begin
						nextstate = FAMT;
						stinterrupt = 1;
					end else begin
						nextstate = ARWT;
						stinterrupt = 0;
					end
			default: begin
						nextstate = RES;
						stinterrupt = 0;
					end
		endcase
	
	assign interrupt = stinterrupt | rfinterrupt;
	  //////////////////
	 // output logic //
	//////////////////
	always_ff @(posedge slwclk) begin
		if (SecondInc) begin
			if (WT4 == 9) 
				if (WT3 == 5)
					if (WT2 == 9)
						if (WT1 == 5) begin
							WT1 <= 0;
							WT2 <= 0;
							WT3 <= 0;
							WT4 <= 0;
						end else begin
							WT1 <= WT1 + 1;
							WT2 <= 0;
							WT3 <= 0;
							WT4 <= 0;
						end
					else begin
						WT1 <= WT1;
						WT2 <= WT2 + 1;
						WT3 <= 0;
						WT4 <= 0;
					end
				else begin
					WT1 <= WT1;
					WT2 <= WT2;
					WT3 <= WT3 + 1;
					WT4 <= 0;
				end
			else begin
				WT1 <= WT1;
				WT2 <= WT2;
				WT3 <= WT3;
				WT4 <= WT4 + 1;
			end
			// Revert counter
			if (PrevWT4 == 9) 
				if (PrevWT3 == 5)
					if (PrevWT2 == 9)
						if (PrevWT1 == 5) begin
							PrevWT1 <= 0;
							PrevWT2 <= 0;
							PrevWT3 <= 0;
							PrevWT4 <= 0;
						end else begin
							PrevWT1 <= PrevWT1 + 1;
							PrevWT2 <= 0;
							PrevWT3 <= 0;
							PrevWT4 <= 0;
						end
					else begin
						PrevWT1 <= PrevWT1;
						PrevWT2 <= PrevWT2 + 1;
						PrevWT3 <= 0;
						PrevWT4 <= 0;
					end
				else begin
					PrevWT1 <= PrevWT1;
					PrevWT2 <= PrevWT2;
					PrevWT3 <= PrevWT3 + 1;
					PrevWT4 <= 0;
				end
			else begin
				PrevWT1 <= PrevWT1;
				PrevWT2 <= PrevWT2;
				PrevWT3 <= PrevWT3;
				PrevWT4 <= PrevWT4 + 1;
			end
			// Revert counter
			if (RFIDFT4 == 0) 
				if (RFIDFT3 == 0)
					if (RFIDFT2 == 0)
						if (RFIDFT1 == 0) begin
							if (feedstart) begin
								RFIDFT1 <= FT1;
								RFIDFT2 <= FT2;
								RFIDFT3 <= FT3;
								RFIDFT4 <= FT4;
							end else begin
								RFIDFT1 <= 0;
								RFIDFT2 <= 0;
								RFIDFT3 <= 0;
								RFIDFT4 <= 0;
							end
						end else begin
							RFIDFT1 <= RFIDFT1 - 1;
							RFIDFT2 <= 9;
							RFIDFT3 <= 5;
							RFIDFT4 <= 9;
						end
					else begin
						RFIDFT1 <= RFIDFT1;
						RFIDFT2 <= RFIDFT2 - 1;
						RFIDFT3 <= 5;
						RFIDFT4 <= 9;
					end
				else begin
					RFIDFT1 <= RFIDFT1;
					RFIDFT2 <= RFIDFT2;
					RFIDFT3 <= RFIDFT3 - 1;
					RFIDFT4 <= 9;
				end
			else begin
				RFIDFT1 <= RFIDFT1;
				RFIDFT2 <= RFIDFT2;
				RFIDFT3 <= RFIDFT3;
				RFIDFT4 <= RFIDFT4 - 1;
			end
		end
		//////////////////////////////////////////////////////////////////
		//																//
		//	|||||||||	||||||||||	  |||||||	||||||||||	||||||||||	//
		//	|||     ||	|||			|||     ||	|||				||		//
		//	|||     ||	|||			|||||		|||			    ||    	//
		//	||||||||	||||||||||	  ||||||  	||||||||||		||		//
		//	|||   |||	|||				 |||||	|||				||		//
		//	|||    |||	|||			||     |||	|||				||		//
		//	|||     || 	||||||||||	 |||||||	||||||||||		||		//
		//																//
		//////////////////////////////////////////////////////////////////
		if (state == RES)  begin
			WT1 <= 4'b0;
			WT2 <= 4'b0;
			WT3 <= 4'b0;
			WT4 <= 4'b0;
			FT1 <= 4'b0;
			FT2 <= 4'b0;
			FT3 <= 4'b0;
			FT4 <= 4'b0;
			FA3 <= 4'b0;
			FA4 <= 4'b0;
		end
		//////////////////////////////////////////////////////////////////
		//																//
		//	||  ||  ||	  ||||||| 	|||||||||	|||			||||||||	//
		//	||  ||  ||	|||     || 	|||     ||	|||			|||	   |||	//
		//	||| || |||	|||     ||	|||     ||	|||			|||		||	//	
		//	 || || || 	|||	    ||	||||||||	|||			|||		||	//
		//	 |||||||| 	|||	    ||	|||   |||	|||			|||		||	//	
		//	  ||  ||  	|||	    ||	|||    |||	|||       	|||	   |||	//
		//	  ||  ||  	  ||||||| 	|||     ||	||||||||||	||||||||	//
		//																//
		//////////////////////////////////////////////////////////////////
		else if (state == WRLD) begin
			cnt <= 0;
			D1 <= WT1;
			D2 <= WT2;
			D3 <= WT3;
			D4 <= WT4;
			DC <= flashing; 
		end else if (state == WSTR) begin
			PrevWT1 <= WT1;
			PrevWT2 <= WT2;
			PrevWT3 <= WT3;
			PrevWT4 <= WT4;
			D1 <= 4'b1110;
			D2 <= 4'b1110;
			D3 <= 4'b1110;
			D4 <= 4'b1110;
			DC <= 4'b1111;
		end else if (state == WRWT) begin
			if (DigitPressed) begin
				cnt <= cnt + 1;
				if (cnt == 0) begin
					WT1 <= digit;
					D1  <= digit;
					if ((digit == 6) |
						(digit == 7) |
						(digit == 8) |
						(digit == 9)) begin
						cnt <= 4;
						WT1 <= PrevWT1;
						WT2 <= PrevWT2;
						WT3 <= PrevWT3;
						WT4 <= PrevWT4;
					end
				end else if (cnt == 1) begin
					WT2 <= digit;
					D2  <= digit;
				end else if (cnt == 2) begin
					WT3 <= digit;
					D3  <= digit;
					if ((digit == 6) |
						(digit == 7) |
						(digit == 8) |
						(digit == 9)) begin
						cnt <= 4;
						WT1 <= PrevWT1;
						WT2 <= PrevWT2;
						WT3 <= PrevWT3;
						WT4 <= PrevWT4;
					end
				end else if (cnt == 3) begin
					WT4 <= digit;
					D4  <= digit;
				end
			end else if (edit) begin
				cnt <= 4;
				WT1 <= PrevWT1;
				WT2 <= PrevWT2;
				WT3 <= PrevWT3;
				WT4 <= PrevWT4;
			end
		end 
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////
		//  																										//
		//  ||||||||||	||||||||||	||||||||||	||||||||			||||||||||	||||||||||	||      ||	||||||||||	//
		//  |||			|||			|||			|||	   ||| 				||			||		|||    |||	|||			//
		//  |||			|||			|||			|||     ||				||			||		||||  ||||	|||			//
		//  ||||||||||	||||||||||	||||||||||	|||     ||				||			||		|| |||| ||	||||||||||	//	
		//  |||			|||			|||			|||     ||				||			||		||  ||  ||	|||			//
		//  |||			|||			|||			|||	   |||				||			||		||      ||	|||			//
		//  |||			||||||||||	||||||||||	||||||||				||		||||||||||	||      ||	||||||||||	//
		//																											//
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////
		else if (state == FDTM) begin
			cnt <= 0;
			if (RFID) begin
				D1 <= RFIDFT1;
				D2 <= RFIDFT2;
				D3 <= RFIDFT3;
				D4 <= RFIDFT4;
				DC <= 4'b1111;
			end else begin
				D1 <= FT1;
				D2 <= FT2;
				D3 <= FT3;
				D4 <= FT4;
				DC <= 4'b1111;
			end
		end else if (state == FSTR) begin
			PrevFT1 <= FT1;
			PrevFT2 <= FT2;
			PrevFT3 <= FT3;
			PrevFT4 <= FT4;
			D1 <= 4'b1110;
			D2 <= 4'b1110;
			D3 <= 4'b1110;
			D4 <= 4'b1110;
			DC <= 4'b1111;
		end else if (state == FRWT) begin
			if (DigitPressed) begin
				cnt <= cnt + 1;
				if (cnt == 0) begin
					FT1 <= digit;
					D1  <= digit;
					if ((digit == 6) |
						(digit == 7) |
						(digit == 8) |
						(digit == 9)) begin
						cnt <= 4;
						FT1 <= PrevFT1;
						FT2 <= PrevFT2;
						FT3 <= PrevFT3;
						FT4 <= PrevFT4;
					end
				end else if (cnt == 1) begin
					FT2 <= digit;
					D2  <= digit;
				end else if (cnt == 2) begin
					FT3 <= digit;
					D3  <= digit;
					if ((digit == 6) |
						(digit == 7) |
						(digit == 8) |
						(digit == 9)) begin
						cnt <= 4;
						FT1 <= PrevFT1;
						FT2 <= PrevFT2;
						FT3 <= PrevFT3;
						FT4 <= PrevFT4;
					end
				end else if (cnt == 3) begin
					FT4 <= digit;
					D4  <= digit;
					RFIDFT1 <= FT1;
					RFIDFT2 <= FT2;
					RFIDFT3 <= FT3;
					RFIDFT4 <= FT4;
				end
			end else if (edit) begin
				cnt <= 4;
				FT1 <= PrevFT1;
				FT2 <= PrevFT2;
				FT3 <= PrevFT3;
				FT4 <= PrevFT4;
			end
		end 
		//////////////////////////////////////////////////////////////////////////////
		//																			//
		//        ||  	||      ||	  |||||||  	|||     ||	|||     ||	||||||||||	//
		//       |||| 	|||    |||	|||     ||	|||     ||	||||    ||		||		//
		//      || ||	||||  ||||	|||	    ||	|||     ||	|||||   ||		||		//
		//     ||  |||	|| |||| ||	|||     ||	|||     ||	||| ||  ||		||		//
		//    |||||||| 	||  ||  ||	|||     ||	|||     ||	|||  || ||		||		//
		//   |||    || 	||      ||	|||     ||	 |||   |||	|||   ||||		||		//
		//  |||     ||	||      ||	  |||||||  	  ||||||| 	|||    |||		||		//
		//																			//
		//////////////////////////////////////////////////////////////////////////////
		else if (state == FAMT) begin
			cnt <= 0;
			D1 <= 4'b1110;
			D2 <= 4'b1110;
			D3 <= FA3;
			D4 <= FA4;
			DC <= 4'b1110;
		end else if (state == ASTR) begin
			PrevFA3 <= FA3;
			PrevFA4 <= FA4;
			D1 <= 8'b1110;
			D2 <= 8'b1110;
			D3 <= 8'b1110;
			D4 <= 8'b1110;
			DC <= 8'b1110;
		end else if (state == ARWT) begin
			if (DigitPressed) begin
				cnt <= cnt + 1;
				if (cnt == 0) begin
					FA3 <= digit;
					D3  <= digit;
				end else if (cnt == 1) begin
					FA4 <= digit;
					D4  <= digit;
				end
			end else if (edit) begin
				cnt <= 2;
				FA3 <= PrevFA3;
				FA4 <= PrevFA4;
			end
		end
	end
	
	  /////////////////
	 // Motor Start //
	/////////////////
	always_ff @(posedge slwclk) begin
		if (RFID) begin
			if (tag & (
				(RFIDFT1 == 4'b0) &
				(RFIDFT2 == 4'b0) &
				(RFIDFT3 == 4'b0) &
				(RFIDFT4 == 4'b0)))	
					feedstart <= 1;
			else	feedstart <= 0;
		end else
			if ((WT1 == FT1) & 
				(WT2 == FT2) & 
				(WT3 == FT3) & 
				(WT4 == FT4))
					feedstart <= 1;
			else 	feedstart <= 0;
	end
	MotorControl mc(.slwclk, .reset, .feedstart, .FA3, .FA4,
					.M1, .M1B, .M2, .M2B);
endmodule

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 // 									                     MotorControl 	                           									 //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*
Controls motor when it's time
*/

module MotorControl(input  logic slwclk, reset, feedstart,
					input  logic [3:0] FA3, FA4,
					output logic M1, M1B, M2, M2B);
	
	logic [31:0] QStepCounter;
	logic [15:0] StepCounter, RevCounter;
	logic 		 Finished;
	
	typedef enum logic [1:0] {IDLE, BUSY, DONE} mcstatetype;
	mcstatetype state, nextstate;
	
	// State Register
	always_ff @(posedge slwclk)
		if (~reset) state <= IDLE;
		else		state <= nextstate;
	
	// Next State Logic
	always_comb
		case (state)
			IDLE: if (feedstart) nextstate = BUSY;
				  else 			 nextstate = IDLE;
			BUSY: if (Finished)  nextstate = DONE;
				  else			 nextstate = BUSY;
			DONE: 				 nextstate = IDLE;
			default: 			 nextstate = IDLE;
		endcase
		
	always_ff @(posedge slwclk) begin
		QStepCounter <= QStepCounter + 1;
		if (state == IDLE) begin 
			QStepCounter <= 0;
			RevCounter <= 0;
			Finished <= 0;
			M1 <= 0;
			M1B <= 0;
			M2 <= 0;
			M2B <= 0;
		end else if (state == BUSY)
			if (RevCounter == (FA3 * 10 + FA4)) Finished <= 1;
			if (QStepCounter == 5000) begin
				M1 <= 1;
				M1B <= 0;
				M2 <= 0;
				M2B <= 1;
			end else if (QStepCounter == 10000) begin
				M1 <= 1;
				M1B <= 0;
				M2 <= 1;
				M2B <= 0;
			end else if (QStepCounter == 15000) begin
				M1 <= 0;
				M1B <= 1;
				M2 <= 1;
				M2B <= 0;
			end else if (QStepCounter == 20000) begin
				QStepCounter <= 0;
				M1 <= 0;
				M1B <= 1;
				M2 <= 0;
				M2B <= 1;
				StepCounter <= StepCounter + 1;
				if (StepCounter == 49) begin
					StepCounter <= 0;
					RevCounter <= RevCounter + 1;
				end
			end
		else if (state == DONE) begin
			M1 <= 0;
			M1B <= 0;
			M2 <= 0;
			M2B <= 0;
		end
	end
endmodule

/////////////////////////
// DigitButtonPressed //
///////////////////////

/*
Checks to see if a digit is pressed
*/

module DigitButtonPressed(input  logic ButtonPressed,
						  input  logic [7:0] Button,
						  output logic DigitPressed,
						  output logic [3:0] digit);
	
	// Check if input is a digit
	logic isDigit;
	always_comb
		case (Button)
			8'b01111101 : digit = 0;
			8'b11101110 : digit = 1;
			8'b11101101 : digit = 2;
			8'b11101011 : digit = 3;
			8'b11011110 : digit = 4;
			8'b11011101 : digit = 5;
			8'b11011011 : digit = 6;
			8'b10111110 : digit = 7;
			8'b10111101 : digit = 8;
			8'b10111011 : digit = 9;
			default		: digit = 12;
		endcase
	
	assign DigitPressed = ButtonPressed & (digit != 12);
	
endmodule

////////////////////
// KeypadScanner //
//////////////////

/*
Returns whether the user has pushed a button
	and what button they pushed.
*/

module KeypadScanner(input  logic clk, reset,
					 input  logic [3:0] col,
					 output logic [3:0] row,
					 output logic ButtonPressed, slwclk,
					 output logic [7:0] Button);
					 
	// Keypad data
	logic [3:0] keys0, keys1, keys2, keys3;

	// Row pointer and clk scaling
	logic [2:0] rp;
	assign slwclk = rp[2];
	
	// Flags for state switching
	logic pressed;
	
	// Switch bounce indicators
	logic [31:0] disphold;
	logic ddone;
	
	// statetype and state declaration
	typedef enum logic [2:0] {SCAN, STOR, UNDO, SHLD, DISP, DHLD} keystatetype;
	keystatetype state, nextstate;

	// state register
	always_ff @(posedge slwclk)
		if (~reset) state <= SCAN;
		else 		state <= nextstate;
	
	// next state logic
	always_comb 
		case (state)
			SCAN:	if (pressed) 	nextstate = STOR;
					else 			nextstate = SCAN;
			STOR: 					nextstate = UNDO;
			UNDO:					nextstate = SHLD;
			SHLD: 	if (ddone) 		nextstate = DISP;
					else			nextstate = SHLD;
			DISP: 	if (pressed) 	nextstate = DISP;
					else 			nextstate = DHLD;
			DHLD: 	if (ddone)		nextstate = SCAN;
					else			nextstate = DHLD;
			default: 				nextstate = SCAN;
		endcase

	// row counter
	always_ff @(posedge clk) rp <= rp + 1;
	
	// row output
	decoder pickrow(.pointer(rp[1:0]), .row);
	
	// Scan all 16 keys, keep in register
	always_ff @(posedge clk)
		if 		(rp[1:0] == 2'b00) 	keys0 <= col;
		else if (rp[1:0] == 2'b01) 	keys1 <= col;
		else if (rp[1:0] == 2'b10) 	keys2 <= col;
		else 						keys3 <= col;

	// Digit checker
	onecold digitcheck(.keys0, .keys1, .keys2, .keys3, .pressed, .Button);
	
	// output logic
	always_ff @(posedge slwclk)
		if (state == SCAN) begin
			disphold <= 0;
			ddone <= 0;
		end else if (state == STOR) begin
			ButtonPressed = 1;
		end else if (state == UNDO) begin
			ButtonPressed = 0;
		end else if (state == SHLD) begin
			disphold <= disphold + 1;
			if (disphold == 31'd30000) ddone <= 1;
		end else if (state == DISP) begin
			disphold <= 0;
			ddone <= 0;
		end else if (state == DHLD) begin
			disphold <= disphold + 1;
			if (disphold == 31'd30000) ddone <= 1;
		end
		
endmodule

//////////////
// onecold //
////////////
/*
Takes in four rows of data; returns
	flags indicating zero, one, or
	more than one bits low. Saves
	singularly low bits.
*/

module onecold(
	input  logic [3:0] keys0, keys1, keys2, keys3,
	output logic pressed,
	output logic [7:0] Button);
	
	logic [2:0] sum0, sum1, sum2, sum3;
	logic [4:0] sumall;
	
	assign sum0 = keys0[0] + keys0[1] + keys0[2] + keys0[3];
	assign sum1 = keys1[0] + keys1[1] + keys1[2] + keys1[3];
	assign sum2 = keys2[0] + keys2[1] + keys2[2] + keys2[3];
	assign sum3 = keys3[0] + keys3[1] + keys3[2] + keys3[3];
	assign sumall = sum0 + sum1 + sum2 + sum3;
	
	always_comb
		if (sumall == 5'b10000) begin
			pressed = 1'b0;
			Button = 8'b0;
		end else begin
			pressed = 1'b1;
			if 		(sum0 == 4'b011) Button = {4'b1110, keys0};
			else if (sum1 == 4'b011) Button = {4'b1101, keys1};
			else if (sum2 == 4'b011) Button = {4'b1011, keys2};
			else 					 Button = {4'b0111, keys3};
		end
endmodule


//////////////
// decoder //
////////////
/*
Simple two-to-four decoder
*/

module decoder(
	input  logic [1:0] pointer,
	output logic [3:0] row);
	
	always_comb
		case(pointer)
			2'b00: row = 4'b1110;
			2'b01: row = 4'b1101;
			2'b10: row = 4'b1011;
			2'b11: row = 4'b0111;
		endcase
endmodule
	
///////////////
// dispSel //
/////////////
/*
This module sets pins to determine 
	which display to turn on.
*/

module DisplaySel(
	input  logic clk,
	output logic [2:0] digit, // L1: digit = 1, L2: digit = 2, ... , LC: digit = 5
	output logic L1, L2, L3, L4, LC);

	logic [24:0] counter;	
	
	always_ff @(posedge clk) begin
		counter <= counter + 1;
		if (counter == 50000) begin 
			counter <= 0;
			L1 <= 0;
			L2 <= 1;
			L3 <= 1;
			L4 <= 1;
			LC <= 1;
			digit <= 1;
		end else if (counter == 8000)  L1 <= 1;
			else if (counter == 10000) begin
			L2 <= 0;
			digit <= 2;
		end else if (counter == 18000) L2 <= 1;
			else if (counter == 20000) begin
			L3 <= 0;
			digit <= 3;
		end else if (counter == 28000) L3 <= 1;
			else if (counter == 30000) begin
			L4 <= 0;
			digit <= 4;
		end else if (counter == 38000) L4 <= 1;
			else if (counter == 40000) begin
			LC <= 0;
			digit <= 5;
		end else if (counter == 48000) LC <= 1;
	end
endmodule
	

module SevenSegDisplay(
	input  logic [3:0] D1, D2, D3, D4, DC,
	input  logic [2:0] digit,
	output logic [6:0] seg);

	// Digits are of the form {row[3:0], col[3:0]}
	logic [3:0] dsel;
	
	always_comb
		case (digit)
			3'b001  : dsel = D1;
			3'b010  : dsel = D2;
			3'b011  : dsel = D3;
			3'b100  : dsel = D4;
			3'b101  : dsel = DC;
			default : dsel = 11;
		endcase
		
	always_comb
		case (dsel)
			// Digits		   abcdefg
			4'b0000 : seg = 7'b0000001; // 0
			4'b0001 : seg = 7'b1001111; // 1
			4'b0010 : seg = 7'b0010010; // 2
			4'b0011 : seg = 7'b0000110; // 3
			4'b0100 : seg = 7'b1001100; // 4
			4'b0101 : seg = 7'b0100100; // 5
			4'b0110 : seg = 7'b0100000; // 6
			4'b0111 : seg = 7'b0001111; // 7
			4'b1000 : seg = 7'b0000000; // 8
			4'b1001 : seg = 7'b0000100; // 9
			// Special Cases
			4'b1011 : seg = 7'b1000010; // d
			4'b1100 : seg = 7'b1100000; // b
			4'b1110 : seg = 7'b1111111; // All off
			4'b1111 : seg = 7'b0010000; // colon
			default : seg = 7'b1111110; // -
		endcase
endmodule
