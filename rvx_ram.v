// SPDX-License-Identifier: MIT
// Copyright (c) 2020-2025 RVX Project Contributors

module rvx_ram #(
  // Memory size in bytes
  parameter MEMORY_SIZE      = 8192,
  // File with program and data
  parameter MEMORY_INIT_FILE = ""
  ) (
  // Global signals
  input   wire          clock,
  input   wire          reset,

  // IO interface
  input  wire   [31:0]  rw_address,
  output reg    [31:0]  read_data,
  input  wire           read_request,
  output reg            read_response,
  input  wire   [31:0]  write_data,
  input  wire   [3:0 ]  write_strobe,
  input  wire           write_request,
  output reg            write_response
  );

  // Endereço e decodificação (8KB = 2048 palavras de 32-bits)
  // Cada banco de SRAM do sky130 tem 512 palavras, totalizando 4 bancos
  wire [10:0] word_addr  = rw_address[12:2];
  wire [1:0]  bank_sel   = word_addr[10:9];
  wire [8:0]  macro_addr = word_addr[8:0];

  // Chip Select Ativo Baixo (CSB)
  wire csb0 = ~((read_request | write_request) & (bank_sel == 2'b00));
  wire csb1 = ~((read_request | write_request) & (bank_sel == 2'b01));
  wire csb2 = ~((read_request | write_request) & (bank_sel == 2'b10));
  wire csb3 = ~((read_request | write_request) & (bank_sel == 2'b11));

  // Write Enable Ativo Baixo (WEB)
  wire web = ~write_request;
  
  // Write Mask Ativo Alto (WMASK)
  wire [3:0] wmask = write_strobe;

  // Fios de Saida das macros
  wire [31:0] dout0, dout1, dout2, dout3;

  sky130_sram_2kbyte_1rw1r_32x512_8 sram_bank0 (
    .clk0(clock), .csb0(csb0), .web0(web), .wmask0(wmask), .addr0(macro_addr), .din0(write_data), .dout0(dout0),
    .clk1(1'b0),  .csb1(1'b1), .addr1(9'b0), .dout1()
  );

  sky130_sram_2kbyte_1rw1r_32x512_8 sram_bank1 (
    .clk0(clock), .csb0(csb1), .web0(web), .wmask0(wmask), .addr0(macro_addr), .din0(write_data), .dout0(dout1),
    .clk1(1'b0),  .csb1(1'b1), .addr1(9'b0), .dout1()
  );

  sky130_sram_2kbyte_1rw1r_32x512_8 sram_bank2 (
    .clk0(clock), .csb0(csb2), .web0(web), .wmask0(wmask), .addr0(macro_addr), .din0(write_data), .dout0(dout2),
    .clk1(1'b0),  .csb1(1'b1), .addr1(9'b0), .dout1()
  );

  sky130_sram_2kbyte_1rw1r_32x512_8 sram_bank3 (
    .clk0(clock), .csb0(csb3), .web0(web), .wmask0(wmask), .addr0(macro_addr), .din0(write_data), .dout0(dout3),
    .clk1(1'b0),  .csb1(1'b1), .addr1(9'b0), .dout1()
  );

  // Registro de seleção para multiplexar no ciclo de read (latência de 1 ciclo)
  reg [1:0] bank_sel_q;
  reg reset_reg;
  always @(posedge clock) begin
    bank_sel_q <= bank_sel;
    reset_reg  <= reset;
  end

  always @(*) begin
    case(bank_sel_q)
      2'b00: read_data = dout0;
      2'b01: read_data = dout1;
      2'b10: read_data = dout2;
      2'b11: read_data = dout3;
    endcase
  end

  wire reset_internal = reset | reset_reg;

  always @(posedge clock) begin
    if (reset_internal) begin
      read_response  <= 1'b0;
      write_response <= 1'b0;
    end else begin
      read_response  <= read_request;
      write_response <= write_request;
    end
  end

  // Avoid warnings about intentionally unused pins/wires
  wire unused_ok = &{1'b0, rw_address[31:13], rw_address[1:0], 1'b0};

endmodule
