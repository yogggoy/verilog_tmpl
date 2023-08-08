`timescale 1 ns / 100 ps

module i2c_slave #(
    parameter [6:0] DEV_ADDR =7'h70,
    parameter SIZE_REG ='h8
    ) (
    input wire mst_sda,
    input wire front_sda,
    input wire back_sda,

    input wire mst_scl,
    input wire front_scl,
    input wire back_scl,

    output reg data_out,    // если 1 - то sda - input

    input wire clk_25,
    input wire reset_n
);
localparam [3:0] ST_IDLE         = 4'h0;
localparam [3:0] ST_START        = 4'h1;
localparam [3:0] ST_STATUS_a     = 4'h2;
localparam [3:0] ST_STATUS_b     = 4'h3;
localparam [3:0] ST_WRITE_addr   = 4'h4;
localparam [3:0] ST_WRITE_data   = 4'h5;
localparam [3:0] ST_READ_data    = 4'h6;
localparam [3:0] ST_READ_STATUS  = 4'h7;

reg [3:0] sm = ST_IDLE;

localparam READ =  1'b1;
localparam WRITE = 1'b0;
localparam ACK =  1'b0;
localparam NACK = 1'b1;

reg [7:0] i2c_addr = 8'h0;
reg rw = 1'b0;
reg _flag = 1'b0;
reg status = NACK;
reg [7:0] counter = 8'b0;

reg [7:0] reg_memory [SIZE_REG-1:0];
reg [7:0] tmp_reg_addr = 8'h0;
reg [7:0] reg_addr = 8'h0;
reg [7:0] tmp_data = 8'b0;



wire START, STOP;
assign START = back_sda & mst_scl;
assign STOP = front_sda & mst_scl;

always @(posedge clk_25) begin

    if (~reset_n) begin
        sm <= ST_IDLE;
        status <= NACK;
        counter <= 0;
        i2c_addr <= 0;
        reg_addr <= 0;
        tmp_reg_addr <= 0;
        data_out <= 1'b1;
        _flag <= 0;
        // TODO: сброс всех регистров в 0
        // reg_memory[0] <= 15'b0;

    end
    else begin
        case (sm)
            ST_IDLE : begin    // 0 | отлов старт
                data_out <= 1'b1;
                _flag <= 0;
                status <= NACK;
                counter <= 0;
                i2c_addr <= 0;
                if (back_sda & mst_scl)
                    sm <= ST_START;
            end

            ST_START : begin    // 1 | отсчет 8 тактов. запомнить RW.
                if (front_scl) begin
                    counter <= counter + 1'b1;
                    i2c_addr <= {i2c_addr[6:0], mst_sda};
                end
                if (counter == 8) begin
                    if (i2c_addr[7:1] == DEV_ADDR)
                        status <= ACK;
                    rw <= mst_sda;
                    counter <= 0;
                    sm <= ST_STATUS_a;
                end
            end

            ST_STATUS_a : begin    // 2 | выставление ACK/NACK
                counter <= 8'b0;
                if (back_scl) begin
                    if (status == ACK) begin
                        data_out <= status;
                        sm <= ST_STATUS_b;
                    end
                    else
                        sm <= ST_IDLE;
                end
            end

            ST_STATUS_b : begin    // 3 |
                if (back_scl) begin
                    data_out <= NACK;
                    status <= NACK;

                    if (rw == WRITE)
                        sm <= ST_WRITE_addr;
                    else begin
                        data_out <= reg_memory[reg_addr][7];
                        tmp_data <= reg_memory[reg_addr][7:0];
                        sm <= ST_READ_data;
                    end
                end
            end

            ST_WRITE_addr : begin    // 4 | register addres
                if (STOP) begin// STOP
                    counter <= 8'b0;
                    sm <= ST_IDLE;
                end
                else if (START) begin // RESTART
                    counter <= 8'b0;
                    sm <= ST_START;
                end
                else begin
                    if (front_scl) begin      // JUST DATA
                        counter <= counter + 1'b1;
                        tmp_reg_addr <= {tmp_reg_addr[6:0], mst_sda};
                    end
                    if ((counter == 8'h8) && (back_scl)) begin
                        reg_addr <= tmp_reg_addr; // адрес фиксируется только в конце
                        _flag <= 1'b1;
                        data_out <= ACK;
                    end
                    if ((back_scl) && (_flag)) begin
                        _flag <= 1'b0;
                        data_out <= NACK;
                        counter <= 8'b0;
                        sm <= ST_WRITE_data;
                    end
                end
            end

            ST_WRITE_data : begin // 5 | register data
                if (STOP) begin // STOP
                    counter <= 8'b0;
                    sm <= ST_IDLE;
                end
                else if (START) begin // RESTART
                    counter <= 8'b0;
                    sm <= ST_START;
                end
                else begin
                    if (front_scl) begin      // JUST DATA
                        counter <= counter + 1'b1;
                        tmp_data <= {tmp_data[6:0], mst_sda};
                    end
                    if ((counter == 8'h8) && (back_scl)) begin
                        reg_memory[reg_addr] <= tmp_data;
                        _flag <= 1'b1;
                        data_out <= ACK;
                    end
                    if ((back_scl) && (_flag)) begin
                        sm <= ST_IDLE;
                    end
                end
            end

            ST_READ_data : begin    // 6 |
                if (front_scl)
                    tmp_data <= {tmp_data[6:0], tmp_data[7]};

                if (back_scl) begin      // JUST DATA
                    counter <= counter + 1'b1;
                    data_out <= tmp_data[7];
                end
                if (counter == 8'h8) begin
                    data_out <= READ;
                    sm <= ST_IDLE;
                    // sm <= ST_READ_STATUS;
                end
            end

            ST_READ_STATUS : begin    // 7 | прочитать ACK/NACK от мастера
                counter <= 0;
                if ((front_scl) & (mst_sda == NACK))
                    sm <= ST_IDLE;
            end

            default : begin
                sm <= ST_IDLE;
            end
        endcase
    end
end

endmodule