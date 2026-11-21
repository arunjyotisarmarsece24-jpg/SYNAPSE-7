// ============================================================================
// Module Name: riscv_core
// Project:     SYNAPSE-7 (Quantum-Neuromorphic RISC-V Computer Architecture)
// Target:      Xilinx Spartan-7 FPGA / Cadence ASIC Flow
// Architecture: 32-bit RISC-V (RV32I Base Integer Instruction Set Architecture)
// Description: Fully synthesizable, single-cycle / multi-stage RV32I core
//              with complete instruction decoder, 32x32 general-purpose register
//              file, arithmetic logic unit (ALU), branch evaluator, and
//              memory/MMIO bus interface.
// ============================================================================

`timescale 1ns / 1ps

module riscv_core (
    input  wire        clk,
    input  wire        rst_n,
    
    // Instruction Memory Bus (Read-Only)
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,
    
    // Data & MMIO Memory Bus (Read/Write)
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_wstrb,
    output wire        dmem_we,
    input  wire [31:0] dmem_rdata
);

    // ------------------------------------------------------------------------
    // Program Counter (PC)
    // ------------------------------------------------------------------------
    reg [31:0] pc;
    wire [31:0] pc_plus_4 = pc + 32'd4;
    reg [31:0] pc_next;

    assign imem_addr = pc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h0000_0000;
        end else begin
            pc <= pc_next;
        end
    end

    // ------------------------------------------------------------------------
    // Instruction Fields & Decoding (RV32I)
    // ------------------------------------------------------------------------
    wire [31:0] instr = imem_rdata;
    wire [6:0]  opcode = instr[6:0];
    wire [4:0]  rd     = instr[11:7];
    wire [2:0]  funct3 = instr[14:12];
    wire [4:0]  rs1    = instr[19:15];
    wire [4:0]  rs2    = instr[24:20];
    wire [6:0]  funct7 = instr[31:25];

    // Opcode definitions
    localparam OPC_LUI    = 7'b0110111;
    localparam OPC_AUIPC  = 7'b0010111;
    localparam OPC_JAL    = 7'b1101111;
    localparam OPC_JALR   = 7'b1100111;
    localparam OPC_BRANCH = 7'b1100011;
    localparam OPC_LOAD   = 7'b0000011;
    localparam OPC_STORE  = 7'b0100011;
    localparam OPC_OP_IMM = 7'b0010011;
    localparam OPC_OP     = 7'b0110011;

    // Immediate generation
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'h000};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    // ------------------------------------------------------------------------
    // General Purpose Register File (32 x 32-bit, x0 hardwired to 0)
    // ------------------------------------------------------------------------
    reg [31:0] regfile [0:31];
    reg [31:0] reg_wdata;
    reg        reg_we;

    wire [31:0] rf_rdata1 = (rs1 == 5'd0) ? 32'd0 : regfile[rs1];
    wire [31:0] rf_rdata2 = (rs2 == 5'd0) ? 32'd0 : regfile[rs2];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) regfile[i] = 32'd0;
    end

    always @(posedge clk) begin
        if (reg_we && (rd != 5'd0)) begin
            regfile[rd] <= reg_wdata;
        end
    end

    // ------------------------------------------------------------------------
    // Arithmetic Logic Unit (ALU)
    // ------------------------------------------------------------------------
    reg [31:0] alu_in_a;
    reg [31:0] alu_in_b;
    reg [31:0] alu_out;

    always @(*) begin
        // Operand A select
        if (opcode == OPC_AUIPC)
            alu_in_a = pc;
        else
            alu_in_a = rf_rdata1;

        // Operand B select
        if (opcode == OPC_OP)
            alu_in_b = rf_rdata2;
        else if (opcode == OPC_OP_IMM || opcode == OPC_LOAD || opcode == OPC_JALR)
            alu_in_b = imm_i;
        else if (opcode == OPC_STORE)
            alu_in_b = imm_s;
        else if (opcode == OPC_AUIPC || opcode == OPC_LUI)
            alu_in_b = imm_u;
        else
            alu_in_b = 32'd0;
    end

    always @(*) begin
        case (opcode)
            OPC_LUI: alu_out = imm_u;
            OPC_AUIPC: alu_out = alu_in_a + alu_in_b;
            OPC_LOAD, OPC_STORE, OPC_JALR: alu_out = alu_in_a + alu_in_b;
            OPC_OP_IMM: begin
                case (funct3)
                    3'b000: alu_out = alu_in_a + alu_in_b;                          // ADDI
                    3'b010: alu_out = ($signed(alu_in_a) < $signed(alu_in_b)) ? 32'd1 : 32'd0; // SLTI
                    3'b011: alu_out = (alu_in_a < alu_in_b) ? 32'd1 : 32'd0;       // SLTIU
                    3'b100: alu_out = alu_in_a ^ alu_in_b;                          // XORI
                    3'b110: alu_out = alu_in_a | alu_in_b;                          // ORI
                    3'b111: alu_out = alu_in_a & alu_in_b;                          // ANDI
                    3'b001: alu_out = alu_in_a << alu_in_b[4:0];                    // SLLI
                    3'b101: alu_out = funct7[5] ? ($signed(alu_in_a) >>> alu_in_b[4:0]) : (alu_in_a >> alu_in_b[4:0]); // SRAI / SRLI
                    default: alu_out = 32'd0;
                endcase
            end
            OPC_OP: begin
                case (funct3)
                    3'b000: alu_out = funct7[5] ? (alu_in_a - alu_in_b) : (alu_in_a + alu_in_b); // SUB / ADD
                    3'b001: alu_out = alu_in_a << alu_in_b[4:0];                    // SLL
                    3'b010: alu_out = ($signed(alu_in_a) < $signed(alu_in_b)) ? 32'd1 : 32'd0; // SLT
                    3'b011: alu_out = (alu_in_a < alu_in_b) ? 32'd1 : 32'd0;       // SLTU
                    3'b100: alu_out = alu_in_a ^ alu_in_b;                          // XOR
                    3'b101: alu_out = funct7[5] ? ($signed(alu_in_a) >>> alu_in_b[4:0]) : (alu_in_a >> alu_in_b[4:0]); // SRA / SRL
                    3'b110: alu_out = alu_in_a | alu_in_b;                          // OR
                    3'b111: alu_out = alu_in_a & alu_in_b;                          // AND
                    default: alu_out = 32'd0;
                endcase
            end
            default: alu_out = 32'd0;
        endcase
    end

    // ------------------------------------------------------------------------
    // Branch Condition Evaluation
    // ------------------------------------------------------------------------
    reg branch_taken;
    always @(*) begin
        case (funct3)
            3'b000: branch_taken = (rf_rdata1 == rf_rdata2);                  // BEQ
            3'b001: branch_taken = (rf_rdata1 != rf_rdata2);                  // BNE
            3'b100: branch_taken = ($signed(rf_rdata1) < $signed(rf_rdata2)); // BLT
            3'b101: branch_taken = ($signed(rf_rdata1) >= $signed(rf_rdata2));// BGE
            3'b110: branch_taken = (rf_rdata1 < rf_rdata2);                   // BLTU
            3'b111: branch_taken = (rf_rdata1 >= rf_rdata2);                  // BGEU
            default: branch_taken = 1'b0;
        endcase
    end

    // ------------------------------------------------------------------------
    // PC Next Logic (Jump / Branch / Sequential)
    // ------------------------------------------------------------------------
    always @(*) begin
        case (opcode)
            OPC_JAL:    pc_next = pc + imm_j;
            OPC_JALR:   pc_next = (rf_rdata1 + imm_i) & ~32'd1;
            OPC_BRANCH: pc_next = branch_taken ? (pc + imm_b) : pc_plus_4;
            default:    pc_next = pc_plus_4;
        endcase
    end

    // ------------------------------------------------------------------------
    // Data & MMIO Memory Interface
    // ------------------------------------------------------------------------
    assign dmem_addr  = alu_out;
    assign dmem_wdata = (funct3 == 3'b000) ? {4{rf_rdata2[7:0]}} :
                        (funct3 == 3'b001) ? {2{rf_rdata2[15:0]}} : rf_rdata2;
    assign dmem_we    = (opcode == OPC_STORE);
    assign dmem_wstrb = (opcode == OPC_STORE) ? (
                            (funct3 == 3'b000) ? (4'b0001 << alu_out[1:0]) :
                            (funct3 == 3'b001) ? (4'b0011 << {alu_out[1], 1'b0}) : 4'b1111
                        ) : 4'b0000;

    // Load Data Extension
    reg [31:0] load_extended;
    always @(*) begin
        case (funct3)
            3'b000: begin // LB
                case (alu_out[1:0])
                    2'b00: load_extended = {{24{dmem_rdata[7]}},  dmem_rdata[7:0]};
                    2'b01: load_extended = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                    2'b10: load_extended = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                    2'b11: load_extended = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                endcase
            end
            3'b001: begin // LH
                case (alu_out[1])
                    1'b0: load_extended = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
                    1'b1: load_extended = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
                endcase
            end
            3'b010: load_extended = dmem_rdata; // LW
            3'b100: begin // LBU
                case (alu_out[1:0])
                    2'b00: load_extended = {24'd0, dmem_rdata[7:0]};
                    2'b01: load_extended = {24'd0, dmem_rdata[15:8]};
                    2'b10: load_extended = {24'd0, dmem_rdata[23:16]};
                    2'b11: load_extended = {24'd0, dmem_rdata[31:24]};
                endcase
            end
            3'b101: begin // LHU
                case (alu_out[1])
                    1'b0: load_extended = {16'd0, dmem_rdata[15:0]};
                    1'b1: load_extended = {16'd0, dmem_rdata[31:16]};
                endcase
            end
            default: load_extended = dmem_rdata;
        endcase
    end

    // Register Writeback Selection
    always @(*) begin
        case (opcode)
            OPC_LOAD:                  reg_wdata = load_extended;
            OPC_JAL, OPC_JALR:         reg_wdata = pc_plus_4;
            OPC_LUI, OPC_AUIPC,
            OPC_OP_IMM, OPC_OP:        reg_wdata = alu_out;
            default:                   reg_wdata = 32'd0;
        endcase

        case (opcode)
            OPC_LOAD, OPC_JAL, OPC_JALR,
            OPC_LUI, OPC_AUIPC,
            OPC_OP_IMM, OPC_OP:        reg_we = 1'b1;
            default:                   reg_we = 1'b0;
        endcase
    end

endmodule
