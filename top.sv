
// =====================================================================
// top.sv - Top-level multicycle RISC-V processor
// =====================================================================
module top(input  logic        clk, reset,
           output logic [31:0] WriteData, DataAdr,
           output logic        MemWrite);

    logic [31:0] ReadData;

    // Processor (riscv = controller + datapath) connected to unified memory
    riscv riscv(
        .clk(clk), .reset(reset),
        .MemWrite(MemWrite),
        .Adr(DataAdr),
        .WriteData(WriteData),
        .ReadData(ReadData)
    );

    mem mem(
        .clk(clk),
        .we(MemWrite),
        .a(DataAdr),
        .wd(WriteData),
        .rd(ReadData)
    );
endmodule

// =====================================================================
// mem.sv - Unified instruction/data memory
// =====================================================================
module mem(input  logic        clk, we,
           input  logic [31:0] a, wd,
           output logic [31:0] rd);

    logic [31:0] RAM[63:0];

    initial $readmemh("C:/Users/musta/Documents/GitHub/OMNI-V/TENIZM/tenizm_msi/PRE3/riscvtest.txt", RAM);

    assign rd = RAM[a[31:2]]; // word aligned read

    always_ff @(posedge clk)
        if (we) RAM[a[31:2]] <= wd;
endmodule

// =====================================================================
// riscv.sv - Processor: controller + datapath
// =====================================================================
module riscv(input  logic        clk, reset,
             output logic        MemWrite,
             output logic [31:0] Adr, WriteData,
             input  logic [31:0] ReadData);

    logic        Zero;
    logic        PCWrite, AdrSrc, IRWrite, RegWrite;
    logic [1:0]  ResultSrc, ALUSrcA, ALUSrcB;
    logic [2:0]  ALUControl, ImmSrc;
    logic [31:0] Instr;

    controller c(
        .clk(clk), .reset(reset),
        .op(Instr[6:0]),
        .funct3(Instr[14:12]),
        .funct7b5(Instr[30]),
        .Zero(Zero),
        .ImmSrc(ImmSrc),
        .ALUSrcA(ALUSrcA), .ALUSrcB(ALUSrcB),
        .ResultSrc(ResultSrc),
        .AdrSrc(AdrSrc),
        .ALUControl(ALUControl),
        .IRWrite(IRWrite), .PCWrite(PCWrite),
        .RegWrite(RegWrite), .MemWrite(MemWrite)
    );

    datapath dp(
        .clk(clk), .reset(reset),
        .PCWrite(PCWrite), .AdrSrc(AdrSrc),
        .IRWrite(IRWrite), .RegWrite(RegWrite),
        .ResultSrc(ResultSrc),
        .ALUSrcA(ALUSrcA), .ALUSrcB(ALUSrcB),
        .ImmSrc(ImmSrc),
        .ALUControl(ALUControl),
        .Zero(Zero),
        .Adr(Adr), .WriteData(WriteData),
        .ReadData(ReadData),
        .Instr(Instr)
    );
endmodule
