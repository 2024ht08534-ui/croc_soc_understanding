# custom_alu — CROC Platform Custom IP

A 32-bit ALU peripheral designed to integrate with the [CROC](https://github.com/pulp-platform/croc) RISC-V SoC platform via an APB slave interface.

## Design Overview

| Block | Description |
|---|---|
| `custom_alu.sv` | Pipelined 32-bit ALU core (ADD/SUB/AND/OR/XOR/SHL/SHR/SRA/NOR/XNOR) |
| `custom_alu_apb_wrapper.sv` | APB3 register interface wrapping the ALU core |
| `tb/tb_custom_alu_apb.sv` | Self-checking SystemVerilog testbench |

## Register Map

| Offset | Name | Access | Description |
|--------|------|--------|-------------|
| 0x00 | OPERAND_A | R/W | 32-bit operand A |
| 0x04 | OPERAND_B | R/W | 32-bit operand B |
| 0x08 | OP_CTRL | R/W | [3:0] op_sel, [4] trigger |
| 0x0C | RESULT | RO | 32-bit ALU result |
| 0x10 | STATUS | RO | [0] ready, [1] zero, [2] carry |

## Quick Start

```bash
# Clone
git clone https://github.com/<your-username>/custom_alu.git
cd custom_alu

# Lint check
make compile

# Run testbench (requires Verilator)
make sim

# Synthesize (requires Yosys)
make synth

# Full PnR (requires OpenROAD + PDK)
make pnr
```

## Integrating with CROC using Bender

1. Add to your CROC `Bender.yml`:

```yaml
dependencies:
  custom_alu:
    git: https://github.com/<your-username>/custom_alu.git
    rev: main
```

2. Run `bender update` inside your CROC working directory.

3. Add the APB wrapper to CROC's peripheral list in `hw/vendor/croc_soc.sv` (see Integration Guide below).

## CROC Integration Steps

### Step 1 — Add APB slave port in croc_soc.sv
Locate the peripheral section and add:
```systemverilog
custom_alu_apb_wrapper u_custom_alu (
  .clk_i          (clk_i),
  .rst_ni         (rst_ni),
  .apb_paddr_i    (periph_apb_paddr),
  .apb_psel_i     (periph_apb_psel[<N>]),
  .apb_penable_i  (periph_apb_penable),
  .apb_pwrite_i   (periph_apb_pwrite),
  .apb_pwdata_i   (periph_apb_pwdata),
  .apb_prdata_o   (periph_apb_prdata[<N>]),
  .apb_pready_o   (periph_apb_pready[<N>]),
  .apb_pslverr_o  (periph_apb_pslverr[<N>])
);
```

### Step 2 — Assign address in the address map
In `hw/include/croc_pkg.sv`, add a base address for your peripheral:
```systemverilog
localparam logic [31:0] CUSTOM_ALU_BASE = 32'h3000_2000;
```

### Step 3 — Add APB decoder entry
Update the APB multiplexer/decoder to route transactions to the new slave.

### Step 4 — Rebuild
```bash
bender update
make all  # or follow CROC's build flow
```

## File Structure

```
custom_alu/
├── Bender.yml          # Bender package manifest
├── Bender.lock         # Locked dependency versions
├── Makefile            # Build automation
├── README.md
├── rtl/
│   ├── custom_alu.sv               # ALU core
│   └── custom_alu_apb_wrapper.sv   # APB wrapper
├── tb/
│   └── tb_custom_alu_apb.sv        # Testbench
└── synth/
    ├── synth_custom_alu.ys         # Yosys script
    ├── openroad_flow.tcl           # OpenROAD script
    └── custom_alu.sdc              # Timing constraints
```

## License

MIT
