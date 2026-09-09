module pe (
    input wire clk, //clock 
    input wire reset, //reset the status of the PE (use active high reset (reset when equals to 1))

    input wire signed [7:0] A_in,
    input wire signed [7:0] B_in, //wire = signal coming elsewhere

    input wire A_valid_in, //vaild = 1 AND B =1. proceed. helps with timing
    input wire B_valid_in,

    output wire signed [7:0] A_out,
    output wire signed [7:0] B_out, //I/O for systolic

    output wire A_valid_out,
    output wire B_valid_out,

    output wire signed [31:0] acc_out
);

reg signed [7:0] A_reg; //store states in the PE declared
reg signed [7:0] B_reg;

reg A_valid_reg;
reg B_valid_reg;

reg signed [31:0] acc;

wire signed [15:0] product; //16 bits since 8x8

assign product = A_in * B_in;

assign A_out = A_reg; //connects A_reg value to A_out
assign B_out = B_reg;

assign A_valid_out = A_valid_reg;
assign B_valid_out = B_valid_reg;

assign acc_out = acc;

always @(posedge clk) begin
    if (reset) begin
        A_reg <= 8'sd0;
        B_reg <= 8'sd0;

        A_valid_reg <= 1'b0;
        B_valid_reg <= 1'b0;

        acc <= 32'sd0; //reset all to 0
    end
    else begin
        A_reg <= A_in; //capture input
        B_reg <= B_in;

        A_valid_reg <= A_valid_in; //capture valid
        B_valid_reg <= B_valid_in;

        if (A_valid_in && B_valid_in) begin
            acc <= acc + product; //actual mac logic
        end
    end
end

endmodule