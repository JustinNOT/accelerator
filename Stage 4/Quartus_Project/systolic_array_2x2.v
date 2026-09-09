module systolic_array_2x2 (
    input wire clk,
    input wire reset,

    // A enters from the left
    input wire signed [7:0] A0_in,
    input wire signed [7:0] A1_in,

    // B enters from the top
    input wire signed [7:0] B0_in,
    input wire signed [7:0] B1_in,

    // Valid signals
    input wire A0_valid_in,
    input wire A1_valid_in,
    input wire B0_valid_in,
    input wire B1_valid_in,

    // One accumulator per PE
    output wire signed [31:0] acc00,
    output wire signed [31:0] acc01,
    output wire signed [31:0] acc10,
    output wire signed [31:0] acc11
);


// ============================================================
// INTERNAL A CONNECTIONS
// A travels from LEFT -> RIGHT
// ============================================================

// PE00 -> PE01
wire signed [7:0] A_00_to_01;
wire A_valid_00_to_01;

// PE10 -> PE11
wire signed [7:0] A_10_to_11;
wire A_valid_10_to_11;


// ============================================================
// INTERNAL B CONNECTIONS
// B travels from TOP -> BOTTOM
// ============================================================

// PE00 -> PE10
wire signed [7:0] B_00_to_10;
wire B_valid_00_to_10;

// PE01 -> PE11
wire signed [7:0] B_01_to_11;
wire B_valid_01_to_11;


// ============================================================
// UNUSED OUTPUTS
// These are the A/B values leaving the outside edges
// of the 2x2 array.
// ============================================================

// Right edge A outputs
wire signed [7:0] A_01_unused;
wire signed [7:0] A_11_unused;

wire A_valid_01_unused;
wire A_valid_11_unused;

// Bottom edge B outputs
wire signed [7:0] B_10_unused;
wire signed [7:0] B_11_unused;

wire B_valid_10_unused;
wire B_valid_11_unused;


// ============================================================
// PE00 - TOP LEFT
// ============================================================

pe PE00 (
    .clk(clk),
    .reset(reset),

    .A_in(A0_in),
    .B_in(B0_in),

    .A_valid_in(A0_valid_in),
    .B_valid_in(B0_valid_in),

    .A_out(A_00_to_01),
    .B_out(B_00_to_10),

    .A_valid_out(A_valid_00_to_01),
    .B_valid_out(B_valid_00_to_10),

    .acc_out(acc00)
);


// ============================================================
// PE01 - TOP RIGHT
// A comes from PE00
// B comes directly from B1_in
// ============================================================

pe PE01 (
    .clk(clk),
    .reset(reset),

    .A_in(A_00_to_01),
    .B_in(B1_in),

    .A_valid_in(A_valid_00_to_01),
    .B_valid_in(B1_valid_in),

    .A_out(A_01_unused),
    .B_out(B_01_to_11),

    .A_valid_out(A_valid_01_unused),
    .B_valid_out(B_valid_01_to_11),

    .acc_out(acc01)
);


// ============================================================
// PE10 - BOTTOM LEFT
// A comes directly from A1_in
// B comes down from PE00
// ============================================================

pe PE10 (
    .clk(clk),
    .reset(reset),

    .A_in(A1_in),
    .B_in(B_00_to_10),

    .A_valid_in(A1_valid_in),
    .B_valid_in(B_valid_00_to_10),

    .A_out(A_10_to_11),
    .B_out(B_10_unused),

    .A_valid_out(A_valid_10_to_11),
    .B_valid_out(B_valid_10_unused),

    .acc_out(acc10)
);


// ============================================================
// PE11 - BOTTOM RIGHT
// A comes from PE10
// B comes from PE01
// ============================================================

pe PE11 (
    .clk(clk),
    .reset(reset),

    .A_in(A_10_to_11),
    .B_in(B_01_to_11),

    .A_valid_in(A_valid_10_to_11),
    .B_valid_in(B_valid_01_to_11),

    .A_out(A_11_unused),
    .B_out(B_11_unused),

    .A_valid_out(A_valid_11_unused),
    .B_valid_out(B_valid_11_unused),

    .acc_out(acc11)
);

endmodule