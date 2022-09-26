// Verilog module: Top for chess program with VGA and SSD output
// Adapted from example code given in my class

`timescale 1ns / 1ps

module vga_top(
	input ClkPort,
	input BtnC,
	input BtnU,
	input BtnR,
	input BtnL,
	input BtnD,
	input Sw15,
	//VGA signal
	output hSync, vSync,
	output [3:0] vgaR, vgaG, vgaB,

	//SSG signal
	output An0, An1, An2, An3, An4, An5, An6, An7,
	output Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp,

	output MemOE, MemWR, RamCS, QuadSpiFlashCS
	);
	wire Reset;
	assign Reset=Sw15;
	wire bright;
	wire[9:0] hc, vc;
	wire[15:0] score;
	wire up,down,left,right,center;
	wire [3:0] anode;
	wire [11:0] rgb;
	wire rst;

	reg [3:0]	SSD;
	wire [3:0]	/*SSD3, SSD2,*/ SSD1, SSD0;
	reg [7:0]  	SSD_CATHODES;
	wire [1:0] 	ssdscan_clk;

	reg [27:0]	DIV_CLK;
	always @ (posedge ClkPort, posedge Reset)
	begin : CLOCK_DIVIDER
      if (Reset)
			DIV_CLK <= 0;
	  else
			DIV_CLK <= DIV_CLK + 1'b1;
	end
	wire move_clk;
	assign move_clk=DIV_CLK[19]; //slower clock to drive the movement of objects on the vga screen
	wire [3:0] last_x, last_y;
	display_controller dc(.clk(ClkPort), .hSync(hSync), .vSync(vSync), .bright(bright), .hCount(hc), .vCount(vc));
	chessboard sc(.clk(move_clk), .bright(bright), .rst(Sw15), .select(center), .up(up), .down(down),.left(left),.right(right),.hCount(hc), .vCount(vc), .rgb(rgb), .last_x(last_x), .last_y(last_y));
	debouncer #(.N_dc(6)) debouncer_U
	        (.CLK(move_clk), .RESET(Reset), .PB(BtnU), .DPB( ),
			.SCEN(up), .MCEN( ), .CCEN( ));
	debouncer #(.N_dc(6)) debouncer_D
	        (.CLK(move_clk), .RESET(Reset), .PB(BtnD), .DPB( ),
			.SCEN(down), .MCEN( ), .CCEN( ));
	debouncer #(.N_dc(6)) debouncer_L
	        (.CLK(move_clk), .RESET(Reset), .PB(BtnL), .DPB( ),
			.SCEN(left), .MCEN( ), .CCEN( ));
	debouncer #(.N_dc(6)) debouncer_R
	        (.CLK(move_clk), .RESET(Reset), .PB(BtnR), .DPB( ),
			.SCEN(right), .MCEN( ), .CCEN( ));
	debouncer #(.N_dc(6)) debouncer_C
	        (.CLK(move_clk), .RESET(Reset), .PB(BtnC), .DPB( ),
			.SCEN(center), .MCEN( ), .CCEN( ));



	assign vgaR = rgb[11 : 8];
	assign vgaG = rgb[7  : 4];
	assign vgaB = rgb[3  : 0];

	// disable mamory ports
	assign {MemOE, MemWR, RamCS, QuadSpiFlashCS} = 4'b1111;

	//------------
// SSD (Seven Segment Display)
	// reg [3:0]	SSD;
	// wire [3:0]	SSD3, SSD2, SSD1, SSD0;

	//SSDs display
	assign SSD1 = last_x;
	assign SSD0 = last_y;


	// need a scan clk for the seven segment display

	// 100 MHz / 2^18 = 381.5 cycles/sec ==> frequency of DIV_CLK[17]
	// 100 MHz / 2^19 = 190.7 cycles/sec ==> frequency of DIV_CLK[18]
	// 100 MHz / 2^20 =  95.4 cycles/sec ==> frequency of DIV_CLK[19]

	// 381.5 cycles/sec (2.62 ms per digit) [which means all 4 digits are lit once every 10.5 ms (reciprocal of 95.4 cycles/sec)] works well.

	assign ssdscan_clk = DIV_CLK[19:18];
	assign An0	= !(~(ssdscan_clk[1]) && ~(ssdscan_clk[0]));  // when ssdscan_clk = 00
	assign An1	= !(~(ssdscan_clk[1]) &&  (ssdscan_clk[0]));  // when ssdscan_clk = 01
	// assign An2	=  !((ssdscan_clk[1]) && ~(ssdscan_clk[0]));  // when ssdscan_clk = 10
	// assign An3	=  !((ssdscan_clk[1]) &&  (ssdscan_clk[0]));  // when ssdscan_clk = 11
	// Turn off another 4 anodes
	assign {An7, An6, An5, An4} = 4'b1111;
	assign {An3, An2} = 2'b11;

	always @ (ssdscan_clk, SSD0, SSD1/*, SSD2, SSD3*/)
	begin : SSD_SCAN_OUT
		case (ssdscan_clk)
				  2'b00: SSD = SSD0;
				  2'b01: SSD = SSD1;
				  // 2'b10: SSD = SSD2;
				  // 2'b11: SSD = SSD3;
		endcase
	end

	// Following is Hex-to-SSD conversion
	// A B C D E F G H 1 2 3 4 5 6 7 8
	always @ (SSD)
	begin : HEX_TO_SSD
		case (SSD) // in this solution file the dot points are made to glow by making Dp = 0
		    //                                                                abcdefg,Dp
			4'b0000: SSD_CATHODES = 8'b10011111; // 0 > 1
			4'b0001: SSD_CATHODES = 8'b00100101; // 1 > 2
			4'b0010: SSD_CATHODES = 8'b00001101; // 2 > 3
			4'b0011: SSD_CATHODES = 8'b10011001; // 3 > 4
			4'b0100: SSD_CATHODES = 8'b01001001; // 4 > 5
			4'b0101: SSD_CATHODES = 8'b01000001; // 5 > 6
			4'b0110: SSD_CATHODES = 8'b00011111; // 6 > 7
			4'b0111: SSD_CATHODES = 8'b00000001; // 7 > 8
			4'b1000: SSD_CATHODES = 8'b00010000; // 8 > A
			4'b1001: SSD_CATHODES = 8'b11000000; // 9 > B
			4'b1010: SSD_CATHODES = 8'b01100010; // A > C
			4'b1011: SSD_CATHODES = 8'b10000100; // B > D
			4'b1100: SSD_CATHODES = 8'b01100000; // C > E
			4'b1101: SSD_CATHODES = 8'b01110000; // D > F
			4'b1110: SSD_CATHODES = 8'b01000000; // E > G (same as 6)
			4'b1111: SSD_CATHODES = 8'b10010000; // F > H
			default: SSD_CATHODES = 8'bXXXXXXXX; // default is not needed as we covered all cases
		endcase
	end

	// reg [7:0]  SSD_CATHODES;
	assign {Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp} = {SSD_CATHODES};

endmodule
