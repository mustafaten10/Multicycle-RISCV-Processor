// =====================================================================
// blocks.sv - Reusable building blocks
// =====================================================================

// ---- Register file: 3-port (2 read, 1 write), x0 hardwired to 0 ----
module regfile(input  logic        clk,
               input  logic        we3,
               input  logic [4:0]  a1, a2, a3,
               input  logic [31:0] wd3,
               output logic [31:0] rd1, rd2);

    logic [31:0] rf[31:0];

    // Write on rising edge of clk if we3 (and a3 != 0)
    always_ff @(posedge clk)
        if (we3 && (a3 != 5'b0)) rf[a3] <= wd3;

    assign rd1 = (a1 != 5'b0) ? rf[a1] : 32'b0;
    assign rd2 = (a2 != 5'b0) ? rf[a2] : 32'b0;
endmodule

// ---- ALU ----
module alu(input  logic [31:0] a, b,
           input  logic [2:0]  alucontrol,
           output logic [31:0] result,
           output logic        zero);

    logic [31:0] sum;
    logic        isAddSub;

    assign isAddSub = (alucontrol == 3'b000) | (alucontrol == 3'b001);
    assign sum = a + (alucontrol[0] ? ~b + 32'd1 : b);

    always_comb
        case (alucontrol)
            3'b000: result = sum;                       // add
            3'b001: result = sum;                       // sub
            3'b010: result = a & b;                     // and
            3'b011: result = a | b;                     // or
            3'b101: result = {31'b0, sum[31]};          // slt (signed)
            default: result = 32'b0;
        endcase

    assign zero = (result == 32'b0);
endmodule

// ---- Immediate extender ----
module extend(input  logic [31:7] instr,
              input  logic [2:0]  immsrc,
              output logic [31:0] immext);

    always_comb
        case (immsrc)
            // I-type
            3'b000: immext = {{20{instr[31]}}, instr[31:20]};
            // S-type (stores)
            3'b001: immext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            // B-type (branches)
            3'b010: immext = {{20{instr[31]}}, instr[7], instr[30:25],
                              instr[11:8], 1'b0};
            // J-type (jal)
            3'b011: immext = {{12{instr[31]}}, instr[19:12], instr[20],
                              instr[30:21], 1'b0};
            default: immext = 32'b0;
        endcase
endmodule

// ---- Resettable D flip-flop ----
module flopr #(parameter WIDTH = 8)
              (input  logic             clk, reset,
               input  logic [WIDTH-1:0] d,
               output logic [WIDTH-1:0] q);

    always_ff @(posedge clk, posedge reset)
        if (reset) q <= 0;
        else       q <= d;
endmodule

// ---- Resettable D flip-flop with enable ----
module flopenr #(parameter WIDTH = 8)
                (input  logic             clk, reset, en,
                 input  logic [WIDTH-1:0] d,
                 output logic [WIDTH-1:0] q);

    always_ff @(posedge clk, posedge reset)
        if (reset)   q <= 0;
        else if (en) q <= d;
endmodule

// ---- 2:1 mux ----
module mux2 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1,
              input  logic             s,
              output logic [WIDTH-1:0] y);
    assign y = s ? d1 : d0;
endmodule

// ---- 3:1 mux ----
module mux3 #(parameter WIDTH = 8)
             (input  logic [WIDTH-1:0] d0, d1, d2,
              input  logic [1:0]       s,
              output logic [WIDTH-1:0] y);
    assign y = (s == 2'b00) ? d0 :
               (s == 2'b01) ? d1 :
               (s == 2'b10) ? d2 : {WIDTH{1'bx}};
endmodule
