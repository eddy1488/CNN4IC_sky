//=======================================================
//  SC_STATEMACHINE_WEIGHT_LOADER — fix weight_latch
//=======================================================
//  BUG CORREGIDO: ultimo registro de pesos nunca cargaba.
//
//  Mismo root cause que IMAGE_LOADER:
//    Al posedge T del ultimo bit del ultimo peso:
//      - SM transiciona IDLE→LOAD_ROW
//      - Main SPI block: weight_count <= weight_count + 1 (NBA, old=4)
//      - i_WROW al evaluar = 4 (correcto)
//    Al negedge T: CS sube → internal_reset ASYNC → weight_count = 0
//    Al posedge T+1:
//      - SM en LOAD_ROW, lee i_WROW = 0 → i_WROW-1 = 3'h7 → no carga
//
//  Fix:
//    weight_latch captura i_WROW al transicionar IDLE→LOAD_ROW.
//    Outputs usan weight_latch (sin -1).
//    Usa i_RESET global → sobrevive a subida de CS.
//
//  Nota de comando:
//    El comando SPI para LOAD WEIGHTS es ahora 3'b010
//    (antes era 3'b001). Actualizado en la condicion de
//    transicion IDLE→LOAD_ROW.
//=======================================================

module SC_STATEMACHINE_WEIGHT_LOADER #(
    parameter [6:0] ROW_BITS = 7'd15
)(
    output reg o_wload00, output reg o_wload01,
    output reg o_wload02, output reg o_wload03,
    output reg o_wload04,

    input       i_CLOCK,
    input       i_RESET,
    input [2:0] i_CMD,
    input [6:0] i_DATA_COUNT,
    input [2:0] i_WROW
);

localparam STATE_IDLE     = 1'b0;
localparam STATE_LOAD_ROW = 1'b1;
localparam [6:0] LAST_BIT = ROW_BITS - 7'd1;  // 14 — ambos operandos [6:0], sin truncamiento

reg STATE_Register;
reg STATE_Signal;

// ── Logica de siguiente estado ────────────────────────
always @(*) begin
    case (STATE_Register)
        STATE_IDLE:
            if (i_CMD == 3'b010 && i_DATA_COUNT == LAST_BIT)
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

// ── FIX: weight_latch ─────────────────────────────────
// Captura i_WROW al transicionar IDLE→LOAD_ROW.
// i_WROW en ese posedge = fila actual (OLD, pre-incremento).
// Usa i_RESET global → sobrevive a internal_reset.
reg [2:0] weight_latch;
always @(posedge i_CLOCK or posedge i_RESET) begin
    if (i_RESET)
        weight_latch <= 3'd0;
    else if (STATE_Register == STATE_IDLE && STATE_Signal == STATE_LOAD_ROW)
        weight_latch <= i_WROW;
end

// ── Outputs combinacionales — activo bajo ─────────────
// Usa STATE_Register (registrado) y weight_latch.
// El posedge T34 (clock extra) da el flanco con STATE_Register=LOAD_ROW
// y weight_mem ya actualizado → Register_Weight captura.
always @(*) begin
    o_wload00 = 1'b1; o_wload01 = 1'b1; o_wload02 = 1'b1;
    o_wload03 = 1'b1; o_wload04 = 1'b1;

    if (STATE_Register == STATE_LOAD_ROW) begin
        case (weight_latch)
            3'd0: o_wload00 = 1'b0;
            3'd1: o_wload01 = 1'b0;
            3'd2: o_wload02 = 1'b0;
            3'd3: o_wload03 = 1'b0;
            3'd4: o_wload04 = 1'b0;
            default: ;
        endcase
    end
end

endmodule