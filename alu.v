module alu(
    input  [7:0] a,
    input  [7:0] b,
    input  [3:0] alu_op,
    output reg [7:0] y,
    output reg       z,
    output reg       c
);

reg [8:0] tmp;

always @(*) begin
    y   = 8'h00;
    z   = 1'b0;
    c   = 1'b0;
    tmp = 9'h000;

    case (alu_op)
        4'h0: begin
            // ADD
            tmp = {1'b0, a} + {1'b0, b};
            y   = tmp[7:0];
            c   = tmp[8];
        end

        4'h1: begin
            // SUB
            tmp = {1'b0, a} - {1'b0, b};
            y   = tmp[7:0];
            c   = tmp[8];   // 借位位
        end

        4'h2: begin
            // AND
            y = a & b;
            c = 1'b0;
        end

        4'h3: begin
            // OR
            y = a | b;
            c = 1'b0;
        end

        4'h4: begin
            // XOR
            y = a ^ b;
            c = 1'b0;
        end

        4'h5: begin
            // NOT
            y = ~a;
            c = 1'b0;
        end

        4'h6: begin
            // SHL
            y = a << 1;
            c = a[7];
        end

        4'h7: begin
            // SHR
            y = a >> 1;
            c = a[0];
        end

        4'h8: begin
            // PASS
            y = b;
            c = 1'b0;
        end

        default: begin
            y = 8'h00;
            c = 1'b0;
        end
    endcase

    z = (y == 8'h00);
end

endmodule