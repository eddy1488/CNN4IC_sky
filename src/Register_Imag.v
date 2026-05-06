module Register_Imag #(
    parameter DATAWIDTH_BUS_IMAGE = 10,
    parameter BITS_PER_POS        = 3,
    parameter DATAWIDTH_BUS       = DATAWIDTH_BUS_IMAGE * BITS_PER_POS  // 30 bits
)(
    input  wire [DATAWIDTH_BUS-1:0] Register_Imag_DataInBUS,
    input  wire                     Register_Imag_CLOCK,
    input  wire                     Register_Imag_Reset_InHigh,
    input  wire                     Register_Imag_Load_InLow,

    output wire [DATAWIDTH_BUS-1:0] Register_Imag_DataOutBUS
);

    reg [DATAWIDTH_BUS-1:0] Datos;

    always @(posedge Register_Imag_CLOCK) begin
        if (Register_Imag_Reset_InHigh == 1'b1)
            Datos <= {DATAWIDTH_BUS{1'b0}};
        else if (Register_Imag_Load_InLow == 1'b0)
            Datos <= Register_Imag_DataInBUS;
    end

    assign Register_Imag_DataOutBUS = Datos;

endmodule