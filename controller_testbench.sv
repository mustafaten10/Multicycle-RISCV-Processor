// ============================================================
// Tests all FSM states and instruction types
// ============================================================

`timescale 1ns/1ps

module controller_testbench();

    // -------------------------------------------------------
    // DUT Signals
    // -------------------------------------------------------
    logic        clk, reset;
    logic [6:0]  op;
    logic [2:0]  funct3;
    logic        funct7b5;
    logic        zero;

    logic [1:0]  immsrc;
    logic [1:0]  alusrca, alusrcb;
    logic [1:0]  resultsrc;
    logic        adrsrc;
    logic [2:0]  alucontrol;
    logic        irwrite, pcwrite;
    logic        regwrite, memwrite;

    // -------------------------------------------------------
    // Test tracking
    // -------------------------------------------------------
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
        .zero      (zero),
        .immsrc    (immsrc),
        .alusrca   (alusrca),
        .alusrcb   (alusrcb),
        .resultsrc (resultsrc),
        .adrsrc    (adrsrc),
        .alucontrol(alucontrol),
        .irwrite   (irwrite),
        .pcwrite   (pcwrite),
        .regwrite  (regwrite),
        .memwrite  (memwrite)
    );

    // -------------------------------------------------------
    // Clock Generation: 10ns period
    // -------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------
    // Task: Check outputs and report
    // -------------------------------------------------------
    task check_outputs;
        input string          state_name;
        input logic [1:0]     exp_immsrc;
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
            if (immsrc     !== exp_immsrc     ||
                alusrca    !== exp_alusrca    ||
                alusrcb    !== exp_alusrcb    ||
                resultsrc  !== exp_resultsrc  ||
                adrsrc     !== exp_adrsrc     ||
                alucontrol !== exp_alucontrol ||
                irwrite    !== exp_irwrite    ||
                pcwrite    !== exp_pcwrite    ||
                regwrite   !== exp_regwrite   ||
                memwrite   !== exp_memwrite) begin

                $display("FAILED Test %0d [%s] at time %0t", test_num, state_name, $time);
                $display("  immsrc    : got %b, expected %b", immsrc,     exp_immsrc);
                $display("  alusrca   : got %b, expected %b", alusrca,    exp_alusrca);
                $display("  alusrcb   : got %b, expected %b", alusrcb,    exp_alusrcb);
                $display("  resultsrc : got %b, expected %b", resultsrc,  exp_resultsrc);
                $display("  adrsrc    : got %b, expected %b", adrsrc,     exp_adrsrc);
                $display("  alucontrol: got %b, expected %b", alucontrol, exp_alucontrol);
                $display("  irwrite   : got %b, expected %b", irwrite,    exp_irwrite);
                $display("  pcwrite   : got %b, expected %b", pcwrite,    exp_pcwrite);
                $display("  regwrite  : got %b, expected %b", regwrite,   exp_regwrite);
                $display("  memwrite  : got %b, expected %b", memwrite,   exp_memwrite);
                errors = errors + 1;
            end else begin
                $display("PASSED Test %0d [%s]", test_num, state_name);
            end
        end
    endtask

    // -------------------------------------------------------
    // Helper: apply reset and reach S0 (Fetch)
    // -------------------------------------------------------
    task do_reset;
        begin
            reset = 1;
            @(posedge clk); #1;
            reset = 0;
        end
    endtask

    // -------------------------------------------------------
    // Helper: advance one clock cycle
    // -------------------------------------------------------
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

        // Default inputs
        op       = 7'b0000000;
        funct3   = 3'b000;
        funct7b5 = 0;
        zero     = 0;

        $display("============================================");
        $display("  ELE432 HW2 Controller Testbench Starting");
        $display("============================================");

        // ==================================================
        // TEST GROUP 1: RESET -> S0 (Fetch)
        // Expected: AdrSrc=0, IRWrite=1, ALUSrcA=00,
        //           ALUSrcB=10, ALUOp=00 -> ALUControl=000,
        //           ResultSrc=10, PCUpdate -> PCWrite=1
        // ImmSrc=00 (op=0000000 -> default)
        // ==================================================
        $display("\n--- TEST GROUP 1: Reset -> S0 Fetch ---");
        do_reset();
        // After reset, controller is in S0_FETCH
        // op=0000000 is not a valid instruction, immsrc=00 (default)
        check_outputs("S0_FETCH",
            2'b00,  // immsrc
            2'b00,  // alusrca
            2'b10,  // alusrcb
            2'b10,  // resultsrc
            1'b0,   // adrsrc
            3'b000, // alucontrol
            1'b1,   // irwrite
            1'b1,   // pcwrite  (PCUpdate=1)
            1'b0,   // regwrite
            1'b0    // memwrite
        );

        // ==================================================
        // TEST GROUP 2: LW instruction path
        // op=0000011 (lw), funct3=000
        // S0->S1->S2->S3->S4->S0
        // ==================================================
        $display("\n--- TEST GROUP 2: LW Path ---");
        do_reset();
        op     = 7'b0000011; // lw
        funct3 = 3'b000;

        // S0: Fetch
        check_outputs("S0_FETCH (lw)",
            2'b00,  // immsrc (lw -> 00)
            2'b00,  // alusrca
            2'b10,  // alusrcb
            2'b10,  // resultsrc
            1'b0,   // adrsrc
            3'b000, // alucontrol
            1'b1,   // irwrite
            1'b1,   // pcwrite
            1'b0,   // regwrite
            1'b0    // memwrite
        );

        tick(); // -> S1: Decode
        check_outputs("S1_DECODE (lw)",
            2'b00,  // immsrc
            2'b01,  // alusrca
            2'b01,  // alusrcb
            2'b00,  // resultsrc
            1'b0,   // adrsrc
            3'b000, // alucontrol (ALUOp=00 -> add)
            1'b0,   // irwrite
            1'b0,   // pcwrite
            1'b0,   // regwrite
            1'b0    // memwrite
        );

        tick(); // -> S2: MemAdr
        check_outputs("S2_MEMADR (lw)",
            2'b00,  // immsrc
            2'b10,  // alusrca
            2'b01,  // alusrcb
            2'b00,  // resultsrc
            1'b0,   // adrsrc
            3'b000, // alucontrol (ALUOp=00 -> add)
            1'b0,   // irwrite
            1'b0,   // pcwrite
            1'b0,   // regwrite
            1'b0    // memwrite
        );

        tick(); // -> S3: MemRead
        check_outputs("S3_MEMREAD (lw)",
            2'b00,  // immsrc
            2'b00,  // alusrca (don't care -> 0)
            2'b00,  // alusrcb (don't care -> 0)
            2'b00,  // resultsrc
            1'b1,   // adrsrc
            3'b000, // alucontrol
            1'b0,   // irwrite
            1'b0,   // pcwrite
            1'b0,   // regwrite
            1'b0    // memwrite
        );

        tick(); // -> S4: MemWB
        check_outputs("S4_MEMWB (lw)",
            2'b00,  // immsrc
            2'b00,  // alusrca (don't care -> 0)
            2'b00,  // alusrcb (don't care -> 0)
            2'b01,  // resultsrc
            1'b0,   // adrsrc
            3'b000, // alucontrol
            1'b0,   // irwrite
            1'b0,   // pcwrite
            1'b1,   // regwrite
            1'b0    // memwrite
        );

        tick(); // -> S0: Fetch again
        check_outputs("S0_FETCH (after lw)",
            2'b00,  // immsrc
            2'b00,  // alusrca
            2'b10,  // alusrcb
            2'b10,  // resultsrc
            1'b0,   // adrsrc
            3'b000, // alucontrol
            1'b1,   // irwrite
            1'b1,   // pcwrite
            1'b0,   // regwrite
            1'b0    // memwrite
        );

        // ==================================================
        // TEST GROUP 3: SW instruction path
        // op=0100011 (sw)
        // S0->S1->S2->S5->S0
        // ==================================================
        $display("\n--- TEST GROUP 3: SW Path ---");
        do_reset();
        op     = 7'b0100011; // sw
        funct3 = 3'b010;

        tick(); // S0->S1
        tick(); // S1->S2
        tick(); // S2->S5: MemWrite
        check_outputs("S5_MEMWRITE (sw)",
            2'b01,  // immsrc (sw -> 01)
            2'b00,  // alusrca
            2'b00,  // alusrcb
            2'b00,  // resultsrc
            1'b1,   // adrsrc
            3'b000, // alucontrol
            1'b0,   // irwrite
            1'b0,   // pcwrite
            1'b0,   // regwrite
            1'b1    // memwrite
        );

        // ==================================================
        // TEST GROUP 4: R-type ADD instruction
        // op=0110011, funct3=000, funct7b5=0 (add)
        // S0->S1->S6->S7->S0
        // ==================================================
        $display("\n--- TEST GROUP 4: R-type ADD Path ---");
        do_reset();
        op       = 7'b0110011; // R-type
        funct3   = 3'b000;
        funct7b5 = 1'b0;       // add (not sub)

        tick(); // S0->S1
        tick(); // S1->S6: ExecuteR
        check_outputs("S6_EXECUTER (add)",
            2'b00,  // immsrc (R-type -> 00)
            2'b10,  // alusrca
            2'b00,  // alusrcb
            2'b00,  // resultsrc
            1'b0,   // adrsrc
            3'b000, // alucontrol (ALUOp=10, funct3=000, RtypeSub=0 -> add=000)
            1'b0,   // irwrite
            1'b0,   // pcwrite
            1'b0,   // regwrite
            1'b0    // memwrite
        );

        tick(); // S6->S7: ALUWB
        check_outputs("S7_ALUWB (add)",
            2'b00,  // immsrc
            2'b00,  // alusrca
            2'b00,  // alusrcb
            2'b00,  // resultsrc
            1'b0,   // adrsrc
            3'b000, // alucontrol
            1'b0,   // irwrite
            1'b0,   // pcwrite
            1'b1,   // regwrite
            1'b0    // memwrite
        );

        // ==================================================
        // TEST GROUP 5: R-type SUB instruction
        // op=0110011, funct3=000, funct7b5=1 (sub)
        // ==================================================
        $display("\n--- TEST GROUP 5: R-type SUB Path ---");
        do_reset();
        op       = 7'b0110011;
        funct3   = 3'b000;
        funct7b5 = 1'b1; // sub

        tick(); // S0->S1
        tick(); // S1->S6: ExecuteR
        check_outputs("S6_EXECUTER (sub)",
            2'b00,  // immsrc
            2'b10,  // alusrca
            2'b00,  // alusrcb
            2'b00,  // resultsrc
            1'b0,   // adrsrc
            3'b001, // alucontrol (ALUOp=10, funct3=000, RtypeSub=1 -> sub=001)
            1'b0,   // irwrite
            1'b0,   // pcwrite
            1'b0,   // regwrite
            1'b0    // memwrite
        );

        // ==================================================
        // TEST GROUP 6: R-type AND (funct3=111)
        // ==================================================
        $display("\n--- TEST GROUP 6: R-type AND ---");
        do_reset();
        op       = 7'b0110011;
        funct3   = 3'b111; // and
        funct7b5 = 1'b0;

        tick(); tick();
        check_outputs("S6_EXECUTER (and)",
            2'b00,  // immsrc
            2'b10,  // alusrca
            2'b00,  // alusrcb
            2'b00,  // resultsrc
            1'b0,   // adrsrc
            3'b010, // alucontrol (and=010)
            1'b0,   // irwrite
            1'b0,   // pcwrite
            1'b0,   // regwrite
            1'b0    // memwrite
        );

        // ==================================================
        // TEST GROUP 7: R-type OR (funct3=110)
        // ==================================================
        $display("\n--- TEST GROUP 7: R-type OR ---");
        do_reset();
        op       = 7'b0110011;
        funct3   = 3'b110; // or
        funct7b5 = 1'b0;

        tick(); tick();
        check_outputs("S6_EXECUTER (or)",
            2'b00,  // immsrc
            2'b10,  // alusrca
            2'b00,  // alusrcb
            2'b00,  // resultsrc
            1'b0,   // adrsrc
            3'b011, // alucontrol (or=011)
            1'b0,   // irwrite
            1'b0,   // pcwrite
            1'b0,   // regwrite
            1'b0    // memwrite
        );

        // ==================================================
        // TEST GROUP 8: R-type SLT (funct3=010)
        // ==================================================
        $display("\n--- TEST GROUP 8: R-type SLT ---");
        do_reset();
        op       = 7'b0110011;
        funct3   = 3'b010; // slt
        funct7b5 = 1'b0;

        tick(); tick();
        check_outputs("S6_EXECUTER (slt)",
            2'b00,  // immsrc
            2'b10,  // alusrca
            2'b00,  // alusrcb
            2'b00,  // resultsrc
            1'b0,   // adrsrc
            3'b101, // alucontrol (slt=101)
            1'b0,   // irwrite
            1'b0,   // pcwrite
            1'b0,   // regwrite
            1'b0    // memwrite
        );

        // ==================================================
        // TEST GROUP 9: I-type ALU (ADDI)
        // op=0010011, funct3=000, funct7b5=0
        // S0->S1->S8->S7->S0
        // ==================================================
        $display("\n--- TEST GROUP 9: I-type ADDI Path ---");
        do_reset();
        op       = 7'b0010011; // I-type ALU
        funct3   = 3'b000;
        funct7b5 = 1'b0;

        tick(); // S0->S1
        tick(); // S1->S8: ExecuteI
        check_outputs("S8_EXECUTEI (addi)",
            2'b00,  // immsrc (I-type -> 00)
            2'b10,  // alusrca
            2'b01,  // alusrcb
            2'b00,  // resultsrc
            1'b0,   // adrsrc
            3'b000, // alucontrol (ALUOp=10, funct3=000, RtypeSub=0->add)
            1'b0,   // irwrite
            1'b0,   // pcwrite
            1'b0,   // regwrite
            1'b0    // memwrite
        );

        tick(); // S8->S7: ALUWB
        check_outputs("S7_ALUWB (addi)",
            2'b00,  // immsrc
            2'b00,  // alusrca
            2'b00,  // alusrcb
            2'b00,  // resultsrc
            1'b0,   // adrsrc
            3'b000, // alucontrol
            1'b0,   // irwrite
            1'b0,   // pcwrite
            1'b1,   // regwrite
            1'b0    // memwrite
        );

        // ==================================================
        // TEST GROUP 10: JAL instruction
        // op=1101111
        // S0->S1->S9->S7->S0
        // ==================================================
        $display("\n--- TEST GROUP 10: JAL Path ---");
        do_reset();
        op     = 7'b1101111; // jal
        funct3 = 3'b000;

        tick(); // S0->S1
        tick(); // S1->S9: JAL
        check_outputs("S9_JAL",
            2'b11,  // immsrc (jal -> 11)
            2'b01,  // alusrca
            2'b10,  // alusrcb
            2'b00,  // resultsrc
            1'b0,   // adrsrc
            3'b000, // alucontrol (ALUOp=00 -> add)
            1'b0,   // irwrite
            1'b1,   // pcwrite (PCUpdate=1)
            1'b0,   // regwrite
            1'b0    // memwrite
        );

        tick(); // S9->S7: ALUWB
        check_outputs("S7_ALUWB (jal)",
            2'b11,  // immsrc
            2'b00,  // alusrca
            2'b00,  // alusrcb
            2'b00,  // resultsrc
            1'b0,   // adrsrc
            3'b000, // alucontrol
            1'b0,   // irwrite
            1'b0,   // pcwrite
            1'b1,   // regwrite
            1'b0    // memwrite
        );

        // ==================================================
        // TEST GROUP 11: BEQ - branch NOT taken (zero=0)
        // op=1100011, zero=0
        // S0->S1->S10->S0
        // ==================================================
        $display("\n--- TEST GROUP 11: BEQ (not taken, zero=0) ---");
        do_reset();
        op     = 7'b1100011; // beq
        funct3 = 3'b000;
        zero   = 1'b0;

        tick(); // S0->S1
        tick(); // S1->S10: BEQ
        check_outputs("S10_BEQ (zero=0)",
            2'b10,  // immsrc (beq -> 10)
            2'b10,  // alusrca
            2'b00,  // alusrcb
            2'b00,  // resultsrc
            1'b0,   // adrsrc
            3'b001, // alucontrol (ALUOp=01 -> sub)
            1'b0,   // irwrite
            1'b0,   // pcwrite  (Branch=1 & zero=0 -> 0; PCUpdate=0)
            1'b0,   // regwrite
            1'b0    // memwrite
        );

        // ==================================================
        // TEST GROUP 12: BEQ - branch TAKEN (zero=1)
        // ==================================================
        $display("\n--- TEST GROUP 12: BEQ (taken, zero=1) ---");
        do_reset();
        op     = 7'b1100011; // beq
        funct3 = 3'b000;
        zero   = 1'b1;

        tick(); // S0->S1
        tick(); // S1->S10: BEQ
        check_outputs("S10_BEQ (zero=1)",
            2'b10,  // immsrc
            2'b10,  // alusrca
            2'b00,  // alusrcb
            2'b00,  // resultsrc
            1'b0,   // adrsrc
            3'b001, // alucontrol (sub)
            1'b0,   // irwrite
            1'b1,   // pcwrite  (Branch=1 & zero=1 -> 1)
            1'b0,   // regwrite
            1'b0    // memwrite
        );

        // ==================================================
        // TEST GROUP 13: Multiple instructions in sequence
        // lw followed by add (no reset between)
        // ==================================================
        $display("\n--- TEST GROUP 13: Sequential LW then ADD ---");
        do_reset();

        // -- LW: S0->S1->S2->S3->S4->S0
        op = 7'b0000011; funct3 = 3'b000;
        tick(); tick(); tick(); tick(); // S1, S2, S3, S4
        tick(); // back to S0

        // -- Now ADD: keep clock running with R-type op
        op = 7'b0110011; funct3 = 3'b000; funct7b5 = 1'b0;
        // currently in S0 Fetch
        check_outputs("S0_FETCH (before add)",
            2'b00, 2'b00, 2'b10, 2'b10, 1'b0, 3'b000, 1'b1, 1'b1, 1'b0, 1'b0);

        tick(); // S0->S1 Decode
        check_outputs("S1_DECODE (add)",
            2'b00, 2'b01, 2'b01, 2'b00, 1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0);

        tick(); // S1->S6 ExecuteR
        check_outputs("S6_EXECUTER (sequential add)",
            2'b00, 2'b10, 2'b00, 2'b00, 1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0);

        tick(); // S6->S7 ALUWB
        check_outputs("S7_ALUWB (sequential add)",
            2'b00, 2'b00, 2'b00, 2'b00, 1'b0, 3'b000, 1'b0, 1'b0, 1'b1, 1'b0);

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

    // -------------------------------------------------------
    // Timeout watchdog (safety net)
    // -------------------------------------------------------
    initial begin
        #10000;
        $display("TIMEOUT: Simulation ran too long.");
        $finish;
    end

    // -------------------------------------------------------
    // Waveform dump (for GTKWave / Questa)
    // -------------------------------------------------------
    initial begin
        $dumpfile("controller_tb.vcd");
        $dumpvars(0, controller_testbench);
    end

endmodule