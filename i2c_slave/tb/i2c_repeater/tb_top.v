module top(
    input wire clk_25,
    input wire reset,

    output wire slv_scl,
    output wire slv_sda,
    input wire slv_sda_r,

    inout wire i2c_sda,
    input wire i2c_scl
);

wire sda_oe;

assign slv_scl = i2c_scl;
assign slv_sda = i2c_sda;
assign i2c_sda = sda_oe ? 1'bz : slv_sda_r;

i2c_repeater i2c_repeater_inst (
    .mst_sda_in (i2c_sda),
    .mst_scl_in (i2c_scl),
    .slv_sda_in (slv_sda_r),
    .sda_oe     (sda_oe),
    .clk_25     (clk_25),
    .reset      (reset)
);

endmodule