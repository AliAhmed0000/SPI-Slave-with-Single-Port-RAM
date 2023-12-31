module SPI_SLAVE #(
    parameter IDLE      = 3'b000,
    parameter CHK_CMD   = 3'b001,
    parameter WRITE     = 3'b010,
    parameter READ_ADD  = 3'b011,
    parameter READ_DATA = 3'b100
) (
    input MOSI,
    input[7:0] tx_data,
    input tx_valid,  
    input SS_n,clk,rst_n,

    output reg MISO,
    output reg [9:0]rx_data,
    output reg rx_valid

    
);
    
    reg [3:0] counter_10_cycle, MISO_counter;//counter_10_cycle if for the transmitting commands to RAM, MISO_counter is for transmission to MASTER (through MISO) 
    reg [9:0] wr_address,rd_address;//wr_address is to hold "opcode + addr/data" when in Write state, rd_address is to hold "opcode + addr" when in read addr/data state 
    reg read_state = 1'b0; //if 0 -->ns will be read address state, if 1 -->ns will be read data
    reg rx_finished = 1'b0;//if 0 --> read data cmd is not sent yet, if  1 --> read data cmd is fully sent (and the MISO transmision is in progress)
    reg [7:0] tx_data_hold;// to store data from tx_data when tx_valid is set and cs is READ_DATA
    reg data_hold_full;//if 0 --> useless data, if 1 --> useful data, then we can increment MISO
    (* fsm_encoding = "gray" *)
    reg [2:0] cs,ns;
    //state memory
        always @(posedge clk or negedge rst_n) begin
            if(~rst_n)begin
                cs <= IDLE;
                wr_address <= 'b0;
                rd_address <= 'b0;
                counter_10_cycle <= 0;
            end
            else begin
                case(cs)
                IDLE:begin
                    wr_address <= 'b0;
                    rd_address <= 'b0;
                    cs <= ns;
                    tx_data_hold <= 0;
                end
                WRITE:begin //for write addr/data
                    if(counter_10_cycle<10) begin 
                        cs <= WRITE;
                        wr_address <= (wr_address << 1) | MOSI;
                        counter_10_cycle <= counter_10_cycle +1;
                    end
                    else if(SS_n==1 && counter_10_cycle == 10)begin //SS_n was added to not reset the counter, therefore remain in the same state
                        cs <= ns;
                        counter_10_cycle <= 0;
                    end
                        
    
                end
                READ_ADD:begin
                    data_hold_full <= 0;
                    if(counter_10_cycle<10) begin
                        cs <= READ_ADD;
                        rd_address <= (rd_address << 1) | MOSI;
                        counter_10_cycle <= counter_10_cycle +1;
                    end
                    else if(SS_n==1 && counter_10_cycle == 10)begin
                        cs <= ns;
                        counter_10_cycle <= 0;
                    end
                end
                READ_DATA:begin
                    if(counter_10_cycle<10) begin
                        cs <= READ_DATA;
                        rd_address <= (rd_address << 1) | MOSI;
                        counter_10_cycle <= counter_10_cycle +1;
                    end
                    
                    else if(SS_n==1 && counter_10_cycle == 10)begin
                        cs <= ns;
                        counter_10_cycle <= 0;
                    end
                    if(tx_valid) begin
                            tx_data_hold <= tx_data;
                            data_hold_full <= 1;
                    end
                end
                default:cs <= ns;
                endcase
            end
        end
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
                else if(read_state)
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

        default : ns = IDLE;
        endcase

        
    end
    

        

        

    //output logic
    always @(posedge clk) begin
        case (cs)
            IDLE:begin
                rx_valid <= 0;
            end
                
            CHK_CMD:begin
                //counter_10_cycle <= 0;
                rx_valid <= 0;
            end
                
            WRITE:begin
                if((~SS_n) && counter_10_cycle == 10)begin
                    if(wr_address[9:8] == 2'b00 || wr_address[9:8] == 2'b01) begin //opcode of write addr/data in RAM
                        //counter_10_cycle <= 0;
                        rx_data <= wr_address;
                        rx_valid <= 1;
                    end
                    else begin //if it's not the right opcode, rx_data is not valid
                        //counter_10_cycle <= 0;/////////////////
                        rx_data <= wr_address;
                        rx_valid <= 0;
                    end
                    
                end
            end

            READ_ADD:begin
                //read_state = 0;
                if((~SS_n) && counter_10_cycle == 10)begin
                    if (rd_address[9:8] == 2'b10) begin //opcode of read addr in RAM 
                        //counter_10_cycle <= 0;
                        rx_data <= rd_address;
                        rx_valid <= 1;
                        read_state <= 1;
                    end
                    else begin
                        //counter_10_cycle <= 0;//safar l counter w ebda2 ml awel//caused multiple driver error (cuz it can't be drived from 2 different blocks)
                        rx_data <= rd_address;
                        rx_valid <= 0;//rx_data is not valid
                        read_state <= 0;//ns won't change to READ_DATA as long as the opcode is not correct
                    end
                    
                end
                /*else
                    read_state <= 0;*/
            end

            READ_DATA:begin
            
                if(~rx_finished) begin
                    if((~SS_n) && counter_10_cycle == 10)begin
                        if(rd_address[9:8] ==2'b11)begin
                            //counter_10_cycle <= 0;
                            rx_data <= rd_address;
                            rx_valid <= 1;

                            rx_finished <= 1;
                            //read_state = 0;
                            MISO_counter <= 0; 
                        end
                        else begin
                            //counter_10_cycle <= 0;
                            rx_data <= rd_address;
                            rx_valid <= 0;

                            rx_finished <= 0;
                            //read_state = 0;
                            //MISO_counter <= 0;
                        end
                        
                    end
                end
                
                
                else if(rx_finished) begin
                    if(MISO_counter<8) begin
                        if(data_hold_full) begin
                            MISO <= tx_data_hold[MISO_counter];
                            //tx_data_hold <= tx_data_hold << 1;
                            MISO_counter <= MISO_counter + 1;
                        end
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