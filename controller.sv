
// ============================================================
// TOP-LEVEL: controller
// ============================================================
module controller(
    input  logic        clk,
    input  logic        reset,
    input  logic [6:0]  op,
    input  logic [2:0]  funct3,
    input  logic        funct7b5,
    input  logic        zero,
    output logic [1:0]  immsrc,
    output logic [1:0]  alusrca, alusrcb,
    output logic [1:0]  resultsrc,
    output logic        adrsrc,
    output logic [2:0]  alucontrol,
    output logic        irwrite, pcwrite,
    output logic        regwrite, memwrite
);

    logic [1:0] aluop;
    logic       branch, pcupdate;

    // PCWrite = PCUpdate OR (Branch AND Zero)
    assign pcwrite = pcupdate | (branch & zero);

    // Sub-module instantiations
    maindec maindec(
        .clk      (clk),
        .reset    (reset),
        .op       (op),
        .pcupdate (pcupdate),
        .branch   (branch),
        .regwrite (regwrite),
        .memwrite (memwrite),
        .irwrite  (irwrite),
        .resultsrc(resultsrc),
        .alusrcb  (alusrcb),
        .alusrca  (alusrca),
        .adrsrc   (adrsrc),
        .aluop    (aluop)
    );

    aludec aludec(
        .opb5      (op[5]),
        .funct3    (funct3),
        .funct7b5  (funct7b5),
        .ALUOp     (aluop),
        .ALUControl(alucontrol)
    );

    instrdec instrdec(
        .op    (op),
        .ImmSrc(immsrc)
    );

endmodule


// ============================================================
// MAIN FSM (Main Decoder)
// ============================================================
module maindec(
    input  logic        clk,
    input  logic        reset,
    input  logic [6:0]  op,
    output logic        pcupdate,
    output logic        branch,
    output logic        regwrite,
    output logic        memwrite,
    output logic        irwrite,
    output logic [1:0]  resultsrc,
    output logic [1:0]  alusrcb,
    output logic [1:0]  alusrca,
    output logic        adrsrc,
    output logic [1:0]  aluop
);

    // State encoding
    typedef enum logic [3:0] {
        S0_FETCH    = 4'd0,
        S1_DECODE   = 4'd1,
        S2_MEMADR   = 4'd2,
        S3_MEMREAD  = 4'd3,
        S4_MEMWB    = 4'd4,
        S5_MEMWRITE = 4'd5,
        S6_EXECUTER = 4'd6,
        S7_ALUWB    = 4'd7,
        S8_EXECUTEI = 4'd8,
        S9_JAL      = 4'd9,
        S10_BEQ     = 4'd10
    } statetype;

    statetype state, nextstate;

    // -------------------------------------------------------
    // State Register (sequential)
    // -------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) state <= S0_FETCH;
        else       state <= nextstate;
    end

    // -------------------------------------------------------
    // Next-State Logic (combinational)
    // -------------------------------------------------------
    always_comb begin
        case (state)
            S0_FETCH:   nextstate = S1_DECODE;

            S1_DECODE:
                case (op)
                    7'b0000011,
                    7'b0100011: nextstate = S2_MEMADR;   // lw / sw
                    7'b0110011: nextstate = S6_EXECUTER;  // R-type
                    7'b0010011: nextstate = S8_EXECUTEI;  // I-type ALU
                    7'b1101111: nextstate = S9_JAL;       // jal
                    7'b1100011: nextstate = S10_BEQ;      // beq
                    default:    nextstate = S0_FETCH;     // unknown -> re-fetch
                endcase

            S2_MEMADR:
                case (op)
                    7'b0000011: nextstate = S3_MEMREAD;   // lw
                    7'b0100011: nextstate = S5_MEMWRITE;  // sw
                    default:    nextstate = S0_FETCH;
                endcase

            S3_MEMREAD:  nextstate = S4_MEMWB;
            S4_MEMWB:    nextstate = S0_FETCH;
            S5_MEMWRITE: nextstate = S0_FETCH;
            S6_EXECUTER: nextstate = S7_ALUWB;
            S7_ALUWB:    nextstate = S0_FETCH;
            S8_EXECUTEI: nextstate = S7_ALUWB;
            S9_JAL:      nextstate = S7_ALUWB;
            S10_BEQ:     nextstate = S0_FETCH;
            default:     nextstate = S0_FETCH;
        endcase
    end

    // -------------------------------------------------------
    // Output Logic (combinational)
    // All don't-care outputs are set to 0 
    // -------------------------------------------------------
    always_comb begin
        // Default all outputs to 0
        pcupdate  = 1'b0;
        branch    = 1'b0;
        regwrite  = 1'b0;
        memwrite  = 1'b0;
        irwrite   = 1'b0;
        resultsrc = 2'b00;
        alusrcb   = 2'b00;
        alusrca   = 2'b00;
        adrsrc    = 1'b0;
        aluop     = 2'b00;

        case (state)
            // S0: Fetch
            // AdrSrc=0, IRWrite, ALUSrcA=00, ALUSrcB=10, ALUOp=00,
            // ResultSrc=10, PCUpdate
            S0_FETCH: begin
                adrsrc    = 1'b0;
                irwrite   = 1'b1;
                alusrca   = 2'b00;
                alusrcb   = 2'b10;
                aluop     = 2'b00;
                resultsrc = 2'b10;
                pcupdate  = 1'b1;
            end

            // S1: Decode
            // ALUSrcA=01, ALUSrcB=01, ALUOp=00
            S1_DECODE: begin
                alusrca = 2'b01;
                alusrcb = 2'b01;
                aluop   = 2'b00;
            end

            // S2: MemAdr
            // ALUSrcA=10, ALUSrcB=01, ALUOp=00
            S2_MEMADR: begin
                alusrca = 2'b10;
                alusrcb = 2'b01;
                aluop   = 2'b00;
            end

            // S3: MemRead
            // ResultSrc=00, AdrSrc=1
            S3_MEMREAD: begin
                resultsrc = 2'b00;
                adrsrc    = 1'b1;
            end

            // S4: MemWB
            // ResultSrc=01, RegWrite
            S4_MEMWB: begin
                resultsrc = 2'b01;
                regwrite  = 1'b1;
            end

            // S5: MemWrite
            // ResultSrc=00, AdrSrc=1, MemWrite
            S5_MEMWRITE: begin
                resultsrc = 2'b00;
                adrsrc    = 1'b1;
                memwrite  = 1'b1;
            end

            // S6: ExecuteR
            // ALUSrcA=10, ALUSrcB=00, ALUOp=10
            S6_EXECUTER: begin
                alusrca = 2'b10;
                alusrcb = 2'b00;
                aluop   = 2'b10;
            end

            // S7: ALUWB
            // ResultSrc=00, RegWrite
            S7_ALUWB: begin
                resultsrc = 2'b00;
                regwrite  = 1'b1;
            end

            // S8: ExecuteI
            // ALUSrcA=10, ALUSrcB=01, ALUOp=10
            S8_EXECUTEI: begin
                alusrca = 2'b10;
                alusrcb = 2'b01;
                aluop   = 2'b10;
            end

            // S9: JAL
            // ALUSrcA=01, ALUSrcB=10, ALUOp=00, ResultSrc=00, PCUpdate
            S9_JAL: begin
                alusrca   = 2'b01;
                alusrcb   = 2'b10;
                aluop     = 2'b00;
                resultsrc = 2'b00;
                pcupdate  = 1'b1;
            end

            // S10: BEQ
            // ALUSrcA=10, ALUSrcB=00, ALUOp=01, ResultSrc=00, Branch
            S10_BEQ: begin
                alusrca   = 2'b10;
                alusrcb   = 2'b00;
                aluop     = 2'b01;
                resultsrc = 2'b00;
                branch    = 1'b1;
            end

            default: begin
                // All outputs remain 0 (set by defaults above)
            end
        endcase
    end

endmodule


// ============================================================
// ALU DECODER
// ============================================================
module aludec(
    input  logic        opb5,
    input  logic [2:0]  funct3,
    input  logic        funct7b5,
    input  logic [1:0]  ALUOp,
    output logic [2:0]  ALUControl
);

    logic RtypeSub;
    assign RtypeSub = funct7b5 & opb5; // TRUE for R-type subtract

    always_comb
        case (ALUOp)
            2'b00: ALUControl = 3'b000; // addition (lw/sw)
            2'b01: ALUControl = 3'b001; // subtraction (beq)
            default: case (funct3)      // R-type or I-type ALU
                3'b000: if (RtypeSub)
                            ALUControl = 3'b001; // sub
                        else
                            ALUControl = 3'b000; // add / addi
                3'b010: ALUControl = 3'b101; // slt / slti
                3'b110: ALUControl = 3'b011; // or / ori
                3'b111: ALUControl = 3'b010; // and / andi
                default: ALUControl = 3'b000; // don't care -> 0
            endcase
        endcase

endmodule


// ============================================================
// INSTRUCTION DECODER
// ============================================================
module instrdec(
    input  logic [6:0] op,
    output logic [1:0] ImmSrc
);

    always_comb
        case (op)
            7'b0110011: ImmSrc = 2'b00; // R-type (don't care -> 0)
            7'b0010011: ImmSrc = 2'b00; // I-type ALU
            7'b0000011: ImmSrc = 2'b00; // lw
            7'b0100011: ImmSrc = 2'b01; // sw
            7'b1100011: ImmSrc = 2'b10; // beq
            7'b1101111: ImmSrc = 2'b11; // jal
            default:    ImmSrc = 2'b00; // don't care -> 0
        endcase

endmodule