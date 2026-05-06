//=======================================================
//  mux_cnn — Convolución de un fragmento 6x6 con kernel 5x5
//=======================================================
//  Itera las 4 ventanas 5x5 posibles dentro del fragmento 6x6,
//  computa el producto punto de cada una con el kernel via
//  mac_parallel, y retiene el máximo via progressive_maxpool.
//
//  FSM:
//    IDLE
//      → PRE_CONV0 (window_sel=0, espera 1 ciclo para que MAC se estabilice)
//      → CONV0     (en_maxpool=1, first_en=1 — carga directa ventana 0)
//      → PRE_CONV1 (window_sel=1)
//      → CONV1     (en_maxpool=1)
//      → PRE_CONV2 (window_sel=2)
//      → CONV2     (en_maxpool=1)
//      → PRE_CONV3 (window_sel=3)
//      → CONV3     (en_maxpool=1)
//      → FINISH    (done=1)
//      → IDLE
//
//  Latencia: 10 ciclos desde start=1 hasta done=1
//
//  Instancia:
//    - window_mux_6x6_5x5  (combinacional)
//    - mac_parallel         (combinacional)
//    - progressive_maxpool  (registrado)
//=======================================================

module mux_cnn (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [107:0] fragment_flat,   // 36 píxeles × 3 bits
    input  wire [74:0]  kernel_flat,     // 25 pesos × 3 bits
    output reg          done,
    output wire signed [15:0] conv_out   // máximo de las 4 ventanas
);

    // ── Estados ──────────────────────────────────────────
    localparam IDLE      = 4'd0;
    localparam PRE_CONV0 = 4'd1;
    localparam CONV0     = 4'd2;
    localparam PRE_CONV1 = 4'd3;
    localparam CONV1     = 4'd4;
    localparam PRE_CONV2 = 4'd5;
    localparam CONV2     = 4'd6;
    localparam PRE_CONV3 = 4'd7;
    localparam CONV3     = 4'd8;
    localparam FINISH    = 4'd9;

    reg [3:0] state;
    reg [1:0] window_sel;
    reg       en_maxpool;
    reg       first_en;

    // ── Wires internos ───────────────────────────────────
    wire [74:0]        window_flat;
    wire signed [15:0] mac_result;

    // ── Instancias ───────────────────────────────────────
    window_mux_6x6_5x5 win_mux (
        .fragment_flat(fragment_flat),
        .window_sel   (window_sel),
        .window_flat  (window_flat)
    );

    mac_parallel mac_inst (
        .px    (window_flat),
        .w     (kernel_flat),
        .result(mac_result)
    );

    progressive_maxpool pool_inst (
        .clk     (clk),
        .rst     (rst),
        .conv_in (mac_result),
        .en      (en_maxpool),
        .first_en(first_en),
        .max_out (conv_out)
    );

    // ── FSM ──────────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            window_sel <= 2'd0;
            en_maxpool <= 1'b0;
            first_en   <= 1'b0;
            done       <= 1'b0;
        end else begin
            // defaults
            en_maxpool <= 1'b0;
            first_en   <= 1'b0;
            done       <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PRE_CONV0;
                    end
                end

                // ── Ventana 0 ────────────────────────────
                PRE_CONV0: begin
                    window_sel <= 2'd0;   // MAC se estabiliza este ciclo
                    state      <= CONV0;
                end

                CONV0: begin
                    en_maxpool <= 1'b1;
                    first_en   <= 1'b1;   // carga directa, sin comparar
                    state      <= PRE_CONV1;
                end

                // ── Ventana 1 ────────────────────────────
                PRE_CONV1: begin
                    window_sel <= 2'd1;
                    state      <= CONV1;
                end

                CONV1: begin
                    en_maxpool <= 1'b1;
                    state      <= PRE_CONV2;
                end

                // ── Ventana 2 ────────────────────────────
                PRE_CONV2: begin
                    window_sel <= 2'd2;
                    state      <= CONV2;
                end

                CONV2: begin
                    en_maxpool <= 1'b1;
                    state      <= PRE_CONV3;
                end

                // ── Ventana 3 ────────────────────────────
                PRE_CONV3: begin
                    window_sel <= 2'd3;
                    state      <= CONV3;
                end

                CONV3: begin
                    en_maxpool <= 1'b1;
                    state      <= FINISH;
                end

                // ── Fin ──────────────────────────────────
                FINISH: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule