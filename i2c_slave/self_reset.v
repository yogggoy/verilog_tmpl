`timescale 1ns / 1ps
// self reset module

module self_reset (
    input wire clk_25,
    output wire reset
);

parameter [7:0] DELAY_10_mks = 8'hFA;
reg [7:0] reset_counter = DELAY_10_mks;
reg reset_reg = 1;
reg flag_reset = 0;

assign reset = reset_reg;

always @(posedge clk_25) begin
    if (!flag_reset) begin
        if (!reset_counter) begin
            flag_reset <= 1'b1;
            reset_counter <= DELAY_10_mks;
            reset_reg <= 1'b0;
        end
        else begin
            reset_counter <= reset_counter - 1'b1;
        end
    end
    else
        if (reset_reg)
            flag_reset <= 1'b0;
end

endmodule