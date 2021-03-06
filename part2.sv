module part2
	(
	CLOCK_50, //	On Board 50 MHz
	// Your inputs and outputs here
	KEY,
	SW,
	HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, LEDR,
	// The ports below are for the VGA output.  Do not change.
	VGA_CLK, //	VGA Clock
	VGA_HS, //	VGA H_SYNC
	VGA_VS, //	VGA V_SYNC
	VGA_BLANK_N, //	VGA BLANK
	VGA_SYNC_N, //	VGA SYNC
	VGA_R, //	VGA Red[9:0]
	VGA_G, //	VGA Green[9:0]
	VGA_B , //	VGA Blue[9:0]
	PS2_DAT,
	PS2_CLK
);

	input logic  CLOCK_50; //	50 MHz
	inout logic PS2_DAT;
	inout logic PS2_CLK;
	input logic [9:0]   SW;
	// Use SW[0] to enable the Delay/Frame counter so that the output will be 1 for these.
	input logic  [3:0]   KEY;

	output [6:0] HEX0;
	output [6:0] HEX1;
	output [6:0] HEX2;
	// HEX2,HEX1,HEX0 will display the score for the right-hand side player;
	// Add 1 to the right hand side score if the ball touches the left wall
	output [6:0] HEX3;
	output [6:0] HEX4;
	output [6:0] HEX5;
	// HEX5,HEXR4,HEX3 will display the score for the left-hand side player;
	// Add 1 to the left  hand side score if the ball touches the right wall

	output logic [9:0] LEDR;

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK; //	VGA Clock
	output			VGA_HS; //	VGA H_SYNC
	output			VGA_VS; //	VGA V_SYNC
	output			VGA_BLANK_N; //	VGA BLANK
	output			VGA_SYNC_N; //	VGA SYNC
	output	[9:0]	VGA_R; //	VGA Red[9:0]
	output	[9:0]	VGA_G; //	VGA Green[9:0]
	output	[9:0]	VGA_B; //	VGA Blue[9:0]

	logic enableHEX;
	assign enableHEX = SW[6];

	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	// Notice that we need 8 bits for x input and 7 bits for y input
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;

	wire [2:0] colour;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
		.resetn(SW[2]),
		.clock(CLOCK_50),
		.colour(colour),
		.x(x),
		.y(y),
		.plot(writeEn),
		/* Signals for the DAC to drive the monitor. */
		.VGA_R(VGA_R),
		.VGA_G(VGA_G),
		.VGA_B(VGA_B),
		.VGA_HS(VGA_HS),
		.VGA_VS(VGA_VS),
		.VGA_BLANK(VGA_BLANK_N),
		.VGA_SYNC(VGA_SYNC_N),
		.VGA_CLK(VGA_CLK));
	defparam VGA.RESOLUTION = "160x120";
	defparam VGA.MONOCHROME = "FALSE";
	defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
	defparam VGA.BACKGROUND_IMAGE = "black.mif";

	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.
	logic valid;
	logic makeBreak;
	logic [7:0] outCode;
	assign LEDR[0] = valid;
	assign LEDR[1] = makeBreak;
	//  assign LEDR[9:2] = outCode;
	keyboard_press_driver keytest(
		.CLOCK_50(CLOCK_50),
		.valid(valid),
		.makeBreak(makeBreak),
		.outCode(outCode),
		.PS2_DAT(PS2_DAT),
		.PS2_CLK(PS2_CLK),
		.reset(~SW[2])
	);


	wire lhitPulse; // 1 if the object hits the left wall
	wire rhitPulse; // 1 if the object hits the right wall
	wire [7:0]lscore; //score for the left hand player
	wire [7:0]rscore; //score for the right hand player
	wire [7:0]strike;

	//timecounter signals for FSM
	wire erase, draw, signal;

	//ball position
	wire [7:0] xCounter;
	wire [6:0] yCounter;


	wire [7:0] leftPaddleXpos, rightPaddleXpos;

	assign leftPaddleXpos = 8'd12;
	assign rightPaddleXpos = 8'd147;

	wire enableCounter;
	logic pause;

	//28 bits of RNG
	logic [27:0] rng;
	always@(posedge CLOCK_50, negedge SW[2]) begin
		if (~SW[2])
			rng <= 1'b0;
		else
			rng <= rng + 1'b1;
	end

	logic [6:0] lPaddleMin;
	assign lPaddleMin = (ylpaddle <= 7'd4) ? 1'b0 : ylpaddle - 7'd4;
	logic [6:0] rPaddleMin;
	assign rPaddleMin = (yrpaddle <= 7'd4) ? 1'b0 : yrpaddle - 7'd4;

	logic softReset; //Soft reset is for repositioning paddles and balls. When it goes high, all balls+paddles should reposition
	//	assign softReset = ((lPaddleMin > yCounter | yCounter > ylpaddle + 7'd20) & lhitPulse) | ((rPaddleMin > yCounter | yCounter > ylpaddle + 7'd20) & rhitPulse) | SW[4];
	assign softReset = LmissedPaddle | RmissedPaddle | SW[4];
	assign LEDR[9] = softReset;
	assign LEDR[8] = delayedLMP;
	assign LEDR[7] = delayedRMP;
	TimeCounter tc(
		.count_enable(enableHEX),
		.clk(CLOCK_50),
		.reset_n(SW[2]),
		.difficulty(SW[1:0]),
		.display(signal), //1 tick
		.erase(erase),
		.draw(draw),
		.pause(pause)
	);
	XCounter xc(
		.count_enable(enableHEX),
		.clk(signal),
		.reset_n(SW[2]),
		.xDisplay(xCounter),
		.lhitPulse(lhitPulse),
		.rhitPulse(rhitPulse),
		.softReset(softReset),
		.rng(rng[25] ^ rng[1])
	);

	YCounter yc(
		.count_enable(enableHEX), //not implemented yet
		.clk(signal),
		.reset_n(SW[2]),
		.yDisplay(yCounter),
		.softReset(softReset),
		.rng(rng[23] ^ rng[3])
	);
	logic clock25;
	//loop to detect if score, and if so, trigger soft reset
	always@(posedge CLOCK_50) begin

		clock25 <= ~clock25;
		if(lhitPulse) begin
			if (yCounter < lPaddleMin | yCounter > ylpaddle + 7'd20) begin
				//missed paddle
				LmissedPaddle <= 1'b1;
			end
		end
		else if (rhitPulse) begin
			if (yCounter < rPaddleMin | yCounter > yrpaddle + 7'd20) begin
				//missed paddle
				RmissedPaddle <= 1'b1;
			end
		end
		else if (delayedLMP | delayedRMP) begin
			LmissedPaddle <= 1'b0;
			RmissedPaddle <= 1'b0;
		end
	end

	logic delayedLMP, delayedRMP;
	always@(posedge clock25) begin
		if(LmissedPaddle)
			delayedLMP <= 1'b1;
		else if (RmissedPaddle)
			delayedRMP <= 1'b1;
		else begin
			delayedLMP <= 1'b0;
			delayedRMP <= 1'b0;
		end
	end

	wire [6:0] ylpaddle; // the left paddle
	wire [6:0] yrpaddle; // the right paddle
	wire lup;
	wire ldown;
	wire rup;
	wire rdown;
	lKeyBoardDetector lDetect(.clock(CLOCK_50), .outCode(outCode),.makeCode(makeBreak),.lupCondition(lup),.ldownCondition(ldown));
	rKeyBoardDetector rDetect(.clock(CLOCK_50), .outCode(outCode),.makeCode(makeBreak),.rupCondition(rup),.rdownCondition(rdown));
	YPaddle yleftPaddle(
		.clk(signal),
		.reset_n(SW[2]),
		.moveEnable(SW[3]),
		.up(lup),
		.down(ldown),
		.ypDisplay(ylpaddle),
		.softReset(softReset)
	);

	YPaddle yrightPaddle(
		.clk(signal),
		.reset_n(SW[2]),
		.moveEnable(SW[3]),
		.up(rup),
		.down(rdown),
		.ypDisplay(yrpaddle),
		.softReset(softReset)
	);

	logic lsignal, rsignal;
	logic [7:0] lstrike;
	logic [7:0] rstrike;
	wire rreset;
	wire lreset;
	logic LmissedPaddle, RmissedPaddle;
	LeftScoreCounter lScore(
		.clock(CLOCK_50),
		.enable(lhitPulse),
		.Ypos(yCounter),
		.lpaddle(ylpaddle),
		.reset(SW[2]),
		.lscore(lscore),
		.lstrike(lstrike),
		.inResetStrike(rreset),
		.outResetStrike(lreset)
	);
	RightScoreCounter rScore(
		.clock(CLOCK_50),
		.enable(rhitPulse),
		.Ypos(yCounter),
		.reset(SW[2]),
		.rpaddle(yrpaddle),
		.rscore(rscore),
		.rstrike(rstrike),
		.inResetStrike(lreset),
		.outResetStrike(rreset)
	);

	StrikeDetector strikeDetect(
		.enable(enableHEX & (lhitPulse | rhitPulse)),
		.reset(SW[2]),
		.softReset(softReset),
		.strike(strike),
		.clock(signal)
	);
	datapathFSM fsm0(
		.clock(CLOCK_50),
		//draw/erase signals from ratedivider
		.eraseIn(erase), //generated by ratedivider
		.drawIn(draw), //generated by ratedivider
		//square inputs
		.Xin(xCounter), //X determined by Xcounter
		.Yin(yCounter), //Y determined by Ycounter
		//left paddle inputs
		.leftPaddleXin(leftPaddleXpos),
		.leftPaddleYin(ylpaddle),
		//right paddle inputs
		.rightPaddleXin(rightPaddleXpos),
		.rightPaddleYin(yrpaddle),
		.resetn(SW[2]), //key0, active low, as pressing key results in 0
		.colorSwitch(SW[9:7]), //switches determine color - optional
		.enableCounter(enableCounter),
		.Xout(x),
		.Yout(y),
		.colour(colour),
		.writeEn(writeEn),
		.softReset(softReset)
	);

	// HEXO,HEX1,HEX2 displays the right hand player score
	hex_decoder hexzero(.hex_digit(lscore[3:0]),.segments(HEX0));
	hex_decoder hexone(.hex_digit(lscore[7:4]),.segments(HEX1));
	hex_decoder hextwo(.hex_digit(strike[3:0]),.segments(HEX2));
	//	hex_decoder hextwo(.hex_digit(outCode[3:0]),.segments(HEX2));

	// HEX3,HEX4,HEX5 displays the left hand player score
	hex_decoder hexthree(.hex_digit(strike[7:4]),.segments(HEX3));
	//	hex_decoder hexthree(.hex_digit(outCode[7:4]),.segments(HEX3));
	hex_decoder hexfour(.hex_digit(rscore[3:0]),.segments(HEX4));
	hex_decoder hexfive(.hex_digit(rscore[7:4]),.segments(HEX5));
endmodule

module testRightScore(input enable, input reset, input lhitPulse,input [6:0] ylpaddle, input [6:0]yCounter, output [7:0] rightscore);
	LeftScoreDetector lDetect(
		.enable(enable),
		.lhit(lhitPulse),
		.lpaddle(ylpaddle),
		.yobject(yCounter),
		.lsignal(lsignal));
	RightScoreCounter rScore(.enable(enable),.reset(reset),.lsignal(lsignal),.rscore(rightscore));
endmodule

module testControl(input signal, input reset, input enable, input lup, input ldown, input rup, input rdown, output [6:0] ylpaddle,output [6:0] yrpaddle);
	YPaddle yleftPaddle(
		.clk(signal),
		.reset_n(reset),
		.moveEnable(enable),
		.up(lup),
		.down(ldown),
		.ypDisplay(ylpaddle)
	);

	YPaddle yrightPaddle(
		.clk(signal),
		.reset_n(reset),
		.moveEnable(enable),
		.up(rup),
		.down(rdown),
		.ypDisplay(yrpaddle)
	);

endmodule

module StrikeDetector(enable, reset,clock,softReset, strike);
	//TODO: change it so it only counts hits, not nonhits
	input enable;
	input reset;
	input softReset;
	input clock;
	output logic [7:0]strike;
	always @(posedge clock, negedge reset, posedge softReset)
	begin
		if (!reset)
			strike <= 1'b0;
		else if (softReset)
			strike <= 1'b0;
		else if (enable == 1'b1)
			strike <= strike + 1'b1;
	end
endmodule

// update and count the score for the left hand side user
module LeftScoreCounter(input clock, input enable, input [6:0] Ypos, input [6:0] lpaddle, input reset, output logic [7:0] lscore,
	output logic [7:0] lstrike,input inResetStrike,output logic outResetStrike);
	// update signal, clk is 1 when object hits the right wall
	logic [6:0] lPaddleMin;
	always @(posedge clock, negedge reset)
	begin
		if(!reset)
			lscore <= 1'b0;
		else if (enable)
			begin
				lPaddleMin = (lpaddle <= 7'd4) ? 1'b0 : lpaddle - 7'd4;
				if (lPaddleMin <= Ypos & Ypos <= lpaddle + 7'd20)
					begin
						if (reset == 1'b0 || lstrike== 8'b11111111 || inResetStrike == 1'b1)
							begin
								lstrike <= 8'b00000001;
								outResetStrike <= 1'b0;
							end
						else
							begin
								lstrike <= lstrike + 8'b00000001;
								outResetStrike <= 1'b1;
							end
					end
				else
					begin
						lscore <= lscore + 1'b1;
						lstrike <= 8'b00000000;
						outResetStrike <= 1'b1;
					end
			end
	end
endmodule

// update and count the score for the right hand side user
module RightScoreCounter(input clock, input enable, input [6:0] Ypos, input [6:0] rpaddle, input reset, output logic [7:0] rscore,
	output logic [7:0] rstrike, input inResetStrike,output logic outResetStrike);
	// update signal, clk is 1 when object hits the left wall

	logic [6:0] rPaddleMin;
	always @(posedge clock, negedge reset)
	begin
		if(!reset)
			rscore <= 1'b0;
		else if (enable)
			begin
				rPaddleMin = (rpaddle <= 7'd4) ? 1'b0 : rpaddle - 7'd4;
				if (rPaddleMin <= Ypos & Ypos <= rpaddle + 7'd20)
					begin
						if (reset == 1'b0 || rstrike== 8'b11111111 || inResetStrike == 1'b1)
							begin
								rstrike <= 8'b00000001;
								outResetStrike <= 1'b0;
							end
						else
							begin
								rstrike <= rstrike + 8'b00000001;
								outResetStrike <= 1'b0;
							end
					end
				else
					begin
						rscore <= rscore + 1'b1;
						rstrike <= 8'b00000000;
						outResetStrike <= 1'b1;
					end
			end
	end
endmodule

module lKeyBoardDetector(input logic clock, input [7:0] outCode, input makeCode,output logic lupCondition = 0, output logic ldownCondition=0);

	always@(posedge clock)
	begin
		case({outCode,makeCode})
			9'b000111011: begin
				lupCondition <= 1 ;
				ldownCondition<=0;
			end
			9'b000111010: begin
				lupCondition <= 0 ;
				ldownCondition<=0;
			end
			9'b000110111: begin
				lupCondition <= 0;
				ldownCondition<= 1;
			end
			9'b000110110: begin
				lupCondition <= 0;
				ldownCondition<= 0;
			end
			default:      begin
				lupCondition <= lupCondition ;
				ldownCondition<= ldownCondition;
			end
		endcase
	end
endmodule

module rKeyBoardDetector(input logic clock, input [7:0] outCode, input makeCode,output logic rupCondition=0, output logic rdownCondition=0);
	always@(posedge clock)
	begin
		case({outCode,makeCode})
			9'b011101011: begin
				rupCondition <= 1 ;
				rdownCondition<=0;
			end
			9'b011101010: begin
				rupCondition <= 0 ;
				rdownCondition<=0;
			end
			9'b011100101: begin
				rupCondition <= 0;
				rdownCondition<= 1;
			end
			9'b011100100: begin
				rupCondition <= 0;
				rdownCondition<= 0;
			end
			default:      begin
				rupCondition <= rupCondition;
				rdownCondition<= rdownCondition;
			end
		endcase
	end
endmodule

//module that primarily interacts with vga
module datapathFSM(
	input clock,
	//draw/erase signals from ratedivider
	input eraseIn, //generated by ratedivider
	input drawIn, //generated by ratedivider
	//square inputs
	input [7:0] Xin, //X determined by Xcounter
	input [6:0] Yin, //Y determined by Ycounter
	//left paddle inputs
	input [7:0] leftPaddleXin,
	input [6:0] leftPaddleYin,
	//right paddle inputs
	input [7:0] rightPaddleXin,
	input [6:0] rightPaddleYin,
	input resetn, //key0, active low, as pressing key results in 0
	input [2:0] colorSwitch, //switches determine color - optional
	output logic enableCounter,
	output logic [7:0] Xout,
	output logic [6:0] Yout,
	output logic [2:0] colour,
	output logic writeEn,
	input softReset
);

	//states 
	logic [3:0] current_state, next_state;

	localparam 	S_DRAW_BORDER = 4'd0,
	S_INIT_OBJ = 4'd1,
	S_DRAW_SQUARE = 4'd2,
	S_DRAW_LEFT_PADDLE = 4'd3,
	S_DRAW_RIGHT_PADDLE = 4'd4,
	S_WAIT_ERASE = 4'd5,
	S_ERASE_SQUARE = 4'd6,
	S_ERASE_LEFT_PADDLE = 4'd7,
	S_ERASE_RIGHT_PADDLE = 4'd8,
	S_WAIT_DRAW = 4'd9,
	S_RESET_COUNTERS = 4'd10,
	S_RESET_STATE = 4'd11; //the state you transition to when you click reset

	//counters	
	logic [14:0] resetCount = 15'd19500; //should be 19200 (160x120), added 300 for error
	logic [9:0] borderCount = 10'd600; //should be 560, added 40 for error
	logic [4:0] squareCount = 5'd18; //should be 16, added 2 for error
	logic [6:0] LpaddleCount = 7'd100; //allocated 100 for paddles, maybe have them be 2x16?
	logic [6:0] RpaddleCount = 7'd100;
	logic [4:0] eraseSquareCount = 5'd18; //should be 16, added 2 for error
	logic [6:0] LerasePaddleCount = 7'd100; //allocated 100 for paddles, maybe have them be 2x16?
	logic [6:0] RerasePaddleCount = 7'd100;

	//switches - might not need these
	//	logic drawBorder, initObj, drawSquare, drawPaddles, eraseSquare, erasePaddles;

	//counters
	always@(posedge clock, negedge resetn, posedge softReset)
	begin
		if(~resetn) begin
			borderCount <= 10'd600;
			squareCount <= 5'd18;
			LpaddleCount <= 7'd100;
			RpaddleCount <= 7'd100;
			eraseSquareCount <= 5'd18;
			LerasePaddleCount <= 7'd100;
			RerasePaddleCount <= 7'd100;
			resetCount <= 15'd19500;
		end
		else if (softReset) begin
			borderCount <= 10'd600;
			squareCount <= 5'd18;
			LpaddleCount <= 7'd100;
			RpaddleCount <= 7'd100;
			eraseSquareCount <= 5'd18;
			LerasePaddleCount <= 7'd100;
			RerasePaddleCount <= 7'd100;
			resetCount <= 15'd19500;
		end
		else begin
			if (current_state == S_DRAW_BORDER & borderCount != 1'b0)
				borderCount <= borderCount - 1'b1;
			else if (current_state == S_DRAW_SQUARE & squareCount != 1'b0)
				squareCount <= squareCount - 1'b1;
			else if (current_state == S_DRAW_LEFT_PADDLE & LpaddleCount != 1'b0)
				LpaddleCount <= LpaddleCount - 1'b1;
			else if (current_state == S_DRAW_RIGHT_PADDLE & RpaddleCount != 1'b0)
				RpaddleCount <= RpaddleCount - 1'b1;
			else if (current_state == S_ERASE_SQUARE & eraseSquareCount != 1'b0)
				eraseSquareCount <= eraseSquareCount - 1'b1;
			else if (current_state == S_ERASE_LEFT_PADDLE & LerasePaddleCount != 1'b0)
				LerasePaddleCount <= LerasePaddleCount - 1'b1;
			else if (current_state == S_ERASE_RIGHT_PADDLE & RerasePaddleCount != 1'b0)
				RerasePaddleCount <= RerasePaddleCount - 1'b1;
			else if (current_state == S_RESET_STATE & resetCount != 1'b0)
				resetCount <= resetCount - 1'b1;
			else if (current_state == S_RESET_COUNTERS) begin
				borderCount <= 10'd600;
				squareCount <= 5'd18;
				LpaddleCount <= 7'd100;
				RpaddleCount <= 7'd100;
				eraseSquareCount <= 5'd18;
				LerasePaddleCount <= 7'd100;
				RerasePaddleCount <= 7'd100;
				resetCount <= 15'd19500;
			end
		end
	end

	//FSM
	always@(posedge clock) //can be always@* but idk
	begin: state_table
		case (current_state)
			S_RESET_STATE: next_state = (resetCount == 1'b0) ? S_DRAW_BORDER : S_RESET_STATE;
			S_DRAW_BORDER: next_state = (borderCount == 1'b0) ? S_INIT_OBJ : S_DRAW_BORDER;
			S_INIT_OBJ: next_state = S_DRAW_SQUARE;
			S_DRAW_SQUARE: next_state = (squareCount == 1'b0) ? S_DRAW_LEFT_PADDLE : S_DRAW_SQUARE;
			S_DRAW_LEFT_PADDLE: next_state = (LpaddleCount == 1'b0) ? S_DRAW_RIGHT_PADDLE : S_DRAW_LEFT_PADDLE;
			S_DRAW_RIGHT_PADDLE: next_state = (RpaddleCount == 1'b0) ? S_WAIT_ERASE : S_DRAW_RIGHT_PADDLE;
			S_WAIT_ERASE: next_state = (eraseIn == 1'b1) ? S_ERASE_SQUARE : S_WAIT_ERASE;
			S_ERASE_SQUARE: next_state = (eraseSquareCount == 1'b0) ? S_ERASE_LEFT_PADDLE : S_ERASE_SQUARE;
			S_ERASE_LEFT_PADDLE: next_state = (LerasePaddleCount == 1'b0) ? S_ERASE_RIGHT_PADDLE : S_ERASE_LEFT_PADDLE;
			S_ERASE_RIGHT_PADDLE: next_state = (RerasePaddleCount == 1'b0) ? S_WAIT_DRAW : S_ERASE_RIGHT_PADDLE;
			S_WAIT_DRAW: next_state = (drawIn == 1'b1) ? S_RESET_COUNTERS : S_WAIT_DRAW;
			S_RESET_COUNTERS: next_state = S_DRAW_SQUARE;
			default: next_state = S_RESET_STATE;
		endcase
	end

	//update states
	always@(posedge clock, negedge resetn, posedge softReset) begin
		if(~resetn)
			current_state <= S_RESET_STATE;
		else if(softReset)
			current_state <= S_RESET_STATE;
		else
			current_state <= next_state;
	end

	//draw the border
	wire [7:0] borderX;
	wire [6:0] borderY;
	drawBorder m0(.enable(current_state == S_DRAW_BORDER), .x(borderX), .y(borderY), .clk(clock)); //cannot use counter count to determine whether active

	//draw/erase the square
	wire [4:0] squareAdd;
	logic resetSquare; //note resetn is not negated here as resetSquare is active low
	squareFSM m1(.clock(clock), .reset(resetSquare | ~resetn), .enable(current_state == S_DRAW_SQUARE | current_state == S_ERASE_SQUARE), .display(squareAdd));

	//draw/erase the left paddle
	wire [5:0] LpaddleX;
	wire [5:0] LpaddleY;
	logic resetLeftPaddle;
	paddleFSM m2(.clock(clock), .reset(resetLeftPaddle | ~resetn), .enable(current_state == S_DRAW_LEFT_PADDLE | current_state == S_ERASE_LEFT_PADDLE), .paddleX(LpaddleX), .paddleY(LpaddleY));


	//draw/erase the right paddle
	logic resetRightPaddle;
	wire [5:0] RpaddleX;
	wire [5:0] RpaddleY;
	paddleFSM m3(.clock(clock), .reset(resetRightPaddle | ~resetn), .enable(current_state == S_DRAW_RIGHT_PADDLE | current_state == S_ERASE_RIGHT_PADDLE), .paddleX(RpaddleX), .paddleY(RpaddleY));

	//erase the entire screen (draw black)
	logic resetErase;
	wire [7:0] eraseX;
	wire [6:0] eraseY;
	//note resetn does not trigger reset
	eraseAll m4(.clock(clock), .reset(resetErase), .enable(current_state == S_RESET_STATE), .eraseX(eraseX), .eraseY(eraseY));

	//datapath control
	always@(posedge clock)
	begin
		case(current_state)
			S_RESET_STATE: begin
				writeEn <= 1'b1;
				resetSquare <= 1'b1;
				resetLeftPaddle <= 1'b1;
				resetRightPaddle <= 1'b1;
				resetErase <= 1'b0;

				colour <= 1'b0;
				Xout <= eraseX;
				Yout <= eraseY;
			end
			S_DRAW_BORDER: begin
				writeEn <= 1'b1;

				resetSquare <= 1'b1;
				resetLeftPaddle <= 1'b1;
				resetRightPaddle <= 1'b1;
				resetErase <= 1'b1;

				enableCounter <= 1'b0;

				colour <= colorSwitch; //white color for borders
				Xout <= borderX;
				Yout <= borderY;
			end
			S_INIT_OBJ: begin
				enableCounter <= 1'b1;
				writeEn <= 1'b0;
				//do stuff
			end
			S_DRAW_SQUARE: begin

				writeEn <= 1'b1;
				colour <= colorSwitch;
				resetSquare <= 1'b0;
				Xout <= Xin + squareAdd[1:0];
				Yout <= Yin + squareAdd[3:2];
			end
			S_DRAW_LEFT_PADDLE: begin
				writeEn <= 1'b1;
				//freeze square counter
				resetSquare <= 1'b1;
				resetLeftPaddle <= 1'b0;
				colour <= colorSwitch;
				Xout <= leftPaddleXin + LpaddleX;
				Yout <= leftPaddleYin + LpaddleY;
			end
			S_DRAW_RIGHT_PADDLE: begin
				writeEn <= 1'b1;
				colour <= colorSwitch; //change for customization if you want
				resetLeftPaddle <= 1'b1;
				resetRightPaddle <= 1'b0;
				Xout <= rightPaddleXin + RpaddleX;
				Yout <= rightPaddleYin + RpaddleY;
			end
			S_WAIT_ERASE: begin
				writeEn <= 1'b0;
			end
			S_ERASE_SQUARE: begin
				writeEn <= 1'b1;
				colour <= 1'b0;
				resetRightPaddle <= 1'b1;
				resetSquare <= 1'b0;
				Xout <= Xin + squareAdd[1:0];
				Yout <= Yin + squareAdd[3:2];
			end
			S_ERASE_LEFT_PADDLE: begin
				writeEn <= 1'b1;
				colour <= 3'b0;
				resetSquare <= 1'b1;
				resetLeftPaddle <= 1'b0;
				Xout <= leftPaddleXin + LpaddleX;
				Yout <= leftPaddleYin + LpaddleY;
			end
			S_ERASE_RIGHT_PADDLE: begin
				writeEn <= 1'b1;
				colour <= 3'b0;
				resetLeftPaddle <= 1'b1;
				resetRightPaddle <= 1'b0;
				Xout <= rightPaddleXin + RpaddleX;
				Yout <= rightPaddleYin + RpaddleY;
			end
			S_WAIT_DRAW: begin
				resetRightPaddle <= 1'b1;
				writeEn <= 1'b0;
			end
			S_RESET_COUNTERS: begin
				//					writeEn <= 1'b0;
				resetRightPaddle <= 1'b1;
				//					//borderCount <= 10'd600; 
				//					squareCount <= 5'd18; 
				//					LpaddleCount <= 7'd100; 
				//					RpaddleCount <= 7'd100;
				//					eraseSquareCount <= 5'd18; 
				//					LerasePaddleCount <= 7'd100; 
				//					RerasePaddleCount <= 7'd100; 
			end
			//				//default: something
		endcase
	end
endmodule

module drawBorder(enable, x, y, clk);
	input clk;
	input enable;
	output logic [7:0] x;
	output logic [6:0] y;

	//draw left border
	always @(posedge clk)
	begin
		if (x == 8'd159 & y == 7'd119) begin //we only run this at the start so that the last pixel is drawn
			x <= 1'd0; //starting coordinates
			y <= 1'd0;
		end
		else if (enable) begin
			if (x == 1'b0) begin
				if (y == 7'd119) begin
					x <= x + 1'b1;
					y <= 1'b0;
				end else begin
					//y != 120, x == 1'b0
					y <= y + 1'b1;
				end
			end else if (x == 8'd159) begin
				if (y != 7'd119) begin
					//assuming y is at 0 when starting the final right border
					//we want to start drawing down
					y <= y + 1'b1;
				end
			end else if (x < 8'd159) begin
				//middle part, only draw top and bottom
				//draw current pixel then either jump down or top and right
				//we start at x = 1, y = 0
				if (y == 1'b0)
					y <= 7'd119;
				else begin
					//y = 119
					y <= 1'b0;
					x <= x + 1'b1;
				end
			end
		end
	end
endmodule

//Based on erase or draw input on every active clock edge
module squareFSM(input clock, input reset, input enable, output logic [4:0] display);
	always@(posedge clock)
	begin
		if (reset) begin
			display <= 1'b0;
		end
		else if (enable) begin
			//draw color over current coordinates
			display <= display + 1'b1;
		end
	end
endmodule

//Based on erase or draw input on every active clock edge
//Set the paddle to be white as default color 
module paddleFSM(input clock, input enable, input reset, output logic [5:0] paddleX, output logic [5:0] paddleY);

	always@(posedge clock) begin
		if (reset) begin
			paddleX <= 1'b0;
			paddleY <= 1'b0;
		end
		else if (enable) begin
			if(paddleY < 6'd20) begin //adjust here for paddle size
				paddleY <= paddleY + 1'b1;
			end
			else begin
				if(paddleX == 1'd0) begin
					paddleX <= 1'b1;
					paddleY <= 1'b0;
				end
			end
		end
	end

endmodule

module eraseAll(input clock, input enable, input reset, output logic [7:0] eraseX, output logic [6:0] eraseY);

	always@(posedge clock) begin
		if (reset) begin
			eraseX <= 1'b0;
			eraseY <= 1'b0;
		end
		else if (enable) begin
			if(eraseY < 7'd120) begin //adjust here for paddle size
				eraseY <= eraseY + 1'b1;
			end
			else begin
				if(eraseX < 8'd160) begin
					eraseX <= eraseX + 1'b1;
					eraseY <= 1'b0;
				end
			end
		end
	end
endmodule

module XCounter(count_enable, clk, reset_n,xDisplay,lhitPulse,rhitPulse, softReset, rng);
	input clk;
	input reset_n;
	input count_enable; //TODO: use count_enable to activate counter
	input softReset;
	input rng;
	output logic lhitPulse; // When the object hits the left side of the wall,lhitPulse is 1,otherwise it is 0
	output logic rhitPulse; // When the object hits the right side of the wall,rhitPulse is 1,otherwise it is 0
	output logic [7:0] xDisplay;
	logic direction; //0 = left, 1 = right:note to go right is to increase x
	logic [3:0] square_size = 4'd4; //size of edge of square
	always @(posedge clk, posedge softReset, negedge reset_n)
	begin
		// reset position and diretion
		if(!reset_n) begin
			xDisplay <= 8'd77;
			direction <= rng;
			lhitPulse <= 1'b0;
			rhitPulse <= 1'b0;
		end
		else if (softReset) begin
			xDisplay <= 8'd77;
			direction <= rng;
			lhitPulse <= 1'b0;
			rhitPulse <= 1'b0;
		end
		else begin
			if (direction == 1'b0)
				xDisplay <= xDisplay - 1'b1; //going left
			else if (direction == 1'b1)
				xDisplay <= xDisplay + 1'b1; //going right	
				// go to right if hits left wall
			if (xDisplay <= 8'd14) //CURRENT OFFSET: 22: 20 for paddles and 2 for border
				begin
					xDisplay <= xDisplay + 1'b1;
					lhitPulse <= 1'b1; // hit the left wall, should have high pulse
					rhitPulse <= 1'b0;
					direction <= 1'b1; //reached left, has to go right
				end
				// go to left if hits right wall
			else if (xDisplay >= (8'd160 - square_size - 8'd12)) //subtract square size AND BORDER SIZE to determine true boundary of x
				begin
					xDisplay <= xDisplay - 1'b1;
					rhitPulse <= 1'b1; // hit the right wall, should have high pulse
					lhitPulse <= 1'b0;
					direction <= 1'b0; //reached rightmost area, has to go left
				end
			else begin
				//TODO: begin block
				lhitPulse <= 1'b0; // the object is in the middle, should have low pulse
				rhitPulse <= 1'b0;
			end
		end
	end
endmodule

module YCounter(count_enable, clk, reset_n,yDisplay, softReset, rng);
	input clk;
	input reset_n;
	input count_enable; //TODO: use count_enable to activate counter
	input softReset;
	input rng;
	output logic [6:0]yDisplay;
	logic direction; //0 = down, 1 = up: note to go up is to decrease y
	logic [3:0] square_size = 4'd4; //size of edge of square
	always @(posedge clk, posedge softReset, negedge reset_n)
	begin
		// reset position and diretion
		if (~reset_n)
			begin
				yDisplay <= 7'd57; //initialize to 0
				direction <= rng;
			end
			// go down if hits upper wall
		else if (softReset) begin
			yDisplay <= 7'd57; //initialize to 0
			direction <= rng;
		end
		else begin

			if (yDisplay <= 2'd2)
				direction <= 1'b0; //reached top of screen; has to go down.
				// go up if hits lower wall

			else if (yDisplay >= (7'd120 - square_size - 2'd2)) //subtract square size to determine true boundary of y
				direction <= 1'b1; //reached bottom of screen; has to go up.
			if (direction == 1'b0)
				yDisplay <= yDisplay + 1'b1; //going down
			else
				yDisplay <= yDisplay - 1'b1; //going up
		end


	end
endmodule

module YPaddle(clk, reset_n,moveEnable,up,down,ypDisplay, softReset);
	input clk;
	input logic reset_n;
	input moveEnable;
	input up;
	input down;
	input softReset;
	output logic [6:0] ypDisplay;
	logic [5:0] paddle_size = 6'd20; //size of edge of square

	always @(posedge clk, posedge softReset, negedge reset_n)
	begin
		// reset position and diretion
		if (!reset_n)
			begin
				ypDisplay <= 7'd50; //initialize to 50
			end
		else if (softReset)
			ypDisplay <= 7'd50; //initialize to 50
		else if (moveEnable)
			begin
				if (up == 1'b0 && down == 1'b1)
					begin
						if (ypDisplay < (7'd120 - paddle_size - 2'd2))
							ypDisplay <= ypDisplay + 1'b1; //going down
					end
				else if (up == 1'b1 && down == 1'b0)
					begin
						if (ypDisplay > 2'd2)
							ypDisplay <= ypDisplay - 1'b1; //going up
					end
			end

	end
endmodule

//should run at 1/60th of a second
module TimeCounter(count_enable, clk, reset_n, difficulty, display, erase, draw, pause);
	input count_enable;
	input clk;
	input reset_n;
	input [1:0] difficulty;
	input pause;
	output logic display;
	output logic erase;
	output logic draw;
	logic [19:0] q;
	// wire [23:0] value = 24'd12500000;
	//wire [23:0] value = 24'd5;
	wire [19:0] value = 20'd200000 + 20'd211111 * difficulty; //1-60th of a second - maybe try 1/50
	always @(posedge clk)
	begin
		if(reset_n == 1'b0) begin
			q <= 1'b0;
			display <= 1'b0;
			draw <= 1'b0;
			erase <= 1'b0;
		end else begin
			if (q < value & !pause) begin
				q <= q + 1'b1;
				if (20'd29000 < q & q < 20'd29500) //(20'd499980 < q & q < 20'd500000) //adjust for erase time
					erase <= 1'b1;
				else if (q == 20'd30000) //the two values above and below should hold so that the drawing/erasing can occur
					display <= 1'b1;
				else if (20'd30100 < q & q < 20'd30600) //(20'd510000 < q & q < 20'd510020)
					draw <= 1'b1;
				else begin
					erase <= 1'b0;
					draw <= 1'b0;
					display <= 1'b0;
				end
			end else begin
				q <= 1'b0;
			end
		end
	end
	//assigning these values outside of the @loop might be unstable
	//note: the reason why the square was not drawing itself properly is because it was only able to draw one or two pixels before display went to 0, thus disabling drawing.
endmodule

module hex_decoder(hex_digit, segments);
	input [3:0] hex_digit;
	output logic [6:0] segments;

	always @(*)
	case (hex_digit)
		4'h0: segments = 7'b100_0000;
		4'h1: segments = 7'b111_1001;
		4'h2: segments = 7'b010_0100;
		4'h3: segments = 7'b011_0000;
		4'h4: segments = 7'b001_1001;
		4'h5: segments = 7'b001_0010;
		4'h6: segments = 7'b000_0010;
		4'h7: segments = 7'b111_1000;
		4'h8: segments = 7'b000_0000;
		4'h9: segments = 7'b001_1000;
		4'hA: segments = 7'b000_1000;
		4'hB: segments = 7'b000_0011;
		4'hC: segments = 7'b100_0110;
		4'hD: segments = 7'b010_0001;
		4'hE: segments = 7'b000_0110;
		4'hF: segments = 7'b000_1110;
		default: segments = 7'h7f;
	endcase
endmodule
