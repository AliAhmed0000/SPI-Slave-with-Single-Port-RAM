module RAM_P2 #(
    parameter MEM_DEPTH = 'd256,
    parameter ADDR_SIZE = 'd8
) (
    input [9:0] din,
    input clk,rstn,rx_valid,

    output reg tx_valid,
    output reg[7:0] dout
);

reg [7:0] mem [MEM_DEPTH - 1: 0];
reg [ADDR_SIZE - 1: 0]wr_address,rd_address;
integer i;
always @(posedge clk or negedge rstn) begin
    if(~rstn) begin
        wr_address <= 'b0;
        rd_address <= 'b0;
        for ( i=0 ;i<MEM_DEPTH ;i=i+1 ) begin
            mem[i] <= 8'b0;
        end
    end

    else if (rx_valid) begin
        if(din[9:8] == 2'b00)begin
            wr_address <= din[7:0];
            tx_valid <= 'b0;
        end
        else if (din[9:8] == 2'b01) begin
            mem[wr_address] <= din[7:0];
            tx_valid <= 'b0;
        end
        else if (din[9:8] == 2'b10) begin
            rd_address <= din[7:0];
            tx_valid <= 'b0;
        end
        else if (din[9:8] == 2'b11) begin
            dout <= mem[rd_address];
            tx_valid <= 'b1;
        end
    end
        
end

    
endmodule