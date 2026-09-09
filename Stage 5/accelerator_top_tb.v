`timescale 1ns/1ps

module accelerator_top_tb;


// ============================================================
// PARAMETERS
// ============================================================

parameter ARRAY_SIZE   = 8;
parameter K            = 64;
parameter DATA_WIDTH   = 8;
parameter ACC_WIDTH    = 32;
parameter ADDR_WIDTH   = 6;
parameter C_ADDR_WIDTH = 6;


// ============================================================
// CLOCK / RESET
// ============================================================

reg clk;
reg reset;


// ============================================================
// ACCELERATOR CONTROL
// ============================================================

reg start;

wire busy;
wire done;


// ============================================================
// A BUFFER WRITE INTERFACE
// ============================================================

reg a_wr_en;

reg [ADDR_WIDTH-1:0] a_wr_addr;

reg [ARRAY_SIZE*DATA_WIDTH-1:0] a_wr_data;


// ============================================================
// B BUFFER WRITE INTERFACE
// ============================================================

reg b_wr_en;

reg [ADDR_WIDTH-1:0] b_wr_addr;

reg [ARRAY_SIZE*DATA_WIDTH-1:0] b_wr_data;


// ============================================================
// C BUFFER READ INTERFACE
// ============================================================

reg c_rd_en;

reg [C_ADDR_WIDTH-1:0] c_rd_addr;

wire signed [ACC_WIDTH-1:0] c_rd_data;


// ============================================================
// TEST MATRICES
//
// Stored as flattened arrays.
//
// A_matrix[r*K + k]         = A[r][k]
//
// B_matrix[k*ARRAY_SIZE+c]  = B[k][c]
//
// expected[r*ARRAY_SIZE+c]  = C[r][c]
// ============================================================

reg signed [7:0] A_matrix
    [0:ARRAY_SIZE*K-1];

reg signed [7:0] B_matrix
    [0:K*ARRAY_SIZE-1];

reg signed [31:0] expected
    [0:ARRAY_SIZE*ARRAY_SIZE-1];


// Temporary 64-bit words used when loading A/B buffers

reg [ARRAY_SIZE*DATA_WIDTH-1:0] a_word;
reg [ARRAY_SIZE*DATA_WIDTH-1:0] b_word;


// Loop / checking variables

integer r;
integer c;
integer k;
integer idx;

integer correct;
integer wait_cycles;


// ============================================================
// DUT
// ============================================================

accelerator_top #(

    .ARRAY_SIZE(ARRAY_SIZE),
    .K(K),
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH(ACC_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .C_ADDR_WIDTH(C_ADDR_WIDTH)

) dut (

    .clk(clk),
    .reset(reset),

    .start(start),

    .busy(busy),
    .done(done),


    // A buffer loading
    .a_wr_en(a_wr_en),
    .a_wr_addr(a_wr_addr),
    .a_wr_data(a_wr_data),


    // B buffer loading
    .b_wr_en(b_wr_en),
    .b_wr_addr(b_wr_addr),
    .b_wr_data(b_wr_data),


    // C buffer reading
    .c_rd_en(c_rd_en),
    .c_rd_addr(c_rd_addr),
    .c_rd_data(c_rd_data)

);


// ============================================================
// CLOCK
//
// 10 ns period = 100 MHz
// ============================================================

initial begin

    clk = 0;

    forever #5 clk = ~clk;

end


// ============================================================
// MAIN TEST
// ============================================================

initial begin


    // --------------------------------------------------------
    // INITIAL VALUES
    // --------------------------------------------------------

    reset = 1;

    start = 0;

    a_wr_en = 0;
    a_wr_addr = 0;
    a_wr_data = 0;

    b_wr_en = 0;
    b_wr_addr = 0;
    b_wr_data = 0;

    c_rd_en = 0;
    c_rd_addr = 0;

    correct = 0;
    wait_cycles = 0;


    // ========================================================
    // CREATE TEST MATRICES
    //
    // Same deterministic pattern we used previously.
    //
    // A[r][k] = (r + 1) + (k mod 4)
    //
    // B[k][c] = (c + 1) + (k mod 4)
    //
    // Odd B columns are negative.
    // ========================================================

    for (r = 0; r < ARRAY_SIZE; r = r + 1) begin

        for (k = 0; k < K; k = k + 1) begin

            A_matrix[r*K + k]
                = (r + 1) + (k % 4);

        end

    end


    for (k = 0; k < K; k = k + 1) begin

        for (c = 0; c < ARRAY_SIZE; c = c + 1) begin

            if ((c % 2) == 0) begin

                B_matrix[k*ARRAY_SIZE + c]
                    = (c + 1) + (k % 4);

            end

            else begin

                B_matrix[k*ARRAY_SIZE + c]
                    = -((c + 1) + (k % 4));

            end

        end

    end


    // ========================================================
    // SOFTWARE-STYLE GOLDEN RESULT
    //
    // expected[r][c]
    //
    // =
    //
    // SUM over k:
    //
    // A[r][k] * B[k][c]
    // ========================================================

    for (r = 0; r < ARRAY_SIZE; r = r + 1) begin

        for (c = 0; c < ARRAY_SIZE; c = c + 1) begin

            expected[r*ARRAY_SIZE + c] = 32'sd0;

            for (k = 0; k < K; k = k + 1) begin

                expected[r*ARRAY_SIZE + c]
                    =
                    expected[r*ARRAY_SIZE + c]
                    +
                    $signed(A_matrix[r*K + k])
                    *
                    $signed(B_matrix[k*ARRAY_SIZE + c]);

            end

        end

    end


    // ========================================================
    // RESET
    // ========================================================

    repeat (3)
        @(posedge clk);

    @(negedge clk);

    reset = 0;


    $display("");
    $display("============================================");
    $display("Loading A and B buffers");
    $display("============================================");


    // ========================================================
    // LOAD A AND B BUFFERS
    //
    // For each k:
    //
    // A word contains:
    //
    // A[0][k]
    // A[1][k]
    // ...
    // A[7][k]
    //
    //
    // B word contains:
    //
    // B[k][0]
    // B[k][1]
    // ...
    // B[k][7]
    //
    // Both buffers are written on the same clock.
    // ========================================================

    for (k = 0; k < K; k = k + 1) begin

        a_word = 0;
        b_word = 0;


        // Pack 8 A values into one 64-bit word

        for (r = 0; r < ARRAY_SIZE; r = r + 1) begin

            a_word[
                r*DATA_WIDTH
                +: DATA_WIDTH
            ]
            =
            A_matrix[r*K + k];

        end


        // Pack 8 B values into one 64-bit word

        for (c = 0; c < ARRAY_SIZE; c = c + 1) begin

            b_word[
                c*DATA_WIDTH
                +: DATA_WIDTH
            ]
            =
            B_matrix[k*ARRAY_SIZE + c];

        end


        // Present write information before rising edge

        @(negedge clk);

        a_wr_en   = 1;
        a_wr_addr = k;
        a_wr_data = a_word;

        b_wr_en   = 1;
        b_wr_addr = k;
        b_wr_data = b_word;


        // A and B buffers capture the words here

        @(posedge clk);

        #1;

    end


    // Stop writing

    @(negedge clk);

    a_wr_en = 0;
    b_wr_en = 0;


    $display("A/B buffers loaded.");
    $display("");
    $display("============================================");
    $display("Starting accelerator");
    $display("============================================");


    // ========================================================
    // START
    //
    // Pulse start high for one clock.
    // ========================================================

    start = 1;

    @(negedge clk);

    start = 0;


    // ========================================================
    // WAIT FOR DONE
    //
    // Controller now performs:
    //
    // CLEAR
    // STREAM
    // DRAIN
    // STORE
    // DONE
    //
    // Timeout prevents simulation from hanging forever if
    // something is wrong.
    // ========================================================

    wait_cycles = 0;

    while (
        (done !== 1'b1)
        &&
        (wait_cycles < 500)
    ) begin

        @(posedge clk);

        #1;

        wait_cycles = wait_cycles + 1;

    end


    if (done !== 1'b1) begin

        $display("");
        $display("ERROR: Accelerator timed out.");
        $display("FSM never reached DONE.");
        $display("");

        $stop;

    end


    $display("");
    $display("Accelerator DONE after %0d clocks.",
             wait_cycles);

    $display("");
    $display("============================================");
    $display("Reading C buffer");
    $display("============================================");


    // ========================================================
    // READ AND CHECK C BUFFER
    //
    // C buffer mapping:
    //
    // addr 0  = C00
    // addr 1  = C01
    // ...
    // addr 7  = C07
    //
    // addr 8  = C10
    //
    // ...
    //
    // addr 63 = C77
    //
    // C buffer has synchronous read:
    //
    // give address
    //      ↓
    // clock edge
    //      ↓
    // c_rd_data valid
    // ========================================================

    correct = 0;

    for (idx = 0;
         idx < ARRAY_SIZE*ARRAY_SIZE;
         idx = idx + 1) begin


        // Set address before rising edge

        @(negedge clk);

        c_rd_en   = 1;
        c_rd_addr = idx;


        // C buffer performs synchronous read

        @(posedge clk);

        #1;


        // Compare hardware result against golden result

        if (
            $signed(c_rd_data)
            ===
            expected[idx]
        ) begin

            correct = correct + 1;

        end

        else begin

            $display(
                "ERROR C[%0d][%0d]: got %0d expected %0d",
                idx / ARRAY_SIZE,
                idx % ARRAY_SIZE,
                $signed(c_rd_data),
                expected[idx]
            );

        end

    end


    @(negedge clk);

    c_rd_en = 0;


    // ========================================================
    // FINAL RESULT
    // ========================================================

    $display("");
    $display("============================================");
    $display("TEST COMPLETE");
    $display("Correct outputs: %0d / %0d",
             correct,
             ARRAY_SIZE*ARRAY_SIZE);
    $display("============================================");


    if (correct == ARRAY_SIZE*ARRAY_SIZE) begin

        $display("");
        $display("PASS: Full accelerator is correct.");
        $display("");

    end

    else begin

        $display("");
        $display("FAIL: One or more C values are incorrect.");
        $display("");

    end


    $stop;

end


endmodule