`timescale 1ns/1ps
//main time unit = 1ns, simulation precision = 1ps

module pe_tb; //tb for the pe

// Inputs driven by the testbench. TB will change these values, so need to save as reg
reg clk;
reg reset;

reg signed [7:0] A_in;
reg signed [7:0] B_in;

reg A_valid_in;
reg B_valid_in;

// Outputs coming from the PE. wire since need to observe the outputs
wire signed [7:0] A_out;
wire signed [7:0] B_out;

wire A_valid_out;
wire B_valid_out;

wire signed [31:0] acc_out;

// Instantiate the PE
pe dut ( //Create one instance of the pe module and call this instance dut.
    .clk(clk), //connects tb to the pe. (PE ports and TB signals)
    .reset(reset),

    .A_in(A_in),
    .B_in(B_in),

    .A_valid_in(A_valid_in),
    .B_valid_in(B_valid_in),

    .A_out(A_out),
    .B_out(B_out),

    .A_valid_out(A_valid_out),
    .B_valid_out(B_valid_out),

    .acc_out(acc_out)
);

// Clock generation: 10 ns period
initial begin
    clk = 0;
    forever #5 clk = ~clk; //flip clk every 5ns
end

// Test sequence
initial begin
    // Initial values
    reset = 1;
    A_in = 0;
    B_in = 0;
    A_valid_in = 0;
    B_valid_in = 0;

    #12; //makes sure its after 1 period. reset at 12

    // Release reset
    reset = 0;

    // Test 1: positive x positive (3x4)
    A_in = 8'sd3;
    B_in = 8'sd4;
    A_valid_in = 1;
    B_valid_in = 1;

    #10;

    // Stop sending valid data so we only accumulate once
    A_in = 0;
    B_in = 0;
    A_valid_in = 0;
    B_valid_in = 0;

    #10;

    // Test 2: Multi-Cycle Accumulation Test
    // tests whether acc remembers the previous result and keeps accumulating

    // Reset PE before Test 2
    reset = 1;

    #10;

    // Release reset
    reset = 0;

    // MAC 1: 3 x 4 = 12
    // Expected acc = 12
    A_in = 8'sd3;
    B_in = 8'sd4;
    A_valid_in = 1;
    B_valid_in = 1;

    #10;

    // MAC 2: 2 x 5 = 10
    // Expected acc = 12 + 10 = 22
    A_in = 8'sd2;
    B_in = 8'sd5;

    #10;

    // MAC 3: 6 x (-2) = -12
    // Expected acc = 22 - 12 = 10
    A_in = 8'sd6;
    B_in = -8'sd2;

    #10;

    // Stop sending valid data
    // acc should stay at 10
    A_in = 0;
    B_in = 0;
    A_valid_in = 0;
    B_valid_in = 0;

    #10;

    // Test 3: Signed Arithmetic Test
    // tests positive x negative, negative x positive, and negative x negative

    // Reset PE before Test 3
    reset = 1;

    #10;

    // Release reset
    reset = 0;

    // Signed MAC 1: 4 x (-3) = -12
    // Expected acc = -12
    A_in = 8'sd4;
    B_in = -8'sd3;
    A_valid_in = 1;
    B_valid_in = 1;

    #10;

    // Signed MAC 2: (-5) x 2 = -10
    // Expected acc = -12 - 10 = -22
    A_in = -8'sd5;
    B_in = 8'sd2;

    #10;

    // Signed MAC 3: (-6) x (-4) = 24
    // Expected acc = -22 + 24 = 2
    A_in = -8'sd6;
    B_in = -8'sd4;

    #10;

    // Stop sending valid data
    // acc should stay at 2
    A_in = 0;
    B_in = 0;
    A_valid_in = 0;
    B_valid_in = 0;

    #10;

    // Test 4: Valid-Signal Combination Test
    // tests whether MAC only occurs when BOTH A_valid_in and B_valid_in are 1

    // Reset PE before Test 4
    reset = 1;

    #10;

    // Release reset
    reset = 0;

    // Keep A and B constant so product is always 12
    A_in = 8'sd3;
    B_in = 8'sd4;

    // Case 1: A_valid = 0, B_valid = 0
    // Expected acc = 0
    A_valid_in = 0;
    B_valid_in = 0;

    #10;

    // Case 2: A_valid = 0, B_valid = 1
    // Expected acc = 0
    A_valid_in = 0;
    B_valid_in = 1;

    #10;

    // Case 3: A_valid = 1, B_valid = 0
    // Expected acc = 0
    A_valid_in = 1;
    B_valid_in = 0;

    #10;

    // Case 4: A_valid = 1, B_valid = 1
    // Expected acc = 12
    A_valid_in = 1;
    B_valid_in = 1;

    #10;

    // Stop sending valid data
    // acc should stay at 12
    A_valid_in = 0;
    B_valid_in = 0;
    A_in = 0;
    B_in = 0;

    #10;

    // Test 5: INT8 Boundary + Zero Test
    // tests the extreme signed INT8 values (-128 to 127) and zero

    // Reset PE before Test 5
    reset = 1;

    #10;

    // Release reset
    reset = 0;

    // Boundary Case 1: 127 x 127 = 16129
    // Expected acc = 16129
    A_in = 8'sd127;
    B_in = 8'sd127;
    A_valid_in = 1;
    B_valid_in = 1;

    #10;

    // Boundary Case 2: -128 x 127 = -16256
    // Expected acc = 16129 - 16256 = -127
    A_in = 8'sh80;     // -128 in signed INT8
    B_in = 8'sd127;

    #10;

    // Boundary Case 3: -128 x -128 = 16384
    // Expected acc = -127 + 16384 = 16257
    A_in = 8'sh80;     // -128
    B_in = 8'sh80;     // -128

    #10;

    // Boundary Case 4: 0 x 127 = 0
    // Expected acc should stay 16257
    A_in = 8'sd0;
    B_in = 8'sd127;

    #10;

    // Stop sending valid data
    // acc should stay at 16257
    A_in = 0;
    B_in = 0;
    A_valid_in = 0;
    B_valid_in = 0;

    #10;

    // Test 6: Reset After Accumulation Test
    // tests whether reset correctly clears the PE after it has accumulated a nonzero value

    // Reset PE before Test 6
    reset = 1;

    #10;

    // Release reset
    reset = 0;

    // MAC 1: 3 x 4 = 12
    // Expected acc = 12
    A_in = 8'sd3;
    B_in = 8'sd4;
    A_valid_in = 1;
    B_valid_in = 1;

    #10;

    // MAC 2: 2 x 5 = 10
    // Expected acc = 12 + 10 = 22
    A_in = 8'sd2;
    B_in = 8'sd5;

    #10;

    // At this point:
    // acc_out should equal 22

    // Assert reset while PE contains accumulated data
    reset = 1;

    // Keep inputs invalid during reset
    A_in = 0;
    B_in = 0;
    A_valid_in = 0;
    B_valid_in = 0;

    #10;

    // After the rising clock edge during reset:
    // Expected: 
    // acc_out = 0 //on next rising clk
    // A_out = 0
    // B_out = 0
    // A_valid_out = 0
    // B_valid_out = 0

    // Release reset again
    reset = 0;

    #10;

    $finish;


end

endmodule