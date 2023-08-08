export PATH=/opt/iverilog-v10_1/bin:$PATH
iverilog -o i2c_simulate.out \
            tb_i2c.v \
            ../../i2c_internal.v \
            ../../i2c_slave.v

vvp i2c_simulate.out #> /dev/null
