module divider_24 (
    input logic clk, 
    input logic reset, 
    //input logic enable,

    input logic[639:0][23:0] Numerator,
    input logic[639:0][23:0] Denominator, 


    output logic[639:0][23:0] Quotient, 
    output logic[639:0][23:0] Remainder

);

//
    //add internal wires here
// 
always_comb begin

    /*
    we operate line by line for mapping so 
    we attempt to process 640 pixels at once
    */

    //generate
    for (int i=0; i<640; i++)begin
        if (reset) begin
            Quotient[i] = 24'h000000;
            Remainder[i] = 24'h000000;  
        end else begin
            if (Denominator[i] == 24'h000000) begin
                Quotient[i] = 24'hXXXXXX;
                Remainder[i] = 24'hXXXXXX;
            end else begin
                Quotient[i] = Numerator[i] / Denominator[i];
                Remainder[i] = Numerator[i] % Denominator[i];
            end
        end
    end
end
    
endmodule


