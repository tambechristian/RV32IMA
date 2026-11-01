`timescale 1ns / 1ps

module rv32ima_atomic_tb;
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

    always_ff @(posedge clk) begin
        if (memory_valid && memory_write) begin
            if (memory_write_strobe[0]) memory[memory_address[9:2]][7:0] <= memory_write_data[7:0];
            if (memory_write_strobe[1]) memory[memory_address[9:2]][15:8] <= memory_write_data[15:8];
            if (memory_write_strobe[2]) memory[memory_address[9:2]][23:16] <= memory_write_data[23:16];
            if (memory_write_strobe[3]) memory[memory_address[9:2]][31:24] <= memory_write_data[31:24];
        end
    end

    function automatic logic [31:0] atomic_instruction(
        input logic [4:0] operation,
        input logic [4:0] destination,
        input logic [4:0] address_register,
        input logic [4:0] source_register
    );
        atomic_instruction = {
            operation, 2'b00, source_register, address_register,
            3'b010, destination, 7'b0101111
        };
    endfunction

    rv32ima_core dut (
        .clk(clk), .reset(reset),
        .memory_valid(memory_valid), .memory_write(memory_write),
        .memory_address(memory_address), .memory_write_data(memory_write_data),
        .memory_write_strobe(memory_write_strobe),
        .memory_ready(memory_valid), .memory_read_data(memory_read_data),
        .memory_error(1'b0),
        .irq_software_m(1'b0), .irq_timer_m(1'b0), .irq_external_m(1'b0),
        .irq_software_s(1'b0), .irq_timer_s(1'b0), .irq_external_s(1'b0),
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

    task automatic check_register(
        input logic [4:0] index,
        input logic [31:0] expected
    );
        begin
            debug_register_index = index;
            #1;
            if (debug_register_data !== expected) begin
                $error("x%0d expected=%08x actual=%08x",
                       index, expected, debug_register_data);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        for (integer i = 0; i < 256; i++) memory[i] = 32'h00000013;
        memory[0] = 32'h10000093; // addi x1,x0,0x100
        memory[1] = 32'h00500113; // addi x2,x0,5
        memory[2] = 32'h0020a023; // sw x2,0(x1)
        memory[3] = atomic_instruction(5'b00010, 5'd3, 5'd1, 5'd0); // lr.w x3,(x1)
        memory[4] = 32'h00700213; // addi x4,x0,7
        memory[5] = atomic_instruction(5'b00011, 5'd5, 5'd1, 5'd4); // sc.w x5,x4,(x1)
        memory[6] = atomic_instruction(5'b00011, 5'd6, 5'd1, 5'd2); // failing sc.w
        memory[7] = atomic_instruction(5'b00001, 5'd7, 5'd1, 5'd2); // amoswap.w
        memory[8] = atomic_instruction(5'b00000, 5'd8, 5'd1, 5'd4); // amoadd.w
        memory[9] = atomic_instruction(5'b00100, 5'd9, 5'd1, 5'd2); // amoxor.w
        memory[10] = atomic_instruction(5'b01100, 5'd10, 5'd1, 5'd4); // amoand.w
        memory[11] = atomic_instruction(5'b01000, 5'd11, 5'd1, 5'd2); // amoor.w
        memory[12] = 32'hfff00613; // addi x12,x0,-1
        memory[13] = atomic_instruction(5'b10000, 5'd13, 5'd1, 5'd12); // amomin.w
        memory[14] = atomic_instruction(5'b10100, 5'd14, 5'd1, 5'd2); // amomax.w
        memory[15] = atomic_instruction(5'b11000, 5'd15, 5'd1, 5'd12); // amominu.w
        memory[16] = atomic_instruction(5'b11100, 5'd16, 5'd1, 5'd12); // amomaxu.w
        memory[17] = 32'h0000a883; // lw x17,0(x1)
        memory[18] = 32'h0000006f; // loop

        repeat (3) @(negedge clk);
        reset = 1'b0;
        repeat (900) @(negedge clk);
        debug_halt_request = 1'b1;
        while (!debug_halted) @(negedge clk);
        debug_halt_request = 1'b0;

        check_register(5'd3, 32'd5);
        check_register(5'd5, 32'd0);
        check_register(5'd6, 32'd1);
        check_register(5'd7, 32'd7);
        check_register(5'd8, 32'd5);
        check_register(5'd9, 32'd12);
        check_register(5'd10, 32'd9);
        check_register(5'd11, 32'd1);
        check_register(5'd13, 32'd5);
        check_register(5'd14, 32'hffffffff);
        check_register(5'd15, 32'd5);
        check_register(5'd16, 32'd5);
        check_register(5'd17, 32'hffffffff);
        if (memory[64] !== 32'hffffffff) begin
            $error("atomic result expected=ffffffff actual=%08x", memory[64]);
            failures = failures + 1;
        end

        if (failures == 0) $display("PASS: rv32ima_atomic");
        else $fatal(1, "FAIL: rv32ima_atomic (%0d failures)", failures);
        $finish;
    end
endmodule
