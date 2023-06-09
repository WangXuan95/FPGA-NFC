del sim.out dump.vcd
iverilog  -g2001  -o sim.out  tb_nfca_controller.v  ../RTL/nfca_controller/*.v
vvp -n sim.out
del sim.out
pause