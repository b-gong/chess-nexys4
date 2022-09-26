`timescale 1ns / 1ps

module chessboard(
	input clk, //this clock must be a slow enough clock to view the changing positions of the objects
	input bright,
	input rst,
	input select,
	input up, input down, input left, input right,
	input [9:0] hCount, vCount,
	output reg [11:0] rgb,
	output reg [3:0] last_x,
	output reg [3:0] last_y
   );

    wire chessboard;
    wire black_square;
	wire selected_square;
	wire pawn;
	wire knight;
	wire bishop;
	wire rook;
	wire queen;
	wire king;

    //these two values determine the coordinates on the chessboard being displayed from hCount and yCount
    wire [3:0] board_x, board_y;

	wire [9:0] xCount = hCount-322;
	wire [9:0] yCount = vCount-122;

	//these two values dictate the selected square on the chessboard, incrementing and decrementing them moves in certain directions
	reg [3:0] xpos, ypos;

	//these register arrays remember the pieces on each spot
	reg [6:0] pieces [7:0] [7:0]; // x, y
	reg [2:0] team [7:0] [7:0];

	// color constants
	parameter RED        = 12'b1111_0000_0000;
    parameter DARK_GREEN = 12'b0000_1100_1000;
	parameter BLACK  	 = 12'b0000_0000_0000;
	parameter WHITE      = 12'b1111_1111_1111;
	parameter COFFEE     = 12'b0111_0101_0011;
	parameter WHEAT      = 12'b1001_1001_0101;
	parameter GREEN      = 12'b0000_1111_0000;

	// piece states
	localparam [6:0] EMPTY  = 7'b0000001;
	localparam [6:0] PAWN   = 7'b0000010;
	localparam [6:0] KNIGHT = 7'b0000100;
	localparam [6:0] BISHOP = 7'b0001000;
	localparam [6:0] ROOK   = 7'b0010000;
	localparam [6:0] QUEEN  = 7'b0100000;
	localparam [6:0] KING   = 7'b1000000;

	localparam [2:0] NA = 3'b001;
	localparam [2:0] WHITETEAM = 3'b010;
	localparam [2:0] BLACKTEAM = 3'b100;

	wire picked_up_square;
	reg selected_flag = 0;
	reg [3:0] selected_x = 3'b000;
	reg [3:0] selected_y = 3'b000;
	reg [6:0] selected_piece = EMPTY;
	reg [2:0] selected_team = NA;


	// initial synthesizes on Xilinx FPGAs
	initial begin : init
		integer i, j;
		for(i = 0; i < 8; i = i + 1) begin
			for(j = 0; j < 8; j = j + 1) begin
				pieces[i][j] <= EMPTY;
				team[i][j] <= NA;
			end
		end
		pieces[0][0] <= ROOK;
		pieces[1][0] <= KNIGHT;
		pieces[2][0] <= BISHOP;
		pieces[3][0] <= QUEEN;
		pieces[4][0] <= KING;
		pieces[5][0] <= BISHOP;
		pieces[6][0] <= KNIGHT;
		pieces[7][0] <= ROOK;

		pieces[0][7] <= ROOK;
		pieces[1][7] <= KNIGHT;
		pieces[2][7] <= BISHOP;
		pieces[3][7] <= QUEEN;
		pieces[4][7] <= KING;
		pieces[5][7] <= BISHOP;
		pieces[6][7] <= KNIGHT;
		pieces[7][7] <= ROOK;

		for(i = 0; i < 8; i = i + 1) begin
			pieces[i][1] <= PAWN;
			pieces[i][6] <= PAWN;
			team[i][0] <= BLACKTEAM;
			team[i][1] <= BLACKTEAM;
			team[i][6] <= WHITETEAM;
			team[i][7] <= WHITETEAM;
		end

		last_x <= 4'b0000;
		last_y <= 4'b0000;
	end

	/*when outputting the rgb value in an always block like this, make sure to include the if(~bright) statement, as this ensures the monitor
	will output some data to every pixel and not just the images you are trying to display*/
	always@ (*) begin
    	if(~bright )	//force black if not inside the display area
			rgb = BLACK;
		else if(chessboard && picked_up_square && selected_flag && border)
			rgb = RED;
        else if(chessboard && selected_square && border)
            rgb = GREEN;
		else if(chessboard && (
		  	   (pawn && pieces[board_x][board_y] == PAWN) ||
			   (knight && pieces[board_x][board_y] == KNIGHT) ||
			   (bishop && pieces[board_x][board_y] == BISHOP) ||
			   (rook && pieces[board_x][board_y] == ROOK) ||
			   (queen && pieces[board_x][board_y] == QUEEN) ||
			   (king && pieces[board_x][board_y] == KING))) begin
			if(team[board_x][board_y] == WHITETEAM)
				rgb = WHITE;
			else if(team[board_x][board_y] == BLACKTEAM)
				rgb = BLACK;
		end
        else if(chessboard && black_square)
            rgb = COFFEE;
        else if(chessboard && ~black_square)
            rgb = WHEAT;
		else
			rgb = DARK_GREEN;
	end

    // chessboard is from (322, 122) to (577, 377), centered at (450, 250)
    assign chessboard = (hCount >= 322) && (hCount <= 577) && (vCount >= 122) && (vCount <= 377);
    assign board_x = ((xCount) >> 5);
    assign board_y = ((yCount) >> 5);
    assign black_square = (~board_x[0] && ~board_y[0])||(board_x[0] && board_y[0]); // if sum of positions is even, its a black square
    // (0, 0) (32, 0) (224, 224) (255, 255)
    // (0, 0) (1, 0) (7, 7)      (7, 7)
    // (xpos-250)

    assign selected_square = (xpos == board_x) && (ypos == board_y);
    assign border = (xCount[4:0] == 5'b00000) || (xCount[4:0] == 5'b11111) ||
                    (yCount[4:0] == 5'b00000) || (yCount[4:0] == 5'b11111);
	assign picked_up_square = (board_x == selected_x) && (board_y == selected_y);

	assign rook = 	((xCount[4:0] >= 5'b00100) && (yCount[4:0] >= 5'b00110) && (xCount[4:0] <= 5'b00111) && (yCount[4:0] <= 5'b01001)) || /*4,6 7,9*/
				   	((xCount[4:0] >= 5'b01010) && (yCount[4:0] >= 5'b00110) && (xCount[4:0] <= 5'b01110) && (yCount[4:0] <= 5'b01001)) || /*10,6 14,9*/
					((xCount[4:0] >= 5'b10001) && (yCount[4:0] >= 5'b00110) && (xCount[4:0] <= 5'b10101) && (yCount[4:0] <= 5'b01001)) || /*17,6 21,9*/
					((xCount[4:0] >= 5'b11000) && (yCount[4:0] >= 5'b00110) && (xCount[4:0] <= 5'b11011) && (yCount[4:0] <= 5'b01001)) || /*24,6 27,9*/
					((xCount[4:0] >= 5'b00100) && (yCount[4:0] >= 5'b01010) && (xCount[4:0] <= 5'b11011) && (yCount[4:0] <= 5'b01111)) || /*4,10 27,15*/
					((xCount[4:0] >= 5'b00110) && (yCount[4:0] >= 5'b10000) && (xCount[4:0] <= 5'b11001) && (yCount[4:0] <= 5'b11011)) || /*6,16 25,27*/
					((xCount[4:0] >= 5'b00100) && (yCount[4:0] >= 5'b11100) && (xCount[4:0] <= 5'b11011) && (yCount[4:0] <= 5'b11101));

	assign knight = ((xCount[4:0] >= 5'b01110) && (yCount[4:0] >= 5'b00010) && (xCount[4:0] <= 5'b01111) && (yCount[4:0] <= 5'b00011)) || /*14,2 15,3*/
					((xCount[4:0] >= 5'b10010) && (yCount[4:0] >= 5'b00010) && (xCount[4:0] <= 5'b10011) && (yCount[4:0] <= 5'b00011)) || /*18,2 11,3*/
					((xCount[4:0] >= 5'b01010) && (yCount[4:0] >= 5'b00100) && (xCount[4:0] <= 5'b10101) && (yCount[4:0] <= 5'b10101)) || /*10,4 21, 21*/
					((xCount[4:0] >= 5'b00110) && (yCount[4:0] >= 5'b01000) && (xCount[4:0] <= 5'b00111) && (yCount[4:0] <= 5'b01111)) || /*6,8 7,15*/
					((xCount[4:0] >= 5'b01000) && (yCount[4:0] >= 5'b00110) && (xCount[4:0] <= 5'b01001) && (yCount[4:0] <= 5'b10011)) || /*8,6 9,19*/
					((xCount[4:0] >= 5'b10110) && (yCount[4:0] >= 5'b01000) && (xCount[4:0] <= 5'b10111) && (yCount[4:0] <= 5'b10001)) || /*22,8 23,17*/
					((xCount[4:0] >= 5'b11000) && (yCount[4:0] >= 5'b01010) && (xCount[4:0] <= 5'b11001) && (yCount[4:0] <= 5'b10011)) || /*24,10 25,19*/
					((xCount[4:0] >= 5'b11010) && (yCount[4:0] >= 5'b01100) && (xCount[4:0] <= 5'b11011) && (yCount[4:0] <= 5'b10011)) || /*26,12 27,19*/
					((xCount[4:0] >= 5'b11100) && (yCount[4:0] >= 5'b01110) && (xCount[4:0] <= 5'b11101) && (yCount[4:0] <= 5'b10001)) || /*28,14 29,17*/
					((xCount[4:0] >= 5'b01011) && (yCount[4:0] >= 5'b10110) && (xCount[4:0] <= 5'b10101) && (yCount[4:0] <= 5'b10111)) || /*1,22 21,23*/
					((xCount[4:0] >= 5'b01000) && (yCount[4:0] >= 5'b11000) && (xCount[4:0] <= 5'b10111) && (yCount[4:0] <= 5'b11011)) || /*8,24 23,27*/
					((xCount[4:0] >= 5'b00100) && (yCount[4:0] >= 5'b11100) && (xCount[4:0] <= 5'b11011) && (yCount[4:0] <= 5'b11101));

	assign bishop = ((xCount[4:0] >= 5'b01100) && (yCount[4:0] >= 5'b00100) && (xCount[4:0] <= 5'b01101) && (yCount[4:0] <= 5'b00101)) || /*12,4 13,5*/
					((xCount[4:0] >= 5'b10000) && (yCount[4:0] >= 5'b00100) && (xCount[4:0] <= 5'b10011) && (yCount[4:0] <= 5'b00101)) || /*16,4 19,5*/
					((xCount[4:0] >= 5'b01010) && (yCount[4:0] >= 5'b00110) && (xCount[4:0] <= 5'b01101) && (yCount[4:0] <= 5'b00111)) || /*10,6 13,7*/
					((xCount[4:0] >= 5'b10000) && (yCount[4:0] >= 5'b00110) && (xCount[4:0] <= 5'b10101) && (yCount[4:0] <= 5'b00111)) || /*16,6 21,7*/
					((xCount[4:0] >= 5'b01010) && (yCount[4:0] >= 5'b01000) && (xCount[4:0] <= 5'b10101) && (yCount[4:0] <= 5'b01001)) || /*10,8 21,9*/
					((xCount[4:0] >= 5'b01000) && (yCount[4:0] >= 5'b01010) && (xCount[4:0] <= 5'b10111) && (yCount[4:0] <= 5'b10111)) || /*8,10 23,23*/
					((xCount[4:0] >= 5'b01100) && (yCount[4:0] >= 5'b11000) && (xCount[4:0] <= 5'b10011) && (yCount[4:0] <= 5'b11001)) || /*12,24 19,25*/
					((xCount[4:0] >= 5'b01000) && (yCount[4:0] >= 5'b11010) && (xCount[4:0] <= 5'b10111) && (yCount[4:0] <= 5'b11011)) || /*8,26 23,27*/
					((xCount[4:0] >= 5'b00100) && (yCount[4:0] >= 5'b11100) && (xCount[4:0] <= 5'b11011) && (yCount[4:0] <= 5'b11101));

	assign queen =  ((xCount[4:0] >= 5'b01000) && (yCount[4:0] >= 5'b00010) && (xCount[4:0] <= 5'b01001) && (yCount[4:0] <= 5'b00011)) || /*8,2 9,3*/
					((xCount[4:0] >= 5'b01110) && (yCount[4:0] >= 5'b00010) && (xCount[4:0] <= 5'b10001) && (yCount[4:0] <= 5'b00101)) || /*14,2 17,5*/
					((xCount[4:0] >= 5'b10110) && (yCount[4:0] >= 5'b00010) && (xCount[4:0] <= 5'b10111) && (yCount[4:0] <= 5'b00011)) || /*22,2 23,3*/
					((xCount[4:0] >= 5'b00110) && (yCount[4:0] >= 5'b00100) && (xCount[4:0] <= 5'b01001) && (yCount[4:0] <= 5'b00101)) || /*6,4 9,5*/
					((xCount[4:0] >= 5'b10110) && (yCount[4:0] >= 5'b00100) && (xCount[4:0] <= 5'b11001) && (yCount[4:0] <= 5'b00101)) || /*22,4 25,5*/
					((xCount[4:0] >= 5'b00100) && (yCount[4:0] >= 5'b00110) && (xCount[4:0] <= 5'b11011) && (yCount[4:0] <= 5'b01011)) || /*4,6 27,11*/
					((xCount[4:0] >= 5'b01000) && (yCount[4:0] >= 5'b01100) && (xCount[4:0] <= 5'b10111) && (yCount[4:0] <= 5'b10001)) || /*8,12 23,17*/
					((xCount[4:0] >= 5'b01010) && (yCount[4:0] >= 5'b10010) && (xCount[4:0] <= 5'b10101) && (yCount[4:0] <= 5'b10101)) || /*10,18 21,21*/
					((xCount[4:0] >= 5'b01000) && (yCount[4:0] >= 5'b10110) && (xCount[4:0] <= 5'b10111) && (yCount[4:0] <= 5'b10111)) || /*8,22 23,23*/
					((xCount[4:0] >= 5'b00110) && (yCount[4:0] >= 5'b11000) && (xCount[4:0] <= 5'b11001) && (yCount[4:0] <= 5'b11011)) || /*6,24 25,27*/
					((xCount[4:0] >= 5'b00100) && (yCount[4:0] >= 5'b11100) && (xCount[4:0] <= 5'b11011) && (yCount[4:0] <= 5'b11101));

	assign king = 	((xCount[4:0] >= 5'b01110) && (yCount[4:0] >= 5'b00010) && (xCount[4:0] <= 5'b10001) && (yCount[4:0] <= 5'b00111)) || /*14,2 17,7*/
					((xCount[4:0] >= 5'b01011) && (yCount[4:0] >= 5'b00100) && (xCount[4:0] <= 5'b10100) && (yCount[4:0] <= 5'b00101)) || /*11,4 20,5*/
					((xCount[4:0] >= 5'b00100) && (yCount[4:0] >= 5'b00100) && (xCount[4:0] <= 5'b00111) && (yCount[4:0] <= 5'b00111)) || /*4,4 7,7*/
					((xCount[4:0] >= 5'b11000) && (yCount[4:0] >= 5'b00100) && (xCount[4:0] <= 5'b11011) && (yCount[4:0] <= 5'b00111)) || /*24,4 27,7*/
					((xCount[4:0] >= 5'b00100) && (yCount[4:0] >= 5'b01000) && (xCount[4:0] <= 5'b11011) && (yCount[4:0] <= 5'b01001)) || /*4,8 27,9*/
					((xCount[4:0] >= 5'b00110) && (yCount[4:0] >= 5'b01010) && (xCount[4:0] <= 5'b11001) && (yCount[4:0] <= 5'b01011)) || /*6,10 25,11*/
					((xCount[4:0] >= 5'b01000) && (yCount[4:0] >= 5'b01100) && (xCount[4:0] <= 5'b10111) && (yCount[4:0] <= 5'b10001)) || /*8,12 23,17*/
					((xCount[4:0] >= 5'b01010) && (yCount[4:0] >= 5'b10010) && (xCount[4:0] <= 5'b10101) && (yCount[4:0] <= 5'b10101)) || /*10,18 21,21*/
					((xCount[4:0] >= 5'b00110) && (yCount[4:0] >= 5'b10110) && (xCount[4:0] <= 5'b11001) && (yCount[4:0] <= 5'b11011)) || /*6,22 25,27*/
					((xCount[4:0] >= 5'b00100) && (yCount[4:0] >= 5'b11100) && (xCount[4:0] <= 5'b11011) && (yCount[4:0] <= 5'b11101));

	assign pawn =   ((xCount[4:0] >= 5'b01110) && (yCount[4:0] >= 5'b01000) && (xCount[4:0] <= 5'b10001) && (yCount[4:0] <= 5'b10001)) || /*14,8 17,17*/
	                ((xCount[4:0] >= 5'b01100) && (yCount[4:0] >= 5'b01010) && (xCount[4:0] <= 5'b10011) && (yCount[4:0] <= 5'b01101)) || /*12,10 19,13*/
	                ((xCount[4:0] >= 5'b01100) && (yCount[4:0] >= 5'b10010) && (xCount[4:0] <= 5'b10011) && (yCount[4:0] <= 5'b10111)) || /*12,18 19,23*/
	                ((xCount[4:0] >= 5'b01000) && (yCount[4:0] >= 5'b11000) && (xCount[4:0] <= 5'b10111) && (yCount[4:0] <= 5'b11001)); /*8,24 23,25*/

    // controls
	integer i, j;
	always@(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			xpos <= 0;
			ypos <= 0;

			last_x <= 4'b0000;
			last_y <= 4'b0000;

			selected_x <= 3'b000;
			selected_y <= 3'b000;

			selected_piece = EMPTY;
			selected_team = NA;
			selected_flag = 0

			for(i = 0; i < 8; i = i + 1) begin
				for(j = 0; j < 8; j = j + 1) begin
					pieces[i][j] <= EMPTY;
					team[i][j] <= NA;
				end
			end

			pieces[0][0] <= ROOK;
			pieces[1][0] <= KNIGHT;
			pieces[2][0] <= BISHOP;
			pieces[3][0] <= QUEEN;
			pieces[4][0] <= KING;
			pieces[5][0] <= BISHOP;
			pieces[6][0] <= KNIGHT;
			pieces[7][0] <= ROOK;

			pieces[0][7] <= ROOK;
			pieces[1][7] <= KNIGHT;
			pieces[2][7] <= BISHOP;
			pieces[3][7] <= QUEEN;
			pieces[4][7] <= KING;
			pieces[5][7] <= BISHOP;
			pieces[6][7] <= KNIGHT;
			pieces[7][7] <= ROOK;

			for(i = 0; i < 8; i = i + 1) begin
				pieces[i][1] <= PAWN;
				pieces[i][6] <= PAWN;
				team[i][0] <= BLACKTEAM;
				team[i][1] <= BLACKTEAM;
				team[i][6] <= WHITETEAM;
				team[i][7] <= WHITETEAM;
			end
		end
		else if (clk) begin

			if(right) begin
				xpos <= xpos+1;
				if(xpos == 7)
					xpos <= 0;
			end
			else if(left) begin
				xpos <= xpos-1;
				if(xpos == 0)
					xpos<=7;
			end
			else if(up) begin
				ypos <= ypos-1;
				if(ypos == 0)
					ypos <= 7;
			end
			else if(down) begin
				ypos <= ypos+1;
				if(ypos == 7)
					ypos <= 0;
			end
			else if(select) begin
				if(selected_flag) begin
					pieces[selected_x][selected_y] <= EMPTY;
					team[selected_x][selected_y] <= NA;

					// auto queen promote
					if(selected_piece == PAWN && ((selected_team == WHITETEAM && ypos == 0) || (selected_team == BLACKTEAM && ypos == 7)))
						pieces[xpos][ypos] <= QUEEN;
					else
						pieces[xpos][ypos] <= selected_piece;

					team[xpos][ypos] <= selected_team;

					// xpos 0-7
					// last_x A-H -> 8-F
					last_x <= xpos + 8;
					// ypos 7-0
					// last_y 1-8 -> 0-7
					last_y <= 7 - ypos;

					selected_flag <= 0;
				end
				else begin
					if(pieces[xpos][ypos] != EMPTY) begin
						selected_x <= xpos;
						selected_y <= ypos;
						selected_piece <= pieces[xpos][ypos];
						selected_team <= team[xpos][ypos];
						selected_flag <= 1;
					end

				end
			end
		end
	end


endmodule
