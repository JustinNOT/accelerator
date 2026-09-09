module controller #(
    parameter ROWS         = 8,
    parameter COLS         = 8,
    parameter K            = 64,
    parameter DATA_WIDTH   = 8,
    parameter ADDR_WIDTH   = 6,
    parameter C_ADDR_WIDTH = 6
)(
    input wire clk,
    input wire reset,

    // Start a matrix multiplication
    input wire start,


    // ========================================================
    // A BUFFER READ INTERFACE
    // ========================================================

    output wire a_rd_en,
    output wire [ADDR_WIDTH-1:0] a_rd_addr,

    // 8 INT8 A values returned from A buffer
    input wire [ROWS*DATA_WIDTH-1:0] a_rd_data,


    // ========================================================
    // B BUFFER READ INTERFACE
    // ========================================================

    output wire b_rd_en,
    output wire [ADDR_WIDTH-1:0] b_rd_addr,

    // 8 INT8 B values returned from B buffer
    input wire [COLS*DATA_WIDTH-1:0] b_rd_data,


    // ========================================================
    // SYSTOLIC ARRAY INPUTS
    // ========================================================

    output wire [ROWS*DATA_WIDTH-1:0] A_in_bus,
    output wire [COLS*DATA_WIDTH-1:0] B_in_bus,

    output wire [ROWS-1:0] A_valid_in,
    output wire [COLS-1:0] B_valid_in,

    // Reset just for the systolic array before a new operation
    output wire array_reset,


    // ========================================================
    // C BUFFER CONTROL
    // ========================================================

    output wire c_wr_en,
    output wire [C_ADDR_WIDTH-1:0] c_wr_addr,


    // ========================================================
    // STATUS
    // ========================================================

    output wire busy,
    output wire done
);


// ============================================================
// FSM STATES
// ============================================================

localparam [2:0] IDLE   = 3'd0;
localparam [2:0] CLEAR  = 3'd1;
localparam [2:0] STREAM = 3'd2;
localparam [2:0] DRAIN  = 3'd3;
localparam [2:0] STORE  = 3'd4;
localparam [2:0] DONE   = 3'd5;

reg [2:0] state;


// ============================================================
// COUNTERS
// ============================================================

// Which k value is currently being requested from A/B memory
// 0 -> 63
reg [ADDR_WIDTH-1:0] fetch_count;

// Which C result is currently being stored
// 0 -> 63
reg [C_ADDR_WIDTH-1:0] store_count;

// Counts extra cycles needed for the final data to move
// through the skew network and systolic array
reg [7:0] drain_count;


// For an 8x8 array:
//
// maximum skew delay = 7 cycles
// maximum PE propagation = 7 cycles
//
// 16 cycles gives enough time for the final data to
// completely pass through the array.
localparam integer DRAIN_CYCLES = 2 * ROWS;


// ============================================================
// SYNCHRONOUS MEMORY VALID PIPELINE
//
// A/B memories have synchronous reads.
//
// Request address on one cycle.
// Data becomes available after the clock.
//
// This bit tells us that a_rd_data / b_rd_data contain
// real values from a previous memory request.
// ============================================================

reg mem_data_valid;


// ============================================================
// SKEW PIPELINES
//
// Stage 4 manually delayed:
//
// A row 0 -> 0 cycles
// A row 1 -> 1 cycle
// ...
// A row 7 -> 7 cycles
//
// B col 0 -> 0 cycles
// B col 1 -> 1 cycle
// ...
// B col 7 -> 7 cycles
//
// These registers now perform those delays in hardware.
// ============================================================

// Each A row gets up to ROWS delay stages
reg [ROWS*ROWS*DATA_WIDTH-1:0] a_pipe;
reg [ROWS*ROWS-1:0] a_valid_pipe;

// Each B column gets up to COLS delay stages
reg [COLS*COLS*DATA_WIDTH-1:0] b_pipe;
reg [COLS*COLS-1:0] b_valid_pipe;


// Loop variables
integer r;
integer c;
integer d;


// ============================================================
// MEMORY READ CONTROL
// ============================================================

// Read A and B simultaneously while STREAMING
assign a_rd_en = (state == STREAM);
assign b_rd_en = (state == STREAM);

// A and B use the same k address
assign a_rd_addr = fetch_count;
assign b_rd_addr = fetch_count;


// ============================================================
// ARRAY RESET
// ============================================================

// Reset all PE accumulators before each new computation
assign array_reset = (state == CLEAR);


// ============================================================
// STATUS
// ============================================================

assign busy =
    (state != IDLE) &&
    (state != DONE);

assign done = (state == DONE);


// ============================================================
// C BUFFER WRITE CONTROL
// ============================================================

// During STORE, write one PE result every clock
assign c_wr_en = (state == STORE);

assign c_wr_addr = store_count;


// ============================================================
// CONNECT SKEW PIPELINES TO SYSTOLIC ARRAY
// ============================================================

genvar gr;
genvar gc;

generate

    // --------------------------------------------------------
    // A ROWS
    //
    // Row r uses delay stage r.
    //
    // row 0 -> stage 0
    // row 1 -> stage 1
    // ...
    // row 7 -> stage 7
    // --------------------------------------------------------

    for (gr = 0; gr < ROWS; gr = gr + 1) begin : A_OUTPUTS

        assign A_in_bus[
            gr*DATA_WIDTH
            +: DATA_WIDTH
        ] =
            a_pipe[
                (gr*ROWS + gr)*DATA_WIDTH
                +: DATA_WIDTH
            ];

        assign A_valid_in[gr] =
            a_valid_pipe[
                gr*ROWS + gr
            ];

    end


    // --------------------------------------------------------
    // B COLUMNS
    //
    // Column c uses delay stage c.
    // --------------------------------------------------------

    for (gc = 0; gc < COLS; gc = gc + 1) begin : B_OUTPUTS

        assign B_in_bus[
            gc*DATA_WIDTH
            +: DATA_WIDTH
        ] =
            b_pipe[
                (gc*COLS + gc)*DATA_WIDTH
                +: DATA_WIDTH
            ];

        assign B_valid_in[gc] =
            b_valid_pipe[
                gc*COLS + gc
            ];

    end

endgenerate


// ============================================================
// MAIN SEQUENTIAL LOGIC
// ============================================================

always @(posedge clk) begin

    if (reset) begin

        state <= IDLE;

        fetch_count <= 0;
        store_count <= 0;
        drain_count <= 0;

        mem_data_valid <= 0;

        a_pipe <= 0;
        a_valid_pipe <= 0;

        b_pipe <= 0;
        b_valid_pipe <= 0;

    end

    else begin


        // ====================================================
        // SKEW PIPELINE OPERATION
        // ====================================================

        if ((state == STREAM) || (state == DRAIN)) begin


            // ------------------------------------------------
            // A SKEWING
            // ------------------------------------------------

            for (r = 0; r < ROWS; r = r + 1) begin

                // Shift existing values through delay stages
                for (d = ROWS-1; d > 0; d = d - 1) begin

                    a_pipe[
                        (r*ROWS + d)*DATA_WIDTH
                        +: DATA_WIDTH
                    ]
                    <=
                    a_pipe[
                        (r*ROWS + d - 1)*DATA_WIDTH
                        +: DATA_WIDTH
                    ];

                    a_valid_pipe[
                        r*ROWS + d
                    ]
                    <=
                    a_valid_pipe[
                        r*ROWS + d - 1
                    ];

                end


                // Put newest memory value into stage 0
                if (mem_data_valid) begin

                    a_pipe[
                        (r*ROWS)*DATA_WIDTH
                        +: DATA_WIDTH
                    ]
                    <=
                    a_rd_data[
                        r*DATA_WIDTH
                        +: DATA_WIDTH
                    ];

                    a_valid_pipe[
                        r*ROWS
                    ]
                    <= 1'b1;

                end

                else begin

                    a_pipe[
                        (r*ROWS)*DATA_WIDTH
                        +: DATA_WIDTH
                    ]
                    <= 0;

                    a_valid_pipe[
                        r*ROWS
                    ]
                    <= 1'b0;

                end

            end



            // ------------------------------------------------
            // B SKEWING
            // ------------------------------------------------

            for (c = 0; c < COLS; c = c + 1) begin

                // Shift existing values through delay stages
                for (d = COLS-1; d > 0; d = d - 1) begin

                    b_pipe[
                        (c*COLS + d)*DATA_WIDTH
                        +: DATA_WIDTH
                    ]
                    <=
                    b_pipe[
                        (c*COLS + d - 1)*DATA_WIDTH
                        +: DATA_WIDTH
                    ];

                    b_valid_pipe[
                        c*COLS + d
                    ]
                    <=
                    b_valid_pipe[
                        c*COLS + d - 1
                    ];

                end


                // Put newest B value into stage 0
                if (mem_data_valid) begin

                    b_pipe[
                        (c*COLS)*DATA_WIDTH
                        +: DATA_WIDTH
                    ]
                    <=
                    b_rd_data[
                        c*DATA_WIDTH
                        +: DATA_WIDTH
                    ];

                    b_valid_pipe[
                        c*COLS
                    ]
                    <= 1'b1;

                end

                else begin

                    b_pipe[
                        (c*COLS)*DATA_WIDTH
                        +: DATA_WIDTH
                    ]
                    <= 0;

                    b_valid_pipe[
                        c*COLS
                    ]
                    <= 1'b0;

                end

            end

        end


        // ====================================================
        // MEMORY READ LATENCY TRACKING
        // ====================================================

        // If we are currently requesting memory,
        // its output will be usable on the following cycle.
        mem_data_valid <= (state == STREAM);


        // ====================================================
        // FSM
        // ====================================================

        case (state)


            // =================================================
            // IDLE
            // =================================================

            IDLE: begin

                fetch_count <= 0;
                store_count <= 0;
                drain_count <= 0;

                mem_data_valid <= 0;

                if (start) begin
                    state <= CLEAR;
                end

            end


            // =================================================
            // CLEAR
            //
            // Reset PE accumulators and clear skew pipelines.
            // =================================================

            CLEAR: begin

                fetch_count <= 0;
                store_count <= 0;
                drain_count <= 0;

                mem_data_valid <= 0;

                a_pipe <= 0;
                a_valid_pipe <= 0;

                b_pipe <= 0;
                b_valid_pipe <= 0;

                state <= STREAM;

            end


            // =================================================
            // STREAM
            //
            // Read:
            //
            // A_mem[k]
            // B_mem[k]
            //
            // for k = 0 ... 63
            // =================================================

            STREAM: begin

                if (fetch_count == K-1) begin

                    // Address 63 is being requested now.
                    // After this request, move to drain.
                    fetch_count <= fetch_count;

                    drain_count <= 0;

                    state <= DRAIN;

                end

                else begin

                    fetch_count <= fetch_count + 1'b1;

                end

            end


            // =================================================
            // DRAIN
            //
            // No more new memory reads.
            //
            // Continue clocking so:
            //
            // - final memory value enters skew pipeline
            // - skew pipeline empties
            // - systolic array finishes propagating
            // =================================================

            DRAIN: begin

                if (drain_count == DRAIN_CYCLES-1) begin

                    drain_count <= drain_count;

                    store_count <= 0;

                    state <= STORE;

                end

                else begin

                    drain_count <= drain_count + 1'b1;

                end

            end


            // =================================================
            // STORE
            //
            // Write:
            //
            // PE00 -> C_mem[0]
            // PE01 -> C_mem[1]
            // ...
            // PE77 -> C_mem[63]
            //
            // accelerator_top will select the corresponding
            // 32-bit accumulator from acc_out_bus.
            // =================================================

            STORE: begin

                if (store_count == ROWS*COLS-1) begin

                    store_count <= store_count;

                    state <= DONE;

                end

                else begin

                    store_count <= store_count + 1'b1;

                end

            end


            // =================================================
            // DONE
            // =================================================

            DONE: begin

                // Hold done high until start goes back low.
                if (!start) begin
                    state <= IDLE;
                end

            end


            default: begin

                state <= IDLE;

            end

        endcase

    end

end


endmodule