module Register #(
    parameter DATAWIDTH_BUS       = 11  // 11 bits
)(
    input  wire [DATAWIDTH_BUS-1:0] Register_DataInBUS,
    input  wire                     Register_CLOCK,
    input  wire                     Register_Reset_InHigh,
    input  wire                     Register_Load_InLow,

    output wire [DATAWIDTH_BUS-1:0] Register_DataOutBUS
);

    reg [DATAWIDTH_BUS-1:0] Datos;

    always @(posedge Register_CLOCK) begin
        if (Register_Reset_InHigh == 1'b1)
            Datos <= {DATAWIDTH_BUS{1'b0}};
        else if (Register_Load_InLow == 1'b0)
            Datos <= Register_DataInBUS;
    end

    assign Register_DataOutBUS = Datos;

endmodule