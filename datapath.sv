// =====================================================================
// datapath.sv - Multicycle RISC-V datapath (Harris & Harris Fig. 7.49)
// =====================================================================
module datapath(input  logic        clk, reset,
                input  logic        PCWrite, AdrSrc, IRWrite, RegWrite,
                input  logic [1:0]  ResultSrc, ALUSrcA, ALUSrcB,
                input  logic [2:0]  ImmSrc, ALUControl,
                output logic        Zero,
                output logic [31:0] Adr, WriteData,
                input  logic [31:0] ReadData,
                output logic [31:0] Instr);

    logic [31:0] PC, OldPC;
    logic [31:0] Data;            // Latched memory read data
    logic [31:0] RD1, RD2, A;     // Register file reads, A register
    logic [31:0] SrcA, SrcB;
    logic [31:0] ImmExt;
    logic [31:0] ALUResult, ALUOut;
    logic [31:0] Result;

    logic [4:0] A1, A2, A3;

    // PC register (enabled by PCWrite)
    flopenr #(32) pcreg(clk, reset, PCWrite, Result, PC);

    // Address mux: PC for instruction fetch, Result (ALUOut) for memory access
    mux2 #(32) adrmux(PC, Result, AdrSrc, Adr);

    // OldPC and Instruction register: both updated when IRWrite asserted
    flopenr #(32) oldpcreg(clk, reset, IRWrite, PC,       OldPC);
    flopenr #(32) irreg   (clk, reset, IRWrite, ReadData, Instr);

    // Data register (always latches memory read data)
    flopr #(32) datareg(clk, reset, ReadData, Data);

    // Register file
    assign A1 = Instr[19:15];
    assign A2 = Instr[24:20];
    assign A3 = Instr[11:7];
    regfile rf(clk, RegWrite, A1, A2, A3, Result, RD1, RD2);

    // A register and WriteData register (latch RD1, RD2 after Decode)
    flopr #(32) areg (clk, reset, RD1, A);
    flopr #(32) wdreg(clk, reset, RD2, WriteData);

    // Immediate extender
    extend ext(Instr[31:7], ImmSrc, ImmExt);

    // ALU source muxes
    mux3 #(32) srcamux(PC,        OldPC,  A,       ALUSrcA, SrcA);
    mux3 #(32) srcbmux(WriteData, ImmExt, 32'd4,   ALUSrcB, SrcB);

    // ALU
    alu alu(SrcA, SrcB, ALUControl, ALUResult, Zero);

    // ALUOut register
    flopr #(32) aluoutreg(clk, reset, ALUResult, ALUOut);

    // Result mux:
    //   00 -> ALUOut    (R-type / I-type ALU result writeback, branch target)
    //   01 -> Data      (lw memory load)
    //   10 -> ALUResult (PC+4 -> directly into PC during Fetch)
    mux3 #(32) resultmux(ALUOut, Data, ALUResult, ResultSrc, Result);
endmodule
