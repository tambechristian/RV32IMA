set script_dir [file dirname [file normalize [info script]]]

read_verilog -sv [file join $script_dir rv32ima_pkg.sv]
read_verilog -sv [file join $script_dir rv32_muldiv.sv]
read_verilog -sv [file join $script_dir sv32_mmu.sv]
read_verilog -sv [file join $script_dir rv32ima_core.sv]
read_verilog -sv [file join $script_dir rv32ima_wb.sv]

synth_design -top rv32ima_wb -part xc7a35tcpg236-1
report_utilization
report_timing_summary
exit
