//=======================================================
//  cnn_top — Convolución 10x10 con un kernel 5x5
//=======================================================
//  Procesa la imagen completa con un único kernel.
//  Itera los 9 fragmentos 6x6 (stride=2), lanza mux_cnn
//  en cada uno y acumula el resultado de maxpool en acc.
//
//  Para procesar dos kernels, el controlador superior
//  debe correr este módulo dos veces con kernels distintos.
//
//  FSM:
//    IDLE
//      → FRAG  (cnn_rst=1, limpia mux_cnn)
//      → START (cnn_start=1, pulso único)
//      → WAIT  (espera cnn_done)
//      → ACC   (acumula, avanza frag_sel o va a FINISH)
//      → FINISH (done=1)
//      → IDLE
//
//  Latencia total: 9 frags × ~12 ciclos/frag ≈ 108 ciclos
//
//  Instancia:
//    - fragment_mux_10x10_6x6  (combinacional)
//    - mux_cnn                  (FSM interna, 10 ciclos de latencia)
//=======================================================

module cnn_top (
    input  wire              clk,
    input  wire              rst,
    input  wire              start,
    input  wire [299:0]      image_flat,   // imagen 10x10 × 3 bits
    input  wire [74:0]       kernel_flat,  // kernel activo
    output reg               done,
    output reg signed [15:0] acc           // suma de 9 maxpoolings
);

    // ── Estados ──────────────────────────────────────────
    localparam IDLE   = 3'd0;
    localparam FRAG   = 3'd1;   // reset de mux_cnn
    localparam START  = 3'd2;   // pulso cnn_start (1 ciclo)
    localparam WAIT   = 3'd3;   // espera cnn_done
    localparam ACC    = 3'd4;   // acumula resultado
    localparam FINISH = 3'd5;

    reg [2:0]  state;
    reg [3:0]  frag_sel;   // 0..8
    reg        cnn_start;
    reg        cnn_rst;

    wire               cnn_done;
    wire signed [15:0] cnn_out;
    wire [107:0]       fragment_flat;

    // ── Instancias ───────────────────────────────────────

    // Selecciona el fragmento 6x6 activo de la imagen 10x10
    fragment_mux_10x10_6x6 frag_mux (
        .image_flat   (image_flat),
        .frag_sel     (frag_sel),
        .fragment_flat(fragment_flat)
    );

    // Procesa el fragmento activo con el kernel
    mux_cnn cnn_inst (
        .clk          (clk),
        .rst          (cnn_rst),
        .start        (cnn_start),
        .fragment_flat(fragment_flat),
        .kernel_flat  (kernel_flat),
        .done         (cnn_done),
        .conv_out     (cnn_out)
    );

    // ── FSM ──────────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            done      <= 1'b0;
            acc       <= 16'sd0;
            frag_sel  <= 4'd0;
            cnn_start <= 1'b0;
            cnn_rst   <= 1'b1;
        end else begin
            // defaults de un ciclo
            cnn_start <= 1'b0;
            cnn_rst   <= 1'b0;
            done      <= 1'b0;

            case (state)

                IDLE: begin
                    if (start) begin
                        acc      <= 16'sd0;
                        frag_sel <= 4'd0;
                        state    <= FRAG;
                    end
                end

                FRAG: begin
                    cnn_rst <= 1'b1;        // limpia mux_cnn
                    state   <= START;
                end

                START: begin
                    cnn_start <= 1'b1;      // pulso único de arranque
                    state     <= WAIT;
                end

                WAIT: begin
                    if (cnn_done)           // espera sin tocar cnn_start
                        state <= ACC;
                end

                ACC: begin
                    acc <= acc + cnn_out;
                    if (frag_sel == 4'd8) begin
                        state <= FINISH;
                    end else begin
                        frag_sel <= frag_sel + 4'd1;
                        state    <= FRAG;
                    end
                end

                FINISH: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule