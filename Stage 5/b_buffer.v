module b_buffer #(
    parameter COLS       = 8,
    parameter K          = 64,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 6
)(
    input wire clk,

    // -------------------------
    // WRITE INTERFACE
    // -------------------------

    input wire wr_en,

    // k = 0 to 63
    input wire [ADDR_WIDTH-1:0] wr_addr,

    // 8 INT8 values packed into one 64-bit word
    input wire [COLS*DATA_WIDTH-1:0] wr_data,


    // -------------------------
    // READ INTERFACE
    // -------------------------

    input wire rd_en,

    // k = 0 to 63
    input wire [ADDR_WIDTH-1:0] rd_addr,

    // Returns 8 INT8 values at once
    output reg [COLS*DATA_WIDTH-1:0] rd_data
);


// ============================================================
// MEMORY
//
// 64 entries
// each entry = 64 bits
//
// mem[k] contains:
//
// B[k][0]
// B[k][1]
// ...
// B[k][7]
//
// Total:
// 64 * 64 = 4096 bits = 512 bytes
// ============================================================

reg [COLS*DATA_WIDTH-1:0] mem [0:K-1];


// ============================================================
// SYNCHRONOUS READ / WRITE
// ============================================================

always @(posedge clk) begin

    // Write one 64-bit word
    if (wr_en) begin
        mem[wr_addr] <= wr_data;
    end

    // Read one 64-bit word
    if (rd_en) begin
        rd_data <= mem[rd_addr];
    end

end


endmodule