module data_ram(
    input        clk,
    input        we,
    input  [7:0] addr,
    input  [7:0] din,
    output [7:0] dout
);

reg [7:0] ram [0:255];
integer i;

initial begin
    for (i = 0; i < 256; i = i + 1)
        ram[i] = 8'h00;
end

// 同步写
always @(posedge clk) begin
    if (we)
        ram[addr] <= din;
end

// 组合读
assign dout = ram[addr];

endmodule