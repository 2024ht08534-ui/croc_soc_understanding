// =============================================================================
// APB Wrapper for Custom ALU - CROC Platform Integration
// File: custom_alu_apb_wrapper.sv
// Description: Wraps the custom ALU with an APB3 slave interface so it can be
//              memory-mapped into CROC's peripheral address space.
//
// Register Map (base + offset):
//   0x00 - OPERAND_A   (R/W) - 32-bit operand A
//   0x04 - OPERAND_B   (R/W) - 32-bit operand B
//   0x08 - OP_CTRL     (R/W) - [3:0] op_sel, [4] valid trigger
//   0x0C - RESULT      (RO)  - 32-bit result
//   0x10 - STATUS      (RO)  - [0] ready, [1] zero, [2] carry
// =============================================================================

`timescale 1ns/1ps

module custom_alu_apb_wrapper #(
    parameter APB_ADDR_WIDTH = 32,
    parameter APB_DATA_WIDTH = 32
) (
    input  logic                      clk_i,
    input  logic                      rst_ni,

    // APB Slave Interface
    input  logic [APB_ADDR_WIDTH-1:0] apb_paddr_i,
    input  logic                      apb_psel_i,
    input  logic                      apb_penable_i,
    input  logic                      apb_pwrite_i,
    input  logic [APB_DATA_WIDTH-1:0] apb_pwdata_i,
    output logic [APB_DATA_WIDTH-1:0] apb_prdata_o,
    output logic                      apb_pready_o,
    output logic                      apb_pslverr_o
);

    // Register addresses (word-addressed offsets)
    localparam ADDR_OPERAND_A = 3'h0;
    localparam ADDR_OPERAND_B = 3'h1;
    localparam ADDR_OP_CTRL   = 3'h2;
    localparam ADDR_RESULT    = 3'h3;
    localparam ADDR_STATUS    = 3'h4;

    // Internal registers
    logic [31:0] reg_operand_a, reg_operand_b;
    logic [4:0]  reg_op_ctrl;
    logic [31:0] alu_result;
    logic        alu_zero, alu_carry, alu_ready;
    logic        alu_valid_pulse;

    // Address decode (word-aligned: bits [4:2])
    logic [2:0] word_addr;
    assign word_addr = apb_paddr_i[4:2];

    // APB write logic
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            reg_operand_a  <= '0;
            reg_operand_b  <= '0;
            reg_op_ctrl    <= '0;
            alu_valid_pulse <= 1'b0;
        end else begin
            alu_valid_pulse <= 1'b0;  // Single-cycle pulse

            if (apb_psel_i && apb_penable_i && apb_pwrite_i) begin
                case (word_addr)
                    ADDR_OPERAND_A: reg_operand_a <= apb_pwdata_i;
                    ADDR_OPERAND_B: reg_operand_b <= apb_pwdata_i;
                    ADDR_OP_CTRL: begin
                        reg_op_ctrl     <= apb_pwdata_i[4:0];
                        alu_valid_pulse <= apb_pwdata_i[4];  // bit4 triggers compute
                    end
                    default: ; // Ignore writes to RO registers
                endcase
            end
        end
    end

    // APB read logic
    always_comb begin
        apb_prdata_o = '0;
        if (apb_psel_i && !apb_pwrite_i) begin
            case (word_addr)
                ADDR_OPERAND_A: apb_prdata_o = reg_operand_a;
                ADDR_OPERAND_B: apb_prdata_o = reg_operand_b;
                ADDR_OP_CTRL:   apb_prdata_o = {27'b0, reg_op_ctrl};
                ADDR_RESULT:    apb_prdata_o = alu_result;
                ADDR_STATUS:    apb_prdata_o = {29'b0, alu_carry, alu_zero, alu_ready};
                default:        apb_prdata_o = 32'hDEAD_BEEF;
            endcase
        end
    end

    assign apb_pready_o  = 1'b1;   // Zero wait states
    assign apb_pslverr_o = 1'b0;   // No error

    // Instantiate ALU core
    custom_alu #(
        .DATA_WIDTH(32)
    ) u_alu (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .operand_a_i (reg_operand_a),
        .operand_b_i (reg_operand_b),
        .op_sel_i    (reg_op_ctrl[3:0]),
        .valid_i     (alu_valid_pulse),
        .result_o    (alu_result),
        .zero_o      (alu_zero),
        .carry_o     (alu_carry),
        .ready_o     (alu_ready)
    );

endmodule : custom_alu_apb_wrapper
