//=======================================================
//  cnn_proc_top — Subtop de Lógica y Procesamiento CNN
//=======================================================
//  Agrupa toda la lógica de clasificación convolucional:
//
//    - SC_STATEMACHINE_CNN_CTRL : orquesta dos corridas CNN
//         └── cnn_top           : convolución completa 10×10
//              ├── fragment_mux_10x10_6x6 : selecciona fragmento 6×6
//              └── mux_cnn                : convolucion + maxpool
//                   ├── window_mux_6x6_5x5
//                   ├── mac_parallel
//                   └── progressive_maxpool
//    - Comparador combinacional : MR1 > MR2 → clasificación
//
//  Interfaz hacia comm_mem_top:
//    Entradas (datos listos):
//      i_img_row00..09  — imagen cargada (10 × 30 bits)
//      i_wgt_row00..04  — pesos cargados  (5 × 15 bits)
//      i_start_cnn      — pulso de arranque (desde SPI cmd 011)
//    Salidas (resultados a guardar):
//      o_acc0, o_mr1_load — acumulador k0 + señal carga MR1
//      o_acc1, o_mr2_load — acumulador k1 + señal carga MR2
//      o_comp_result      — 1 si k0 > k1 (clasificacion final)
//      o_done             — pulso cuando ambos kernels terminaron
//=======================================================

module cnn_proc_top (
    input  wire        i_CLOCK,
    input  wire        i_RESET,

    // ── Control desde comm_mem_top ────────────────────
    input  wire        i_start_cnn,

    // ── Imagen 10×10 desde registros de imagen ────────
    input  wire [29:0] i_img_row00, i_img_row01, i_img_row02,
    input  wire [29:0] i_img_row03, i_img_row04, i_img_row05,
    input  wire [29:0] i_img_row06, i_img_row07, i_img_row08,
    input  wire [29:0] i_img_row09,

    // ── Pesos 5×5 desde registros de pesos ───────────
    input  wire [14:0] i_wgt_row00, i_wgt_row01, i_wgt_row02,
    input  wire [14:0] i_wgt_row03, i_wgt_row04,

    // ── Resultados hacia Master Registers ────────────
    output wire [15:0] o_acc0,
    output wire        o_mr1_load,    // activo bajo
    output wire [15:0] o_acc1,
    output wire        o_mr2_load,    // activo bajo

    // ── Resultado final de clasificación ─────────────
    output wire        o_comp_result, // 1 = kernel0 gana, 0 = kernel1 gana
    output wire        o_done
);

    // ── Wires internos del controlador CNN ───────────
    wire [15:0] ctrl_acc0, ctrl_acc1;
    wire        ctrl_mr1_load, ctrl_mr2_load;
    wire        ctrl_done;

    // ── Pasar señales al exterior ─────────────────────
    assign o_acc0     = ctrl_acc0;
    assign o_acc1     = ctrl_acc1;
    assign o_mr1_load = ctrl_mr1_load;
    assign o_mr2_load = ctrl_mr2_load;
    assign o_done     = ctrl_done;

    // ═══════════════════════════════════════════════════
    // 1. Controlador CNN — orquesta dos corridas secuenciales
    // ═══════════════════════════════════════════════════
    SC_STATEMACHINE_CNN_CTRL cnn_ctrl_u0 (
        .i_CLOCK    (i_CLOCK),
        .i_RESET    (i_RESET),
        .i_START_CNN(i_start_cnn),
        // Imagen
        .i_row00(i_img_row00), .i_row01(i_img_row01), .i_row02(i_img_row02),
        .i_row03(i_img_row03), .i_row04(i_img_row04), .i_row05(i_img_row05),
        .i_row06(i_img_row06), .i_row07(i_img_row07), .i_row08(i_img_row08),
        .i_row09(i_img_row09),
        // Pesos
        .i_wrow00(i_wgt_row00), .i_wrow01(i_wgt_row01), .i_wrow02(i_wgt_row02),
        .i_wrow03(i_wgt_row03), .i_wrow04(i_wgt_row04),
        // Salidas
        .o_acc0    (ctrl_acc0),
        .o_acc1    (ctrl_acc1),
        .o_mr1_load(ctrl_mr1_load),
        .o_mr2_load(ctrl_mr2_load),
        .o_done    (ctrl_done)
    );

    // ═══════════════════════════════════════════════════
    // 2. Comparador combinacional (signed 16 bits)
    //    1 si acc0 > acc1 → kernel0 gana (ej: imagen es una X)
    //    0 si acc0 ≤ acc1 → kernel1 gana (ej: imagen es una cruz)
    // ═══════════════════════════════════════════════════
    assign o_comp_result = ($signed(ctrl_acc0) > $signed(ctrl_acc1)) ? 1'b1 : 1'b0;

endmodule
