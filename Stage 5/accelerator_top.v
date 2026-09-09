module accelerator_top #(
    parameter ARRAY_SIZE   = 8,
    parameter K            = 64,
    parameter DATA_WIDTH   = 8,
    parameter ACC_WIDTH    = 32,
    parameter ADDR_WIDTH   = 6,
    parameter C_ADDR_WIDTH = 6
)(
    input wire clk,
    input wire reset,

    // ========================================================
    // ACCELERATOR CONTROL
    // ========================================================

    input wire start,

    output wire busy,
    output wire done,


    // ========================================================
    // A BUFFER HOST WRITE INTERFACE
    //
    // Used to load matrix A before computation.
    // ========================================================

    input wire a_wr_en,
    input wire [ADDR_WIDTH-1:0] a_wr_addr,
    input wire [ARRAY_SIZE*DATA_WIDTH-1:0] a_wr_data,


    // ========================================================
    // B BUFFER HOST WRITE INTERFACE
    //
    // Used to load matrix B before computation.
    // ========================================================

    input wire b_wr_en,
    input wire [ADDR_WIDTH-1:0] b_wr_addr,
    input wire [ARRAY_SIZE*DATA_WIDTH-1:0] b_wr_data,


    // ========================================================
    // C BUFFER HOST READ INTERFACE
    //
    // Used to read results after done = 1.
    // ========================================================

    input wire c_rd_en,
    input wire [C_ADDR_WIDTH-1:0] c_rd_addr,
    output wire signed [ACC_WIDTH-1:0] c_rd_data
);


// ============================================================
// A BUFFER <-> CONTROLLER SIGNALS
// ============================================================

wire a_rd_en;
wire [ADDR_WIDTH-1:0] a_rd_addr;

wire [ARRAY_SIZE*DATA_WIDTH-1:0] a_rd_data;


// ============================================================
// B BUFFER <-> CONTROLLER SIGNALS
// ============================================================

wire b_rd_en;
wire [ADDR_WIDTH-1:0] b_rd_addr;

wire [ARRAY_SIZE*DATA_WIDTH-1:0] b_rd_data;


// ============================================================
// CONTROLLER -> SYSTOLIC ARRAY SIGNALS
// ============================================================

wire [ARRAY_SIZE*DATA_WIDTH-1:0] A_in_bus;
wire [ARRAY_SIZE*DATA_WIDTH-1:0] B_in_bus;

wire [ARRAY_SIZE-1:0] A_valid_in;
wire [ARRAY_SIZE-1:0] B_valid_in;

wire array_reset;


// ============================================================
// SYSTOLIC ARRAY OUTPUT
//
// 64 PEs * 32-bit accumulator = 2048 bits
//
// This stays INTERNAL.
// It is NOT exposed as FPGA pins.
// ============================================================

wire [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] acc_out_bus;


// ============================================================
// CONTROLLER -> C BUFFER SIGNALS
// ============================================================

wire c_wr_en;
wire [C_ADDR_WIDTH-1:0] c_wr_addr;

wire signed [ACC_WIDTH-1:0] c_wr_data;


// ============================================================
// A BUFFER
// ============================================================

a_buffer #(
    .ROWS(ARRAY_SIZE),
    .K(K),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) A_BUFFER (

    .clk(clk),

    // Host writes A matrix
    .wr_en(a_wr_en),
    .wr_addr(a_wr_addr),
    .wr_data(a_wr_data),

    // Controller reads A matrix
    .rd_en(a_rd_en),
    .rd_addr(a_rd_addr),
    .rd_data(a_rd_data)

);


// ============================================================
// B BUFFER
// ============================================================

b_buffer #(
    .COLS(ARRAY_SIZE),
    .K(K),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) B_BUFFER (

    .clk(clk),

    // Host writes B matrix
    .wr_en(b_wr_en),
    .wr_addr(b_wr_addr),
    .wr_data(b_wr_data),

    // Controller reads B matrix
    .rd_en(b_rd_en),
    .rd_addr(b_rd_addr),
    .rd_data(b_rd_data)

);


// ============================================================
// CONTROLLER
// ============================================================

controller #(
    .ROWS(ARRAY_SIZE),
    .COLS(ARRAY_SIZE),
    .K(K),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .C_ADDR_WIDTH(C_ADDR_WIDTH)
) CONTROLLER (

    .clk(clk),
    .reset(reset),

    .start(start),


    // A buffer
    .a_rd_en(a_rd_en),
    .a_rd_addr(a_rd_addr),
    .a_rd_data(a_rd_data),


    // B buffer
    .b_rd_en(b_rd_en),
    .b_rd_addr(b_rd_addr),
    .b_rd_data(b_rd_data),


    // Systolic array
    .A_in_bus(A_in_bus),
    .B_in_bus(B_in_bus),

    .A_valid_in(A_valid_in),
    .B_valid_in(B_valid_in),

    .array_reset(array_reset),


    // C buffer
    .c_wr_en(c_wr_en),
    .c_wr_addr(c_wr_addr),


    // Status
    .busy(busy),
    .done(done)

);


// ============================================================
// SYSTOLIC ARRAY
//
// reset OR array_reset:
//
// reset       = reset whole accelerator
// array_reset = controller clearing PE accumulators before run
// ============================================================

systolic_array #(
    .ARRAY_SIZE(ARRAY_SIZE),
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH(ACC_WIDTH)
) ARRAY (

    .clk(clk),

    .reset(reset | array_reset),

    .A_in_bus(A_in_bus),
    .B_in_bus(B_in_bus),

    .A_valid_in(A_valid_in),
    .B_valid_in(B_valid_in),

    .acc_out_bus(acc_out_bus)

);


// ============================================================
// C RESULT SELECTION
//
// Controller gives us:
//
// c_wr_addr = 0, 1, 2, ... 63
//
// We use that number to select the corresponding 32-bit
// accumulator from the 2048-bit acc_out_bus.
//
// Example:
//
// c_wr_addr = 0
//      -> bits [31:0]
//      -> PE00
//
// c_wr_addr = 1
//      -> bits [63:32]
//      -> PE01
//
// c_wr_addr = 8
//      -> PE10
//
// c_wr_addr = 63
//      -> PE77
// ============================================================

assign c_wr_data =
    acc_out_bus[
        c_wr_addr * ACC_WIDTH
        +: ACC_WIDTH
    ];


// ============================================================
// C BUFFER
// ============================================================

c_buffer #(
    .ROWS(ARRAY_SIZE),
    .COLS(ARRAY_SIZE),
    .ACC_WIDTH(ACC_WIDTH),
    .ADDR_WIDTH(C_ADDR_WIDTH)
) C_BUFFER (

    .clk(clk),

    // Controller stores results
    .wr_en(c_wr_en),
    .wr_addr(c_wr_addr),
    .wr_data(c_wr_data),

    // Host/testbench reads results
    .rd_en(c_rd_en),
    .rd_addr(c_rd_addr),
    .rd_data(c_rd_data)

);


endmodule