module Register_Weight #(
    parameter DATAWIDTH_BUS_WEIGHT = 5,
    parameter BITS_PER_POS         = 3,
    parameter DATAWIDTH_BUS        = DATAWIDTH_BUS_WEIGHT * BITS_PER_POS  // 15 bits ★ Fix
)(
    input  wire [DATAWIDTH_BUS-1:0] Register_Weight_DataInBUS,
    input  wire                     Register_Weight_CLOCK,
    input  wire                     Register_Weight_Reset_InHigh,
    input  wire                     Register_Weight_Load_InLow,

    output wire [DATAWIDTH_BUS-1:0] Register_Weight_DataOutBUS
);

    reg [DATAWIDTH_BUS-1:0] Datos;

    always @(posedge Register_Weight_CLOCK) begin
        if (Register_Weight_Reset_InHigh == 1'b1)
            Datos <= {DATAWIDTH_BUS{1'b0}};
        else if (Register_Weight_Load_InLow == 1'b0)
            Datos <= Register_Weight_DataInBUS;
    end

    assign Register_Weight_DataOutBUS = Datos;

endmodule