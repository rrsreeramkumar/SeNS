`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Daniel Ferguson, Sree Ram Kumar
// 
// Create Date:    10:32:13 11/29/2011 
// Design Name: 
// Module Name:    top 
//
//  Mote_debug:
//      this debug module is for testing and development only.
//
//////////////////////////////////////////////////////////////////////////////////
module Mote_debug (
                input 			    clk50,            		// 50MHz clock from on-board oscillator
                input			    reset,			        // reset
                
                output reg[7:0]     led,  					// LED outputs
                
                input               rs232_rxd,
                output              rs232_txd,
                input               bus_grant,
                output reg          bus_request,
                output reg          txd_start,
                output reg[7:0]     mote_out,
                input               txd_busy,
                input [15:0]        timestamp
               );
    //------         
    parameter   DEBUG               = 0;
    //mote_brain will read from these port addresses
    parameter   PA_INTERRUPT_TYPE   = 8'h00,
                PA_UART_DATA_RX     = 8'h01,
                PA_TIMESTAMP        = 8'h02;
                
    //mote_brain will write to these port addresses
    parameter   PA_BUFFER_INSERT    = 8'h03,
                PA_DONE_BUFFERING   = 8'h04;                
    //------
    wire clock;
    //------
    
    parameter MAX_BUFFER_SIZE = 8'h0F;
    reg[7:0] buffer[MAX_BUFFER_SIZE-1:0];
    reg[3:0]  buffer_pointer;
    //------
    wire[9:0]       address;
    wire[17:0]      instruction;    
    wire[7:0]       port_id;
    wire            read_strobe;
    wire            write_strobe;
    wire            interrupt, interrupt_ack;
    wire            upd_sysregs;
    wire[7:0]       port_out;
    reg [7:0]       port_in;
    
    reg [7:0]       buffer_size;
    reg             ready_to_tx;
    //------
    assign clock = clk50;    
    //assign led     = {bus_request, bus_grant,interrupt,uart_data_available, 4'b0};//{1'b0, GPout[6-:7]};      
    //------    
    
    
    kcpsm3 mote_brain(       
        .address        (address),               //output
        .instruction    (instruction),           //input
        .port_id        (port_id),               //output
        .write_strobe   (write_strobe),          //output
        .out_port       (port_out),              //output
        .read_strobe    (read_strobe),           //output
        .in_port        (port_in),               //input
        .interrupt      (interrupt),             //input
        .interrupt_ack  (interrupt_ack),         //output
        .reset          (reset),                 //input
        .clk            (clock));                //input
    
    motepgmb mote_pgm1(  
        .address        (address),               //output
        .instruction    (instruction),           //output
        .clk            (clock));              //input
   
    //FAKE UART Output
    parameter COUNTER_SIZE = 22;
    reg uart_data_available;
    reg [7:0] uart_rx_data;    
    reg[COUNTER_SIZE-1:0] fake_counter;
    reg[2:0] fuhg;
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            fake_counter = 0;
            uart_data_available = 1'b0;
            fuhg = 0;
        end else begin
            fake_counter = fake_counter + 1;
            
            if (fake_counter == 0) begin
                uart_rx_data = 8'd97 + fuhg;
                fuhg = fuhg + 1;
                uart_data_available = 1'b1;
            end else 
                uart_data_available = 1'b0;
            
        end
    end
    //------Programmable Interrupt Controller(but not programmable)
    PIC pic(.clock          (clock),
            .reset          (reset),
            .clr            (interrupt_ack),
            .int1           (uart_data_available),
            .int2           (bus_buffer_empty),    //TODO: shared_bus_grant not connected yet
            .interrupt_type (interrupt_type),
            .interrupt      (interrupt));

    //------
 
    
    //The picoblaze is reading from our registers
    always @* begin
        case (port_id[7:0])
            PA_INTERRUPT_TYPE: begin
                if          (uart_data_available) begin
                    port_in <= 8'h00;
                end else
                    port_in <= port_in;
            end
            PA_UART_DATA_RX: begin
                port_in <= uart_rx_data;                
            end
            PA_TIMESTAMP: begin
                port_in <= timestamp;
            end            
            default: begin
                port_in <= port_in;
                
            end
        endcase
    end
    


    //The picoBlaze is writing 
    //  When the mote_brain accumulates an entire sample
    //  It will, in quick succession, fill the buffer
    //  one byte at a time(PA_BUFFER_INSERT).
    //  When the mote_brain finishes
    //  filling the buffer, it will output the sample size
    //  on PA_DONE_BUFFERING.
    //  The PA_DONE_BUFFERING command initiates a bus request.
    // When the bus is eventually granted, the hardware will stream the 
    // entire contents of the buffer out over the uart transmitter(located in top.v)
    // when the hardware finishes transmitting the buffer, it will automatically
    // deassert the bus request, which will cause the bus grant to deassert. thus ending the cycle. 
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            buffer_pointer = 4'b0;
            ready_to_tx = 1'b0;
        end else begin       
            if(write_strobe) begin      
                case (port_id[7:0])                    
                    PA_BUFFER_INSERT: begin
                        buffer[buffer_pointer] = port_out;                    
                        buffer_pointer = buffer_pointer + 4'b1;
                    end
                    PA_DONE_BUFFERING: begin                        
                        buffer_size = port_out;
                        buffer_pointer = 4'b0;
                        bus_request = 1'b1;
                        led = 8'b11111111;
                    end
                    default: begin
                        buffer[buffer_pointer] = buffer[buffer_pointer];                   
                    end                        
                endcase
            end else begin     
                if (bus_request == 1'b1) begin
                    if (bus_grant == 1'b1) begin
                        if (txd_busy == 1'b0) begin
                            if (buffer_pointer == buffer_size) begin
                                txd_start = 1'b0;
                                buffer_pointer = 4'b0;
                                bus_request = 1'b0;
                                led = 8'b00000000;
                            end else begin 
                                mote_out = buffer[buffer_pointer];
                                txd_start = 1'b1;
                                buffer_pointer = buffer_pointer + 4'b1;
                            end
                        end else begin
                            mote_out = mote_out;
                            txd_start = txd_start;
                        end               
                    end
                end
            end
        end
    end
endmodule
