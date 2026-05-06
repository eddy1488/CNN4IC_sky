module Master_register #(
    parameter DATAWIDTH_BUS = 16  // resultado final 16 bits -> MISO
)(
    input  wire [DATAWIDTH_BUS-1:0] Master_register_DataInBUS,
    input  wire                     Master_register_CLOCK,
    input  wire                     Master_register_Reset_InHigh,
    input  wire                     Master_register_Load_InLow,

    output wire [DATAWIDTH_BUS-1:0] Master_register_DataOutBUS
);

    reg [DATAWIDTH_BUS-1:0] Datos;

    always @(posedge Master_register_CLOCK) begin
        if (Master_register_Reset_InHigh == 1'b1)
            Datos <= {DATAWIDTH_BUS{1'b0}};
        else if (Master_register_Load_InLow == 1'b0)
            Datos <= Master_register_DataInBUS;
    end

    assign Master_register_DataOutBUS = Datos;

endmodule
