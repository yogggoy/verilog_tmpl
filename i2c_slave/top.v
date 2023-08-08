`timescale 1ns / 1ps

module top (
    input wire clk_25,
    inout wire i2c_sda,
    input wire i2c_scl
);

wire self_reset;

// I2C =========================================================
wire int_sda_oe;

assign i2c_sda = (int_sda_oe) ? 1'bz : 1'b0;

i2c_internal #(7'h77, 'h52) i2c_internal_inst (
    .mst_sda_in  (i2c_sda),
    .mst_scl_in  (i2c_scl),
    .int_sda_oe  (int_sda_oe),  // slave data out
    .clk_25      (clk_25),
    .reset_n     (~self_reset)
);

// SELF-Reset ==================================================
self_reset self_fuck_inst (
    .clk_25(clk_25),
    .reset(self_reset)
);

endmodule
