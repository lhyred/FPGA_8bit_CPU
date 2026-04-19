module cpu_top( 
    input        clk_50,         // 50MHz
    input  [3:0] key,         // 按下为低电平
    input  [3:0] SW,          // 4个开关
    output [15:0] dled,       // 数码管
    output [3:0]  led_data    // 4个LED
);

//====================================================
// 1) 复位与时钟
//====================================================
wire rst = ~key[0];

wire step_mode = SW[3]; //step_mode=0：连续慢速运行（100Hz）,step_mode=1：单步执行
reg [32:0] div_cnt;   // 250000 < 2^18
reg        slow_clk;  //100Hz
always @(posedge clk_50 or posedge rst) begin
    if (rst) begin
        div_cnt  <= 32'd0;
        slow_clk <= 1'b0;
    end
    else if (div_cnt == 32'd999999) begin
        div_cnt  <= 32'd0;
        slow_clk <= ~slow_clk;
    end
    else begin
        div_cnt <= div_cnt + 32'd1;
    end
end

//消抖
wire key1_raw = ~key[1];
reg key1_ff0, key1_ff1;      // 同步
reg key1_db;                 // 消抖后的稳定值
reg [19:0] db_cnt;           // 20ms 级别够用
reg key1_db_d;
always @(posedge clk_50 or posedge rst) begin
    if (rst)
        key1_db_d <= 1'b0;
    else
        key1_db_d <= key1_db;
end
wire step_pulse = key1_db & ~key1_db_d;

wire clk = (step_mode == 1'b0) ? slow_clk : step_pulse;
always @(posedge clk_50 or posedge rst) begin
    if (rst) begin
        key1_ff0 <= 1'b0;
        key1_ff1 <= 1'b0;
        key1_db  <= 1'b0;
        db_cnt   <= 20'd0;
    end
    else begin
        // 1) 两级同步
        key1_ff0 <= key1_raw;
        key1_ff1 <= key1_ff0;

        // 2) 消抖：只有当 key1_ff1 和 key1_db 不同时才开始计数
        if (key1_ff1 == key1_db) begin
            db_cnt <= 20'd0;
        end
        else begin
            if (db_cnt == 20'd999_999) begin
                db_cnt  <= 20'd0;
                key1_db <= key1_ff1;
            end
            else begin
                db_cnt <= db_cnt + 20'd1;
            end
        end
    end
end

//====================================================
// 2) 数码管显示相关
//====================================================
reg  [31:0] showdata;
wire [6:0]  dataout;
wire [7:0]  en;

assign dled = {en[0], en[1], en[2], en[3], en[4], en[5], en[6], en[7], 1'b1, dataout};

digital_show digital_show_u1(
    .clk(clk_50),
    .rst(key[0]),      // 保持你原来的接法
    .dataout(dataout),
    .en(en),
    .showdata(showdata),
    .SW(SW)
);

//====================================================
// 3) 指令字段拆分
// 指令格式：
// [15:12] opcode
// [11:10] rd
// [ 9: 8] rs
// [ 7: 0] imm/addr
//====================================================
wire [15:0] ir_out;
wire [3:0]  opcode = ir_out[15:12];
wire [1:0]  rd     = ir_out[11:10];
wire [1:0]  rs     = ir_out[9:8];
wire [7:0]  imm8   = ir_out[7:0];

//====================================================
// 4) 各模块之间的连线
//====================================================
// PC / ROM / IR
wire [7:0]  pc_out;
wire [7:0]  pc_plus1;
reg  [7:0]  next_pc;
wire [15:0] rom_data;

// 寄存器堆
wire [7:0]  rf_rdata1;   // 默认接 R[rd]
wire [7:0]  rf_rdata2;   // 默认接 R[rs]
reg  [7:0]  rf_wdata;
wire [31:0] regs_value;
// ALU
wire [7:0]  alu_y;
wire        alu_z;
wire        alu_c;

// RAM
wire [7:0]  ram_dout;

// Flags
reg         z_flag;
reg         c_flag;

// 控制器输出
wire        ir_load;
wire        pc_load;
wire [1:0]  pc_src;      // 00: hold, 01: PC+1, 10: imm8
wire        reg_we;
wire        mem_we;
wire        flags_we;
wire [3:0]  alu_op;
wire [1:0]  wb_sel;      // 00: ALU, 01: IMM8, 10: RAM, 11: R[rs] (MOV)
wire        halt;

//====================================================
// 5) 下一条PC选择
//====================================================
assign pc_plus1 = pc_out + 8'd1;

always @(*) begin
    case (pc_src)
        2'b01: next_pc = pc_plus1; // 顺序执行
        2'b10: next_pc = imm8;     // JMP/JZ/JC
        default: next_pc = pc_out; // 保持
    endcase
end

//====================================================
// 6) 写回数据选择
//====================================================
always @(*) begin
    case (wb_sel)
        2'b00: rf_wdata = alu_y;       // ADD/SUB/AND/OR/XOR/NOT/SHL/SHR
        2'b01: rf_wdata = imm8;        // LDI
        2'b10: rf_wdata = ram_dout;    // LOAD
        2'b11: rf_wdata = rf_rdata2;   // MOV rd, rs
        default: rf_wdata = 8'h00;
    endcase
end

//====================================================
// 7) 标志寄存器
//====================================================
always @(posedge clk or posedge rst) begin
    if (rst) begin
        z_flag <= 1'b0;
        c_flag <= 1'b0;
    end
    else if (flags_we) begin
        z_flag <= alu_z;
        c_flag <= alu_c;
    end
end

//====================================================
// 8) 模块实例化
//====================================================

//---------------- PC ----------------
// load=1 时 pc_out <= next_pc
// load=0 时 pc_out <= pc_out
pc u_pc(
    .clk(clk),
    .rst(rst),
    .load(pc_load),
    .next_pc(next_pc),
    .pc_out(pc_out)
);

//---------------- 指令ROM ----------------
instr_rom u_instr_rom(
    .addr(pc_out),
    .data(rom_data)
);

//---------------- IR ----------------
ir u_ir(
    .clk(clk),
    .rst(rst),
    .load(ir_load),
    .instr_in(rom_data),
    .instr_out(ir_out)
);

//---------------- 寄存器堆 ----------------
// raddr1 接 rd，是为了支持：ADD rd, rs => R[rd] <- R[rd] + R[rs]
register_file u_regfile(
    .clk(clk),
    //.rst(rst),
    .we(reg_we),
    .raddr1(rd),
    .raddr2(rs),
    .waddr(rd),
    .wdata(rf_wdata),
    .rdata1(rf_rdata1),
    .rdata2(rf_rdata2),
    .regs_value(regs_value)
);

//---------------- ALU ----------------
alu u_alu(
    .a(rf_rdata1),
    .b(rf_rdata2),
    .alu_op(alu_op),
    .y(alu_y),
    .z(alu_z),
    .c(alu_c)
);

//---------------- 数据RAM ----------------
data_ram u_data_ram(
    .clk(clk),
    .we(mem_we),
    .addr(imm8),
    .din(rf_rdata2),   // STORE rs, [addr]
    .dout(ram_dout)
);

//---------------- 控制器 ----------------
// FSM 放在这个模块里，顶层不写状态机
control_unit u_ctrl(
    .clk(clk),
    .rst(rst),
    .opcode(opcode),
    .z_flag(z_flag),
    .c_flag(c_flag),

    .ir_load(ir_load),
    .pc_load(pc_load),
    .pc_src(pc_src),

    .reg_we(reg_we),
    .mem_we(mem_we),
    .flags_we(flags_we),

    .alu_op(alu_op),
    .wb_sel(wb_sel),
    .halt(halt)
);

//====================================================
// 9) 调试显示
// SW 用来切换数码管显示内容
//====================================================
always @(*) begin
    case (SW[2:0])
        3'b000: showdata = regs_value;                              // 查看4个寄存器的值
        3'b001: showdata = {pc_out,4'h0, opcode, 2'h0, rd, 2'h0, rs, imm8};      // 指令字段拆分结果
        3'b010: showdata = {24'h000000,regs_value[7:0]};                 // 看寄存器R0
        3'b011: showdata = {16'h0000, rf_rdata1, rf_rdata2};        // 两个读口
        3'b100: showdata = {14'h0000, z_flag, c_flag, 8'h00, alu_y};// ALU + flags
        3'b101: showdata = {16'h0000, imm8, ram_dout};              // RAM + 地址
        3'b110: showdata = {24'h000000, next_pc};                   // next_pc
        3'b111: showdata = {24'h000000, rf_wdata};                  // 写回数据
        default: showdata = 32'h12345678;
    endcase
end

// 4个LED做简单状态指示
// led_data[3] = halt
// led_data[2] = mem_we
// led_data[1] = reg_we
// led_data[0] = pc_load
assign led_data = SW[3] ?  {halt, mem_we, reg_we, pc_load} : regs_value[3:0];

endmodule