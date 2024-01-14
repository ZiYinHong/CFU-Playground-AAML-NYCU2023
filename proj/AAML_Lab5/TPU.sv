
module TPU(
    clk,
    reset,

    in_valid,
    K,
    M,
    N,
    busy,

    A_wr_en,
    A_index,
    A_data_out,

    B_wr_en,
    B_index,
    B_data_out,

    C_wr_en,
    C_index,
    C_data_in
);



input clk;
input reset;
input            in_valid;
input [8:0]      K;
input [7:0]      M;
input [7:0]      N;
output      busy;

output           A_wr_en;
output signed [9:0]    A_index;
input  [31:0]    A_data_out;

output           B_wr_en;
output signed [9:0]    B_index;
input  [31:0]    B_data_out;

output           C_wr_en;
output signed [2:0]    C_index;
output [127:0]   C_data_in;



//* Implement your design here

parameter [1:0] ST_INIT     = 2'b00,
                ST_READ_AND_MULADD    = 2'b01,
                ST_OUTPUT   = 2'b10,
                ST_DONE     = 2'b11;

reg [1:0] curr_state, next_state;
// reg [31 : 0] a [0:300+3-1]; //257 = 255 +3 -1, cause max K is 255
// reg [31 : 0] b [0:300+3-1]; //257 = 255 +3 -1, cause max K is 255

reg cal, out;
reg [8:0] cal_counter;
wire [8:0] cnt_cal;
reg  signed [2:0] cnt_out_index;
reg signed [9:0] index_a, index_b;
reg [2:0] cnt_out;

reg  [127:0] dataout_o;
reg  wr_en_out;
reg start, busy_temp;

assign busy = busy_temp;
assign A_wr_en = 0;
assign B_wr_en = 0;
assign C_wr_en = wr_en_out;

assign A_index = index_a;
assign B_index = index_b;
assign C_index = cnt_out_index;
assign C_data_in = dataout_o;

reg [8:0] k;
reg [7:0] m;
reg [7:0] n;
assign cnt_cal = k + 9'h7;

wire signed [15:0] h11, h12, h13, h21, h22, h23, h31, h32, h33, h41, h42, h43;
wire signed [15:0] v11, v12, v13, v14, v21, v22, v23, v24, v31, v32, v33, v34;
wire signed [31:0] o11, o12, o13, o14, o21, o22, o23, o24, o31, o32, o33, o34, o41, o42, o43, o44;
reg signed [15:0] a1, a2, a3, a4;
reg signed [15:0] b1, b2, b3, b4;
reg signed [31:0]  res11, res12, res13, res14, res21, res22, res23, res24,
           res31, res32, res33, res34, res41, res42, res43, res44;

localparam InputOffset = $signed(9'd128);

PE pe11(.clk(clk), .rst(reset), .top_in(b1),  .bot_out(v11), .left_in(a1),  .right_out(h11), .mult(o11));
PE pe12(.clk(clk), .rst(reset), .top_in(b2),  .bot_out(v12), .left_in(h11), .right_out(h12), .mult(o12));
PE pe13(.clk(clk), .rst(reset), .top_in(b3),  .bot_out(v13), .left_in(h12), .right_out(h13), .mult(o13));
PE pe14(.clk(clk), .rst(reset), .top_in(b4),  .bot_out(v14), .left_in(h13), .right_out(),    .mult(o14));
PE pe21(.clk(clk), .rst(reset), .top_in(v11), .bot_out(v21), .left_in(a2),  .right_out(h21), .mult(o21));
PE pe22(.clk(clk), .rst(reset), .top_in(v12), .bot_out(v22), .left_in(h21), .right_out(h22), .mult(o22));
PE pe23(.clk(clk), .rst(reset), .top_in(v13), .bot_out(v23), .left_in(h22), .right_out(h23), .mult(o23));
PE pe24(.clk(clk), .rst(reset), .top_in(v14), .bot_out(v24), .left_in(h23), .right_out(),    .mult(o24));
PE pe31(.clk(clk), .rst(reset), .top_in(v21), .bot_out(v31), .left_in(a3),  .right_out(h31), .mult(o31));
PE pe32(.clk(clk), .rst(reset), .top_in(v22), .bot_out(v32), .left_in(h31), .right_out(h32), .mult(o32));
PE pe33(.clk(clk), .rst(reset), .top_in(v23), .bot_out(v33), .left_in(h32), .right_out(h33), .mult(o33));
PE pe34(.clk(clk), .rst(reset), .top_in(v24), .bot_out(v34), .left_in(h33), .right_out(),    .mult(o34));
PE pe41(.clk(clk), .rst(reset), .top_in(v31), .bot_out(),    .left_in(a4),  .right_out(h41), .mult(o41));
PE pe42(.clk(clk), .rst(reset), .top_in(v32), .bot_out(),    .left_in(h41), .right_out(h42), .mult(o42));
PE pe43(.clk(clk), .rst(reset), .top_in(v33), .bot_out(),    .left_in(h42), .right_out(h43), .mult(o43));
PE pe44(.clk(clk), .rst(reset), .top_in(v34), .bot_out(),    .left_in(h43), .right_out(),    .mult(o44));



// initial begin
//     cal = 0;
//     out = 0;
//     cal_counter = 0;
//     cnt_out_index = -1;
//     cnt_out = 0;
//     dataout_o = 128'h0;
//     index_a = 0;
//     index_b = 0;
//     wr_en_out = 0;
//     start = 0;
//     busy_temp = 0;
//     k = 0;
//     m = 0;
//     n = 0;
//     curr_state = ST_INIT;
//     res11 = 32'h0; res12 = 32'h0; res13 = 32'h0; res14 = 32'h0;
//     res21 = 32'h0; res22 = 32'h0; res23 = 32'h0; res24 = 32'h0;
//     res31 = 32'h0; res32 = 32'h0; res33 = 32'h0; res34 = 32'h0;
//     res41 = 32'h0; res42 = 32'h0; res43 = 32'h0; res44 = 32'h0;
//     a1  = 16'b0; a2 = 16'b0; a3 = 16'b0; a4 = 16'b0;
//     b1  = 16'b0; b2 = 16'b0; b3 = 16'b0; b4 = 16'b0;  
// end


always @(*) begin
    case (curr_state)
        ST_INIT : begin
            cal = 1'b0; out = 1'b0; wr_en_out = 1'b0; busy_temp = 1'b0;
        end
        ST_READ_AND_MULADD : begin
            cal = (index_a >= 1) ? 1'b1 : 1'b0; busy_temp = 1'b1;
            out = 1'b0; wr_en_out = 1'b0;
        end
        ST_OUTPUT : begin
            cal = 1'b0; out = 1'b1; 
            wr_en_out = (cnt_out > 0 && cnt_out <= 4) ? 1'b1 : 1'b0; busy_temp = 1'b1;
        end
        ST_DONE : begin
            cal = 1'b0; out = 1'b0; wr_en_out = 1'b0; busy_temp = 1'b0;
        end
        default : begin
            cal = 1'b0; out = 1'b0; wr_en_out = 1'b0; busy_temp = 1'b0;
        end
    endcase
end


always @(negedge clk) begin
    if (reset)
        curr_state <= ST_INIT;
    else
        curr_state <= next_state;
end


always @(*) begin
    case (curr_state)
        ST_INIT : begin
            next_state = (start) ? ST_READ_AND_MULADD : ST_INIT;
        end
        ST_READ_AND_MULADD : begin
            next_state = (cal_counter < cnt_cal) ? ST_READ_AND_MULADD : ST_OUTPUT;
        end
        ST_OUTPUT : begin
            next_state = (cnt_out == 4) ? ST_DONE : ST_OUTPUT;
        end
        ST_DONE : begin
            next_state = ST_INIT;
        end
        default : begin
            next_state = ST_INIT;
        end
    endcase
end

// OUTPUT
always @(negedge clk) begin
    if (!reset) begin
        if (out) begin
            case (cnt_out)
                3'h0 : dataout_o <= {res11, res12, res13, res14}; 
                3'h1 : dataout_o <= {res21, res22, res23, res24}; 
                3'h2 : dataout_o <= {res31, res32, res33, res34}; 
                3'h3 : dataout_o <= {res41, res42, res43, res44}; 
                default:;
            endcase   
            // $display("in ST_OUTPUT, cnt_out_index = %8h, dataout_o = %32h", cnt_out_index, dataout_o);
        end
        else if (cal) begin
            res11 <= res11 + o11; res12 <= res12 + o12; res13 <= res13 + o13; res14 <= res14 + o14;
            res21 <= res21 + o21; res22 <= res22 + o22; res23 <= res23 + o23; res24 <= res24 + o24;
            res31 <= res31 + o31; res32 <= res32 + o32; res33 <= res33 + o33; res34 <= res34 + o34;
            res41 <= res41 + o41; res42 <= res42 + o42; res43 <= res43 + o43; res44 <= res44 + o44;
        end
        else begin
            res11 <= 32'h0; res12 <= 32'h0; res13 <= 32'h0; res14 <= 32'h0;
            res21 <= 32'h0; res22 <= 32'h0; res23 <= 32'h0; res24 <= 32'h0;
            res31 <= 32'h0; res32 <= 32'h0; res33 <= 32'h0; res34 <= 32'h0;
            res41 <= 32'h0; res42 <= 32'h0; res43 <= 32'h0; res44 <= 32'h0;
            dataout_o <= 128'h0;
        end
    end
end


// feed to PE
always @(negedge clk) begin
    if (cal  && (cal_counter < k + 3)) begin 
        a1  <= $signed(A_data_out[31:24]);
        a2  <= $signed(A_data_out[23:16]);
        a3  <= $signed(A_data_out[15: 8]);
        a4  <= $signed(A_data_out[ 7: 0]);
        b1  <= $signed(B_data_out[31:24]) + InputOffset;
        b2  <= $signed(B_data_out[23:16]) + InputOffset;
        b3  <= $signed(B_data_out[15: 8]) + InputOffset;
        b4  <= $signed(B_data_out[ 7: 0]) + InputOffset;
    end
    else begin
        a1  <= 16'b0; a2 <= 16'b0; a3 <= 16'b0; a4 <= 16'b0;
        b1  <= 16'b0; b2 <= 16'b0; b3 <= 16'b0; b4 <= 16'b0;  
    end
end


always @(negedge clk) begin
    if(K > 0) begin
        k = K;
        m = M;
        n = N;
    end
end

always @(posedge clk) begin
    if(reset) begin
        start <= 1'b0; 
    end
    else if(in_valid) begin
        start <= 1'b1; 
    end
    else begin
        start <= 1'b0; 
    end
end

// COUNTER, INDEX
always @(negedge clk) begin
    if (!reset) begin
        case (curr_state)
            ST_INIT: begin
                cal_counter <= 0;
                cnt_out_index <= -1;
                cnt_out <= 0;

                index_a <= 0;
                index_b <= 0;
            end
            ST_READ_AND_MULADD: begin     
                if(index_a >= 1) begin
                    cal_counter <=  cal_counter+1;
                end   

                index_a <= index_a + 1;
                index_b <= index_b + 1;
            end
            ST_OUTPUT: begin
                cnt_out_index <= cnt_out_index + 1;
                cnt_out       <= cnt_out + 1;
            end
        endcase
    end
end

endmodule

// ********************************************
// **************PE MODULE*********************
// ********************************************
module PE(clk, rst, top_in, left_in, bot_out, right_out, mult);
input clk, rst;
input signed [15:0] left_in;
input signed [15:0] top_in;
output reg signed [15:0] right_out;
output reg signed [15:0] bot_out;
output reg signed [31:0] mult;


always @(negedge clk) begin
    if (rst) begin
        bot_out     <= 16'h0; 
        right_out   <= 16'h0; 
        mult        <= 32'h0; 
    end
    else begin
        bot_out     <= top_in;
        right_out   <= left_in;
        mult        <= top_in * left_in;
    end
end

endmodule