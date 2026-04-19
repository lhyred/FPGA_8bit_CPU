module ir(
    input         clk,
    input         rst,
    input         load,
    input  [15:0] instr_in,
    output reg [15:0] instr_out
);

always @(posedge clk or posedge rst) begin
    if (rst)
        instr_out <= 16'h0000;
    else if (load)
        instr_out <= instr_in;
    else
        instr_out <= instr_out;
end

endmodule