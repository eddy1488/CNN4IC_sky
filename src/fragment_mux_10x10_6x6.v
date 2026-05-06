module fragment_mux_10x10_6x6 (
    input  wire [299:0] image_flat,   // 100 píxeles * 3 bits = 300 bits
    input  wire [3:0]   frag_sel,     // 0-8: selección del fragmento 6x6
    output reg  [107:0] fragment_flat // 36 píxeles * 3 bits = 108 bits
);

    integer r, c, base_row, base_col, flat_idx;

    always @(*) begin
        // Valores por defecto para evitar latches
        fragment_flat = 108'b0;
        base_row = 0;
        base_col = 0;

        // Determinar la esquina superior izquierda del fragmento 6x6 (stride de 2)
        case (frag_sel)
            4'd0: begin base_row = 0; base_col = 0; end
            4'd1: begin base_row = 0; base_col = 2; end
            4'd2: begin base_row = 0; base_col = 4; end
            4'd3: begin base_row = 2; base_col = 0; end
            4'd4: begin base_row = 2; base_col = 2; end
            4'd5: begin base_row = 2; base_col = 4; end
            4'd6: begin base_row = 4; base_col = 0; end
            4'd7: begin base_row = 4; base_col = 2; end
            4'd8: begin base_row = 4; base_col = 4; end
            default: begin base_row = 0; base_col = 0; end
        endcase

        // Mapear los 36 píxeles del fragmento 6x6 desde la imagen 10x10
        for (r = 0; r < 6; r = r + 1) begin
            for (c = 0; c < 6; c = c + 1) begin
                // Cálculo del índice plano: ((fila_actual * ancho_total) + col_actual) * bits_por_pixel
                // Imagen original es 10x10
                flat_idx = ((base_row + r) * 10 + (base_col + c)) * 3;
                fragment_flat[(r * 6 + c) * 3 +: 3] = image_flat[flat_idx +: 3];
            end
        end
    end
endmodule