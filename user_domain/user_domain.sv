// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>

`include "obi/typedef.svh"
`include "apb/typedef.svh"

module user_domain import user_pkg::*; import croc_pkg::*; #(
  parameter int unsigned GpioCount = 16,
  parameter int unsigned NumExternalIrqs = 4
) (
  input  logic      clk_i,
  input  logic      ref_clk_i,
  input  logic      rst_ni,
  input  logic      testmode_i,

  input  sbr_obi_req_t user_sbr_obi_req_i, // User Sbr (rsp_o), Croc Mgr (req_i)
  output sbr_obi_rsp_t user_sbr_obi_rsp_o,

  output mgr_obi_req_t user_mgr_obi_req_o, // User Mgr (req_o), Croc Sbr (rsp_i)
  input  mgr_obi_rsp_t user_mgr_obi_rsp_i,

  input  logic [      GpioCount-1:0] gpio_in_sync_i, // synchronized GPIO inputs
  output logic [NumExternalIrqs-1:0] interrupts_o    // interrupts to core
);

  assign interrupts_o = '0;

  // APB types for OBI-to-APB bridge
  `APB_TYPEDEF_REQ_T  ( alu_apb_req_t,  logic [31:0], logic [31:0], logic [3:0] )
  `APB_TYPEDEF_RESP_T ( alu_apb_resp_t, logic [31:0] )

  alu_apb_req_t  alu_apb_req;
  alu_apb_resp_t alu_apb_rsp;


  //////////////////////
  // User Manager MUX //
  /////////////////////

  // No manager so we don't need a obi_mux module and just terminate the request properly
  assign user_mgr_obi_req_o = '0;


  ////////////////////////////
  // User Subordinate DEMUX //
  ////////////////////////////

  // ----------------------------------------------------------------------------------------------
  // User Subordinate Buses
  // ----------------------------------------------------------------------------------------------

  // collection of signals from the demultiplexer
  sbr_obi_req_t [NumDemuxSbr-1:0] all_user_sbr_obi_req;
  sbr_obi_rsp_t [NumDemuxSbr-1:0] all_user_sbr_obi_rsp;

  // Error Subordinate Bus
  sbr_obi_req_t user_error_obi_req;
  sbr_obi_rsp_t user_error_obi_rsp;

  // OBI bus to your design
  sbr_obi_req_t user_design_obi_req;
  sbr_obi_rsp_t user_design_obi_rsp;

  // Fanout into more readable signals
  assign user_error_obi_req               = all_user_sbr_obi_req[UserError];
  assign all_user_sbr_obi_rsp[UserError]  = user_error_obi_rsp;
  assign user_design_obi_req              = all_user_sbr_obi_req[UserDesign];
  assign all_user_sbr_obi_rsp[UserDesign] = user_design_obi_rsp;


  //-----------------------------------------------------------------------------------------------
  // Demultiplex to User Subordinates according to address map
  //-----------------------------------------------------------------------------------------------

  logic [cf_math_pkg::idx_width(NumDemuxSbr)-1:0] user_idx;

  addr_decode #(
    .NoIndices ( NumDemuxSbr                    ),
    .NoRules   ( $size(UserAddrMap)             ),
    .addr_t    ( logic[SbrObiCfg.DataWidth-1:0] ),
    .rule_t    ( addr_map_rule_t                ),
    .Napot     ( 1'b0                           )
  ) i_addr_decode_periphs (
    .addr_i           ( user_sbr_obi_req_i.a.addr ),
    .addr_map_i       ( UserAddrMap               ),
    .idx_o            ( user_idx                  ),
    .dec_valid_o      (),
    .dec_error_o      (),
    .en_default_idx_i ( 1'b1      ),
    .default_idx_i    ( UserError )
  );

  obi_demux #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NumMgrPorts ( NumDemuxSbr   ),
    .NumMaxTrans ( 2             )
  ) i_obi_demux (
    .clk_i,
    .rst_ni,

    .sbr_port_select_i ( user_idx             ),
    .sbr_port_req_i    ( user_sbr_obi_req_i   ),
    .sbr_port_rsp_o    ( user_sbr_obi_rsp_o   ),

    .mgr_ports_req_o   ( all_user_sbr_obi_req ),
    .mgr_ports_rsp_i   ( all_user_sbr_obi_rsp )
  );


//-------------------------------------------------------------------------------------------------
// User Subordinates
//-------------------------------------------------------------------------------------------------

  ///////////////////////////////////
  // Custom ALU via OBI->APB bridge //
  ///////////////////////////////////

  obi_to_apb #(
    .ObiCfg             ( SbrObiCfg      ),
    .obi_req_t          ( sbr_obi_req_t  ),
    .obi_rsp_t          ( sbr_obi_rsp_t  ),
    .apb_req_t          ( alu_apb_req_t  ),
    .apb_rsp_t          ( alu_apb_resp_t ),
    .EnableSameCycleRsp ( 1'b1           )
  ) i_obi_to_apb (
    .clk_i,
    .rst_ni,
    .obi_req_i ( user_design_obi_req ),
    .obi_rsp_o ( user_design_obi_rsp ),
    .apb_req_o ( alu_apb_req         ),
    .apb_rsp_i ( alu_apb_rsp         )
  );

  custom_alu_apb_wrapper u_custom_alu (
    .clk_i         ( clk_i               ),
    .rst_ni        ( rst_ni              ),
    .apb_paddr_i   ( alu_apb_req.paddr   ),
    .apb_psel_i    ( alu_apb_req.psel    ),
    .apb_penable_i ( alu_apb_req.penable ),
    .apb_pwrite_i  ( alu_apb_req.pwrite  ),
    .apb_pwdata_i  ( alu_apb_req.pwdata  ),
    .apb_prdata_o  ( alu_apb_rsp.prdata  ),
    .apb_pready_o  ( alu_apb_rsp.pready  ),
    .apb_pslverr_o ( alu_apb_rsp.pslverr )
  );

  // Error Subordinate
  obi_err_sbr #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NumMaxTrans ( 1             ),
    .RspData     ( 32'hBADCAB1E  )
  ) i_user_err (
    .clk_i,
    .rst_ni,
    .testmode_i ( testmode_i         ),
    .obi_req_i  ( user_error_obi_req ),
    .obi_rsp_o  ( user_error_obi_rsp )
  );

endmodule
