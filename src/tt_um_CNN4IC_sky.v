//=======================================================
//  tt_um_CNN4IC_sky — Tiny Tapeout Top Wrapper
//=======================================================
//  Mapeo de pines TT:
//
//  Entradas (ui):
//    ui[0] = SPI_Clk
//    ui[1] = SPI_CS_n
//    ui[2] = SPI_MOSI
//    ui[3] = CMD_Reset  (aborta comando SPI en curso)
//    ui[4..7] = (no usados)
//
//  Salidas (uo):
//    uo[0] = SPI_MISO
//    uo[1] = comp_result  (1=kernel0 gana, 0=kernel1 gana)
//    uo[2] = done         (pulso: ambos kernels terminaron)
//    uo[3] = MR1_Load_dbg (debug activo bajo)
//    uo[4] = MR2_Load_dbg (debug activo bajo)
//    uo[5..7] = (no usados)
//
//  Bidireccionales (uio): no usados
//
//  Señales TT estándar:
//    clk    = reloj del sistema
//    rst_n  = reset activo bajo (mapea a i_RESET activo alto)
//    ena    = habilitación (no usado internamente)
//=======================================================

`default_nettype none

module tt_um_CNN4IC_sky (
    input  wire [7:0] ui_in,    // Entradas dedicadas
    output wire [7:0] uo_out,   // Salidas dedicadas
    input  wire [7:0] uio_in,   // Bidireccionales (entrada)
    output wire [7:0] uio_out,  // Bidireccionales (salida)
    output wire [7:0] uio_oe,   // Bidireccionales (dirección: 1=salida)
    input  wire       ena,      // Habilitación (activo alto)
    input  wire       clk,      // Reloj del sistema
    input  wire       rst_n     // Reset activo bajo
);

    // Bidireccionales no usados
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // Reset: TT usa activo bajo, diseño usa activo alto
    wire i_reset = ~rst_n;

    // ── Wires entre comm_mem_top y cnn_proc_top ─────
    wire [29:0] img_row00, img_row01, img_row02, img_row03, img_row04;
    wire [29:0] img_row05, img_row06, img_row07, img_row08, img_row09;
    wire [14:0] wgt_row00, wgt_row01, wgt_row02, wgt_row03, wgt_row04;
    wire        start_cnn;
    wire [15:0] acc0, acc1;
    wire        mr1_load, mr2_load;
    wire        comp_result;
    wire        done;

    // ── Instancia: Comunicación y Memoria ───────────
    comm_mem_top comm_u0 (
        // SPI externo
        .i_SPI_Clk   (ui_in[0]),
        .i_SPI_CS_n  (ui_in[1]),
        .i_SPI_MOSI  (ui_in[2]),
        .o_SPI_MISO  (uo_out[0]),
        .i_RESET     (i_reset),
        .i_CMD_Reset (ui_in[3]),
        // Debug outputs
        .o_MR1_Load_dbg (uo_out[3]),
        .o_MR2_Load_dbg (uo_out[4]),
        // Imagen → cnn_proc_top
        .o_img_row00 (img_row00), .o_img_row01 (img_row01),
        .o_img_row02 (img_row02), .o_img_row03 (img_row03),
        .o_img_row04 (img_row04), .o_img_row05 (img_row05),
        .o_img_row06 (img_row06), .o_img_row07 (img_row07),
        .o_img_row08 (img_row08), .o_img_row09 (img_row09),
        // Pesos → cnn_proc_top
        .o_wgt_row00 (wgt_row00), .o_wgt_row01 (wgt_row01),
        .o_wgt_row02 (wgt_row02), .o_wgt_row03 (wgt_row03),
        .o_wgt_row04 (wgt_row04),
        // Control
        .o_start_cnn (start_cnn),
        // Resultados ← cnn_proc_top
        .i_acc0      (acc0),
        .i_mr1_load  (mr1_load),
        .i_acc1      (acc1),
        .i_mr2_load  (mr2_load),
        .i_comp_result (comp_result)
    );

    // ── Instancia: Procesamiento CNN ────────────────
    cnn_proc_top proc_u0 (
        .i_CLOCK     (clk),
        .i_RESET     (i_reset),
        .i_start_cnn (start_cnn),
        // Imagen ← comm_mem_top
        .i_img_row00 (img_row00), .i_img_row01 (img_row01),
        .i_img_row02 (img_row02), .i_img_row03 (img_row03),
        .i_img_row04 (img_row04), .i_img_row05 (img_row05),
        .i_img_row06 (img_row06), .i_img_row07 (img_row07),
        .i_img_row08 (img_row08), .i_img_row09 (img_row09),
        // Pesos ← comm_mem_top
        .i_wgt_row00 (wgt_row00), .i_wgt_row01 (wgt_row01),
        .i_wgt_row02 (wgt_row02), .i_wgt_row03 (wgt_row03),
        .i_wgt_row04 (wgt_row04),
        // Resultados → comm_mem_top
        .o_acc0      (acc0),
        .o_mr1_load  (mr1_load),
        .o_acc1      (acc1),
        .o_mr2_load  (mr2_load),
        // Clasificación y control
        .o_comp_result (comp_result),
        .o_done        (done)
    );

    // ── Salidas directas ────────────────────────────
    assign uo_out[1] = comp_result;
    assign uo_out[2] = done;
    assign uo_out[5] = 1'b0;
    assign uo_out[6] = 1'b0;
    assign uo_out[7] = 1'b0;

endmodule
