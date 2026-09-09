module a_buffer #(
    parameter ROWS       = 8,
    parameter K          = 64,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 6
)(
    input wire clk,

    // -------------------------
    // WRITE INTERFACE
    // -------------------------

    // Write enable
    input wire wr_en,

    // Which k position to write: 0 to 63
    input wire [ADDR_WIDTH-1:0] wr_addr,

    // 8 INT8 values packed together
    // 8 rows * 8 bits = 64 bits
    input wire [ROWS*DATA_WIDTH-1:0] wr_data,


    // -------------------------
    // READ INTERFACE
    // -------------------------

    // Read enable
    input wire rd_en,

    // Which k position to read: 0 to 63
    input wire [ADDR_WIDTH-1:0] rd_addr,

    // Returns 8 INT8 values at once
    output reg [ROWS*DATA_WIDTH-1:0] rd_data
);


// ============================================================
// MEMORY
//
// 64 entries
// each entry = 64 bits
//
// Total:
//
// 64 * 64 = 4096 bits
//
// Each address stores all 8 rows for one value of k.
// ============================================================

reg [ROWS*DATA_WIDTH-1:0] mem [0:K-1];


// ============================================================
// SYNCHRONOUS READ / WRITE
// ============================================================

always @(posedge clk) begin

    // Write one 64-bit word into memory
    if (wr_en) begin
        mem[wr_addr] <= wr_data;
    end


    // Read one 64-bit word from memory
    if (rd_en) begin
        rd_data <= mem[rd_addr];
    end

end


endmodule