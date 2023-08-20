module project_2 #(
    parameter IDLE      = 'b000,
    parameter CHK_CMD   = 'b001,
    parameter WRITE     = 'b010,
    parameter READ_ADD  = 'b011,
    parameter READ_DATA = 'b100,

    parameter MEM_DEPTH = 'd256,
    parameter ADDR_SIZE = 'd8
) (
    input MOSI,
    input SS_n,clk,rst_n,

    output MISO
);
    wire [9:0]rx_data;
    wire rx_valid,tx_valid;
    wire [7:0]tx_data;

    SPI_SLAVE S1(.MOSI(MOSI),.tx_data(tx_data),.tx_valid(tx_valid),
    .SS_n(SS_n),.clk(clk),.rst_n(rst_n),
    .MISO(MISO),.rx_data(rx_data),.rx_valid(rx_valid));

    RAM_P2 R1(.din(rx_data),.clk(clk),.rstn(rst_n),
    .rx_valid(rx_valid),.tx_valid(tx_valid),.dout(tx_data));
    
endmodule