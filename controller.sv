// =====================================================================
// controller.sv - Multicycle RISC-V controller
// Contains: main FSM, ALU decoder, instruction decoder
// =====================================================================
module controller(input  logic       clk, reset,
                  input  logic [6:0] op,
                  input  logic [2:0] funct3,
                  input  logic       funct7b5,
                  input  logic       Zero,
                  output logic [2:0] ImmSrc,
                  output logic [1:0] ALUSrcA, ALUSrcB,
                  output logic [1:0] ResultSrc,
                  output logic       AdrSrc,
                  output logic [2:0] ALUControl,
                  output logic       IRWrite, PCWrite,
                  output logic       RegWrite, MemWrite);

    logic [1:0] ALUOp;
    logic       Branch, PCUpdate;

    // Main FSM
    mainfsm fsm(clk, reset, op, funct3, Zero,
                ALUSrcA, ALUSrcB, ResultSrc,
                AdrSrc, IRWrite, PCUpdate,
                RegWrite, MemWrite,
                Branch, ALUOp);

    // PCWrite logic: write PC if Branch & Zero, or unconditional PCUpdate
    assign PCWrite = (Branch & Zero) | PCUpdate;

    // ALU decoder
    aludec ad(op[5], funct3, funct7b5, ALUOp, ALUControl);

    // Instruction decoder for ImmSrc
    instrdec id(op, ImmSrc);
endmodule

// =====================================================================
// mainfsm.sv - Main multicycle FSM (Harris & Harris Fig. 7.50)
// =====================================================================
module mainfsm(input  logic       clk, reset,
               input  logic [6:0] op,
               input  logic [2:0] funct3,
               input  logic       Zero,
               output logic [1:0] ALUSrcA, ALUSrcB,
               output logic [1:0] ResultSrc,
               output logic       AdrSrc,
               output logic       IRWrite, PCUpdate,
               output logic       RegWrite, MemWrite,
               output logic       Branch,
               output logic [1:0] ALUOp);

    typedef enum logic [3:0] {
        S_FETCH    = 4'd0,
        S_DECODE   = 4'd1,
        S_MEMADR   = 4'd2,
        S_MEMREAD  = 4'd3,
        S_MEMWB    = 4'd4,
        S_MEMWRITE = 4'd5,
        S_EXECUTER = 4'd6,
        S_ALUWB    = 4'd7,
        S_EXECUTEI = 4'd8,
        S_JAL      = 4'd9,
        S_BEQ      = 4'd10
    } statetype;

    statetype state, nextstate;

    // State register
    always_ff @(posedge clk, posedge reset)
        if (reset) state <= S_FETCH;
        else       state <= nextstate;

    // Next state logic
    always_comb begin
        case (state)
            S_FETCH:    nextstate = S_DECODE;
            S_DECODE:   case (op)
                            7'b0000011: nextstate = S_MEMADR;    // lw
                            7'b0100011: nextstate = S_MEMADR;    // sw
                            7'b0110011: nextstate = S_EXECUTER;  // R-type
                            7'b0010011: nextstate = S_EXECUTEI;  // I-type ALU
                            7'b1101111: nextstate = S_JAL;       // jal
                            7'b1100011: nextstate = S_BEQ;       // beq
                            default:    nextstate = S_FETCH;
                        endcase
            S_MEMADR:   if (op[5]) nextstate = S_MEMWRITE;       // sw
                        else       nextstate = S_MEMREAD;         // lw
            S_MEMREAD:  nextstate = S_MEMWB;
            S_MEMWB:    nextstate = S_FETCH;
            S_MEMWRITE: nextstate = S_FETCH;
            S_EXECUTER: nextstate = S_ALUWB;
            S_EXECUTEI: nextstate = S_ALUWB;
            S_ALUWB:    nextstate = S_FETCH;
            S_JAL:      nextstate = S_ALUWB;
            S_BEQ:      nextstate = S_FETCH;
            default:    nextstate = S_FETCH;
        endcase
    end

    // Output logic
    always_comb begin
        // defaults
        ALUSrcA   = 2'b00;
        ALUSrcB   = 2'b00;
        ResultSrc = 2'b00;
        AdrSrc    = 1'b0;
        IRWrite   = 1'b0;
        PCUpdate  = 1'b0;
        RegWrite  = 1'b0;
        MemWrite  = 1'b0;
        Branch    = 1'b0;
        ALUOp     = 2'b00;

        case (state)
            S_FETCH: begin
                // Adr <= PC (AdrSrc=0); IRWrite=1 to latch instruction;
                // ALU computes PC+4 (SrcA=PC, SrcB=4, ALUOp=add);
                // Result = ALUResult (ResultSrc=10); PCUpdate=1
                AdrSrc    = 1'b0;
                IRWrite   = 1'b1;
                ALUSrcA   = 2'b00;   // PC
                ALUSrcB   = 2'b10;   // 4
                ALUOp     = 2'b00;   // add
                ResultSrc = 2'b10;   // ALUResult
                PCUpdate  = 1'b1;
            end
            S_DECODE: begin
                // Compute branch target = OldPC + Imm (in case it's a branch)
                ALUSrcA = 2'b01;  // OldPC
                ALUSrcB = 2'b01;  // ImmExt
                ALUOp   = 2'b00;  // add
            end
            S_MEMADR: begin
                // Effective address = A + Imm
                ALUSrcA = 2'b10;  // A
                ALUSrcB = 2'b01;  // ImmExt
                ALUOp   = 2'b00;  // add
            end
            S_MEMREAD: begin
                // Read memory: Adr = ALUOut (Result), AdrSrc=1
                ResultSrc = 2'b00;
                AdrSrc    = 1'b1;
            end
            S_MEMWB: begin
                // Writeback Data to register file
                ResultSrc = 2'b01;  // Data
                RegWrite  = 1'b1;
            end
            S_MEMWRITE: begin
                // Store: Adr = ALUOut, MemWrite=1
                ResultSrc = 2'b00;
                AdrSrc    = 1'b1;
                MemWrite  = 1'b1;
            end
            S_EXECUTER: begin
                // R-type: SrcA = A, SrcB = WriteData (RD2 latched)
                ALUSrcA = 2'b10;
                ALUSrcB = 2'b00;
                ALUOp   = 2'b10;  // R-type
            end
            S_EXECUTEI: begin
                // I-type ALU: SrcA = A, SrcB = ImmExt
                ALUSrcA = 2'b10;
                ALUSrcB = 2'b01;
                ALUOp   = 2'b10;  // funct3-based
            end
            S_ALUWB: begin
                // Writeback ALUOut to register file
                ResultSrc = 2'b00;
                RegWrite  = 1'b1;
            end
            S_JAL: begin
                // PC <- OldPC + Imm; rd <- OldPC + 4 (computed earlier)
                ALUSrcA   = 2'b01;  // OldPC
                ALUSrcB   = 2'b10;  // 4 (link return addr to be in ALUOut)
                ALUOp     = 2'b00;
                ResultSrc = 2'b00;  // branch target was already in ALUOut from decode
                PCUpdate  = 1'b1;
            end
            S_BEQ: begin
                // Branch: SrcA = A, SrcB = WriteData; ALU subtracts; if Zero, take branch
                ALUSrcA   = 2'b10;
                ALUSrcB   = 2'b00;
                ALUOp     = 2'b01;  // subtract
                ResultSrc = 2'b00;  // branch target in ALUOut
                Branch    = 1'b1;
            end
            default: ;
        endcase
    end
endmodule

// =====================================================================
// aludec.sv - ALU decoder
// =====================================================================
module aludec(input  logic       opb5,
              input  logic [2:0] funct3,
              input  logic       funct7b5,
              input  logic [1:0] ALUOp,
              output logic [2:0] ALUControl);

    logic RtypeSub;
    assign RtypeSub = funct7b5 & opb5;  // sub for R-type

    always_comb
        case (ALUOp)
            2'b00: ALUControl = 3'b000;  // add (lw, sw, jal, fetch, decode)
            2'b01: ALUControl = 3'b001;  // sub (beq)
            default: case (funct3)        // R-type or I-type ALU
                3'b000: if (RtypeSub) ALUControl = 3'b001; // sub
                        else          ALUControl = 3'b000; // add, addi
                3'b010: ALUControl = 3'b101;  // slt, slti
                3'b110: ALUControl = 3'b011;  // or, ori
                3'b111: ALUControl = 3'b010;  // and, andi
                default: ALUControl = 3'b000;
            endcase
        endcase
endmodule

// =====================================================================
// instrdec.sv - Instruction decoder, produces ImmSrc
// =====================================================================
module instrdec(input  logic [6:0] op,
                output logic [2:0] ImmSrc);
    always_comb
        case (op)
            7'b0110011: ImmSrc = 3'b000;  // R-type (no immediate; don't care)
            7'b0010011: ImmSrc = 3'b000;  // I-type ALU
            7'b0000011: ImmSrc = 3'b000;  // lw (I-type)
            7'b0100011: ImmSrc = 3'b001;  // sw (S-type)
            7'b1100011: ImmSrc = 3'b010;  // beq (B-type)
            7'b1101111: ImmSrc = 3'b011;  // jal (J-type)
            default:    ImmSrc = 3'b000;
        endcase
endmodule
