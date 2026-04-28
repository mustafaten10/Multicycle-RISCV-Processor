// ============================================================
// controller_testbench.sv
// ============================================================

`timescale 1ns/1ps

module controller_testbench();

    // -------------------------------------------------------
    // DUT Signals (CamelCase to match new controller)
    // -------------------------------------------------------
    logic        clk, reset;
    logic [6:0]  op;
    logic [2:0]  funct3;
    logic        funct7b5;
    logic        Zero;

    logic [2:0]  ImmSrc;       // 3-bit now
    logic [1:0]  ALUSrcA, ALUSrcB;
    logic [1:0]  ResultSrc;
    logic        AdrSrc;
    logic [2:0]  ALUControl;
    logic        IRWrite, PCWrite;
    logic        RegWrite, MemWrite;

    integer test_num;
    integer errors;

    // -------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------
    controller dut (
        .clk       (clk),
        .reset     (reset),
        .op        (op),
        .funct3    (funct3),
        .funct7b5  (funct7b5),
        .Zero      (Zero),
        .ImmSrc    (ImmSrc),
        .ALUSrcA   (ALUSrcA),
        .ALUSrcB   (ALUSrcB),
        .ResultSrc (ResultSrc),
        .AdrSrc    (AdrSrc),
        .ALUControl(ALUControl),
        .IRWrite   (IRWrite),
        .PCWrite   (PCWrite),
        .RegWrite  (RegWrite),
        .MemWrite  (MemWrite)
    );

    // Clock: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------
    // Check task (ImmSrc is now 3-bit)
    // -------------------------------------------------------
    task check_outputs;
        input string          state_name;
        input logic [2:0]     exp_immsrc;       // 3-bit
        input logic [1:0]     exp_alusrca;
        input logic [1:0]     exp_alusrcb;
        input logic [1:0]     exp_resultsrc;
        input logic           exp_adrsrc;
        input logic [2:0]     exp_alucontrol;
        input logic           exp_irwrite;
        input logic           exp_pcwrite;
        input logic           exp_regwrite;
        input logic           exp_memwrite;
        begin
            test_num = test_num + 1;
            if (ImmSrc     !== exp_immsrc     ||
                ALUSrcA    !== exp_alusrca    ||
                ALUSrcB    !== exp_alusrcb    ||
                ResultSrc  !== exp_resultsrc  ||
                AdrSrc     !== exp_adrsrc     ||
                ALUControl !== exp_alucontrol ||
                IRWrite    !== exp_irwrite    ||
                PCWrite    !== exp_pcwrite    ||
                RegWrite   !== exp_regwrite   ||
                MemWrite   !== exp_memwrite) begin

                $display("FAILED Test %0d [%s] at time %0t", test_num, state_name, $time);
                $display("  ImmSrc    : got %b, expected %b", ImmSrc,     exp_immsrc);
                $display("  ALUSrcA   : got %b, expected %b", ALUSrcA,    exp_alusrca);
                $display("  ALUSrcB   : got %b, expected %b", ALUSrcB,    exp_alusrcb);
                $display("  ResultSrc : got %b, expected %b", ResultSrc,  exp_resultsrc);
                $display("  AdrSrc    : got %b, expected %b", AdrSrc,     exp_adrsrc);
                $display("  ALUControl: got %b, expected %b", ALUControl, exp_alucontrol);
                $display("  IRWrite   : got %b, expected %b", IRWrite,    exp_irwrite);
                $display("  PCWrite   : got %b, expected %b", PCWrite,    exp_pcwrite);
                $display("  RegWrite  : got %b, expected %b", RegWrite,   exp_regwrite);
                $display("  MemWrite  : got %b, expected %b", MemWrite,   exp_memwrite);
                errors = errors + 1;
            end else begin
                $display("PASSED Test %0d [%s]", test_num, state_name);
            end
        end
    endtask

    task do_reset;
        begin
            reset = 1;
            @(posedge clk); #1;
            reset = 0;
        end
    endtask

    task tick;
        begin
            @(posedge clk); #1;
        end
    endtask

    // -------------------------------------------------------
    // MAIN TEST SEQUENCE
    // -------------------------------------------------------
    initial begin
        errors   = 0;
        test_num = 0;

        op       = 7'b0000000;
        funct3   = 3'b000;
        funct7b5 = 0;
        Zero     = 0;

        $display("============================================");
        $display("  Controller Testbench Starting");
        $display("============================================");

        // ==================================================
        // TEST GROUP 1: RESET -> S_FETCH
        // ==================================================
        $display("\n--- TEST GROUP 1: Reset -> S_FETCH ---");
        do_reset();
        check_outputs("S_FETCH",
            3'b000, // ImmSrc (op=0 -> default)
            2'b00,  // ALUSrcA = PC
            2'b10,  // ALUSrcB = 4
            2'b10,  // ResultSrc = ALUResult
            1'b0,   // AdrSrc
            3'b000, // ALUControl = add
            1'b1,   // IRWrite
            1'b1,   // PCWrite (PCUpdate)
            1'b0,   // RegWrite
            1'b0    // MemWrite
        );

        // ==================================================
        // TEST GROUP 2: LW Path
        // ==================================================
        $display("\n--- TEST GROUP 2: LW Path ---");
        do_reset();
        op     = 7'b0000011; // lw
        funct3 = 3'b010;

        check_outputs("S_FETCH (lw)",
            3'b000, 2'b00, 2'b10, 2'b10, 1'b0, 3'b000, 1'b1, 1'b1, 1'b0, 1'b0);

        tick(); // -> S_DECODE
        check_outputs("S_DECODE (lw)",
            3'b000, 2'b01, 2'b01, 2'b00, 1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0);

        tick(); // -> S_MEMADR
        check_outputs("S_MEMADR (lw)",
            3'b000, 2'b10, 2'b01, 2'b00, 1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0);

        tick(); // -> S_MEMREAD
        check_outputs("S_MEMREAD (lw)",
            3'b000, 2'b00, 2'b00, 2'b00, 1'b1, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0);

        tick(); // -> S_MEMWB
        check_outputs("S_MEMWB (lw)",
            3'b000, 2'b00, 2'b00, 2'b01, 1'b0, 3'b000, 1'b0, 1'b0, 1'b1, 1'b0);

        tick(); // -> S_FETCH
        check_outputs("S_FETCH (after lw)",
            3'b000, 2'b00, 2'b10, 2'b10, 1'b0, 3'b000, 1'b1, 1'b1, 1'b0, 1'b0);

        // ==================================================
        // TEST GROUP 3: SW Path (ImmSrc = 3'b001 now)
        // ==================================================
        $display("\n--- TEST GROUP 3: SW Path ---");
        do_reset();
        op     = 7'b0100011; // sw
        funct3 = 3'b010;

        tick(); // S_FETCH -> S_DECODE
        tick(); // -> S_MEMADR
        tick(); // -> S_MEMWRITE
        check_outputs("S_MEMWRITE (sw)",
            3'b001, // ImmSrc (sw -> 001)
            2'b00, 2'b00, 2'b00, 1'b1, 3'b000, 1'b0, 1'b0, 1'b0, 1'b1);

        // ==================================================
        // TEST GROUP 4: R-type ADD
        // ==================================================
        $display("\n--- TEST GROUP 4: R-type ADD Path ---");
        do_reset();
        op       = 7'b0110011;
        funct3   = 3'b000;
        funct7b5 = 1'b0;

        tick(); // -> S_DECODE
        tick(); // -> S_EXECUTER
        check_outputs("S_EXECUTER (add)",
            3'b000, 2'b10, 2'b00, 2'b00, 1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0);

        tick(); // -> S_ALUWB
        check_outputs("S_ALUWB (add)",
            3'b000, 2'b00, 2'b00, 2'b00, 1'b0, 3'b000, 1'b0, 1'b0, 1'b1, 1'b0);

        // ==================================================
        // TEST GROUP 5: R-type SUB
        // ==================================================
        $display("\n--- TEST GROUP 5: R-type SUB Path ---");
        do_reset();
        op       = 7'b0110011;
        funct3   = 3'b000;
        funct7b5 = 1'b1;

        tick(); tick();
        check_outputs("S_EXECUTER (sub)",
            3'b000, 2'b10, 2'b00, 2'b00, 1'b0, 3'b001, 1'b0, 1'b0, 1'b0, 1'b0);

        // ==================================================
        // TEST GROUP 6: R-type AND
        // ==================================================
        $display("\n--- TEST GROUP 6: R-type AND ---");
        do_reset();
        op       = 7'b0110011;
        funct3   = 3'b111;
        funct7b5 = 1'b0;

        tick(); tick();
        check_outputs("S_EXECUTER (and)",
            3'b000, 2'b10, 2'b00, 2'b00, 1'b0, 3'b010, 1'b0, 1'b0, 1'b0, 1'b0);

        // ==================================================
        // TEST GROUP 7: R-type OR
        // ==================================================
        $display("\n--- TEST GROUP 7: R-type OR ---");
        do_reset();
        op       = 7'b0110011;
        funct3   = 3'b110;
        funct7b5 = 1'b0;

        tick(); tick();
        check_outputs("S_EXECUTER (or)",
            3'b000, 2'b10, 2'b00, 2'b00, 1'b0, 3'b011, 1'b0, 1'b0, 1'b0, 1'b0);

        // ==================================================
        // TEST GROUP 8: R-type SLT
        // ==================================================
        $display("\n--- TEST GROUP 8: R-type SLT ---");
        do_reset();
        op       = 7'b0110011;
        funct3   = 3'b010;
        funct7b5 = 1'b0;

        tick(); tick();
        check_outputs("S_EXECUTER (slt)",
            3'b000, 2'b10, 2'b00, 2'b00, 1'b0, 3'b101, 1'b0, 1'b0, 1'b0, 1'b0);

        // ==================================================
        // TEST GROUP 9: I-type ADDI
        // ==================================================
        $display("\n--- TEST GROUP 9: I-type ADDI Path ---");
        do_reset();
        op       = 7'b0010011;
        funct3   = 3'b000;
        funct7b5 = 1'b0;

        tick(); // -> S_DECODE
        tick(); // -> S_EXECUTEI
        check_outputs("S_EXECUTEI (addi)",
            3'b000, 2'b10, 2'b01, 2'b00, 1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0);

        tick(); // -> S_ALUWB
        check_outputs("S_ALUWB (addi)",
            3'b000, 2'b00, 2'b00, 2'b00, 1'b0, 3'b000, 1'b0, 1'b0, 1'b1, 1'b0);

        // ==================================================
        // TEST GROUP 10: JAL (ImmSrc = 3'b011 now)
        // ==================================================
        $display("\n--- TEST GROUP 10: JAL Path ---");
        do_reset();
        op     = 7'b1101111;
        funct3 = 3'b000;

        tick(); // -> S_DECODE
        tick(); // -> S_JAL
        check_outputs("S_JAL",
            3'b011, // ImmSrc (jal -> 011)
            2'b01,  // ALUSrcA = OldPC
            2'b10,  // ALUSrcB = 4
            2'b00,  // ResultSrc
            1'b0,   // AdrSrc
            3'b000, // ALUControl = add
            1'b0,   // IRWrite
            1'b1,   // PCWrite (PCUpdate)
            1'b0,   // RegWrite
            1'b0    // MemWrite
        );

        tick(); // -> S_ALUWB
        check_outputs("S_ALUWB (jal)",
            3'b011, 2'b00, 2'b00, 2'b00, 1'b0, 3'b000, 1'b0, 1'b0, 1'b1, 1'b0);

        // ==================================================
        // TEST GROUP 11: BEQ - not taken (Zero=0)
        // ==================================================
        $display("\n--- TEST GROUP 11: BEQ (not taken, Zero=0) ---");
        do_reset();
        op     = 7'b1100011;
        funct3 = 3'b000;
        Zero   = 1'b0;

        tick(); // -> S_DECODE
        tick(); // -> S_BEQ
        check_outputs("S_BEQ (Zero=0)",
            3'b010, // ImmSrc (beq -> 010)
            2'b10,  // ALUSrcA
            2'b00,  // ALUSrcB
            2'b00,  // ResultSrc
            1'b0,   // AdrSrc
            3'b001, // ALUControl = sub
            1'b0,   // IRWrite
            1'b0,   // PCWrite (Branch & ~Zero -> 0)
            1'b0,   // RegWrite
            1'b0    // MemWrite
        );

        // ==================================================
        // TEST GROUP 12: BEQ - taken (Zero=1)
        // ==================================================
        $display("\n--- TEST GROUP 12: BEQ (taken, Zero=1) ---");
        do_reset();
        op     = 7'b1100011;
        funct3 = 3'b000;
        Zero   = 1'b1;

        tick(); tick();
        check_outputs("S_BEQ (Zero=1)",
            3'b010, 2'b10, 2'b00, 2'b00, 1'b0, 3'b001,
            1'b0,   // IRWrite
            1'b1,   // PCWrite (Branch & Zero -> 1)
            1'b0, 1'b0);

        // ==================================================
        // TEST GROUP 13: Sequential LW then ADD
        // ==================================================
        $display("\n--- TEST GROUP 13: Sequential LW then ADD ---");
        do_reset();

        op = 7'b0000011; funct3 = 3'b010;
        tick(); tick(); tick(); tick();
        tick(); // back to S_FETCH

        op = 7'b0110011; funct3 = 3'b000; funct7b5 = 1'b0;
        check_outputs("S_FETCH (before add)",
            3'b000, 2'b00, 2'b10, 2'b10, 1'b0, 3'b000, 1'b1, 1'b1, 1'b0, 1'b0);

        tick();
        check_outputs("S_DECODE (add)",
            3'b000, 2'b01, 2'b01, 2'b00, 1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0);

        tick();
        check_outputs("S_EXECUTER (sequential add)",
            3'b000, 2'b10, 2'b00, 2'b00, 1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0);

        tick();
        check_outputs("S_ALUWB (sequential add)",
            3'b000, 2'b00, 2'b00, 2'b00, 1'b0, 3'b000, 1'b0, 1'b0, 1'b1, 1'b0);

        // ==================================================
        // SUMMARY
        // ==================================================
        $display("\n============================================");
        if (errors == 0)
            $display("  ALL %0d TESTS PASSED WITH 0 ERRORS!", test_num);
        else
            $display("  COMPLETED %0d TESTS WITH %0d ERRORS", test_num, errors);
        $display("============================================\n");

        $finish;
    end

    // Timeout
    initial begin
        #10000;
        $display("TIMEOUT: Simulation ran too long.");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("controller_tb.vcd");
        $dumpvars(0, controller_testbench);
    end

endmodule
