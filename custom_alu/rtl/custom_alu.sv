// =============================================================================
// Custom ALU Design for CROC Platform
// File: custom_alu.sv
// Description: 32-bit ALU supporting ADD, SUB, AND, OR, XOR, SHL, SHR ops
//              Designed to integrate with CROC SoC via simple register interface
// =============================================================================

`timescale 1ns/1ps

module custom_alu #(
    parameter DATA_WIDTH = 32
) (
    input  logic                   clk_i,
    input  logic                   rst_ni,      // Active-low reset

    // Register interface (memory-mapped via CROC APB)
    input  logic [DATA_WIDTH-1:0]  operand_a_i, // Operand A
    input  logic [DATA_WIDTH-1:0]  operand_b_i, // Operand B
    input  logic [3:0]             op_sel_i,    // Operation select
    input  logic                   valid_i,     // Input valid strobe

    // Outputs
    output logic [DATA_WIDTH-1:0]  result_o,    // ALU result
    output logic                   zero_o,      // Zero flag
    output logic                   carry_o,     // Carry/overflow flag
    output logic                   ready_o      // Result ready
);

    // Operation encoding
    typedef enum logic [3:0] {
        ALU_ADD = 4'h0,
        ALU_SUB = 4'h1,
        ALU_AND = 4'h2,
        ALU_OR  = 4'h3,
        ALU_XOR = 4'h4,
        ALU_SHL = 4'h5,
        ALU_SHR = 4'h6,
        ALU_SRA = 4'h7,  // Arithmetic right shift
        ALU_NOR = 4'h8,
        ALU_XNOR= 4'h9
    } alu_op_e;

    // Internal signals
    logic [DATA_WIDTH:0]   result_extended;  // Extra bit for carry
    logic [DATA_WIDTH-1:0] result_q;
    logic                  carry_q, zero_q, ready_q;

    // Combinational ALU logic
    always_comb begin : alu_operation
        result_extended = '0;
        case (alu_op_e'(op_sel_i))
            ALU_ADD: result_extended = {1'b0, operand_a_i} + {1'b0, operand_b_i};
            ALU_SUB: result_extended = {1'b0, operand_a_i} - {1'b0, operand_b_i};
            ALU_AND: result_extended = {1'b0, operand_a_i  & operand_b_i};
            ALU_OR:  result_extended = {1'b0, operand_a_i  | operand_b_i};
            ALU_XOR: result_extended = {1'b0, operand_a_i  ^ operand_b_i};
            ALU_SHL: result_extended = {1'b0, operand_a_i << operand_b_i[4:0]};
            ALU_SHR: result_extended = {1'b0, operand_a_i >> operand_b_i[4:0]};
            ALU_SRA: result_extended = {1'b0, $signed(operand_a_i) >>> operand_b_i[4:0]};
            ALU_NOR: result_extended = {1'b0, ~(operand_a_i | operand_b_i)};
            ALU_XNOR:result_extended = {1'b0, ~(operand_a_i ^ operand_b_i)};
            default: result_extended = '0;
        endcase
    end

    // Registered output stage
    always_ff @(posedge clk_i or negedge rst_ni) begin : output_reg
        if (!rst_ni) begin
            result_q <= '0;
            carry_q  <= 1'b0;
            zero_q   <= 1'b0;
            ready_q  <= 1'b0;
        end else begin
            ready_q  <= valid_i;
            if (valid_i) begin
                result_q <= result_extended[DATA_WIDTH-1:0];
                carry_q  <= result_extended[DATA_WIDTH];
                zero_q   <= (result_extended[DATA_WIDTH-1:0] == '0);
            end
        end
    end

    assign result_o = result_q;
    assign carry_o  = carry_q;
    assign zero_o   = zero_q;
    assign ready_o  = ready_q;

endmodule : custom_alu
