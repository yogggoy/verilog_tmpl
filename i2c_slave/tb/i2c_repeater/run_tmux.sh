#!/bin/bash

PRJ_FLDR="/home/mergenov/projects/bzr/BZR2_i2c_try"

tmux new -s i2c_tb -d
tmux send-keys -t i2c_tb 'cd '$PRJ_FLDR'/src/tb/i2c_repeater' C-j
tmux send-keys -t i2c_tb './i2c_script.sh > test.log; grep FAIL test.log' C-j

tmux split-window -t i2c_tb

tmux send-keys -t i2c_tb 'cd '$PRJ_FLDR C-j
tmux send-keys -t i2c_tb './ftdi_i2cdetect.py' C-j

tmux new-window -t i2c_tb
tmux send-keys -t i2c_tb  'cd '$PRJ_FLDR'/python/bzr_soft_ft2232h' C-j
tmux send-keys -t i2c_tb  './power_control.py' C-j

tmux select-window -t :0

tmux a -t i2c_tb
