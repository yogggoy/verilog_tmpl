module usart_rx(
	input wire clk,
	input wire reset,
	input wire rxd,
	output reg [7:0] rx_dat = 0,
	output reg receiv = 0,
	output reg error = 0
);

parameter [2:0] WAIT_START	= 0 ;
parameter [2:0] RECEIVING 	= 1 ;
parameter [2:0] STOP_BIT 	= 2 ;
parameter [2:0] ERROR 		= 3 ;


reg [2:0] i = 3'b111 ;
reg [2:0] sm = 0 ;


always @(posedge clk) begin
	if (reset) begin
		rx_dat <= 0 ;
		i <= 3'b111 ;
		error <= 0 ;
		sm <= 0 ;
		receiv <= 0 ;
	end
	else begin
		case (sm)
			WAIT_START : begin
				receiv <= 0 ;
				if (!rxd) begin
					sm <= RECEIVING ;
				end
			end
			RECEIVING : begin
				rx_dat <= { rxd, rx_dat[7:1] } ;
				if (!i)
					sm <= STOP_BIT ;
				else
					i <= i-1 ;
			end
			STOP_BIT : begin
				if (rxd) begin
					i <= 3'b111 ;
					receiv <= 1 ;
					sm <= WAIT_START ;
				end
				else
					sm <= ERROR ;
			end
			ERROR : begin
				error <= 1 ;
				sm <= WAIT_START ;
			end
			default : begin
				sm <= WAIT_START ;
			end
		endcase
	end
end

endmodule