`timescale 1ns/1ps

module systolic_array_2x2_tb;


// ============================================================
// INPUTS
// Testbench drives these signals, so use reg
// ============================================================

reg clk;
reg reset;

reg signed [7:0] A0_in;
reg signed [7:0] A1_in;

reg signed [7:0] B0_in;
reg signed [7:0] B1_in;

reg A0_valid_in;
reg A1_valid_in;

reg B0_valid_in;
reg B1_valid_in;


// ============================================================
// OUTPUTS
// Outputs come from the DUT, so use wire
// ============================================================

wire signed [31:0] acc00;
wire signed [31:0] acc01;
wire signed [31:0] acc10;
wire signed [31:0] acc11;


// ============================================================
// INSTANTIATE 2x2 SYSTOLIC ARRAY
// ============================================================

systolic_array_2x2 dut (

    .clk(clk),
    .reset(reset),

    .A0_in(A0_in),
    .A1_in(A1_in),

    .B0_in(B0_in),
    .B1_in(B1_in),

    .A0_valid_in(A0_valid_in),
    .A1_valid_in(A1_valid_in),

    .B0_valid_in(B0_valid_in),
    .B1_valid_in(B1_valid_in),

    .acc00(acc00),
    .acc01(acc01),
    .acc10(acc10),
    .acc11(acc11)

);


// ============================================================
// CLOCK
// 10 ns clock period
// ============================================================

always #5 clk = ~clk;


// ============================================================
// TESTS
// ============================================================

initial begin

    // --------------------------------------------------------
    // INITIAL VALUES
    // --------------------------------------------------------

    clk = 0;
    reset = 1;

    A0_in = 0;
    A1_in = 0;

    B0_in = 0;
    B1_in = 0;

    A0_valid_in = 0;
    A1_valid_in = 0;

    B0_valid_in = 0;
    B1_valid_in = 0;


    // Hold reset for two clock cycles
    repeat (2) @(posedge clk);

    @(negedge clk);
    reset = 0;


    // ========================================================
    // TEST 1: DATA PROPAGATION
    // ========================================================

    $display("========================================");
    $display("TEST 1: DATA PROPAGATION");
    $display("========================================");

    // Put 11 into the top row
    // Put 33 into the first column
    //
    // Expected:
    // A0 = 11 should move PE00 -> PE01
    // B0 = 33 should move PE00 -> PE10

    A0_in = 8'sd11;
    B0_in = 8'sd33;

    A0_valid_in = 1;
    B0_valid_in = 1;


    // First rising edge:
    // PE00 captures 11 and 33
    @(posedge clk);
    #1;

    if (dut.A_00_to_01 == 8'sd11)
        $display("PASS: A moved into PE00 and toward PE01");
    else
        $display("FAIL: A propagation incorrect");

    if (dut.B_00_to_10 == 8'sd33)
        $display("PASS: B moved into PE00 and toward PE10");
    else
        $display("FAIL: B propagation incorrect");


    // Remove external values
    @(negedge clk);

    A0_in = 0;
    B0_in = 0;

    A0_valid_in = 0;
    B0_valid_in = 0;


    // Second rising edge:
    // 11 should now pass through PE01
    // 33 should now pass through PE10
    @(posedge clk);
    #1;

    if (dut.A_01_unused == 8'sd11)
        $display("PASS: A propagated PE00 -> PE01");
    else
        $display("FAIL: A did not propagate to PE01");

    if (dut.B_10_unused == 8'sd33)
        $display("PASS: B propagated PE00 -> PE10");
    else
        $display("FAIL: B did not propagate to PE10");


    // ========================================================
    // RESET BEFORE MATRIX TEST
    // ========================================================

    @(negedge clk);
    reset = 1;

    @(posedge clk);
    #1;

    @(negedge clk);
    reset = 0;


    // ========================================================
    // TEST 2: 2x2 MATRIX MULTIPLICATION
    // ========================================================

    $display("");
    $display("========================================");
    $display("TEST 2: 2x2 MATRIX MULTIPLICATION");
    $display("========================================");

    /*
        A = [1 2]
            [3 4]

        B = [5 6]
            [7 8]


        Expected:

        C00 = 1*5 + 2*7 = 19
        C01 = 1*6 + 2*8 = 22

        C10 = 3*5 + 4*7 = 43
        C11 = 3*6 + 4*8 = 50
    */


    // --------------------------------------------------------
    // CYCLE 1
    //
    // Row 0 and Column 0 begin immediately.
    //
    // PE00 gets:
    // A00 = 1
    // B00 = 5
    // --------------------------------------------------------

    A0_in = 8'sd1;
    B0_in = 8'sd5;

    A0_valid_in = 1;
    B0_valid_in = 1;

    // Row 1 and Column 1 are delayed
    A1_in = 0;
    B1_in = 0;

    A1_valid_in = 0;
    B1_valid_in = 0;

    @(posedge clk);


    // --------------------------------------------------------
    // CYCLE 2
    //
    // PE00:
    //      2 * 7
    //
    // PE01:
    //      1 * 6
    //
    // PE10:
    //      3 * 5
    // --------------------------------------------------------

    @(negedge clk);

    A0_in = 8'sd2;
    B0_in = 8'sd7;

    A1_in = 8'sd3;
    B1_in = 8'sd6;

    A0_valid_in = 1;
    B0_valid_in = 1;

    A1_valid_in = 1;
    B1_valid_in = 1;

    @(posedge clk);


    // --------------------------------------------------------
    // CYCLE 3
    //
    // PE01:
    //      2 * 8
    //
    // PE10:
    //      4 * 7
    //
    // PE11:
    //      3 * 6
    //
    // PE00 is finished.
    // --------------------------------------------------------

    @(negedge clk);

    A0_in = 0;
    B0_in = 0;

    A0_valid_in = 0;
    B0_valid_in = 0;

    A1_in = 8'sd4;
    B1_in = 8'sd8;

    A1_valid_in = 1;
    B1_valid_in = 1;

    @(posedge clk);


    // --------------------------------------------------------
    // CYCLE 4
    //
    // PE11 receives:
    //      4 * 8
    //
    // Everything entering from outside can now be invalid.
    // --------------------------------------------------------

    @(negedge clk);

    A0_in = 0;
    A1_in = 0;

    B0_in = 0;
    B1_in = 0;

    A0_valid_in = 0;
    A1_valid_in = 0;

    B0_valid_in = 0;
    B1_valid_in = 0;

    @(posedge clk);

    #1;


    // ========================================================
    // CHECK FINAL RESULTS
    // ========================================================

    $display("");
    $display("Results:");
    $display("acc00 = %0d (expected 19)", acc00);
    $display("acc01 = %0d (expected 22)", acc01);
    $display("acc10 = %0d (expected 43)", acc10);
    $display("acc11 = %0d (expected 50)", acc11);


    if (acc00 == 32'sd19)
        $display("PASS: acc00");
    else
        $display("FAIL: acc00");


    if (acc01 == 32'sd22)
        $display("PASS: acc01");
    else
        $display("FAIL: acc01");


    if (acc10 == 32'sd43)
        $display("PASS: acc10");
    else
        $display("FAIL: acc10");


    if (acc11 == 32'sd50)
        $display("PASS: acc11");
    else
        $display("FAIL: acc11");


    if (
        acc00 == 32'sd19 &&
        acc01 == 32'sd22 &&
        acc10 == 32'sd43 &&
        acc11 == 32'sd50
    )
        $display("***** 2x2 MATRIX MULTIPLICATION PASSED *****");
    else
        $display("***** 2x2 MATRIX MULTIPLICATION FAILED *****");


    // Give ModelSim some extra waveform time
    #20;

    $stop;

end

endmodule