module divider_24_tb(
);

logic clk;
logic reset; 

logic [639:0][23:0] Numerator;
logic [639:0][23:0] Denominator;

logic [639:0][23:0] Remainder;
logic [639:0][23:0] Quotient;


initial begin
    #1
    reset = 0; 
    #1
    Numerator[0] = 24'h000004;
    Denominator[0] = 24'h000002;

    Numerator[1] = 24'h000003;
    Denominator[1] = 24'h000002;

    Numerator[2] = 24'h111111;
    Denominator[2] = 24'h000002;

    Numerator[639] = 24'h000001;
    Denominator[639] = 24'h000001;

    #1

    assert(Remainder[0] == 24'h000000);
    assert(Quotient[0] == 24'h000002);
    $display("i = 0 R=%d, Q=%d \n", Remainder[0],Quotient[0]);

    $display("i = 1 R=%d, Q=%d \n", Remainder[1],Quotient[1]);

    $display("i = 2 R=%d, Q=%d \n", Remainder[2],Quotient[2]);

    $display("i = 639 R=%d, Q=%d \n", Remainder[639],Quotient[639]);

    

end

divider_24 divider(
    .clk(clk),
    .reset(reset), 
    .Numerator(Numerator),
    .Denominator(Denominator),
    .Remainder(Remainder),
    .Quotient(Quotient)
);

endmodule