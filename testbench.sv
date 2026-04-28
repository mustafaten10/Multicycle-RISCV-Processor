// =====================================================================
// riscv_testbench.sv - Testbench with debug output
// =====================================================================
module testbench();

    logic        clk;
    logic        reset;

    logic [31:0] WriteData, DataAdr;
    logic        MemWrite;

    // Instantiate device under test
    top dut(clk, reset, WriteData, DataAdr, MemWrite);

    // Initialize test
    initial begin
        // Print first few memory contents to verify memfile loaded
        #1;
        $display("=== Memory check (memfile.txt load test) ===");
        $display("RAM[0]  = %h  (expected: 00500113)", dut.mem.RAM[0]);
        $display("RAM[1]  = %h  (expected: 00C00193)", dut.mem.RAM[1]);
        $display("RAM[2]  = %h  (expected: FF718393)", dut.mem.RAM[2]);
        $display("RAM[3]  = %h  (expected: 0023E233)", dut.mem.RAM[3]);
        if (dut.mem.RAM[0] === 32'h00500113)
            $display(">>> memfile.txt LOADED OK");
        else
            $display(">>> ERROR: memfile.txt NOT LOADED");
        $display("============================================");

        reset <= 1; # 22; reset <= 0;
    end

    // Generate clock
    always begin
        clk <= 1; # 5; clk <= 0; # 5;
    end

    // Print PC and Instr each cycle for debug
    always @(posedge clk) begin
        if (!reset) begin
            $display("t=%0t  PC=%h  Instr=%h  state=%0d  MemWrite=%b  DataAdr=%h  WriteData=%h",
                     $time,
                     dut.riscv.dp.PC,
                     dut.riscv.dp.Instr,
                     dut.riscv.c.fsm.state,
                     MemWrite, DataAdr, WriteData);
        end
    end

    // Check results
    always @(negedge clk) begin
        if (MemWrite) begin
            if (DataAdr === 32'd100 & WriteData === 32'd25) begin
                $display(">>> Simulation succeeded");
                $finish;
            end else if (DataAdr !== 32'd96) begin
                $display(">>> Simulation failed: DataAdr=%h  WriteData=%h", DataAdr, WriteData);
                $finish;
            end
        end
    end

    // Safety timeout
    initial begin
        #5000;
        $display(">>> TIMEOUT: did not finish in 5000ns");
        $finish;
    end
endmodule