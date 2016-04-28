`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Daniel Ferguson, Sree Ram Kumar
// 
// Create Date:    15:14:20 12/03/2011 
// Design Name: 
// Module Name:    top 
// 
//
//
//////////////////////////////////////////////////////////////////////////////////
module top  (   input 			    clk50,            		// 50MHz clock from on-board oscillator
                input			    rotary_press,			// pushbutton inputs - rotary encoder button
                
                output [7:0]        led,  					// LED outputs
                
                input               rs232_rxd_a,
                output              rs232_txd_a,
                input               rs232_rxd_b,
                output              rs232_txd_b
    );
    
    wire        reset;

    wire        bus_request_a;
    reg         bus_grant_a;
    wire        txd_start_a;
    wire[7:0]   mote_out_a;  
    wire[7:0]   led_a;
    
    wire        bus_request_b;
    reg         bus_grant_b;
    wire        txd_start_b;
    wire[7:0]   mote_out_b; 
    wire[7:0]   led_b;
    
    wire        to_transmit;
    wire[7:0]   data_out;    
    wire        txd_busy;
    
    wire[7:0]   mote_out;
    wire        txd_start;
    
    
    assign reset     = rotary_press;
    reg[15:0]   timestamp;
    reg[6:0]   timestamp_increment;
    
    //Free Running Counter - to be used(in the future) for timestamp
    //It is updated every microsecond.
    always@(posedge clk50) begin
        timestamp_increment = timestamp_increment + 6'b1;
        if (timestamp_increment == 6'd50) begin
            timestamp = timestamp + 16'b1;
            timestamp_increment = 6'b0;
        end else
            timestamp = timestamp;
    end
    
    //Mote A
    // Motes don't transmit anything via UART, only receive.
    Mote mote_a(.clk50          (clk50),
                .reset          (reset),
                .led            (led_a),
                .rs232_rxd      (rs232_rxd_a),
                //.rs232_txd      (rs232_txd_a),
                .txd_start      (txd_start_a),
                .bus_request    (bus_request_a),
                .bus_grant      (bus_grant_a),
                .mote_out       (mote_out_a),
                .txd_busy       (txd_busy),
                .timestamp      (timestamp)
              );
    
    //Mote B
    // This mote implements a data generator in place of
    // a UART.
    Mote_debug mote_b(.clk50    (clk50),
                .reset          (reset),
                .led            (led_b),
                .rs232_rxd      (rs232_rxd_b),
                .rs232_txd      (rs232_txd_b),
                .txd_start      (txd_start_b),
                .bus_request    (bus_request_b),
                .bus_grant      (bus_grant_b),
                .mote_out       (mote_out_b),
                .txd_busy       (txd_busy),
                .timestamp      (timestamp)
              );
    

    //Multiplex the mote outputs
    assign mote_out  = (bus_grant_a ? mote_out_a  : (bus_grant_b ? mote_out_b : 8'b0));
    assign txd_start = (bus_grant_a ? txd_start_a : (bus_grant_b ? txd_start_b : 1'b0));
    assign led       = (bus_grant_a ? led_a       : (bus_grant_b ? led_b : 8'b0));
    
    //Synchronize bus requests and grants.
    // Priority given to Mote A
    always@(posedge clk50) begin
        if      (bus_request_a == 1'b1 && bus_grant_b == 1'b0)
            bus_grant_a = 1'b1;
        
        if (bus_request_b == 1'b1 && bus_grant_a == 1'b0)
            bus_grant_b = 1'b1;
        
        if (bus_request_a == 1'b0) 
            bus_grant_a = 1'b0;
        
        
        if (bus_request_b == 1'b0) 
            bus_grant_b = 1'b0;

    end
    
    //The UART transmitter to the PC
    async_transmitter #(.ClkFrequency(50000000),.Baud(115200)) 	
	TX_TO_PC(.clk(clk50), 
             .TxD(rs232_txd_a), 
             .TxD_start(txd_start), 
             .TxD_data(mote_out),
             .TxD_busy(txd_busy));
         
endmodule
