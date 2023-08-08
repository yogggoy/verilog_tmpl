`timescale 1 ns / 100 ps

module i2c_tb;

reg clk = 0;
reg tb_reset = 0;

reg i2c_sda = 1;
reg i2c_scl = 1;
reg slv_sda_r = 1;
wire ext_sda_oe, int_sda_oe;

reg [7:0] iter_counter = 0;

i2c_internal #(7'h77, 'h52) i2c_internal_inst (
    .mst_sda_in  (i2c_sda),
    .mst_scl_in  (i2c_scl),
    .int_sda_oe  (int_sda_oe),
    .clk_25      (clk),
    .reset_n     (~tb_reset)
);

// initial begin
    // $dumpfile("out.vcd");
    // $dumpvars(0, i2c_tb);

    // clk = 0;
    // i2c_scl = 1;
    // i2c_sda = 1;
    // tb_reset = 1;
    // #500 tb_reset = 0;
// end

localparam NACK = 1'b1;
localparam ACK = 1'b0;

always
    #20 clk = ~clk; // 25 MHz

initial begin
    $dumpfile("out.vcd");
    $dumpvars(0, i2c_tb);

    clk = 0;
    i2c_scl = 1;
    i2c_sda = 1;
    tb_reset = 1;
    #500 tb_reset = 0;
    #1250
    // ---------------------------

    $display("-");
    $display("---");

    loop_mem_write('h10);
    // mem_display();
    mem_read('h13);
end

initial
begin
    #20000000 $finish;
end

// ==============================================

reg [7:0] pack_cntr = 0;

task loop_mem_write;
    input [7:0] width;
    begin
        $display("WRITE DATA ...");
        while (pack_cntr != width) begin
            i2c_start();
            i2c_write(8'h77<<1);
            i2c_write(pack_cntr); //add
            i2c_write(pack_cntr+1); //dat
            i2c_stop();
            pack_cntr = pack_cntr + 1;
        end
        pack_cntr = 0;
    end
endtask

task mem_read;
    input [7:0] width;
    begin
        $display("READ DATA ...");
        while (pack_cntr != width) begin
            i2c_start();
            i2c_write(8'h77<<1);
            i2c_write(pack_cntr);

            i2c_start();
            i2c_write((8'h77<<1) + 1);
            i2c_read(1);
            i2c_stop();
            pack_cntr = pack_cntr + 1;
        end
        pack_cntr = 0;
    end
endtask

task mem_display;
    begin
        while (counter != 'h20) begin
            $display("%x: reg = %d", counter,
                i2c_internal_inst.i2c_slave_inst.reg_memory[counter]
            );
            counter = counter + 1;
        end
        counter = 0;
    end
endtask

// ==========================================

reg [7:0] i2c_data = 0;
reg [7:0] counter = 0;

task i2c_start;
    begin
        #10000
        iter_counter = iter_counter + 1;
        // $display(iter_counter);
        i2c_sda = 1;
        #500
        i2c_scl = 1;
        #1250
        i2c_sda = 0;
        #1250
        i2c_scl = 0;
    end
endtask


task i2c_stop;
    begin
        #1250
        i2c_sda = 0;
        #1250
        i2c_scl = 1;
        #1250
        i2c_sda = 1;
    end
endtask


task i2c_write;
    input [7:0] data;
    begin
        i2c_data = data;
        while (counter != 8) begin
            counter = counter + 1;
            #250 i2c_sda = i2c_data[7];
            #1000 i2c_scl = 1;
            #1250 i2c_scl = 0;
            i2c_data = {i2c_data[6:0], i2c_data[7]};
        end
        counter = 0;
        #1250 i2c_scl = 1;
        // if (int_sda_oe)
        //     $display(int_sda_oe, " FAIL");
        // else
        //     $display(int_sda_oe, " OK");
        #1250 i2c_scl = 0;
    end
endtask


task i2c_read;
    input master_ack;
    begin
        i2c_sda = 0;
        while (counter != 8) begin
            counter = counter + 1;
            #1250 i2c_scl = 1;
            i2c_data[0] = int_sda_oe;
            #1250 i2c_scl = 0;
            i2c_data = {i2c_data[6:0], i2c_data[7]};
        end
        i2c_data = {i2c_data[0], i2c_data[7:1]};
        i2c_sda = master_ack;
        counter = 0;
        #1250 i2c_scl = 1;
        $display("data: 0x%h", i2c_data);
        #1250 i2c_scl = 0;
    end
endtask

endmodule
