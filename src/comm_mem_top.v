//=======================================================
//  comm_mem_top — Subtop de Comunicación y Memoria
//=======================================================
//  Agrupa todo lo relacionado con la interfaz SPI y el
//  almacenamiento de datos que entran y salen del chip:
//
//    - spi_cnn_slave_8   : esclavo SPI, decodifica comandos
//    - Register_Imag x10 : almacena las 10 filas de la imagen
//    - Register_Weight x5: almacena las 5 filas del kernel
//    - Master_register x2: almacena acc0 (MR1) y acc1 (MR2)
//
//  Interfaz hacia cnn_proc_top:
//    Salidas (datos listos para procesar):
//      o_img_row00..09  — imagen cargada (10 × 30 bits)
//      o_wgt_row00..04  — pesos cargados  (5 × 15 bits)
//      o_start_cnn      — pulso de arranque CNN (cmd 011)
//    Entradas (resultados del procesamiento):
//      i_acc0, i_mr1_load — acumulador kernel0 + señal de carga
//      i_acc1, i_mr2_load — acumulador kernel1 + señal de carga
//
//  Puertos externos SPI:
//      i_SPI_Clk, i_SPI_CS_n, i_SPI_MOSI, o_SPI_MISO
//      i_RESET, i_CMD_Reset
//      o_MR1_Load_dbg, o_MR2_Load_dbg  (debug, activo bajo)
//=======================================================

module comm_mem_top #(
    parameter DATAWIDTH_BUS        = 8,
    parameter DATAWIDTH_BUS_IMAGE  = 10,
    parameter DATAWIDTH_BUS_WEIGHT = 5,
    parameter BITS_PER_POS         = 3,
    parameter DATAWIDTH_BUS_FULL   = DATAWIDTH_BUS_IMAGE  * BITS_PER_POS,  // 30
    parameter DATAWIDTH_WGT_FULL   = DATAWIDTH_BUS_WEIGHT * BITS_PER_POS   // 15
)(
    // ── Pines SPI externos ────────────────────────────
    input  wire i_SPI_Clk,
    input  wire i_SPI_CS_n,
    input  wire i_SPI_MOSI,
    output wire o_SPI_MISO,
    input  wire i_RESET,
    input  wire i_CMD_Reset,

    // ── Debug: pulsos de carga de Master Registers ────
    output wire o_MR1_Load_dbg,   // activo bajo
    output wire o_MR2_Load_dbg,   // activo bajo

    // ── Hacia cnn_proc_top: imagen lista ──────────────
    output wire [DATAWIDTH_BUS_FULL-1:0] o_img_row00, o_img_row01,
    output wire [DATAWIDTH_BUS_FULL-1:0] o_img_row02, o_img_row03,
    output wire [DATAWIDTH_BUS_FULL-1:0] o_img_row04, o_img_row05,
    output wire [DATAWIDTH_BUS_FULL-1:0] o_img_row06, o_img_row07,
    output wire [DATAWIDTH_BUS_FULL-1:0] o_img_row08, o_img_row09,

    // ── Hacia cnn_proc_top: pesos listos ─────────────
    output wire [DATAWIDTH_WGT_FULL-1:0] o_wgt_row00, o_wgt_row01,
    output wire [DATAWIDTH_WGT_FULL-1:0] o_wgt_row02, o_wgt_row03,
    output wire [DATAWIDTH_WGT_FULL-1:0] o_wgt_row04,

    // ── Hacia cnn_proc_top: control ──────────────────
    output wire o_start_cnn,

    // ── Desde cnn_proc_top: resultados a guardar ─────
    input  wire [15:0] i_acc0,
    input  wire        i_mr1_load,    // activo bajo
    input  wire [15:0] i_acc1,
    input  wire        i_mr2_load,    // activo bajo

    // ── Desde cnn_proc_top: resultado clasificación ──
    input  wire        i_comp_result  // 1=k0 gana, 0=k1 gana (cmd 100)
);

    // ── Wires internos SPI → Registros de imagen ─────
    wire [DATAWIDTH_BUS_FULL-1:0] spi_row00, spi_row01, spi_row02, spi_row03, spi_row04;
    wire [DATAWIDTH_BUS_FULL-1:0] spi_row05, spi_row06, spi_row07, spi_row08, spi_row09;
    wire load_img_u0, load_img_u1, load_img_u2, load_img_u3, load_img_u4;
    wire load_img_u5, load_img_u6, load_img_u7, load_img_u8, load_img_u9;

    // ── Wires internos SPI → Registros de pesos ──────
    wire [DATAWIDTH_WGT_FULL-1:0] spi_wrow00, spi_wrow01, spi_wrow02, spi_wrow03, spi_wrow04;
    wire wload_u0, wload_u1, wload_u2, wload_u3, wload_u4;

    // ── Wires Master Registers → SPI (lectura) ───────
    wire [15:0] mr1_out, mr2_out;

    // ── Debug pins ────────────────────────────────────
    assign o_MR1_Load_dbg = i_mr1_load;
    assign o_MR2_Load_dbg = i_mr2_load;

    // ═══════════════════════════════════════════════════
    // 1. SPI Slave
    // ═══════════════════════════════════════════════════
    spi_cnn_slave_8 #(
        .DATAWIDTH_BUS       (DATAWIDTH_BUS),
        .DATAWIDTH_BUS_IMAGE (DATAWIDTH_BUS_IMAGE),
        .DATAWIDTH_BUS_WEIGHT(DATAWIDTH_BUS_WEIGHT),
        .BITS_PER_POS        (BITS_PER_POS)
    ) spi_u0 (
        .i_SPI_Clk   (i_SPI_Clk),
        .i_SPI_CS_n  (i_SPI_CS_n),
        .i_SPI_MOSI  (i_SPI_MOSI),
        .o_SPI_MISO  (o_SPI_MISO),
        .i_RESET     (i_RESET),
        .i_cmd_reset (i_CMD_Reset),
        .o_start_cnn (o_start_cnn),
        // Imagen
        .o_row00(spi_row00), .o_row01(spi_row01), .o_row02(spi_row02),
        .o_row03(spi_row03), .o_row04(spi_row04), .o_row05(spi_row05),
        .o_row06(spi_row06), .o_row07(spi_row07), .o_row08(spi_row08),
        .o_row09(spi_row09),
        .o_load00(load_img_u0), .o_load01(load_img_u1), .o_load02(load_img_u2),
        .o_load03(load_img_u3), .o_load04(load_img_u4), .o_load05(load_img_u5),
        .o_load06(load_img_u6), .o_load07(load_img_u7), .o_load08(load_img_u8),
        .o_load09(load_img_u9),
        // Pesos
        .o_wrow00(spi_wrow00), .o_wrow01(spi_wrow01), .o_wrow02(spi_wrow02),
        .o_wrow03(spi_wrow03), .o_wrow04(spi_wrow04),
        .o_wload00(wload_u0), .o_wload01(wload_u1), .o_wload02(wload_u2),
        .o_wload03(wload_u3), .o_wload04(wload_u4),
        // MISO sources
        .i_cnn_result (mr1_out),
        .i_cnn_result2(mr2_out),
        .i_comp_result(i_comp_result),  // viene de cnn_proc_top (cmd 100)
        // MaxPool (no utilizado)
        .o_mp_data(), .o_mp_load()
    );

    // ═══════════════════════════════════════════════════
    // 2. Registros de Imagen (10 × 30 bits)
    // ═══════════════════════════════════════════════════
    Register_Imag #(.DATAWIDTH_BUS_IMAGE(DATAWIDTH_BUS_IMAGE),.BITS_PER_POS(BITS_PER_POS))
        reg_img_u0 (.Register_Imag_DataInBUS(spi_row00), .Register_Imag_CLOCK(i_SPI_Clk),
                    .Register_Imag_Reset_InHigh(i_RESET), .Register_Imag_Load_InLow(load_img_u0),
                    .Register_Imag_DataOutBUS(o_img_row00));

    Register_Imag #(.DATAWIDTH_BUS_IMAGE(DATAWIDTH_BUS_IMAGE),.BITS_PER_POS(BITS_PER_POS))
        reg_img_u1 (.Register_Imag_DataInBUS(spi_row01), .Register_Imag_CLOCK(i_SPI_Clk),
                    .Register_Imag_Reset_InHigh(i_RESET), .Register_Imag_Load_InLow(load_img_u1),
                    .Register_Imag_DataOutBUS(o_img_row01));

    Register_Imag #(.DATAWIDTH_BUS_IMAGE(DATAWIDTH_BUS_IMAGE),.BITS_PER_POS(BITS_PER_POS))
        reg_img_u2 (.Register_Imag_DataInBUS(spi_row02), .Register_Imag_CLOCK(i_SPI_Clk),
                    .Register_Imag_Reset_InHigh(i_RESET), .Register_Imag_Load_InLow(load_img_u2),
                    .Register_Imag_DataOutBUS(o_img_row02));

    Register_Imag #(.DATAWIDTH_BUS_IMAGE(DATAWIDTH_BUS_IMAGE),.BITS_PER_POS(BITS_PER_POS))
        reg_img_u3 (.Register_Imag_DataInBUS(spi_row03), .Register_Imag_CLOCK(i_SPI_Clk),
                    .Register_Imag_Reset_InHigh(i_RESET), .Register_Imag_Load_InLow(load_img_u3),
                    .Register_Imag_DataOutBUS(o_img_row03));

    Register_Imag #(.DATAWIDTH_BUS_IMAGE(DATAWIDTH_BUS_IMAGE),.BITS_PER_POS(BITS_PER_POS))
        reg_img_u4 (.Register_Imag_DataInBUS(spi_row04), .Register_Imag_CLOCK(i_SPI_Clk),
                    .Register_Imag_Reset_InHigh(i_RESET), .Register_Imag_Load_InLow(load_img_u4),
                    .Register_Imag_DataOutBUS(o_img_row04));

    Register_Imag #(.DATAWIDTH_BUS_IMAGE(DATAWIDTH_BUS_IMAGE),.BITS_PER_POS(BITS_PER_POS))
        reg_img_u5 (.Register_Imag_DataInBUS(spi_row05), .Register_Imag_CLOCK(i_SPI_Clk),
                    .Register_Imag_Reset_InHigh(i_RESET), .Register_Imag_Load_InLow(load_img_u5),
                    .Register_Imag_DataOutBUS(o_img_row05));

    Register_Imag #(.DATAWIDTH_BUS_IMAGE(DATAWIDTH_BUS_IMAGE),.BITS_PER_POS(BITS_PER_POS))
        reg_img_u6 (.Register_Imag_DataInBUS(spi_row06), .Register_Imag_CLOCK(i_SPI_Clk),
                    .Register_Imag_Reset_InHigh(i_RESET), .Register_Imag_Load_InLow(load_img_u6),
                    .Register_Imag_DataOutBUS(o_img_row06));

    Register_Imag #(.DATAWIDTH_BUS_IMAGE(DATAWIDTH_BUS_IMAGE),.BITS_PER_POS(BITS_PER_POS))
        reg_img_u7 (.Register_Imag_DataInBUS(spi_row07), .Register_Imag_CLOCK(i_SPI_Clk),
                    .Register_Imag_Reset_InHigh(i_RESET), .Register_Imag_Load_InLow(load_img_u7),
                    .Register_Imag_DataOutBUS(o_img_row07));

    Register_Imag #(.DATAWIDTH_BUS_IMAGE(DATAWIDTH_BUS_IMAGE),.BITS_PER_POS(BITS_PER_POS))
        reg_img_u8 (.Register_Imag_DataInBUS(spi_row08), .Register_Imag_CLOCK(i_SPI_Clk),
                    .Register_Imag_Reset_InHigh(i_RESET), .Register_Imag_Load_InLow(load_img_u8),
                    .Register_Imag_DataOutBUS(o_img_row08));

    Register_Imag #(.DATAWIDTH_BUS_IMAGE(DATAWIDTH_BUS_IMAGE),.BITS_PER_POS(BITS_PER_POS))
        reg_img_u9 (.Register_Imag_DataInBUS(spi_row09), .Register_Imag_CLOCK(i_SPI_Clk),
                    .Register_Imag_Reset_InHigh(i_RESET), .Register_Imag_Load_InLow(load_img_u9),
                    .Register_Imag_DataOutBUS(o_img_row09));

    // ═══════════════════════════════════════════════════
    // 3. Registros de Pesos (5 × 15 bits)
    // ═══════════════════════════════════════════════════
    Register_Weight #(.DATAWIDTH_BUS_WEIGHT(DATAWIDTH_BUS_WEIGHT),.BITS_PER_POS(BITS_PER_POS))
        reg_wgt_u0 (.Register_Weight_DataInBUS(spi_wrow00), .Register_Weight_CLOCK(i_SPI_Clk),
                    .Register_Weight_Reset_InHigh(i_RESET), .Register_Weight_Load_InLow(wload_u0),
                    .Register_Weight_DataOutBUS(o_wgt_row00));

    Register_Weight #(.DATAWIDTH_BUS_WEIGHT(DATAWIDTH_BUS_WEIGHT),.BITS_PER_POS(BITS_PER_POS))
        reg_wgt_u1 (.Register_Weight_DataInBUS(spi_wrow01), .Register_Weight_CLOCK(i_SPI_Clk),
                    .Register_Weight_Reset_InHigh(i_RESET), .Register_Weight_Load_InLow(wload_u1),
                    .Register_Weight_DataOutBUS(o_wgt_row01));

    Register_Weight #(.DATAWIDTH_BUS_WEIGHT(DATAWIDTH_BUS_WEIGHT),.BITS_PER_POS(BITS_PER_POS))
        reg_wgt_u2 (.Register_Weight_DataInBUS(spi_wrow02), .Register_Weight_CLOCK(i_SPI_Clk),
                    .Register_Weight_Reset_InHigh(i_RESET), .Register_Weight_Load_InLow(wload_u2),
                    .Register_Weight_DataOutBUS(o_wgt_row02));

    Register_Weight #(.DATAWIDTH_BUS_WEIGHT(DATAWIDTH_BUS_WEIGHT),.BITS_PER_POS(BITS_PER_POS))
        reg_wgt_u3 (.Register_Weight_DataInBUS(spi_wrow03), .Register_Weight_CLOCK(i_SPI_Clk),
                    .Register_Weight_Reset_InHigh(i_RESET), .Register_Weight_Load_InLow(wload_u3),
                    .Register_Weight_DataOutBUS(o_wgt_row03));

    Register_Weight #(.DATAWIDTH_BUS_WEIGHT(DATAWIDTH_BUS_WEIGHT),.BITS_PER_POS(BITS_PER_POS))
        reg_wgt_u4 (.Register_Weight_DataInBUS(spi_wrow04), .Register_Weight_CLOCK(i_SPI_Clk),
                    .Register_Weight_Reset_InHigh(i_RESET), .Register_Weight_Load_InLow(wload_u4),
                    .Register_Weight_DataOutBUS(o_wgt_row04));

    // ═══════════════════════════════════════════════════
    // 4. Master Register 1 — acumulador kernel0 (MR1)
    // ═══════════════════════════════════════════════════
    Master_register #(.DATAWIDTH_BUS(16)) mr1_u0 (
        .Master_register_DataInBUS   (i_acc0),
        .Master_register_CLOCK       (i_SPI_Clk),
        .Master_register_Reset_InHigh(i_RESET),
        .Master_register_Load_InLow  (i_mr1_load),
        .Master_register_DataOutBUS  (mr1_out)
    );

    // ═══════════════════════════════════════════════════
    // 5. Master Register 2 — acumulador kernel1 (MR2)
    // ═══════════════════════════════════════════════════
    Master_register #(.DATAWIDTH_BUS(16)) mr2_u0 (
        .Master_register_DataInBUS   (i_acc1),
        .Master_register_CLOCK       (i_SPI_Clk),
        .Master_register_Reset_InHigh(i_RESET),
        .Master_register_Load_InLow  (i_mr2_load),
        .Master_register_DataOutBUS  (mr2_out)
    );

endmodule
