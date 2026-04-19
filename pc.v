module pc(
    input        clk,
    input        rst,
    input        load,
    input  [7:0] next_pc,
    output reg [7:0] pc_out
);

always @(posedge clk or posedge rst) begin
    if (rst)
        pc_out <= 8'h00;
    else if (load)
        pc_out <= next_pc;
    else
        pc_out <= pc_out;
end

endmodule