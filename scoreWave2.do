# Set the working dir, where all compiled Verilog goes.
vlib work
vlog -timescale 1ns/1ns  part2.sv
vsim -L altera_mf_ver testLeftScore
log {/*}
add wave {/*}

force {enable} 1;
force {rhitPulse} 0 0,1 5 -r 10;
force {yrpaddle} 0000010;
force {yCounter} 0101111;
force {reset} 0;
run 5ns
force {reset} 1;
run 400ns



