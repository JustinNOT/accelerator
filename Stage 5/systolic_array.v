module systolic_array #(
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input wire clk,
    input wire reset,

    // One INT8 A input for each row
    input wire [ARRAY_SIZE*DATA_WIDTH-1:0] A_in_bus,

    // One INT8 B input for each column
    input wire [ARRAY_SIZE*DATA_WIDTH-1:0] B_in_bus,

    // One valid bit for each row / column
    input wire [ARRAY_SIZE-1:0] A_valid_in,
    input wire [ARRAY_SIZE-1:0] B_valid_in,

    // One INT32 accumulator for every PE
    output wire [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] acc_out_bus
);


// ============================================================
// INTERNAL A CONNECTIONS
//
// Each row needs ARRAY_SIZE + 1 positions:
//
// input -> PE -> PE -> ... -> output
//
// For 8x8:
// 8 rows * 9 positions
// ============================================================

wire [ARRAY_SIZE*(ARRAY_SIZE+1)*DATA_WIDTH-1:0] A_links;
wire [ARRAY_SIZE*(ARRAY_SIZE+1)-1:0] A_valid_links;


// ============================================================
// INTERNAL B CONNECTIONS
//
// Each column needs ARRAY_SIZE + 1 positions:
//
// input
//   |
//   PE
//   |
//   PE
//   |
// output
// ============================================================

wire [(ARRAY_SIZE+1)*ARRAY_SIZE*DATA_WIDTH-1:0] B_links;
wire [(ARRAY_SIZE+1)*ARRAY_SIZE-1:0] B_valid_links;


genvar r;
genvar c;


// ============================================================
// CONNECT EXTERNAL A INPUTS TO LEFT EDGE
// ============================================================

generate
    for (r = 0; r < ARRAY_SIZE; r = r + 1) begin : A_INPUTS

        assign A_links[
            (r*(ARRAY_SIZE+1))*DATA_WIDTH
            +: DATA_WIDTH
        ] =
            A_in_bus[r*DATA_WIDTH +: DATA_WIDTH];

        assign A_valid_links[
            r*(ARRAY_SIZE+1)
        ] =
            A_valid_in[r];

    end
endgenerate


// ============================================================
// CONNECT EXTERNAL B INPUTS TO TOP EDGE
// ============================================================

generate
    for (c = 0; c < ARRAY_SIZE; c = c + 1) begin : B_INPUTS

        assign B_links[
            c*DATA_WIDTH
            +: DATA_WIDTH
        ] =
            B_in_bus[c*DATA_WIDTH +: DATA_WIDTH];

        assign B_valid_links[c] =
            B_valid_in[c];

    end
endgenerate


// ============================================================
// CREATE THE PE GRID
// ============================================================

generate

    for (r = 0; r < ARRAY_SIZE; r = r + 1) begin : ROW

        for (c = 0; c < ARRAY_SIZE; c = c + 1) begin : COL

            pe PE (

                .clk(clk),
                .reset(reset),

                // A comes from the left
                .A_in(
                    A_links[
                        (r*(ARRAY_SIZE+1) + c)*DATA_WIDTH
                        +: DATA_WIDTH
                    ]
                ),

                // B comes from above
                .B_in(
                    B_links[
                        (r*ARRAY_SIZE + c)*DATA_WIDTH
                        +: DATA_WIDTH
                    ]
                ),

                .A_valid_in(
                    A_valid_links[
                        r*(ARRAY_SIZE+1) + c
                    ]
                ),

                .B_valid_in(
                    B_valid_links[
                        r*ARRAY_SIZE + c
                    ]
                ),

                // A moves right
                .A_out(
                    A_links[
                        (r*(ARRAY_SIZE+1) + c + 1)*DATA_WIDTH
                        +: DATA_WIDTH
                    ]
                ),

                // B moves down
                .B_out(
                    B_links[
                        ((r+1)*ARRAY_SIZE + c)*DATA_WIDTH
                        +: DATA_WIDTH
                    ]
                ),

                .A_valid_out(
                    A_valid_links[
                        r*(ARRAY_SIZE+1) + c + 1
                    ]
                ),

                .B_valid_out(
                    B_valid_links[
                        (r+1)*ARRAY_SIZE + c
                    ]
                ),

                // Each PE gets one 32-bit section
                .acc_out(
                    acc_out_bus[
                        (r*ARRAY_SIZE + c)*ACC_WIDTH
                        +: ACC_WIDTH
                    ]
                )

            );

        end

    end

endgenerate


endmodule