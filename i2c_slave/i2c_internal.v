`timescale 1 ns / 100 ps

module i2c_internal #(
    parameter [6:0] DEV_ADDR =7'h70,
    parameter SIZE_REG ='h8
    ) (
    input wire mst_sda_in,
    input wire mst_scl_in,

    output wire int_sda_oe,  // internal slave data out

    input wire clk_25,
    input wire reset_n
);

// межклоковая синхронизация sda_in и отлов фронтов
reg [2:0] detect_mst_sda_in = 3'b111;
always @(negedge clk_25) begin
    detect_mst_sda_in[0] <= mst_sda_in;
    detect_mst_sda_in[1] <= detect_mst_sda_in[0];
    detect_mst_sda_in[2] <= detect_mst_sda_in[1];
end
wire mst_sda;
assign mst_sda = detect_mst_sda_in[1];

wire front_sda, back_sda;
assign front_sda = ~detect_mst_sda_in[2] & mst_sda;
assign back_sda =  detect_mst_sda_in[2] & ~mst_sda;

// межклоковая синхронизация scl_in и отлов фронтов
reg [2:0] detect_mst_scl_in = 3'b111;
always @(negedge clk_25) begin
    detect_mst_scl_in[0] <= mst_scl_in;
    detect_mst_scl_in[1] <= detect_mst_scl_in[0];
    detect_mst_scl_in[2] <= detect_mst_scl_in[1];
end
wire mst_scl;
assign mst_scl = detect_mst_scl_in[1];

wire front_scl, back_scl;
assign front_scl = ~detect_mst_scl_in[2] & mst_scl;
assign back_scl =  detect_mst_scl_in[2] & ~mst_scl;


// DEBUG WIRES
wire START, STOP;
assign START = back_sda & (mst_scl == 1'b1);
assign STOP = front_sda & (mst_scl == 1'b1);

i2c_slave #(DEV_ADDR, SIZE_REG) i2c_slave_inst (
    .mst_sda   (mst_sda),
    .front_sda (front_sda),
    .back_sda  (back_sda),
    .mst_scl   (mst_scl),
    .front_scl (front_scl),
    .back_scl  (back_scl),
    .data_out  (int_sda_oe),
    .clk_25    (clk_25),
    .reset_n   (reset_n)
);

endmodule