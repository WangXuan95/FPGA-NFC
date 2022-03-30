del sim.out dump.vcd
iverilog  -g2005-sv  -o sim.out  tb_nfca_controller.sv  ../RTL/nfca_controller/*.sv
vvp -n sim.out
del sim.out
pause