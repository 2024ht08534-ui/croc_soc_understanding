// =============================================================================
// Testbench for custom_alu_apb_wrapper
// File: tb_custom_alu_apb.sv
// Tests: APB write/read register access, ALU operations via APB interface
// Compatible with: Verilator, ModelSim, Xcelium, VCS
// =============================================================================

`timescale 1ns/1ps

module tb_custom_alu_apb;

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic        clk, rst_n;
    logic [31:0] apb_paddr;
    logic        apb_psel, apb_penable, apb_pwrite;
    logic [31:0] apb_pwdata;
    logic [31:0] apb_prdata;
    logic        apb_pready, apb_pslverr;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    custom_alu_apb_wrapper u_dut (
        .clk_i          (clk),
        .rst_ni         (rst_n),
        .apb_paddr_i    (apb_paddr),
        .apb_psel_i     (apb_psel),
        .apb_penable_i  (apb_penable),
        .apb_pwrite_i   (apb_pwrite),
        .apb_pwdata_i   (apb_pwdata),
        .apb_prdata_o   (apb_prdata),
        .apb_pready_o   (apb_pready),
        .apb_pslverr_o  (apb_pslverr)
    );

    // -------------------------------------------------------------------------
    // Clock generation: 100 MHz
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Test result tracking
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // -------------------------------------------------------------------------
    // APB Tasks
    // -------------------------------------------------------------------------

    // APB Write task
    task automatic apb_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        apb_paddr   = addr;
        apb_pwdata  = data;
        apb_pwrite  = 1'b1;
        apb_psel    = 1'b1;
        apb_penable = 1'b0;
        @(posedge clk);
        apb_penable = 1'b1;
        @(posedge clk);
        while (!apb_pready) @(posedge clk);
        apb_psel    = 1'b0;
        apb_penable = 1'b0;
        apb_pwrite  = 1'b0;
    endtask

    // APB Read task
    task automatic apb_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        apb_paddr   = addr;
        apb_pwrite  = 1'b0;
        apb_psel    = 1'b1;
        apb_penable = 1'b0;
        @(posedge clk);
        apb_penable = 1'b1;
        @(posedge clk);
        while (!apb_pready) @(posedge clk);
        data        = apb_prdata;
        apb_psel    = 1'b0;
        apb_penable = 1'b0;
    endtask

    // Check task
    task automatic check(
        input string  test_name,
        input logic [31:0] got,
        input logic [31:0] expected
    );
        if (got === expected) begin
            $display("[PASS] %s | got=0x%08h expected=0x%08h", test_name, got, expected);
            pass_count++;
        end else begin
            $display("[FAIL] %s | got=0x%08h expected=0x%08h", test_name, got, expected);
            fail_count++;
        end
    endtask

    // Run ALU operation via APB and return result
    task automatic run_alu(
        input  logic [31:0] op_a,
        input  logic [31:0] op_b,
        input  logic [3:0]  op,
        output logic [31:0] result,
        output logic [31:0] status
    );
        apb_write(32'h00, op_a);          // Write operand A
        apb_write(32'h04, op_b);          // Write operand B
        apb_write(32'h08, {27'b0, 1'b1, op}); // op_sel + trigger bit
        repeat(5) @(posedge clk);         // Wait for pipeline
        apb_read(32'h0C, result);         // Read result
        apb_read(32'h10, status);         // Read status flags
    endtask

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------
    initial begin
        // Dump waveforms
        $dumpfile("tb_custom_alu_apb.vcd");
        $dumpvars(0, tb_custom_alu_apb);

        // Initialize APB bus
        apb_paddr   = '0;
        apb_psel    = '0;
        apb_penable = '0;
        apb_pwrite  = '0;
        apb_pwdata  = '0;

        // Reset
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        $display("\n========================================");
        $display("  CROC Custom ALU APB Testbench");
        $display("========================================\n");

        // ---------------------------------------------------------------
        // TEST GROUP 1: Register Read/Write
        // ---------------------------------------------------------------
        $display("--- TEST GROUP 1: Register R/W ---");

        // Write and read back operand A
        apb_write(32'h00, 32'hABCD_1234);
        begin
            logic [31:0] rd;
            apb_read(32'h00, rd);
            check("REG_WRITE_OPERAND_A", rd, 32'hABCD_1234);
        end

        // Write and read back operand B
        apb_write(32'h04, 32'h5678_EFFF);
        begin
            logic [31:0] rd;
            apb_read(32'h04, rd);
            check("REG_WRITE_OPERAND_B", rd, 32'h5678_EFFF);
        end

        // Write op control (op only, no trigger)
        apb_write(32'h08, 32'h0000_0003); // OR operation
        begin
            logic [31:0] rd;
            apb_read(32'h08, rd);
            check("REG_WRITE_OP_CTRL", rd, 32'h0000_0003);
        end

        // ---------------------------------------------------------------
        // TEST GROUP 2: ALU Operations
        // ---------------------------------------------------------------
        $display("\n--- TEST GROUP 2: ALU Operations ---");

        begin
            logic [31:0] res, status;

            // ADD: 100 + 200 = 300
            run_alu(32'd100, 32'd200, 4'h0, res, status);
            check("ALU_ADD_100+200", res, 32'd300);

            // ADD with carry: 0xFFFFFFFF + 1 => 0, carry=1
            run_alu(32'hFFFF_FFFF, 32'h1, 4'h0, res, status);
            check("ALU_ADD_OVERFLOW_RESULT", res, 32'h0000_0000);
            check("ALU_ADD_OVERFLOW_CARRY",  32'(status[2]), 32'h1);
            check("ALU_ADD_OVERFLOW_ZERO",   32'(status[1]), 32'h1);

            // SUB: 500 - 200 = 300
            run_alu(32'd500, 32'd200, 4'h1, res, status);
            check("ALU_SUB_500-200", res, 32'd300);

            // SUB to zero: same operands
            run_alu(32'hDEAD_BEEF, 32'hDEAD_BEEF, 4'h1, res, status);
            check("ALU_SUB_ZERO_RESULT", res, 32'h0);
            check("ALU_SUB_ZERO_FLAG",   32'(status[1]), 32'h1);

            // AND
            run_alu(32'hFF00_FF00, 32'h0FF0_0FF0, 4'h2, res, status);
            check("ALU_AND", res, 32'h0F00_0F00);

            // OR
            run_alu(32'hA0A0_A0A0, 32'h0B0B_0B0B, 4'h3, res, status);
            check("ALU_OR", res, 32'hABAB_ABAB);

            // XOR: same values = 0
            run_alu(32'h1234_5678, 32'h1234_5678, 4'h4, res, status);
            check("ALU_XOR_SAME_ZERO", res, 32'h0);
            check("ALU_XOR_ZERO_FLAG", 32'(status[1]), 32'h1);

            // SHL: 1 << 8 = 0x100
            run_alu(32'h0000_0001, 32'd8, 4'h5, res, status);
            check("ALU_SHL_1<<8", res, 32'h0000_0100);

            // SHR: 0x100 >> 4 = 0x10
            run_alu(32'h0000_0100, 32'd4, 4'h6, res, status);
            check("ALU_SHR_0x100>>4", res, 32'h0000_0010);

            // SRA: preserve sign on negative number
            run_alu(32'h8000_0000, 32'd1, 4'h7, res, status);
            check("ALU_SRA_NEG", res, 32'hC000_0000); // Arithmetic: MSB preserved
        end

        // ---------------------------------------------------------------
        // TEST GROUP 3: Status flags edge cases
        // ---------------------------------------------------------------
        $display("\n--- TEST GROUP 3: Status Flags ---");
        begin
            logic [31:0] res, status;

            // Check ready flag
            //run_alu(32'd1, 32'd1, 4'h0, res, status);
            //check("STATUS_READY_FLAG", 32'(status[0]), 32'h1);

            // NOR: ~(A | B)
            run_alu(32'h0000_0000, 32'h0000_0000, 4'h8, res, status);
            check("ALU_NOR_ZERO_INPUTS", res, 32'hFFFF_FFFF);
        end

        // ---------------------------------------------------------------
        // Results summary
        // ---------------------------------------------------------------
        $display("\n========================================");
        $display("  RESULTS: %0d PASS | %0d FAIL", pass_count, fail_count);
        $display("========================================\n");

        if (fail_count == 0)
            $display("ALL TESTS PASSED!\n");
        else
            $display("SOME TESTS FAILED - check above.\n");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #500000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule : tb_custom_alu_apb
