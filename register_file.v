module register_file(
    input        clk,
    input        we,
    input  [1:0] raddr1,
    input  [1:0] raddr2,
    input  [1:0] waddr,
    input  [7:0] wdata,
    output [7:0] rdata1,
    output [7:0] rdata2,
    output [31:0] regs_value
);

reg [7:0] regs [0:3];

initial begin
    regs[0] = 8'h00;
    regs[1] = 8'h00;
    regs[2] = 8'h00;
    regs[3] = 8'h00;
end

// 组合读
assign rdata1 = regs[raddr1];
assign rdata2 = regs[raddr2];
assign regs_value = {regs[3],regs[2],regs[1],regs[0]};
// 时钟写
always @(posedge clk) begin
    if (we)
        regs[waddr] <= wdata;
end

endmodule