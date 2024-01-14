//============================================================================//
// AIC2021 Project1 - TPU Design                                              //
// file: global_buffer.v                                                      //
// description: global buffer read write behavior module                      //
// authors: kaikai (deekai9139@gmail.com)                                     //
//          suhan  (jjs93126@gmail.com)                                       //
//============================================================================//
module global_buffer #(parameter ADDR_BITS=16, parameter DATA_IN_BITS=8, parameter DATA_OUT_BITS=32, parameter DEPTH=350, parameter FLAG)(clk, reset, wr_en, cnt_4, in_index, out_index, data_in, data_out);

  input clk;
  input reset;
  input wr_en; // Write enable: 1->write 0->read
  input signed [2:0] cnt_4;
  input signed [ADDR_BITS-1:0] in_index;
  input signed [ADDR_BITS-1:0] out_index;
  input      [DATA_IN_BITS-1:0] data_in;
  output  reg  [DATA_OUT_BITS-1:0] data_out;

  integer i;
//----------------------------------------------------------------------------//
// Global buffer (Don't change the name)                                      //
//----------------------------------------------------------------------------//
  // reg [`GBUFF_ADDR_SIZE-1:0] gbuff [`WORD_SIZE-1:0];
  reg [DATA_OUT_BITS-1:0] gbuff [DEPTH-1:0];



initial begin
    for (i = 0; i < DEPTH; i = i + 1) begin
        gbuff[i] = 0;
    end
end
//----------------------------------------------------------------------------//
// Global buffer read write behavior                                          //
//----------------------------------------------------------------------------//
  always @ (negedge clk) begin
    if(reset)begin
      for(i=0; i<(DEPTH); i=i+1)
        gbuff[i] = 0;
    end
    else begin
      case(FLAG) 
          0: begin
            //gbuff A
            if(wr_en) begin
              case (cnt_4) 
                3'h0: gbuff[in_index][31:24]  <= data_in;
                3'h1: gbuff[in_index+1][23:16]  <= data_in;//gbuff_C.gbuff[C_out_index][95:64];
                3'h2: gbuff[in_index+2][15: 8]  <= data_in;
                3'h3: gbuff[in_index+3][ 7: 0]  <= data_in;
                default:;
              endcase        
            end
            else begin
              data_out <= gbuff[out_index];
            end
          end
          1: begin
            //gbuff B
            if(wr_en) begin
              case (cnt_4) 
                3'h0: gbuff[in_index][31:24]  <= data_in;
                3'h1: gbuff[in_index+1][23:16]  <= data_in;//gbuff_C.gbuff[C_out_index][95:64];
                3'h2: gbuff[in_index+2][15: 8]  <= data_in;
                3'h3: gbuff[in_index+3][ 7: 0]  <= data_in;
                default:;
              endcase     
            end
            else begin
              data_out <= gbuff[out_index];
            end
          end
          2: begin
            //gbuff C
            if(wr_en) begin
              gbuff[in_index] <= data_in;
            end
            else begin
              data_out <= gbuff[out_index];
            end
          end
      endcase

      
    end
  end

endmodule
