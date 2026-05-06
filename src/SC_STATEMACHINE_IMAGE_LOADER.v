//=======================================================
//  SC_STATEMACHINE_IMAGE_LOADER — fix row_latch
//=======================================================
//  BUG CORREGIDO: ultimo registro de imagen nunca cargaba.
//
//  Root cause:
//    Al posedge T del ultimo bit de la ultima fila:
//      - SM transiciona IDLE→LOAD_ROW (STATE_Signal=LOAD_ROW)
//      - Main SPI block: row <= row + 1 (NBA pendiente, row=OLD=9)
//      - i_ROW al evaluar = 9 (correcto)
//    Al negedge T: CS sube → internal_reset ASYNC → row = 0
//    Al posedge T+1:
//      - SM ya en LOAD_ROW
//      - i_ROW = 0 (reseteado) → i_ROW-1 = 4'hF → ninguna fila → no carga
//
//  Fix:
//    row_latch captura i_ROW en el mismo posedge donde
//    la SM transiciona IDLE→LOAD_ROW (i_ROW aun tiene el
//    valor OLD = fila que se esta cargando, pre-incremento).
//    Los outputs usan row_latch directamente (sin -1).
//    row_latch usa i_RESET global (no internal_reset), por lo
//    tanto sobrevive a la subida de CS.
//
//  Filas 0-8: funcionaban antes (CS no sube entre su
//    posedge-T y posedge-T+1). Siguen funcionando igual
//    porque row_latch captura el mismo valor que antes.
//
//  Nota de comando:
//    El comando SPI para LOAD IMAGE es ahora 3'b001
//    (antes era 3'b000). Actualizado en la condicion de
//    transicion IDLE→LOAD_ROW.
//=======================================================

module SC_STATEMACHINE_IMAGE_LOADER #(
    parameter [6:0] ROW_BITS = 7'd30
)(
    output reg o_load00, output reg o_load01,
    output reg o_load02, output reg o_load03,
    output reg o_load04, output reg o_load05,
    output reg o_load06, output reg o_load07,
    output reg o_load08, output reg o_load09,

    input       i_CLOCK,
    input       i_RESET,
    input [2:0] i_CMD,
    input [6:0] i_DATA_COUNT,
    input [3:0] i_ROW
);

localparam STATE_IDLE     = 1'b0;
localparam STATE_LOAD_ROW = 1'b1;
localparam [6:0] LAST_BIT = ROW_BITS - 7'd1;  // 29 — ambos operandos [6:0], sin truncamiento

reg STATE_Register;
reg STATE_Signal;

// ── Logica de siguiente estado ────────────────────────
always @(*) begin
    case (STATE_Register)
        STATE_IDLE:
            if (i_CMD == 3'b001 && i_DATA_COUNT == LAST_BIT)
                STATE_Signal = STATE_LOAD_ROW;
            else
                STATE_Signal = STATE_IDLE;
        STATE_LOAD_ROW:
            STATE_Signal = STATE_IDLE;
        default:
            STATE_Signal = STATE_IDLE;
    endcase
end

// ── Registro de estado ────────────────────────────────
always @(posedge i_CLOCK or posedge i_RESET) begin
    if (i_RESET)
        STATE_Register <= STATE_IDLE;
    else
        STATE_Register <= STATE_Signal;
end

// ── FIX: row_latch ─────────────────────────────────────
// Captura i_ROW en el posedge donde SM transiciona IDLE→LOAD_ROW.
// En ese momento i_ROW = fila actual (OLD, pre-incremento del main block).
// Ese es exactamente el indice de la fila que queremos cargar.
// Usa i_RESET global → sobrevive a internal_reset (subida de CS).
reg [3:0] row_latch;
always @(posedge i_CLOCK or posedge i_RESET) begin
    if (i_RESET)
        row_latch <= 4'd0;
    else if (STATE_Register == STATE_IDLE && STATE_Signal == STATE_LOAD_ROW)
        row_latch <= i_ROW;
    // else: mantiene valor hasta el proximo LOAD_ROW
end

// ── Outputs combinacionales — activo bajo ─────────────
// Usa STATE_Register (registrado) y row_latch.
// El posedge T34 (clock extra en el SPI master) da el flanco con
// STATE_Register=LOAD_ROW e image_mem ya actualizado → Register_Imag captura.
always @(*) begin
    o_load00 = 1'b1; o_load01 = 1'b1; o_load02 = 1'b1; o_load03 = 1'b1;
    o_load04 = 1'b1; o_load05 = 1'b1; o_load06 = 1'b1; o_load07 = 1'b1;
    o_load08 = 1'b1; o_load09 = 1'b1;

    if (STATE_Register == STATE_LOAD_ROW) begin
        case (row_latch)
            4'd0: o_load00 = 1'b0;
            4'd1: o_load01 = 1'b0;
            4'd2: o_load02 = 1'b0;
            4'd3: o_load03 = 1'b0;
            4'd4: o_load04 = 1'b0;
            4'd5: o_load05 = 1'b0;
            4'd6: o_load06 = 1'b0;
            4'd7: o_load07 = 1'b0;
            4'd8: o_load08 = 1'b0;
            4'd9: o_load09 = 1'b0;
            default: ;
        endcase
    end
end

endmodule