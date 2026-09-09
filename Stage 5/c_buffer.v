module c_buffer #(
    parameter ROWS       = 8,
    parameter COLS       = 8,
    parameter ACC_WIDTH  = 32,
    parameter ADDR_WIDTH = 6
)(
    input wire clk,

    // Write interface
    input wire wr_en,
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire signed [ACC_WIDTH-1:0] wr_data,

    // Read interface
    input wire rd_en,
    input wire [ADDR_WIDTH-1:0] rd_addr,
    output reg signed [ACC_WIDTH-1:0] rd_data
);


// 8 x 8 = 64 output values
// Each output is INT32
//
// mem[0]  = C[0][0]
// mem[1]  = C[0][1]
// ...
// mem[7]  = C[0][7]
//
// mem[8]  = C[1][0]
// ...
//
// mem[63] = C[7][7]

reg signed [ACC_WIDTH-1:0] mem [0:ROWS*COLS-1];


always @(posedge clk) begin

    // Store one finished PE result
    if (wr_en) begin
        mem[wr_addr] <= wr_data;
    end

    // Read one stored C result
    if (rd_en) begin
        rd_data <= mem[rd_addr];
    end

end


endmodule