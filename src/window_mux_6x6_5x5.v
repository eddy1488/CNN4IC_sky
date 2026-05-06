module window_mux_6x6_5x5 (
    input  wire [107:0] fragment_flat,
    input  wire [1:0]   window_sel,
    output reg  [74:0]  window_flat
);

    // En lugar de desempaquetar en un array, 
    // calculamos los índices directamente sobre fragment_flat (píxeles de 3 bits)
    
    integer r, c, base_idx;
    
    always @(*) begin
        window_flat = 75'b0; // Valor por defecto
        case (window_sel)
            2'b00: base_idx = 0; // Fila 0, Col 0 dentro del fragmento
            2'b01: base_idx = 1; // Fila 0, Col 1
            2'b10: base_idx = 6; // Fila 1, Col 0
            2'b11: base_idx = 7; // Fila 1, Col 1
            default: base_idx = 0;
        endcase

        // Mapeamos la ventana 5x5 (25 píxeles) empezando desde base_idx
        for (r = 0; r < 5; r = r + 1) begin
            for (c = 0; c < 5; c = c + 1) begin
                // fragment_flat tiene 6 columnas. 
                // La posición en el fragmento es: (base_row + r)*6 + (base_col + c)
                // Pero como usamos base_idx que ya incluye la fila:
                window_flat[(r*5 + c)*3 +: 3] = fragment_flat[(base_idx + r*6 + c)*3 +: 3];
            end
        end
    end
endmodule