/*
module Cfu (
  input               cmd_valid,
  output              cmd_ready,
  input      [9:0]    cmd_payload_function_id,
  input      [31:0]   cmd_payload_inputs_0,
  input      [31:0]   cmd_payload_inputs_1,
  output reg          rsp_valid,
  input               rsp_ready,
  output reg [31:0]   rsp_payload_outputs_0,
  input               reset,
  input               clk
);
  reg [15:0] InputOffset;

  // SIMD multiply step:
  wire signed [16:0] prod_0, prod_1, prod_2, prod_3;
  assign prod_0 =  ($signed(cmd_payload_inputs_0[7 : 0]) + $signed(InputOffset))
                  * $signed(cmd_payload_inputs_1[7 : 0]);
  assign prod_1 =  ($signed(cmd_payload_inputs_0[15: 8]) + $signed(InputOffset))
                  * $signed(cmd_payload_inputs_1[15: 8]);
  assign prod_2 =  ($signed(cmd_payload_inputs_0[23:16]) + $signed(InputOffset))
                  * $signed(cmd_payload_inputs_1[23:16]);
  assign prod_3 =  ($signed(cmd_payload_inputs_0[31:24]) + $signed(InputOffset))
                  * $signed(cmd_payload_inputs_1[31:24]);

  wire signed [31:0] sum_prods;
  assign sum_prods = prod_0 + prod_1 + prod_2 + prod_3;

  // Only not ready for a command when we have a response.
  assign cmd_ready = ~rsp_valid;

  always @(posedge clk) begin
    if (reset) begin
      rsp_payload_outputs_0 <= 32'b0;
      rsp_valid <= 1'b0;
      InputOffset <= 0;
    end else if (rsp_valid) begin
      // Waiting to hand off response to CPU.
      rsp_valid <= ~rsp_ready;
    end else if (cmd_valid) begin
      rsp_valid <= 1'b1;
      // Accumulate step:
      case (cmd_payload_function_id[9:3])
        2'b000_0000: begin
          InputOffset <= InputOffset;
          rsp_payload_outputs_0 <= rsp_payload_outputs_0 + sum_prods;
        end
        2'b000_0001: begin
          InputOffset <= cmd_payload_inputs_0[15:0];
          rsp_payload_outputs_0 <= 0'b0;
        end
        default: begin
          InputOffset <= InputOffset;
          rsp_payload_outputs_0 <= 0'b0;
        end
      endcase
    end
  end
endmodule
*/
// hybrid super scale SIMD
// offload bias part to cfu
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
  reg [15:0] InputOffset;
  reg [127:0] buffA = 'b0, buffB = 'b0;

  // SIMD multiply step:
  wire signed [16:0] prod_0, prod_1, prod_2, prod_3;
  wire signed [16:0] prod_4, prod_5, prod_6, prod_7;
  wire signed [16:0] prod_8, prod_9, prod_10, prod_11;
  wire signed [16:0] prod_12, prod_13, prod_14, prod_15;

  assign prod_0  = ($signed(buffA[7 : 0]) + $signed(InputOffset)) * $signed(buffB[7 : 0]);
  assign prod_1  = ($signed(buffA[15:8]) + $signed(InputOffset)) * $signed(buffB[15:8]);
  assign prod_2  = ($signed(buffA[23:16]) + $signed(InputOffset)) * $signed(buffB[23:16]);
  assign prod_3  = ($signed(buffA[31:24]) + $signed(InputOffset)) * $signed(buffB[31:24]);

  assign prod_4  = ($signed(buffA[39:32]) + $signed(InputOffset)) * $signed(buffB[39:32]);
  assign prod_5  = ($signed(buffA[47:40]) + $signed(InputOffset)) * $signed(buffB[47:40]);
  assign prod_6  = ($signed(buffA[55:48]) + $signed(InputOffset)) * $signed(buffB[55:48]);
  assign prod_7  = ($signed(buffA[63:56]) + $signed(InputOffset)) * $signed(buffB[63:56]);

  assign prod_8  = ($signed(buffA[71 : 64]) + $signed(InputOffset)) * $signed(buffB[71 : 64]);
  assign prod_9  = ($signed(buffA[79:72]) + $signed(InputOffset)) * $signed(buffB[79:72]);
  assign prod_10 = ($signed(buffA[87:80]) + $signed(InputOffset)) * $signed(buffB[87:80]);
  assign prod_11 = ($signed(buffA[95:88]) + $signed(InputOffset)) * $signed(buffB[95:88]);

  assign prod_12 = ($signed(buffA[103 : 96]) + $signed(InputOffset)) * $signed(buffB[103:96]);
  assign prod_13 = ($signed(buffA[111:104]) + $signed(InputOffset)) * $signed(buffB[111:104]);
  assign prod_14 = ($signed(buffA[119:112]) + $signed(InputOffset)) * $signed(buffB[119:112]);
  assign prod_15 = ($signed(buffA[127:120]) + $signed(InputOffset)) * $signed(buffB[127:120]);

  wire signed [127:0] sum_prods;
  assign sum_prods = prod_0 + prod_1 + prod_2 + prod_3 + prod_4 + prod_5 + prod_6 + prod_7 + prod_8 + prod_9 + prod_10 + prod_11 + prod_12 + prod_13 + prod_14 + prod_15;

  // Only not ready for a command when we have a response.
  assign cmd_ready = ~rsp_valid;

  always @(posedge clk) begin
    if (reset) begin
      rsp_payload_outputs_0 <= 32'b0;
      rsp_valid <= 1'b0;
      InputOffset <= 0;
    end else if (rsp_valid) begin
      // Waiting to hand off response to CPU.
      rsp_valid <= ~rsp_ready;
    end else if (cmd_valid) begin
      rsp_valid <= 1'b1;
      // Accumulate step:
      case (cmd_payload_function_id[9:3])
        2'b000_0000: begin
          InputOffset <= InputOffset;
          rsp_payload_outputs_0 <= rsp_payload_outputs_0 + sum_prods;
        end
        2'b000_0001: begin
          InputOffset <= cmd_payload_inputs_0[15:0];
          rsp_payload_outputs_0 <= 0'b0;
          
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

        default: begin
          InputOffset <= InputOffset;
          rsp_payload_outputs_0 <= 0'b0;
        end
      endcase
    end
  end
endmodule
/*
module SaturatingRoundingDoublingHighMul (
  input signed [31:0] a,
  input signed [31:0] b,
  output reg signed [31:0] result
);

reg overflow;
reg [63:0] a_64, b_64, ab_64;
reg [31:0] ab_x2_high32;
reg [31:0] nudge;

// Overflow Check
    always @* begin
        overflow = (a == b) && (a == 32'b1000_0000_0000_0000_0000_0000_0000_0000);
    end

    // Type Conversion
    always @* begin
        a_64 = $signed(a);
        b_64 = $signed(b);
    end

    // Multiplication
    always @* begin
        ab_64 = a_64 * b_64;
    end

    // Rounding Adjustment
    always @* begin
        nudge = (ab_64 >= 0) ? 32'b01_0000_0000_0000_0000_0000_0000_0000 : 32'b10_1111_1111_1111_1111_1111_1111_1111;
    end

    // Rounding and Shrinking
    always @* begin
        ab_x2_high32 = (ab_64 + nudge) >>> 31;
    end

    // Overflow Handling
    always @* begin
        result = overflow ? 32'b0111_1111_1111_1111_1111_1111_1111_1111 : ab_x2_high32;
    end
endmodule

module RoundingDivideByPOT(
  input signed [31:0] result_prev,
  input signed [31:0] right_shift,
  output signed [31:0] result
);


endmodule
*/

/*
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
  reg [15:0] InputOffset;
  reg [63:0] buffer_A, buffer_B;

  // SIMD multiply step:
  wire signed [16:0] prod_0, prod_1, prod_2, prod_3, prod_4, prod_5, prod_6, prod_7;

  assign prod_0 = ($signed(buffer_A[7 : 0]) + $signed(InputOffset)) * $signed(buffer_B[7 : 0]);

  assign prod_1 = ($signed(buffer_A[15:8]) + $signed(InputOffset)) * $signed(buffer_B[15:8]);

  assign prod_2 = ($signed(buffer_A[23:16]) + $signed(InputOffset)) * $signed(buffer_B[23:16]);

  assign prod_3 = ($signed(buffer_A[31:24]) + $signed(InputOffset)) * $signed(buffer_B[31:24]);

  assign prod_4 = ($signed(buffer_A[39:32]) + $signed(InputOffset)) * $signed(buffer_B[39:32]);

  assign prod_5 = ($signed(buffer_A[47:40]) + $signed(InputOffset)) * $signed(buffer_B[47:40]);

  assign prod_6 = ($signed(buffer_A[55:48]) + $signed(InputOffset)) * $signed(buffer_B[55:48]);

  assign prod_7 = ($signed(buffer_A[63:56]) + $signed(InputOffset)) * $signed(buffer_B[63:56]);

  wire signed [31:0] sum_prods;
  assign sum_prods = prod_0 + prod_1 + prod_2 + prod_3 + prod_4 + prod_5 + prod_6 + prod_7;

  // Only not ready for a command when we have a response.
  assign cmd_ready = ~rsp_valid;

  always @(posedge clk) begin
    if (reset) begin
      rsp_payload_outputs_0 <= 32'b0;
      rsp_valid <= 1'b0;
      InputOffset <= 0;
    end else if (rsp_valid) begin
      // Waiting to hand off response to CPU.
      rsp_valid <= ~rsp_ready;
    end else if (cmd_valid) begin
      rsp_valid <= 1'b1;
      // Accumulate step:
      case (cmd_payload_function_id[9:3])
        2'b000_0000: begin
          InputOffset <= InputOffset;
          rsp_payload_outputs_0 <= rsp_payload_outputs_0 + sum_prods;
        end
        2'b000_0001: begin
          InputOffset <= cmd_payload_inputs_0[15:0];
          rsp_payload_outputs_0 <= 0'b0;
        end

        // load first part
        7'd2: begin
          buffer_A[31:0] <= cmd_payload_inputs_0;
          buffer_B[31:0] <= cmd_payload_inputs_1;
        end

        7'd3: begin
          buffer_A[63:32] <= cmd_payload_inputs_0;
          buffer_B[63:32] <= cmd_payload_inputs_1;
        end

        default: begin
          InputOffset <= InputOffset;
          rsp_payload_outputs_0 <= 0'b0;
        end
      endcase
    end
  end
endmodule
*/
