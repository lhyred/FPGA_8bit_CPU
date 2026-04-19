module control_unit(
    input        clk,
    input        rst,
    input  [3:0] opcode,
    input        z_flag,
    input        c_flag,

    output reg        ir_load,
    output reg        pc_load,
    output reg [1:0]  pc_src,    // 00: hold, 01: PC+1, 10: imm8
    output reg        reg_we,
    output reg        mem_we,
    output reg        flags_we,
    output reg [3:0]  alu_op,
    output reg [1:0]  wb_sel,    // 00: ALU, 01: IMM8, 10: RAM, 11: R[rs]
    output reg        halt
);

    //==================================================
    // 1) 状态编码
    //==================================================
    localparam S_FETCH     = 3'd0;
    localparam S_DECODE    = 3'd1;
    localparam S_EXEC      = 3'd2;
    localparam S_MEM       = 3'd3;
    localparam S_WRITEBACK = 3'd4;
    localparam S_HALT      = 3'd5;

    reg [2:0] state, next_state;

    //==================================================
    // 2) 指令 opcode 编码
    //==================================================
    localparam OP_LDI   = 4'h0;
    localparam OP_MOV   = 4'h1;
    localparam OP_LOAD  = 4'h2;
    localparam OP_STORE = 4'h3;
    localparam OP_ADD   = 4'h4;
    localparam OP_SUB   = 4'h5;
    localparam OP_AND   = 4'h6;
    localparam OP_OR    = 4'h7;
    localparam OP_XOR   = 4'h8;
    localparam OP_NOT   = 4'h9;
    localparam OP_SHL   = 4'hA;
    localparam OP_SHR   = 4'hB;
    localparam OP_JMP   = 4'hC;
    localparam OP_JZ    = 4'hD;
    localparam OP_JC    = 4'hE;
    localparam OP_HLT   = 4'hF;

    //==================================================
    // 3) ALU 操作码
    // 要和 alu.v 内部定义保持一致
    //==================================================
    localparam ALU_ADD  = 4'h0;
    localparam ALU_SUB  = 4'h1;
    localparam ALU_AND  = 4'h2;
    localparam ALU_OR   = 4'h3;
    localparam ALU_XOR  = 4'h4;
    localparam ALU_NOT  = 4'h5;
    localparam ALU_SHL  = 4'h6;
    localparam ALU_SHR  = 4'h7;
    localparam ALU_PASS = 4'h8;

    //==================================================
    // 4) 状态寄存器
    //==================================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= S_FETCH;
        else
            state <= next_state;
    end

    //==================================================
    // 5) 次态逻辑
    //==================================================
    always @(*) begin
        case (state)
            S_FETCH: begin
                next_state = S_DECODE;
            end

            S_DECODE: begin
                case (opcode)
                    OP_HLT:   next_state = S_HALT;

                    OP_LOAD,
                    OP_STORE: next_state = S_EXEC;

                    OP_JMP,
                    OP_JZ,
                    OP_JC:    next_state = S_EXEC;

                    default:  next_state = S_EXEC;
                endcase
            end

            S_EXEC: begin
                case (opcode)
                    OP_LOAD,
                    OP_STORE: next_state = S_MEM;

                    OP_JMP,
                    OP_JZ,
                    OP_JC:    next_state = S_FETCH;

                    OP_HLT:   next_state = S_HALT;

                    default:  next_state = S_WRITEBACK;
                endcase
            end

            S_MEM: begin
                case (opcode)
                    OP_LOAD:  next_state = S_WRITEBACK;
                    OP_STORE: next_state = S_FETCH;
                    default:  next_state = S_FETCH;
                endcase
            end

            S_WRITEBACK: begin
                next_state = S_FETCH;
            end

            S_HALT: begin
                next_state = S_HALT;
            end

            default: begin
                next_state = S_FETCH;
            end
        endcase
    end

    //==================================================
    // 6) 输出控制逻辑（Moore 型）
    //==================================================
    always @(*) begin
        // 默认值
        ir_load  = 1'b0;
        pc_load  = 1'b0;
        pc_src   = 2'b00;
        reg_we   = 1'b0;
        mem_we   = 1'b0;
        flags_we = 1'b0;
        alu_op   = ALU_PASS;
        wb_sel   = 2'b00;
        halt     = 1'b0;

        case (state)
            //==========================================
            // FETCH:
            // 1. 锁存 ROM -> IR
            // 2. PC <- PC + 1
            //==========================================
            S_FETCH: begin
                ir_load = 1'b1;
                pc_load = 1'b1;
                pc_src  = 2'b01; // PC+1
            end

            //==========================================
            // DECODE:
            // 暂不发控制信号，主要等待译码稳定
            //==========================================
            S_DECODE: begin
                // 无操作
            end

            //==========================================
            // EXEC:
            // - ALU 类：给出 alu_op
            // - 跳转类：决定是否改写 PC
            //==========================================
            S_EXEC: begin
                case (opcode)
                    OP_ADD: alu_op = ALU_ADD;
                    OP_SUB: alu_op = ALU_SUB;
                    OP_AND: alu_op = ALU_AND;
                    OP_OR : alu_op = ALU_OR;
                    OP_XOR: alu_op = ALU_XOR;
                    OP_NOT: alu_op = ALU_NOT;
                    OP_SHL: alu_op = ALU_SHL;
                    OP_SHR: alu_op = ALU_SHR;

                    OP_JMP: begin
                        pc_load = 1'b1;
                        pc_src  = 2'b10; // imm8
                    end

                    OP_JZ: begin
                        if (z_flag) begin
                            pc_load = 1'b1;
                            pc_src  = 2'b10;
                        end
                    end

                    OP_JC: begin
                        if (c_flag) begin
                            pc_load = 1'b1;
                            pc_src  = 2'b10;
                        end
                    end

                    default: begin
                        // LDI/MOV/LOAD/STORE 在此阶段不需要额外控制
                    end
                endcase
            end

            //==========================================
            // MEM:
            // - LOAD: 读 RAM（组合读，不需要额外使能）
            // - STORE: 写 RAM
            //==========================================
            S_MEM: begin
                case (opcode)
                    OP_STORE: begin
                        mem_we = 1'b1;
                    end

                    default: begin
                        // LOAD 无需额外控制
                    end
                endcase
            end

            //==========================================
            // WRITEBACK:
            // - LDI   -> 写回 imm8
            // - MOV   -> 写回 R[rs]
            // - LOAD  -> 写回 RAM
            // - ALU类 -> 写回 ALU，并更新标志位
            //==========================================
            S_WRITEBACK: begin
                case (opcode)
                    OP_LDI: begin
                        reg_we = 1'b1;
                        wb_sel = 2'b01; // IMM8
                    end

                    OP_MOV: begin
                        reg_we = 1'b1;
                        wb_sel = 2'b11; // R[rs]
                    end

                    OP_LOAD: begin
                        reg_we = 1'b1;
                        wb_sel = 2'b10; // RAM
                    end

                    OP_ADD: begin
                        reg_we   = 1'b1;
                        flags_we = 1'b1;
                        wb_sel   = 2'b00; // ALU
                        alu_op   = ALU_ADD;
                    end

                    OP_SUB: begin
                        reg_we   = 1'b1;
                        flags_we = 1'b1;
                        wb_sel   = 2'b00;
                        alu_op   = ALU_SUB;
                    end

                    OP_AND: begin
                        reg_we   = 1'b1;
                        flags_we = 1'b1;
                        wb_sel   = 2'b00;
                        alu_op   = ALU_AND;
                    end

                    OP_OR: begin
                        reg_we   = 1'b1;
                        flags_we = 1'b1;
                        wb_sel   = 2'b00;
                        alu_op   = ALU_OR;
                    end

                    OP_XOR: begin
                        reg_we   = 1'b1;
                        flags_we = 1'b1;
                        wb_sel   = 2'b00;
                        alu_op   = ALU_XOR;
                    end

                    OP_NOT: begin
                        reg_we   = 1'b1;
                        flags_we = 1'b1;
                        wb_sel   = 2'b00;
                        alu_op   = ALU_NOT;
                    end

                    OP_SHL: begin
                        reg_we   = 1'b1;
                        flags_we = 1'b1;
                        wb_sel   = 2'b00;
                        alu_op   = ALU_SHL;
                    end

                    OP_SHR: begin
                        reg_we   = 1'b1;
                        flags_we = 1'b1;
                        wb_sel   = 2'b00;
                        alu_op   = ALU_SHR;
                    end

                    default: begin
                        // 无操作
                    end
                endcase
            end

            //==========================================
            // HALT:
            // 停机状态，保持所有写使能关闭
            //==========================================
            S_HALT: begin
                halt = 1'b1;
            end

            default: begin
                // 保持默认值
            end
        endcase
    end

endmodule