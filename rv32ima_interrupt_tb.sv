`timescale 1ns / 1ps

module rv32ima_interrupt_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic memory_valid, memory_write;
    logic [31:0] memory_address, memory_write_data;
    logic [3:0] memory_write_strobe;
    logic [31:0] memory_read_data;
    logic debug_halt_request = 1'b0;
    logic debug_halted;
    logic [31:0] debug_program_counter;
    logic [4:0] debug_register_index;
    logic [31:0] debug_register_data;
    logic [31:0] memory [0:255];
    integer failures = 0;

    always #5 clk = ~clk;
    assign memory_read_data = memory[memory_address[9:2]];

    rv32ima_core dut (
        .clk(clk), .reset(reset),
        .memory_valid(memory_valid), .memory_write(memory_write),
        .memory_address(memory_address), .memory_write_data(memory_write_data),
        .memory_write_strobe(memory_write_strobe),
        .memory_ready(memory_valid), .memory_read_data(memory_read_data),
        .memory_error(1'b0),
        .irq_software_m(1'b0), .irq_timer_m(1'b0), .irq_external_m(1'b0),
        .irq_software_s(1'b1), .irq_timer_s(1'b0), .irq_external_s(1'b1),
        .time_value(64'd0),
        .debug_halt_request(debug_halt_request),
        .debug_resume_request(1'b0), .debug_step_request(1'b0),
        .debug_halted(debug_halted),
        .debug_program_counter(debug_program_counter),
        .debug_register_index(debug_register_index),
        .debug_register_data(debug_register_data),
        .debug_register_write(1'b0),
        .debug_register_write_data(32'd0)
    );

    initial begin
        for (integer i = 0; i < 256; i++) memory[i] = 32'h00000013;
        memory[0] = 32'h08000093; // addi x1,x0,0x80
        memory[1] = 32'h30509073; // csrw mtvec,x1
        memory[2] = 32'h20200093; // addi x1,x0,0x202 (SEIE|SSIE)
        memory[3] = 32'h30409073; // csrw mie,x1
        memory[4] = 32'h20000093; // addi x1,x0,0x200 (delegate SEI only)
        memory[5] = 32'h30309073; // csrw mideleg,x1
        memory[6] = 32'h00800093; // addi x1,x0,8 (MIE)
        memory[7] = 32'h30009073; // csrw mstatus,x1
        memory[8] = 32'h0000006f; // should be interrupted before this loop

        memory['h20] = 32'h34202173; // csrr x2,mcause
        memory['h21] = 32'h0000006f; // loop with MIE disabled by trap entry

        repeat (3) @(negedge clk);
        reset = 1'b0;
        repeat (200) @(negedge clk);
        debug_halt_request = 1'b1;
        while (!debug_halted) @(negedge clk);
        debug_halt_request = 1'b0;

        debug_register_index = 5'd2;
        #1;
        if (debug_register_data !== 32'h80000001) begin
            $error("expected SSIP machine trap, mcause=%08x",
                   debug_register_data);
            failures = failures + 1;
        end
        if (debug_program_counter !== 32'h00000084) begin
            $error("expected interrupt handler loop PC 00000084 actual=%08x",
                   debug_program_counter);
            failures = failures + 1;
        end

        if (failures == 0) $display("PASS: rv32ima_interrupt");
        else $fatal(1, "FAIL: rv32ima_interrupt (%0d failures)", failures);
        $finish;
    end
endmodule
