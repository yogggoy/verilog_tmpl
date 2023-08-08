module usart_tx(
	input wire clk,
	input wire reset,
	output reg txd = 1,
	input wire [7:0] tx_dat,
	output reg is_trns = 0,
	input wire start
);

parameter [2:0] WAIT_START	= 0 ;
parameter [2:0] TRANSMIT	= 1 ;
parameter [2:0] STOP_BIT	= 2 ;

reg [7:0] tx_reg = 0 ;
reg [2:0] i = 0 ;
reg [2:0] sm = 0 ;

always @(negedge clk) begin
	if (reset) begin
		txd 	<= 1 ;
		tx_reg 	<= 0 ;
		i 		<= 0 ;
		is_trns <= 0 ;
		sm 		<= 0 ;
	end
	else begin
		case (sm)
			WAIT_START : begin
				if (start) begin
					txd <= 0 ;
					tx_reg <= tx_dat ;
					is_trns <= 1 ;
					sm <= TRANSMIT ;
				end
				else begin
					is_trns <= 0 ;
					txd <= 1 ;
				end
			end
			TRANSMIT : begin
				if (i == 3'b111) begin
					txd <= tx_reg[i] ;
					i <= 0 ;
					sm <= STOP_BIT ;
				end
				else begin
					txd <= tx_reg[i] ;
					i <= i + 1 ;
				end
			end
			STOP_BIT : begin
				txd <= 1 ;
				sm <= WAIT_START ;
			end
			default : begin
				sm <= WAIT_START ;
			end
		endcase
	end
end

endmodule