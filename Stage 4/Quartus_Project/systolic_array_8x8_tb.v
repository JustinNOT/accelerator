`timescale 1ns/1ps

module systolic_array_8x8_tb;


// ============================================================
// PARAMETERS
// ============================================================

parameter ARRAY_SIZE = 8;
parameter DATA_WIDTH = 8;
parameter ACC_WIDTH  = 32;
parameter K          = 64;


// ============================================================
// TESTBENCH INPUTS
// ============================================================

reg clk;
reg reset;

// 8 INT8 A inputs packed into one 64-bit bus
reg [ARRAY_SIZE*DATA_WIDTH-1:0] A_in_bus;

// 8 INT8 B inputs packed into one 64-bit bus
reg [ARRAY_SIZE*DATA_WIDTH-1:0] B_in_bus;

// One valid bit for each row and column
reg [ARRAY_SIZE-1:0] A_valid_in;
reg [ARRAY_SIZE-1:0] B_valid_in;


// ============================================================
// DUT OUTPUT
//
// 64 PEs × 32-bit accumulator = 2048 bits
// ============================================================

wire [ARRAY_SIZE*ARRAY_SIZE*ACC_WIDTH-1:0] acc_out_bus;


// ============================================================
// TESTBENCH VARIABLES
// ============================================================

integer t;
integer r;
integer c;
integer k_idx;

integer a_value;
integer b_value;

integer expected;
integer pass_count;
integer fail_count;

reg signed [31:0] actual;


// ============================================================
// INSTANTIATE THE PARAMETERIZED SYSTOLIC ARRAY
// ============================================================

systolic_array #(
    .ARRAY_SIZE(ARRAY_SIZE),
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH(ACC_WIDTH)
) dut (

    .clk(clk),
    .reset(reset),

    .A_in_bus(A_in_bus),
    .B_in_bus(B_in_bus),

    .A_valid_in(A_valid_in),
    .B_valid_in(B_valid_in),

    .acc_out_bus(acc_out_bus)

);


// ============================================================
// CLOCK
//
// 10 ns clock period
// ============================================================

always #5 clk = ~clk;


// ============================================================
// TEST SEQUENCE
// ============================================================

initial begin

    // --------------------------------------------------------
    // INITIAL VALUES
    // --------------------------------------------------------

    clk = 0;
    reset = 1;

    A_in_bus = 0;
    B_in_bus = 0;

    A_valid_in = 0;
    B_valid_in = 0;

    pass_count = 0;
    fail_count = 0;


    // Hold reset for two clock cycles
    repeat (2) @(posedge clk);

    @(negedge clk);
    reset = 0;


    // ========================================================
    // TEST 1: 8x8 DATA PROPAGATION
    // ========================================================

    $display("");
    $display("==================================================");
    $display("TEST 1: 8x8 DATA PROPAGATION");
    $display("==================================================");

    /*
        Inject:

        A row 0 = 11
        B col 0 = 33

        Only one cycle is marked valid.

        Expected:

        A = 11 moves:

        PE[0][0]
            ->
        PE[0][1]
            ->
        ...
            ->
        PE[0][7]


        B = 33 moves:

        PE[0][0]
            |
            v
        PE[1][0]
            |
            v
        ...
            |
            v
        PE[7][0]
    */


    // Put 11 into A row 0
    A_in_bus[0*DATA_WIDTH +: DATA_WIDTH] = 8'sd11;

    // Put 33 into B column 0
    B_in_bus[0*DATA_WIDTH +: DATA_WIDTH] = 8'sd33;

    // Mark only these streams as valid
    A_valid_in[0] = 1'b1;
    B_valid_in[0] = 1'b1;


    // First rising edge:
    // PE[0][0] captures the values
    @(posedge clk);
    #1;


    // --------------------------------------------------------
    // CHECK FIRST HOP
    // --------------------------------------------------------

    if ($signed(
        dut.A_links[
            1*DATA_WIDTH
            +: DATA_WIDTH
        ]
    ) == 8'sd11)

        $display("PASS: A=11 entered PE[0][0] and moved right");

    else begin

        $display("FAIL: A first-hop propagation");

        fail_count = fail_count + 1;

    end


    if ($signed(
        dut.B_links[
            ARRAY_SIZE*DATA_WIDTH
            +: DATA_WIDTH
        ]
    ) == 8'sd33)

        $display("PASS: B=33 entered PE[0][0] and moved down");

    else begin

        $display("FAIL: B first-hop propagation");

        fail_count = fail_count + 1;

    end


    // --------------------------------------------------------
    // REMOVE EXTERNAL INPUT
    //
    // We only wanted to inject one data item.
    // --------------------------------------------------------

    @(negedge clk);

    A_in_bus = 0;
    B_in_bus = 0;

    A_valid_in = 0;
    B_valid_in = 0;


    // The first PE already captured the data.
    //
    // It now takes another 7 clock cycles to move
    // through the remaining 7 PEs.
    repeat (ARRAY_SIZE-1) @(posedge clk);

    #1;


    // --------------------------------------------------------
    // CHECK RIGHT EDGE
    //
    // Row 0 has ARRAY_SIZE+1 A link positions:
    //
    // input -> PE0 -> PE1 ... -> PE7 -> output
    //
    // Final right-edge location = ARRAY_SIZE
    // --------------------------------------------------------

    if ($signed(
        dut.A_links[
            ARRAY_SIZE*DATA_WIDTH
            +: DATA_WIDTH
        ]
    ) == 8'sd11)

        $display("PASS: A=11 propagated across all 8 columns");

    else begin

        $display("FAIL: A did not reach right edge");

        fail_count = fail_count + 1;

    end


    // --------------------------------------------------------
    // CHECK BOTTOM EDGE
    //
    // Final B position for column 0 occurs after row 7.
    // --------------------------------------------------------

    if ($signed(
        dut.B_links[
            (ARRAY_SIZE*ARRAY_SIZE)*DATA_WIDTH
            +: DATA_WIDTH
        ]
    ) == 8'sd33)

        $display("PASS: B=33 propagated down all 8 rows");

    else begin

        $display("FAIL: B did not reach bottom edge");

        fail_count = fail_count + 1;

    end


    if (fail_count == 0)
        $display("***** TEST 1 PASSED *****");
    else
        $display("***** TEST 1 FAILED *****");



    // ========================================================
    // RESET BEFORE MATRIX MULTIPLICATION
    // ========================================================

    @(negedge clk);

    reset = 1;

    A_in_bus = 0;
    B_in_bus = 0;

    A_valid_in = 0;
    B_valid_in = 0;


    repeat (2) @(posedge clk);


    @(negedge clk);

    reset = 0;



    // ========================================================
    // TEST 2:
    //
    // FULL 8x64 × 64x8 MATRIX MULTIPLICATION
    // ========================================================

    $display("");
    $display("==================================================");
    $display("TEST 2: 8x64 x 64x8 MATRIX MULTIPLICATION");
    $display("==================================================");


    /*
        We create deterministic test matrices without storing
        1024 separate numbers in the testbench.


        A[r][k] = (r + 1) + (k mod 4)


        B[k][c] = (c + 1) + (k mod 4)

        Odd-numbered columns of B are made NEGATIVE.


        Example:

        A row 0 begins:

        k = 0  1  2  3  4 ...
            1  2  3  4  1 ...


        B column 0:

            1  2  3  4  1 ...


        B column 1:

           -2 -3 -4 -5 -2 ...


        This lets us test:

        - K = 64 accumulation
        - different values over time
        - positive multiplication
        - negative multiplication
        - all 64 PEs
        - skewed inputs
    */


    pass_count = 0;
    fail_count = 0;


    // ========================================================
    // STREAM THE MATRICES
    //
    // For each global systolic-array cycle t:
    //
    // A row r uses:
    //
    //      k = t - r
    //
    // because row r is delayed by r cycles.
    //
    //
    // B column c uses:
    //
    //      k = t - c
    //
    // because column c is delayed by c cycles.
    //
    //
    // Last external input:
    //
    // k = 63
    // row/column delay = 7
    //
    // therefore:
    //
    // t = 63 + 7 = 70
    // ========================================================

    for (t = 0;
         t <= K + ARRAY_SIZE - 2;
         t = t + 1) begin


        @(negedge clk);


        // Default everything to invalid
        A_in_bus = 0;
        B_in_bus = 0;

        A_valid_in = 0;
        B_valid_in = 0;



        // ====================================================
        // GENERATE A INPUTS
        // ====================================================

        for (r = 0; r < ARRAY_SIZE; r = r + 1) begin

            // Account for row skew
            k_idx = t - r;


            if ((k_idx >= 0) && (k_idx < K)) begin

                // A[r][k]
                a_value =
                    (r + 1)
                    +
                    (k_idx % 4);


                // Pack INT8 value into correct row position
                A_in_bus[
                    r*DATA_WIDTH
                    +: DATA_WIDTH
                ] = a_value;


                // This row contains real data this cycle
                A_valid_in[r] = 1'b1;

            end

        end



        // ====================================================
        // GENERATE B INPUTS
        // ====================================================

        for (c = 0; c < ARRAY_SIZE; c = c + 1) begin

            // Account for column skew
            k_idx = t - c;


            if ((k_idx >= 0) && (k_idx < K)) begin

                // B[k][c]
                b_value =
                    (c + 1)
                    +
                    (k_idx % 4);


                // Make odd columns negative
                if ((c % 2) == 1)
                    b_value = -b_value;


                B_in_bus[
                    c*DATA_WIDTH
                    +: DATA_WIDTH
                ] = b_value;


                B_valid_in[c] = 1'b1;

            end

        end


        // Allow this cycle to enter the array
        @(posedge clk);

    end



    // ========================================================
    // STOP FEEDING DATA
    // ========================================================

    @(negedge clk);

    A_in_bus = 0;
    B_in_bus = 0;

    A_valid_in = 0;
    B_valid_in = 0;



    // ========================================================
    // DRAIN THE PIPELINE
    //
    // The farthest PE is PE[7][7].
    //
    // The final values need another 7 cycles to reach it.
    // ========================================================

    repeat (ARRAY_SIZE-1) @(posedge clk);

    #1;



    // ========================================================
    // PRINT FINAL C MATRIX
    // ========================================================

    $display("");
    $display("Final C matrix from systolic array:");
    $display("");


    for (r = 0; r < ARRAY_SIZE; r = r + 1) begin

        $write("C row %0d: ", r);

        for (c = 0; c < ARRAY_SIZE; c = c + 1) begin

            actual =
                acc_out_bus[
                    (r*ARRAY_SIZE + c)*ACC_WIDTH
                    +: ACC_WIDTH
                ];

            $write("%0d ", actual);

        end

        $display("");

    end



    // ========================================================
    // AUTOMATICALLY VERIFY ALL 64 OUTPUTS
    // ========================================================

    $display("");
    $display("Checking all 64 PE accumulators...");
    $display("");


    for (r = 0; r < ARRAY_SIZE; r = r + 1) begin

        for (c = 0; c < ARRAY_SIZE; c = c + 1) begin


            // ----------------------------------------------
            // Calculate expected software result:
            //
            // C[r][c] =
            //
            // sum from k=0 to 63:
            //
            // A[r][k] * B[k][c]
            // ----------------------------------------------

            expected = 0;


            for (k_idx = 0;
                 k_idx < K;
                 k_idx = k_idx + 1) begin


                a_value =
                    (r + 1)
                    +
                    (k_idx % 4);


                b_value =
                    (c + 1)
                    +
                    (k_idx % 4);


                if ((c % 2) == 1)
                    b_value = -b_value;


                expected =
                    expected
                    +
                    a_value * b_value;

            end



            // Read actual PE accumulator
            actual =
                acc_out_bus[
                    (r*ARRAY_SIZE + c)*ACC_WIDTH
                    +: ACC_WIDTH
                ];



            // Compare
            if (actual == expected) begin

                pass_count = pass_count + 1;

            end

            else begin

                fail_count = fail_count + 1;

                $display(
                    "FAIL PE[%0d][%0d]: expected %0d, got %0d",
                    r,
                    c,
                    expected,
                    actual
                );

            end

        end

    end



    // ========================================================
    // FINAL RESULT
    // ========================================================

    $display("");
    $display("Correct outputs: %0d / 64", pass_count);


    if (pass_count == ARRAY_SIZE*ARRAY_SIZE) begin

        $display("");
        $display("**********************************************");
        $display("***** TEST 2 PASSED: ALL 64 PEs CORRECT *****");
        $display("**********************************************");

    end

    else begin

        $display("");
        $display("**********************************************");
        $display("***** TEST 2 FAILED *****");
        $display("**********************************************");

    end



    #20;

    $stop;

end


endmodule