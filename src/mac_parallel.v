module mac_parallel (
    input  wire [74:0]        px,
    input  wire [74:0]        w,
    output wire signed [15:0] result
);
    assign result = 
        $signed(px[0  +: 3]) * $signed(w[0  +: 3]) +
        $signed(px[3  +: 3]) * $signed(w[3  +: 3]) +
        $signed(px[6  +: 3]) * $signed(w[6  +: 3]) +
        $signed(px[9  +: 3]) * $signed(w[9  +: 3]) +
        $signed(px[12 +: 3]) * $signed(w[12 +: 3]) +
        $signed(px[15 +: 3]) * $signed(w[15 +: 3]) +
        $signed(px[18 +: 3]) * $signed(w[18 +: 3]) +
        $signed(px[21 +: 3]) * $signed(w[21 +: 3]) +
        $signed(px[24 +: 3]) * $signed(w[24 +: 3]) +
        $signed(px[27 +: 3]) * $signed(w[27 +: 3]) +
        $signed(px[30 +: 3]) * $signed(w[30 +: 3]) +
        $signed(px[33 +: 3]) * $signed(w[33 +: 3]) +
        $signed(px[36 +: 3]) * $signed(w[36 +: 3]) +
        $signed(px[39 +: 3]) * $signed(w[39 +: 3]) +
        $signed(px[42 +: 3]) * $signed(w[42 +: 3]) +
        $signed(px[45 +: 3]) * $signed(w[45 +: 3]) +
        $signed(px[48 +: 3]) * $signed(w[48 +: 3]) +
        $signed(px[51 +: 3]) * $signed(w[51 +: 3]) +
        $signed(px[54 +: 3]) * $signed(w[54 +: 3]) +
        $signed(px[57 +: 3]) * $signed(w[57 +: 3]) +
        $signed(px[60 +: 3]) * $signed(w[60 +: 3]) +
        $signed(px[63 +: 3]) * $signed(w[63 +: 3]) +
        $signed(px[66 +: 3]) * $signed(w[66 +: 3]) +
        $signed(px[69 +: 3]) * $signed(w[69 +: 3]) +
        $signed(px[72 +: 3]) * $signed(w[72 +: 3]);
endmodule