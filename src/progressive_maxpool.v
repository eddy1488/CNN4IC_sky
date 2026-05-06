module progressive_maxpool (
    input  wire        clk,
    input  wire        rst,
    input  wire signed [15:0] conv_in,
    input  wire        en,
    input  wire        first_en,   // pulso en la iteración 0: carga sin comparar
    output reg  signed [15:0] max_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            max_out <= 16'sd0;
        end else if (en) begin
            if (first_en)
                max_out <= conv_in;             // iter 0: carga directa
            else if (conv_in > max_out)
                max_out <= conv_in;             // iter 1-3: actualiza si es mayor
            // si no es mayor, max_out se conserva solo
        end
    end
endmodule