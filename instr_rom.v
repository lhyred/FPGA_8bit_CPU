module instr_rom(
    input  [7:0]  addr,
    output [15:0] data
);

reg [15:0] rom [0:255];
integer i;

initial begin
    for (i = 0; i < 256; i = i + 1)
        rom[i] = 16'hF000;   // 默认填 HLT，避免跑飞

    $readmemh("prog.mem", rom);
end

assign data = rom[addr];

endmodule