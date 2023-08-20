module SPI_SLAVE #(
    parameter IDLE      = 'b000,
    parameter CHK_CMD   = 'b001,
    parameter WRITE     = 'b010,
    parameter READ_ADD  = 'b011,
    parameter READ_DATA = 'b100
) (
    input MOSI,
    input[7:0] tx_data,
    input tx_valid,  
    input SS_n,clk,rst_n,

    output reg MISO,
    output reg [9:0]rx_data,
    output reg rx_valid

    
);
    reg [2:0] cs,ns;
    reg [3:0] counter_10_cycle, MISO_counter;
    reg [7:0] wr_address,rd_address;
    reg read_state; //if 0 --> read address, if 1 --> read data
    reg rx_finished;//if 0, if  1
    reg [7:0] tx_data_hold;
    //next case logic
    always @(cs,SS_n,MOSI,read_state,counter_10_cycle) begin
        case(cs)
        IDLE:
        if(~SS_n)
            ns = CHK_CMD;
        else
            ns =IDLE;
        CHK_CMD: begin
            if(SS_n == 0 && MOSI == 0) //write addr/data
                ns = WRITE;
            else if(SS_n ==0 && MOSI == 1)begin //read
                if(~read_state)
                    ns = READ_ADD;
                else
                    ns = READ_DATA;
            end
            else if (SS_n) begin
                ns = IDLE;
            end 
        end
            //ns = CHK_CMD;
        WRITE:
        if(SS_n == 0 && counter_10_cycle <10)
            ns = WRITE;
        else if(SS_n == 1)
            ns = IDLE;

        READ_ADD:
        if(SS_n == 0 && counter_10_cycle <10)
            ns = READ_ADD;
        else if(SS_n == 1)
            ns = IDLE;

        READ_DATA:
        if(SS_n == 0 && counter_10_cycle <10)
            ns = READ_DATA;
        else if(SS_n == 1)
            ns = IDLE;
        endcase

        
    end
    //state memory
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n)begin
            cs <= IDLE;
            wr_address <= 'b0;
            rd_address <= 'b0;
        end
        else begin
            case(cs)
            WRITE:begin //for write addr/data
                if(counter_10_cycle<10) begin 
                    cs <= WRITE;
                    wr_address <= (wr_address << 1) | MOSI;
                    counter_10_cycle <= counter_10_cycle +1;
                end
                else
                    cs <= ns;
            end
            READ_ADD:begin
                if(counter_10_cycle<10) begin
                    cs <= READ_ADD;
                    rd_address <= (rd_address << 1) | MOSI;
                    counter_10_cycle <= counter_10_cycle +1;
                end
                else
                    cs <= ns;
            end
            READ_DATA:begin
                if(counter_10_cycle<10) begin
                    cs <= READ_DATA;
                    rd_address <= (rd_address << 1) | MOSI;
                    counter_10_cycle <= counter_10_cycle +1;
                end
                
                else
                    cs <= ns;
                if(tx_valid) begin
                        tx_data_hold <= tx_data;
                end
            end
            default:cs <= ns;
            endcase
        end

        

        
    end
    //output logic
    always @(posedge clk) begin
        case (cs)
            IDLE:begin
                rx_valid <= 0;
            end
                
            CHK_CMD:begin
                counter_10_cycle <= 0;
                rx_valid <= 0;
            end
                
            WRITE:begin
                if((~SS_n) && counter_10_cycle == 10)begin
                    counter_10_cycle <= 0;
                    rx_data <= wr_address;
                    rx_valid <= 1;
                end
            end

            READ_ADD:begin
                //read_state = 0;
                if((~SS_n) && counter_10_cycle == 10)begin
                    counter_10_cycle <= 0;
                    rx_data <= rd_address;
                    rx_valid <= 1;
                    read_state <= 1;
                end
                else
                    read_state <= 0;
            end

            READ_DATA:begin
            
                
                if((~SS_n) && counter_10_cycle == 10)begin
                    counter_10_cycle <= 0;
                    rx_data <= rd_address;
                    rx_valid <= 1;

                    rx_finished <= 1;
                    //read_state = 0;
                    MISO_counter <= 0;
                end
                
                
                if(rx_finished) begin
                    if(MISO_counter<8) begin
                        MISO <= tx_data_hold[7];
                        tx_data_hold <= tx_data_hold << 1;
                        MISO_counter <= MISO_counter + 1;
                    end
                    else if (MISO_counter == 8) begin
                        MISO_counter <= 0;
                        rx_finished <= 0;
                        read_state <= 0;
                    end
                    
                end
                /*if (tx_valid) begin
                    tx
                end*/
                
            end

            default: rx_valid <= 0;
        endcase
    end

/*
objectives:
1) write address --done--
2) write data --done-- i think there's no difference between it and no. "1)", just recheck
3) read address
4) read data
*/
    
endmodule