//=======================================================
//  SC_STATEMACHINE_CNN_CTRL — Controlador CNN con interfaz SPI
//=======================================================
//  Corre cnn_top dos veces de forma secuencial, una por
//  cada kernel. Cada corrida es disparada por un pulso
//  i_START_CNN proveniente del SPI (cmd 010).
//
//  Flujo esperado desde el MCU:
//    1. cmd 001 → carga kernel0 en registros de pesos
//    2. cmd 010 → primer START  → chip procesa 9 frags con kernel0 → acc0
//    3. cmd 001 → carga kernel1 en registros de pesos
//    4. cmd 010 → segundo START → chip procesa 9 frags con kernel1 → acc1
//    5. cmd 011 → lee MR1 (acc0)
//    6. cmd 011 → lee MR2 (acc1)  [o cmd 110 para comparar]
//
//  FSM:
//    IDLE
//      → LATCH_K0    captura kernel0 del SPI
//      → CNN_RESET0  cnn_rst=1 por 1 ciclo
//      → CNN_START0  cnn_start=1 por 1 ciclo
//      → CNN_WAIT0   espera cnn_done
//      → SAVE_K0     guarda acc en o_acc0, pulsa o_mr1_load
//      → WAIT_K1     espera segundo i_START_CNN
//      → LATCH_K1    captura kernel1 del SPI
//      → CNN_RESET1  cnn_rst=1 por 1 ciclo
//      → CNN_START1  cnn_start=1 por 1 ciclo
//      → CNN_WAIT1   espera cnn_done
//      → SAVE_K1     guarda acc en o_acc1, pulsa o_mr2_load
//      → FINISH      pulsa o_done
//      → IDLE
//
//  Notas:
//    - kernel_reg: se captura al inicio de cada fase para que el SPI
//      pueda cambiar los pesos sin afectar el procesamiento en curso
//    - o_mr1_load y o_mr2_load son activos bajo (convención SPI)
//    - cnn_top se resetea explícitamente antes de cada corrida
//=======================================================

module SC_STATEMACHINE_CNN_CTRL (
    input  wire         i_CLOCK,
    input  wire         i_RESET,
    input  wire         i_START_CNN,      // pulso desde SPI cmd 010

    // Imagen 10x10 desde registros SPI (10 filas × 30 bits)
    input  wire [29:0]  i_row00, i_row01, i_row02, i_row03, i_row04,
    input  wire [29:0]  i_row05, i_row06, i_row07, i_row08, i_row09,

    // Pesos 5x5 desde registros SPI (5 filas × 15 bits)
    input  wire [14:0]  i_wrow00, i_wrow01, i_wrow02, i_wrow03, i_wrow04,

    // Salidas hacia Master Registers
    output reg  [15:0]  o_acc0,       // resultado kernel0 → MR1
    output reg  [15:0]  o_acc1,       // resultado kernel1 → MR2
    output reg          o_mr1_load,   // activo bajo: guarda acc0 en MR1
    output reg          o_mr2_load,   // activo bajo: guarda acc1 en MR2
    output reg          o_done        // activo alto: ambos kernels procesados
);

    // ── Estados ──────────────────────────────────────────
    localparam IDLE        = 4'd0;
    localparam LATCH_K0    = 4'd1;
    localparam CNN_RESET0  = 4'd2;
    localparam CNN_START0  = 4'd3;
    localparam CNN_WAIT0   = 4'd4;
    localparam SAVE_K0     = 4'd5;
    localparam WAIT_K1     = 4'd6;
    localparam LATCH_K1    = 4'd7;
    localparam CNN_RESET1  = 4'd8;
    localparam CNN_START1  = 4'd9;
    localparam CNN_WAIT1   = 4'd10;
    localparam SAVE_K1     = 4'd11;
    localparam FINISH      = 4'd12;

    reg [3:0] state;

    // ── Kernel registrado ─────────────────────────────────
    // Se captura antes de cada corrida para aislar el proceso
    // del SPI durante el procesamiento
    reg [74:0] kernel_reg;

    // ── Imagen empaquetada (combinacional) ───────────────
    wire [299:0] image_flat;
    assign image_flat = {i_row09, i_row08, i_row07, i_row06, i_row05,
                         i_row04, i_row03, i_row02, i_row01, i_row00};

    // ── Señales de control hacia cnn_top ─────────────────
    reg        cnn_rst;
    reg        cnn_start;
    wire       cnn_done;
    wire signed [15:0] cnn_acc;

    // ── Instancia cnn_top ─────────────────────────────────
    cnn_top cnn_inst (
        .clk        (i_CLOCK),
        .rst        (cnn_rst),
        .start      (cnn_start),
        .image_flat (image_flat),
        .kernel_flat(kernel_reg),
        .done       (cnn_done),
        .acc        (cnn_acc)
    );

    // ── FSM ──────────────────────────────────────────────
    always @(posedge i_CLOCK or posedge i_RESET) begin
        if (i_RESET) begin
            state      <= IDLE;
            kernel_reg <= 75'd0;
            o_acc0     <= 16'd0;
            o_acc1     <= 16'd0;
            o_mr1_load <= 1'b1;
            o_mr2_load <= 1'b1;
            o_done     <= 1'b0;
            cnn_rst    <= 1'b1;
            cnn_start  <= 1'b0;
        end else begin
            // defaults de un ciclo
            cnn_rst    <= 1'b0;
            cnn_start  <= 1'b0;
            o_mr1_load <= 1'b1;
            o_mr2_load <= 1'b1;
            o_done     <= 1'b0;

            case (state)

                IDLE: begin
                    cnn_rst <= 1'b1;   // mantiene cnn_top en reset mientras espera
                    if (i_START_CNN)
                        state <= LATCH_K0;
                end

                // ── Kernel 0 ─────────────────────────────

                LATCH_K0: begin
                    // Captura los pesos actuales del SPI
                    kernel_reg <= {i_wrow04, i_wrow03, i_wrow02,
                                   i_wrow01, i_wrow00};
                    state      <= CNN_RESET0;
                end

                CNN_RESET0: begin
                    cnn_rst <= 1'b1;   // reset de 1 ciclo a cnn_top
                    state   <= CNN_START0;
                end

                CNN_START0: begin
                    cnn_start <= 1'b1;   // arranque de 1 ciclo
                    state     <= CNN_WAIT0;
                end

                CNN_WAIT0: begin
                    if (cnn_done)        // espera sin tocar cnn_start
                        state <= SAVE_K0;
                end

                SAVE_K0: begin
                    o_acc0     <= cnn_acc;   // captura resultado
                    o_mr1_load <= 1'b0;      // activo: guarda en MR1
                    state      <= WAIT_K1;
                end

                // ── Espera kernel 1 ───────────────────────

                WAIT_K1: begin
                    // El MCU carga el nuevo kernel via cmd 001
                    // y luego dispara cmd 010 para el segundo START
                    if (i_START_CNN)
                        state <= LATCH_K1;
                end

                // ── Kernel 1 ─────────────────────────────

                LATCH_K1: begin
                    kernel_reg <= {i_wrow04, i_wrow03, i_wrow02,
                                   i_wrow01, i_wrow00};
                    state      <= CNN_RESET1;
                end

                CNN_RESET1: begin
                    cnn_rst <= 1'b1;
                    state   <= CNN_START1;
                end

                CNN_START1: begin
                    cnn_start <= 1'b1;
                    state     <= CNN_WAIT1;
                end

                CNN_WAIT1: begin
                    if (cnn_done)
                        state <= SAVE_K1;
                end

                SAVE_K1: begin
                    o_acc1     <= cnn_acc;
                    o_mr2_load <= 1'b0;      // activo: guarda en MR2
                    state      <= FINISH;
                end

                // ── Fin ──────────────────────────────────

                FINISH: begin
                    o_done <= 1'b1;
                    state  <= IDLE;
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule