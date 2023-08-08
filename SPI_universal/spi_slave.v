`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: NIIR
// Engineer: Mergenov E
//
// Create Date:    18:43:30 04/10/2014
// Design Name:
// Module Name:    spi_slave
// Project Name:
// Target Devices:
// Tool versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module spi_slave (
	input wire spi_clk,
	input wire spi_mosi,
	output reg spi_miso = 1,
	input wire spi_str,

	output reg [15:0] d_rx = 16'hFEA2,		// данные пришедшие с SPI
	input wire [15:0] d_tx,				// данные передаваемые по SPI

	output wire ready,
	input wire reset,
	input wire clk
);

reg [15:0] Temp_RX = 16'h8912 ;		// регистр передающей линии
reg [15:0] Temp_TX = 16'h5678 ;		// регистр входящей линии
reg [3:0] i = 4'hf;

reg clk_1MHz = 0;
reg str_latch = 0;
reg flag_ready;
reg prev_posdg;
wire back_edge;
wire front_edge;

always @(posedge clk) begin		// синхронизируем входные сигналы
	clk_1MHz <= spi_clk ;
	str_latch <= spi_str;
	prev_posdg <= clk_1MHz;
	flag_ready <= str_latch;
end

assign back_edge = prev_posdg & ~clk_1MHz;
assign front_edge = ~prev_posdg & clk_1MHz;
assign ready = ~flag_ready & str_latch;
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	always @(negedge clk) begin
		if (reset) begin
			i <= 4'hF;
			spi_miso <= 1 ;
			Temp_RX <= 16'h0123 ;
			Temp_TX <= 16'h4567 ;
		end
		else begin

			//<RX line RX line RX line RX line RX line>

			if (front_edge == 1)
				Temp_RX[0] <= spi_mosi ;

			if ((back_edge == 1) && (i != 0 ) )
				Temp_RX <= Temp_RX << 1 ;

			// if (ready == 1 )
				d_rx <= Temp_RX;

			//<TX line TX line TX line TX line TX line>

			Temp_TX <= d_tx ;	// ну хз, как тут без строба в начале транзакции

			if (str_latch == 1)
				i <= 4'hF ;
			else begin
				if (i==4'hF)
					spi_miso <= Temp_TX[15] ;
				else
					spi_miso <= Temp_TX[i] ;

				if (back_edge == 1)
					i <= i-1'b1 ;
			end


		end
	end

endmodule