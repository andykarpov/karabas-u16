//==============================================================
// Test reset circuit
//==============================================================
`timescale 100 ns/ 100 ns

module test_reset;

// ----------------- CLOCKS AND RESET -----------------
`define T #2
bit clk = 1;
initial repeat (40) #1 clk = ~clk;

// Specific to FPGA, some modules in the schematic need to be pre-initialized
reg fpga_reset = 1;
always_latch
    if (clk) fpga_reset <= 0;

//----------------------------------------------------------
// Input reset from the pin; state from the sequencer
//----------------------------------------------------------
logic reset_in = 0;
logic M1 = 0;
logic T2 = 0;

wire clrpc;            // Load 0 to PC
wire nhold_clk_wait;   // Hold clrpc
wire nreset;           // Internal inverted reset signal

assign nhold_clk_wait = 1; // Will not test this case

// ----------------- TEST -------------------
initial begin
    // Test normal reset sequence - 3 clocks long
    `T reset_in = 1;
    `T `T `T reset_in = 0;
    `T assert(nreset==0);
    // Out of the reset for several more cycles
    // Check that the clrpc is set for the next 2 1/2 cycles (see waveform)
    `T assert(nreset==1 && clrpc==1);
    `T assert(nreset==1 && clrpc==1);
    `T assert(nreset==1 && clrpc==0);
    `T assert(nreset==1 && clrpc==0);
    `T assert(nreset==1 && clrpc==0);

    // Test special reset sequence: a reset pin is briefly
    // asserted at M1/T1 and CLRPC should hold until the next
    // M1/T2
    `T reset_in = 1; M1=1;
    `T reset_in = 0; M1=1; T2=1;
    `T               M1=1; T2=0;
    `T `T
    `T assert(nreset==1 && clrpc==1);
    `T               M1=1; T2=1;
    `T               M1=1; T2=0;
    `T assert(nreset==1 && clrpc==0);

    `T $display("End of test");
end

//--------------------------------------------------------------
// Instantiate DUT
//--------------------------------------------------------------

resets reset_block ( .* );

endmodule

