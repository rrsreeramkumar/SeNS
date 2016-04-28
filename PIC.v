`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Daniel Ferguson, 2011
// 
// Create Date:    14:54:37 12/02/2011 
// Module Name:    PIC 
//
//  *Positive Edge Triggered 
//  *2 interrupt inputs.
//  *parameterized interrupt type assignments
//  *synchronous clear and reset
//////////////////////////////////////////////////////////////////////////////////
module PIC(input            clock,
           input            reset,
           input            clr,
           input            int1,
           input            int2,
           output reg[7:0]  interrupt_type,
           output reg       interrupt           
           );
           
    parameter Interrupt_Type_1      = 8'h00,
              Interrupt_Type_2      = 8'h01;
              
    parameter Interrupt_Asserted    = 1'b1;
              
    //always @ (posedge reset or posedge clr or posedge int1 or posedge int2) begin
    always @ (posedge clock) begin
        if (reset == 1'b1 || clr == 1'b1) begin
            interrupt_type  <=  Interrupt_Type_1;
            interrupt       <=  1'b0;
        end else begin
            if          (int1) begin
                interrupt_type  <=  Interrupt_Type_1;
                interrupt       <=  Interrupt_Asserted;
            end else if (int2) begin
                interrupt_type  <=  Interrupt_Type_2;
                interrupt       <=  Interrupt_Asserted;
            end else begin
                interrupt_type  <=  interrupt_type;
                interrupt       <=  interrupt;
            end
        end
    end

endmodule
