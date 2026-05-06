//=======================================================
//  spi_cnn_slave_8 — version final
//=======================================================
//  Protocolo MOSI (3 bits de comando al inicio):
//    3'b000 = IDLE                  : sin payload, no hace nada
//    3'b001 = LOAD IMAGE            : 10 filas x 30 bits
//    3'b010 = LOAD WEIGHTS          : 5 filas  x 15 bits
//    3'b011 = START CNN             : sin payload, pulso o_start_cnn
//    3'b100 = READ RESULT           : 1 clock → MISO (1 bit comparador)
//    3'b101 = READ MASTER REGISTER1 : 16 clocks → MISO (16 bits acc0)
//    3'b110 = READ MASTER REGISTER2 : 16 clocks → MISO (16 bits acc1)
//    3'b111 = READ WEIGHTS          : 16 clocks → MISO (16 bits pesos)
//
//  Fixes de timing aplicados (ver notas en bloques):
//    FIX-1: o_start_cnn, o_mp_load en bloques
//           separados con solo i_RESET (no internal_reset)
//           → sobreviven hasta el posedge donde la FSM los lee
//    FIX-2: SM loaders usan i_RESET (no internal_reset)
//           → ultimo registro siempre se carga correctamente
//
//  Puertos removidos respecto a version anterior:
//    - o_result_pos (antes pin externo, ahora no necesario)
//    - o_save_accum (comando SAVE ACCUM eliminado del mapa SPI)
//  Puertos agregados respecto a version anterior:
//    - i_cnn_result2 : resultado 16 bits acc1 para READ MASTER REGISTER2
//=======================================================

module spi_cnn_slave_8 #(
    parameter DATAWIDTH_BUS        = 8,
    parameter DATAWIDTH_BUS_IMAGE  = 10,
    parameter DATAWIDTH_BUS_WEIGHT = 5,
    parameter BITS_PER_POS         = 3,
    parameter DATAWIDTH_IMG_FULL   = DATAWIDTH_BUS_IMAGE  * BITS_PER_POS,  // 30
    parameter DATAWIDTH_WGT_FULL   = DATAWIDTH_BUS_WEIGHT * BITS_PER_POS   // 15
)(
    input  wire i_SPI_Clk,
    input  wire i_SPI_CS_n,
    input  wire i_SPI_MOSI,
    output wire o_SPI_MISO,

    input  wire i_RESET,      // Reset global — SM loaders y pulsos de salida
    input  wire i_cmd_reset,  // Aborta comando en curso (no afecta pulsos)

    // Pulsos de 1 ciclo (bloques separados, no borrados por CS)
    output reg  o_start_cnn,

    // Imagen: 30 bits por fila, 10 filas
    output wire [DATAWIDTH_IMG_FULL-1:0] o_row00, o_row01, o_row02, o_row03, o_row04,
    output wire [DATAWIDTH_IMG_FULL-1:0] o_row05, o_row06, o_row07, o_row08, o_row09,
    output wire o_load00, o_load01, o_load02, o_load03, o_load04,
    output wire o_load05, o_load06, o_load07, o_load08, o_load09,

    // Pesos: 15 bits por fila, 5 filas
    output wire [DATAWIDTH_WGT_FULL-1:0] o_wrow00, o_wrow01, o_wrow02, o_wrow03, o_wrow04,
    output wire o_wload00, o_wload01, o_wload02, o_wload03, o_wload04,

    // Resultado 16 bits acc0 desde Master Register 1 (cmd 101 READ MASTER REGISTER1)
    input  wire [15:0] i_cnn_result,

    // Resultado 16 bits acc1 desde Master Register 2 (cmd 110 READ MASTER REGISTER2)
    input  wire [15:0] i_cnn_result2,

    // Resultado 1 bit del comparador (cmd 100 READ RESULT)
    input  wire        i_comp_result,

    // MaxPool: datos hacia maxpool_shift (bloque separado, mantenido para compatibilidad)
    output reg  [10:0] o_mp_data,
    output reg         o_mp_load
);

    // ── Memorias internas ──────────────────────────────────────────────
    reg [DATAWIDTH_IMG_FULL-1:0] image_mem  [0:DATAWIDTH_BUS_IMAGE-1];
    reg [DATAWIDTH_WGT_FULL-1:0] weight_mem [0:DATAWIDTH_BUS_WEIGHT-1];

    assign o_row00 = image_mem[0]; assign o_row01 = image_mem[1];
    assign o_row02 = image_mem[2]; assign o_row03 = image_mem[3];
    assign o_row04 = image_mem[4]; assign o_row05 = image_mem[5];
    assign o_row06 = image_mem[6]; assign o_row07 = image_mem[7];
    assign o_row08 = image_mem[8]; assign o_row09 = image_mem[9];

    assign o_wrow00 = weight_mem[0]; assign o_wrow01 = weight_mem[1];
    assign o_wrow02 = weight_mem[2]; assign o_wrow03 = weight_mem[3];
    assign o_wrow04 = weight_mem[4];

    // ── Registros de control ──────────────────────────────────────────
    reg [2:0] cmd;
    reg [8:0] bit_count;
    reg [6:0] data_count;
    reg [3:0] row;
    reg [2:0] weight_count;
    reg [DATAWIDTH_IMG_FULL-1:0]  image_shift;
    reg [DATAWIDTH_WGT_FULL-1:0]  weight_shift;
    reg [4:0]  miso_count;
    reg        miso_active;

    // internal_reset: SOLO para contadores/shifts internos del SPI.
    // NO para o_start_cnn, o_mp_load ni SM loaders.
    wire internal_reset = i_SPI_CS_n | i_cmd_reset;

    localparam IMG_LAST_BIT = DATAWIDTH_IMG_FULL - 1;  // 29
    localparam WGT_LAST_BIT = DATAWIDTH_WGT_FULL - 1;  // 14

    // ── SM imagen: reset GLOBAL (FIX-2) ──────────────────────────────
    SC_STATEMACHINE_IMAGE_LOADER #(.ROW_BITS(DATAWIDTH_IMG_FULL))
    loader_image_sm (
        .i_CLOCK      (i_SPI_Clk),
        .i_RESET      (i_RESET),
        .i_CMD        (cmd),
        .i_DATA_COUNT (data_count),
        .i_ROW        (row),
        .o_load00(o_load00), .o_load01(o_load01), .o_load02(o_load02),
        .o_load03(o_load03), .o_load04(o_load04), .o_load05(o_load05),
        .o_load06(o_load06), .o_load07(o_load07), .o_load08(o_load08),
        .o_load09(o_load09)
    );

    // ── SM pesos: reset GLOBAL (FIX-2) ───────────────────────────────
    SC_STATEMACHINE_WEIGHT_LOADER #(.ROW_BITS(DATAWIDTH_WGT_FULL))
    loader_weight_sm (
        .i_CLOCK      (i_SPI_Clk),
        .i_RESET      (i_RESET),
        .i_CMD        (cmd),
        .i_DATA_COUNT (data_count),
        .i_WROW       (weight_count),
        .o_wload00(o_wload00), .o_wload01(o_wload01), .o_wload02(o_wload02),
        .o_wload03(o_wload03), .o_wload04(o_wload04)
    );

    // ── MISO: mux entre READ_RESULT (1b), READ_MR1 (16b), READ_MR2 (16b) ────
    // cmd 100: MISO = i_comp_result (1 clock, miso_count no avanza)
    // cmd 101: MISO = i_cnn_result  bit [15-miso_count] (16 clocks) — acc0 MR1
    // cmd 110: MISO = i_cnn_result2 bit [15-miso_count] (16 clocks) — acc1 MR2
    // cmd 111: MISO = i_cnn_result  bit [15-miso_count] (16 clocks) — pesos (fuente por defecto)
    assign o_SPI_MISO = miso_active ?
        ((cmd == 3'b100) ? i_comp_result                       :
         (cmd == 3'b110) ? i_cnn_result2[15 - miso_count[3:0]] :
                           i_cnn_result [15 - miso_count[3:0]])
        : 1'bZ;

    // ─────────────────────────────────────────────────────────────────
    // FIX-1a: o_start_cnn
    // Usa solo i_RESET global (no internal_reset).
    // El pulso se genera en el posedge donde bit_count==3 y cmd==011.
    // Dura hasta el SIGUIENTE posedge, donde el SM lo muestrea y el
    // default lo limpia. CS puede subir sin afectar el pulso.
    // ─────────────────────────────────────────────────────────────────
    always @(posedge i_SPI_Clk or posedge i_RESET) begin
        if (i_RESET)
            o_start_cnn <= 1'b0;
        else begin
            o_start_cnn <= 1'b0;  // default: limpiar en cada posedge
            if ((bit_count == 9'd3) && (cmd == 3'b011))
                o_start_cnn <= 1'b1;
        end
    end

    // ─────────────────────────────────────────────────────────────────
    // FIX-1c: o_mp_load + o_mp_data — bloque solo con reset GLOBAL
    // Mantenido para compatibilidad con maxpool_shift.
    // En el nuevo mapa de comandos no existe un cmd dedicado a LOAD MAXPOOL,
    // por lo que o_mp_load nunca se activa desde SPI (queda en 0).
    // ─────────────────────────────────────────────────────────────────
    always @(posedge i_SPI_Clk or posedge i_RESET) begin
        if (i_RESET) begin
            o_mp_load <= 1'b0;
            o_mp_data <= 11'd0;
        end else begin
            o_mp_load <= 1'b0;
				o_mp_data <= 11'd0;
            // Sin comando LOAD MAXPOOL en nuevo mapa — o_mp_load permanece 0
        end
    end

    // ─────────────────────────────────────────────────────────────────
    // Logica principal SPI: contadores, shifts, memorias
    // Reset con internal_reset (CS o i_cmd_reset)
    // ─────────────────────────────────────────────────────────────────
    always @(posedge i_SPI_Clk or posedge internal_reset) begin
        if (internal_reset) begin
            bit_count    <= 9'd0;
            data_count   <= 7'd0;
            row          <= 4'd0;
            weight_count <= 3'd0;
            miso_count   <= 5'd0;
            miso_active  <= 1'b0;
            cmd          <= 3'b000;
            image_shift  <= {DATAWIDTH_IMG_FULL{1'b0}};
            weight_shift <= {DATAWIDTH_WGT_FULL{1'b0}};
        end
        else begin
            bit_count <= bit_count + 9'd1;

            // ── Primeros 3 posedges: captura cmd (3 bits, MSB primero) ──
            if (bit_count < 9'd3) begin
                cmd[2 - bit_count[1:0]] <= i_SPI_MOSI;
                data_count <= 7'd0;
                // FIX-MISO: en el ultimo bit del CMD (bit_count==2), si es comando
                // de lectura, activar miso_active para que MISO sea valido desde
                // el primer clock del payload (bit_count==3, primer clock de datos).
                if (bit_count == 9'd2) begin
                    // cmd[2:1] ya capturados; cmd[0]=MOSI se aplica tras la NBA.
                    // Evaluamos los 2 bits ya conocidos + el bit actual de MOSI.
                    case ({cmd[2], cmd[1], i_SPI_MOSI})
                        3'b100, 3'b101, 3'b110, 3'b111: miso_active <= 1'b1;
                        default: miso_active <= 1'b0;
                    endcase
                end
            end
            else begin
                data_count <= data_count + 7'd1;

                case (cmd)

                    // CMD 000: IDLE — sin payload, no hace nada
                    3'b000: ;

                    // CMD 001: LOAD IMAGE — 10 filas x 30 bits
                    3'b001: begin
                        image_shift <= {image_shift[DATAWIDTH_IMG_FULL-2:0], i_SPI_MOSI};
                        if (data_count == IMG_LAST_BIT) begin
                            image_mem[row] <= {image_shift[DATAWIDTH_IMG_FULL-2:0], i_SPI_MOSI};
                            row        <= row + 4'd1;
                            data_count <= 7'd0;
                        end
                    end

                    // CMD 010: LOAD WEIGHTS — 5 filas x 15 bits
                    3'b010: begin
                        weight_shift <= {weight_shift[DATAWIDTH_WGT_FULL-2:0], i_SPI_MOSI};
                        if (data_count == WGT_LAST_BIT) begin
                            weight_mem[weight_count] <= {weight_shift[DATAWIDTH_WGT_FULL-2:0], i_SPI_MOSI};
                            weight_count <= weight_count + 3'd1;
                            data_count   <= 7'd0;
                        end
                    end

                    // CMD 011: START CNN — pulso generado en bloque separado (FIX-1a)
                    3'b011: ;

                    // CMD 100: READ RESULT — 1 bit MISO (comparador)
                    // miso_count NO avanza (no hay multiplex de bits)
                    // miso_active ya activo desde la captura del ultimo bit CMD (bit_count==2)
                    3'b100: begin
                        // miso_count queda en 0: siempre muestra i_comp_result
                    end

                    // CMD 101: READ MASTER REGISTER1 — 16 bits MSB primero por MISO (acc0)
                    // miso_active ya activo desde bit_count==2 (ultimo bit CMD)
                    // miso_count=0 en primer clock → bit[15], incrementa cada clock siguiente
                    3'b101: begin
                        if (miso_count < 5'd15)
                            miso_count <= miso_count + 5'd1;
                    end

                    // CMD 110: READ MASTER REGISTER2 — 16 bits MSB primero por MISO (acc1)
                    3'b110: begin
                        if (miso_count < 5'd15)
                            miso_count <= miso_count + 5'd1;
                    end

                    // CMD 111: READ WEIGHTS — 16 bits MSB primero por MISO
                    3'b111: begin
                        if (miso_count < 5'd15)
                            miso_count <= miso_count + 5'd1;
                    end

                    default: ;
                endcase
            end
        end
    end

endmodule