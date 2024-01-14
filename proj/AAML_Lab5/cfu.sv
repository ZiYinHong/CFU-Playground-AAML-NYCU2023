// Copyright 2021 The CFU-Playground Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// `include "/home/michelle/CFU-Playground/proj/lab5_cfu_old/TPU.sv"
// `include "/home/michelle/CFU-Playground/proj/lab5_cfu_old/global_buffer.sv"
`include "/home/michelle/CFU-Playground/proj/lab5_cfu/TPU.sv"
`include "/home/michelle/CFU-Playground/proj/lab5_cfu/global_buffer.sv"


module Cfu (
  input               reset,
  input               clk,
   // CFU <---> CPU handshaking
  input               cmd_valid,
  output reg          cmd_ready,
  output reg          rsp_valid,
  input               rsp_ready,
  // RISC-V assembly inputs ({funct7, funct3}, rs1, and rs2)
  input  reg [9:0]    cmd_payload_function_id,
  input      [31:0]   cmd_payload_inputs_0,
  input      [31:0]   cmd_payload_inputs_1,
  // CFU output signals
  output [31:0]   rsp_payload_outputs_0
);

wire busy;
reg in_valid;
// reg rsp_cpu;
reg signed [9:0] A_in_index, B_in_index; 
reg  signed [2:0] C_out_index, c4_cnt;
wire signed [9:0] A_out_index, B_out_index;
wire signed [2:0] C_in_index;
reg [8:0] K;
reg [7:0] M;
reg [7:0] N;
reg [7:0] A_data_in, B_data_in;
wire [31:0] A_data_out, B_data_out;
wire [127:0] C_data_in, C_data_out;
reg signed [2:0] cnt_4;
reg [31:0] dataout;
reg busy_flag;


reg A_wr_en_init;
reg B_wr_en_init;
reg C_wr_en_init;
wire A_wr_en_mux;
wire B_wr_en_mux;
wire C_wr_en_mux;
wire A_wr_en, B_wr_en, C_wr_en;
assign A_wr_en_mux = (in_valid | busy) ? A_wr_en : A_wr_en_init;
assign B_wr_en_mux = (in_valid | busy) ? B_wr_en : B_wr_en_init;
assign C_wr_en_mux = (busy) ? C_wr_en : C_wr_en_init;

global_buffer #(
    .ADDR_BITS(10),
    .DATA_IN_BITS(8),
    .DATA_OUT_BITS(32),
    .DEPTH(320),
    .FLAG(0)
)gbuff_A(
    .clk(clk),
    .reset(reset),  //rst can't reset, or just overwrite the value
    .wr_en(A_wr_en_mux),
    .cnt_4(cnt_4),
    .in_index(A_in_index),
    .out_index(A_out_index),
    .data_in(A_data_in),
    .data_out(A_data_out)
);

global_buffer #(
    .ADDR_BITS(10),
    .DATA_IN_BITS(8),
    .DATA_OUT_BITS(32),
    .DEPTH(320),
    .FLAG(1)
) gbuff_B(
    .clk(clk),
    .reset(reset), //rst
    .wr_en(B_wr_en_mux),
    .cnt_4(cnt_4),
    .in_index(B_in_index),
    .out_index(B_out_index),
    .data_in(B_data_in),
    .data_out(B_data_out)
);


global_buffer #(
    .ADDR_BITS(3),  //0,1,2,3
    .DATA_IN_BITS(128),
    .DATA_OUT_BITS(128),
    .DEPTH(7),
    .FLAG(2)
) gbuff_C(
    .clk(clk),
    .reset(reset),  //rst
    .wr_en(C_wr_en_mux),
    .cnt_4(cnt_4),
    .in_index(C_in_index),
    .out_index(C_out_index),
    .data_in(C_data_in),
    .data_out(C_data_out)
);

TPU My_TPU(
    .clk            (clk),     
    .reset          (reset),     
    .in_valid       (in_valid),         
    .K              (K), 
    .M              (M), 
    .N              (N), 
    .busy           (busy),     
    .A_wr_en        (A_wr_en),         
    .A_index        (A_out_index),          
    .A_data_out     (A_data_out),         
    .B_wr_en        (B_wr_en),         
    .B_index        (B_out_index),         
    .B_data_out     (B_data_out),         
    .C_wr_en        (C_wr_en),         
    .C_index        (C_in_index),         
    .C_data_in      (C_data_in)         
);


// initial begin
//     in_valid = 1'b0;
//     K = 'bx;
//     M = 4;
//     N = 4;
//     A_in_index = 0;
//     B_in_index = 0;
//     // C_out_index = -1; 
//     C_out_index = 0;
//     cnt_4 = -1;
//     c4_cnt = 0;
//     rsp_valid = 0;
//     cmd_ready = 1;
//     A_data_in = 0;
//     B_data_in = 0;
//     busy_flag = 0;
//     dataout = 0;
//     A_wr_en_init = 0;
//     B_wr_en_init = 0;
//     C_wr_en_init = 0;
// end

always @(posedge clk) begin
  if (cmd_valid && cmd_payload_function_id[9:3] == 7'd3) begin  
    in_valid <= 1'b1;
  end
  else begin
    in_valid <= 1'b0;
  end
end


// Only not ready for a command when we have a response.
assign rsp_payload_outputs_0 = (busy_flag && busy == 1'b1) ? busy : dataout;


//cmd_payload_function_id
//7'd0: reset
//7'd1: read K, M, N
//7'd2: read A, B
//7'd3: tell TPU start cal
//7'd4: check if TPU done cal
//7'd5: return val to CPU
  always @(posedge clk) begin
    if (reset) begin  //not occur at all
      rsp_valid <= 1'b0;
    end
    else if (rsp_valid) begin
      // Waiting to hand off response to CPU.
      rsp_valid <= 1'b0;
      cmd_ready <= 1'b1;
    end 
    else if (cmd_valid) begin 
      rsp_valid <= 1'b1;
      cmd_ready <= 1'b0;
      //$display("busy= %h\n",busy);

      case (cmd_payload_function_id[9:3])
        7'd0 : begin
          A_in_index <= 0;
          B_in_index <= 0;
          C_out_index <= 0;
          K <= 'bx;
          M <= 4;
          N <= 4;
          cnt_4 <= -1;
          c4_cnt <= 0;
          A_data_in <= 0;
          B_data_in <= 0;
          busy_flag <= 0;
          dataout <= 0;
          A_wr_en_init <= 0;
          B_wr_en_init <= 0;
          C_wr_en_init <= 0;
          //$display("reset: c4_cnt = %3h, rsp_cpu = %h, C_out_index = %8h\n",c4_cnt, rsp_cpu,  rsp_cpu);
        end
        7'd1 : begin
          K <= cmd_payload_inputs_0;
          M <= cmd_payload_inputs_1;
        end
        7'd2 : begin
          A_data_in <= cmd_payload_inputs_0[7:0]; //filter
          B_data_in <= cmd_payload_inputs_1[7:0]; //input, need to add on input offset: 128
          A_in_index <= (cnt_4 == 3) ? A_in_index + 1 : A_in_index;
          B_in_index <= (cnt_4 == 3) ? B_in_index + 1 : B_in_index; 
          A_wr_en_init <= 1'b1;
          B_wr_en_init <= 1'b1;
          cnt_4 <= (cnt_4 == 3) ? 0 : cnt_4+1;
        end
        7'd3: begin
          A_wr_en_init <= 1'b0;
          B_wr_en_init <= 1'b0;
          busy_flag <= 1'b1;
        end
        7'd5 : begin
          busy_flag <= 1'b0;     
          case (c4_cnt) 
            3'h0: dataout <= C_data_out[127:96];
            3'h1: dataout <= C_data_out[95:64];//gbuff_C.gbuff[C_out_index][95:64];
            3'h2: dataout <= C_data_out[63:32];
            3'h3: dataout <= C_data_out[31:0];
          endcase

          //$display("c4_cnt = %3h, busy = %h, C_out_index = %8h, C_data_out = %8h, rsp_payload_outputs_0 = %8h\n",c4_cnt, busy,C_out_index, C_data_out, rsp_payload_outputs_0);

          if (c4_cnt == 3'h3) begin
            C_out_index <= (C_out_index == 3'h3) ? 0:C_out_index + 1;
          end
          c4_cnt <= (c4_cnt == 3'h3) ? 0: c4_cnt + 1; 
        end
      endcase 
    end
  end




endmodule

