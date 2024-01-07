module Cfu (
    input             cmd_valid,
    output            cmd_ready,
    input      [ 9:0] cmd_payload_function_id,
    input      [31:0] cmd_payload_inputs_0,
    input      [31:0] cmd_payload_inputs_1,
    output reg        rsp_valid,
    input             rsp_ready,
    output reg [31:0] rsp_payload_outputs_0,
    input             reset,
    input             clk
);

  // localparam InputOffset = $signed(16'd128);
  localparam activation_min = $signed(-32'd128);
  localparam activation_max = $signed(32'd127);

  reg [127:0] buffA = 'b0, buffB = 'b0;

  // post processing
  reg [15:0] OutputOffset;
  reg [31:0] MBQM_input0, MBQM_input1;
  reg signed [31:0] acc;


  wire signed [31:0] output_data, add_offset, act_min, act_max;
  wire signed [31:0] output_simd, output_mbqm;

  SIMD_16x simd(
    .buffA(buffA),
    .buffB(buffB),
    .result(output_simd)
  );

/*
  MBQM mbqm(
    .x(acc),
    .quantized_m(MBQM_input0),
    .shift(MBQM_input1),
    .result(output_mbqm)
  );
  
  assign add_offset = output_mbqm + $signed(OutputOffset);
  assign act_max = (add_offset > activation_min) ? add_offset : activation_min;
  assign act_min = (act_max < activation_max) ? act_max : activation_max;
  assign output_data = act_min;
  */
  


  // Only not ready for a command when we have a response.
  assign cmd_ready = ~rsp_valid;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      rsp_payload_outputs_0 <= 32'b0;
      rsp_valid <= 1'b0;
    end else if (rsp_valid) begin
      // Waiting to hand off response to CPU.
      rsp_valid <= ~rsp_ready;
    end else if (cmd_valid) begin
      rsp_valid <= 1'b1;
      // Accumulate step:
      // update : SIMD part belongs to cfu_op0
      case (cmd_payload_function_id[9:3])
        // SIMD start
        // 2'b000_0000: begin
          // rsp_payload_outputs_0 <= rsp_payload_outputs_0 + sum_prods;
        // end
        // reload
        2'b000_0001: begin
          OutputOffset <= OutputOffset;
          rsp_payload_outputs_0 <= 0'b0;
          buffA <= 32'b0;
          buffB <= 32'b0;
          acc <= 32'b0;
          MBQM_input0 <= 'b0;
          MBQM_input1 <= 'b0;
        end

        7'd2: begin
          buffA[31:0] <= cmd_payload_inputs_0;
          buffB[31:0] <= cmd_payload_inputs_1;
        end

        7'd3: begin
          buffA[63:32] <= cmd_payload_inputs_0;
          buffB[63:32] <= cmd_payload_inputs_1;
        end

        7'd4: begin
          buffA[95:64] <= cmd_payload_inputs_0;
          buffB[95:64] <= cmd_payload_inputs_1;
        end

        7'd5: begin
          buffA[127:96] <= cmd_payload_inputs_0;
          buffB[127:96] <= cmd_payload_inputs_1;
        end
        // SIMD end

        7'd6: begin
          MBQM_input0 <= cmd_payload_inputs_0;
          MBQM_input1 <= cmd_payload_inputs_1; 
        end

        7'd7: begin
          OutputOffset <= cmd_payload_inputs_0;
        end

        7'd8: begin
          rsp_payload_outputs_0 <= acc;
        end

        7'd9: begin
          buffA <= 'b0;
          buffB <= 'b0;
        end

        7'd10: begin
          rsp_payload_outputs_0 <= output_data;
        end
        
        7'd11: begin
          acc <= 'b0;
        end

        7'd12: begin
          acc <= acc + output_simd;
        end

        7'd13: begin
          acc <= acc + $signed(cmd_payload_inputs_0);
        end

        default: begin
          rsp_payload_outputs_0 <= 0'b0;
          OutputOffset <= OutputOffset;
        end

      endcase
    end else begin
      OutputOffset <= OutputOffset;
    end
  end

endmodule

module SIMD_16x(
  input [127:0] buffA,
  input [127:0] buffB,
  output signed [31:0] result
);

  localparam InputOffset = $signed(16'd128);

  wire signed [16:0] prod_0, prod_1, prod_2, prod_3;
  wire signed [16:0] prod_4, prod_5, prod_6, prod_7;
  wire signed [16:0] prod_8, prod_9, prod_10, prod_11;
  wire signed [16:0] prod_12, prod_13, prod_14, prod_15;

  assign prod_0  = ($signed(buffA[7:0]) + $signed(InputOffset)) * $signed(buffB[7:0]);
  assign prod_1  = ($signed(buffA[15:8]) + $signed(InputOffset)) * $signed(buffB[15:8]);
  assign prod_2  = ($signed(buffA[23:16]) + $signed(InputOffset)) * $signed(buffB[23:16]);
  assign prod_3  = ($signed(buffA[31:24]) + $signed(InputOffset)) * $signed(buffB[31:24]);

  assign prod_4  = ($signed(buffA[39:32]) + $signed(InputOffset)) * $signed(buffB[39:32]);
  assign prod_5  = ($signed(buffA[47:40]) + $signed(InputOffset)) * $signed(buffB[47:40]);
  assign prod_6  = ($signed(buffA[55:48]) + $signed(InputOffset)) * $signed(buffB[55:48]);
  assign prod_7  = ($signed(buffA[63:56]) + $signed(InputOffset)) * $signed(buffB[63:56]);

  assign prod_8  = ($signed(buffA[71:64]) + $signed(InputOffset)) * $signed(buffB[71:64]);
  assign prod_9  = ($signed(buffA[79:72]) + $signed(InputOffset)) * $signed(buffB[79:72]);
  assign prod_10 = ($signed(buffA[87:80]) + $signed(InputOffset)) * $signed(buffB[87:80]);
  assign prod_11 = ($signed(buffA[95:88]) + $signed(InputOffset)) * $signed(buffB[95:88]);

  assign prod_12 = ($signed(buffA[103:96]) + $signed(InputOffset)) * $signed(buffB[103:96]);
  assign prod_13 = ($signed(buffA[111:104]) + $signed(InputOffset)) * $signed(buffB[111:104]);
  assign prod_14 = ($signed(buffA[119:112]) + $signed(InputOffset)) * $signed(buffB[119:112]);
  assign prod_15 = ($signed(buffA[127:120]) + $signed(InputOffset)) * $signed(buffB[127:120]);

  assign result = prod_0 + prod_1 + prod_2 + prod_3 + prod_4 + prod_5 + prod_6 + prod_7 + prod_8 + prod_9 + prod_10 + prod_11 + prod_12 + prod_13 + prod_14 + prod_15;

endmodule

module MBQM (
    input [31:0] x,
    input [31:0] quantized_m,
    input signed [31:0] shift,
    output [31:0] result
);

  wire [31:0] input1;
  wire [4:0] lshift, rshift;
  wire [31:0] resultSRDHM;

  assign lshift = (shift > 0) ? shift : 0;
  assign rshift = (shift > 0) ? 0 : -shift;
  assign input1 = x * (1 << lshift);

  SRDHM srhdm_module (
      .a(input1),
      .b(quantized_m),
      .result(resultSRDHM)
  );

  RoundingDivideByPOT rdbp_module (
      .result_prev(resultSRDHM),
      .right_shift(rshift),
      .result(result)
  );

endmodule

// cor
module SRDHM (
  input   [31:0] a,
  input   [31:0] b,
  output  [31:0] result
);

  wire overflow;
  wire [63:0] ab_64;
  wire [64:0] add_nudge;
  wire [33:0] temp_result;

  assign overflow = ($signed(a) == $signed(b)) && ($signed(a) == $signed(33'h080000000));
  assign ab_64 = $signed(a) * $signed(b);
  assign add_nudge = $signed(ab_64) + $signed(32'h40000000);
  assign temp_result = overflow ? 34'h07fffffff : add_nudge[64:31];
  assign result = temp_result[31:0];

endmodule

module RoundingDivideByPOT (
  input [31:0] result_prev,
  input [4:0] right_shift,
  output [31:0] result
);

  wire [32:0] mask;
  wire [33:0] remainder, threshold;
  wire [31:0] out;
  wire [31:0] rhs, lhs;

  assign mask = (1'b1 << right_shift) - 1'b1;
  
  assign remainder = {1'b0, mask} & {1'b0, result_prev};
  assign threshold = {1'b0, mask[32:1]} + result_prev[31];
  assign lhs = $signed(result_prev) >> right_shift;
  assign rhs = ($signed(remainder) > $signed(threshold));
  
  assign out = lhs + rhs;
  assign result = (out[15:8] == 8'hff) ? {24'hffffff, out[7:0]} : out;

endmodule

/*
// unable to debug
module MBQM (
    input [31:0] x,
    input [31:0] quantized_m,
    input signed [31:0] shift,
    output [31:0] result
);

  wire [31:0] input1;
  wire [4:0] lshift, rshift;
  wire [31:0] resultSRDHM;

  assign lshift = (shift > 0) ? shift : 0;
  assign rshift = (shift > 0) ? 0 : -shift;
  assign input1 = x * (1 << lshift);

  SRDHM srhdm_module (
      .a(input1),
      .b(quantized_m),
      .result(resultSRDHM)
  );

  RoundingDivideByPOT rdbp_module (
      .result_prev(resultSRDHM),
      .right_shift(rshift),
      .result(result)
  );

endmodule

// cor
module SRDHM (
  input   [31:0] a,
  input   [31:0] b,
  output  [31:0] result
);

  wire overflow;
  wire [63:0] ab_64;
  wire [64:0] add_nudge;
  wire [33:0] temp_result;

  assign overflow = ($signed(a) == $signed(b)) && ($signed(a) == $signed(33'h080000000));
  assign ab_64 = $signed(a) * $signed(b);
  assign add_nudge = $signed(ab_64) + $signed(32'h40000000);
  assign temp_result = overflow ? 34'h07fffffff : add_nudge[64:31];
  assign result = temp_result[31:0];

endmodule

module RoundingDivideByPOT (
  input [31:0] result_prev,
  input [4:0] right_shift,
  output [31:0] result
);

  wire [32:0] mask;
  wire [33:0] remainder, threshold;
  wire [31:0] out;
  wire [31:0] rhs, lhs;

  assign mask = (1'b1 << right_shift) - 1'b1;
  
  assign remainder = {1'b0, mask} & {1'b0, result_prev};
  assign threshold = {1'b0, mask[32:1]} + result_prev[31];
  assign lhs = $signed(result_prev) >> right_shift;
  assign rhs = ($signed(remainder) > $signed(threshold));
  
  assign out = lhs + rhs;
  assign result = (out[15:8] == 8'hff) ? {24'hffffff, out[7:0]} : out;

endmodule
*/

/*
module PostProcessor (
  input clk,
  input reset,
  input [31:0] x,
  input [31:0] quantized_m,
  input signed [4:0] shift,
  input signed [31:0] output_offset,
  
  output reg [31:0] result
  
); 
    MBQM mbqm(
    .clk(clk),
    .reset(reset),
    .x(x),
    .quantized_m(quantized_m),
    .shift(shift),
    .out(output_MBQM)
  );
  
  localparam activation_min = $signed(-32'd128);
  localparam activation_max = $signed(32'd127);
  
  wire [31:0] output_MBQM;
  wire [31:0] add_offset, act_min, act_max;
  
  assign add_offset = $signed(output_MBQM) + output_offset;
  assign act_max = ($signed(add_offset) > $signed(activation_min)) ? $signed(add_offset) : $signed(activation_min);
  assign act_min = ($signed(act_max) < $signed(activation_max)) ? $signed(act_max) : $signed(activation_max);
  
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      result <= 'b0;
    end else begin
      result <= act_min; 
    end    
  end
  
endmodule

module MBQM (
  input clk,
  input reset,
  input [31:0] x,
  input [31:0] quantized_m,
  input signed [4:0] shift,
  output [31:0] out
);
  wire [31:0] input1;
  wire [4:0] lshift, rshift;
  wire [31:0] resultSRDHM;
  
  assign lshift = (shift > 0) ? shift : 0;
  assign rshift = (shift > 0) ? 0 : -shift;
  assign input1 = x * (1'b1 << lshift);

  SRDHM srhdm_module (
    .clk(clk),
    .reset(reset),
    .a(input1),
    .b(quantized_m),
    .result(resultSRDHM)
  );

  RoundingDivideByPOT rdbp_module (
    .clk(clk),
    .reset(reset),
    .result_prev(resultSRDHM),
    .right_shift(rshift),
    .result(out)
  );
  
endmodule

module SRDHM (
  input clk,
  input reset,
  input   [31:0] a,
  input   [31:0] b,
  output reg [31:0] result
);

  wire overflow;
  wire [63:0] ab_64;
  // wire overflow;
  // wire [63:0] ab_64;
  wire [64:0] add_nudge;
  wire [33:0] temp_result;

  
  assign overflow = ($signed(a) == $signed(b)) && ($signed(a) == $signed(33'h080000000));
  assign ab_64 = $signed(a) * $signed(b);
    
  // assign overflow = ($signed(a) == $signed(b)) && ($signed(a) == $signed(33'h080000000));
  // assign ab_64 = $signed(a) * $signed(b);

  assign add_nudge = $signed(ab_64) + $signed(32'h40000000);
  assign temp_result = overflow ? 34'h07fffffff : add_nudge[64:31];
  
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      result <= 'b0;
    end else begin
      result <= temp_result[31:0];
    end
  end

endmodule

module RoundingDivideByPOT (
  input clk,
  input reset,
  input [31:0] result_prev,
  input [4:0] right_shift,
  output reg [31:0] result
);

  wire [32:0] mask;
  wire [33:0] remainder, threshold;
  wire [31:0] out;
  // reg [31:0] rhs, lhs;
  wire [31:0] rhs, lhs;
  wire [31:0] result1;

  assign mask = (1'b1 << right_shift) - 1'b1;
  
  assign remainder = {1'b0, mask} & {1'b0, result_prev};
  assign threshold = {1'b0, mask[32:1]} + result_prev[31];

  assign lhs = $signed(result_prev) >> right_shift;
  assign rhs = ($signed(remainder) > $signed(threshold));   
  
  // assign lhs = $signed(result_prev) >> right_shift;
  // assign rhs = ($signed(remainder) > $signed(threshold));
  
  
  assign out = lhs + rhs;
  assign result1 = (out[15:8] == 8'hff) ? {24'hffffff, out[7:0]} : out;

  always @(posedge clk or posedge reset) begin
    if(reset) begin
      result <= 'b0;
    end else begin
      result <= result1; 
    end
  end
endmodule
*/