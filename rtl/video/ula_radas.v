`timescale 1ns / 1ps
`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:54:55 02/16/2014 
// Design Name: 
// Module Name:    ula 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module ula_radas (
    // Clocks
    input wire clk28,
    input wire clkregs,  // clock to load registers
    input wire clk14,    // 14MHz master clock
    input wire clk7,
    input wire cpuclk,
    output wire CPUContention,
    input wire rst_n,  // reset para volver al modo normal

    // CPU interface
    input wire [15:0] a,
    input wire mreq_n,
    input wire iorq_n,
    input wire rd_n,
    input wire wr_n,
    output wire int_n,
    input wire [7:0] din,
    output reg [7:0] dout,
    input wire rasterint_enable,
    input wire vretraceint_disable,
    input wire [8:0] raster_line,
    output wire raster_int_in_progress,
    
    // VRAM interface
    output reg [13:0] va,  // 16KB videoram
    input wire [7:0] vramdata,

    // ZX-UNO register interface
    input wire [7:0] zxuno_addr,
    input wire zxuno_regrd,
    input wire zxuno_regwr,
    input wire regaddr_changed,

    // I/O ports
    input wire ear,
    input wire [4:0] kbd,
    output reg mic,
    output reg spk,
    input wire issue2_keyboard,
    input wire [1:0] mode,
    input wire ioreqbank,
    input wire disable_contention,
    input wire access_to_contmem,
    output wire doc_ext_option,
    input wire enable_timexmmu,
    input wire disable_timexscr,
    input wire disable_ulaplus,    
    input wire disable_radas,
    input wire csync_option,

    // Video
    output wire [2:0] r,
    output wire [2:0] g,
    output wire [2:0] b,
    output wire hsync,
    output wire vsync,
    output wire csync,
    output wire y_n,
	 
	 output wire [8:0] hcnt_o,
	 output wire [8:0] vcnt_o,
	 output wire invert_o,
	 input wire trdos_active,
	 output wire [7:0] debug
    );

    parameter
      BHPIXEL =  0,
      EHPIXEL =  255,
      BVPIXEL =  0,
      EVPIXEL =  191,
      BVSYNC  =  248;    

    parameter
      ULA48K   = 2'b00,
      ULA128K  = 2'b01,
      PENTAGON = 2'b10,
      RESERVED = 2'b11;

	 // RGB inputs to sync module
	 reg [2:0] ri;
	 reg [2:0] gi;
	 reg [2:0] bi;

    // Counters from sync module
	 wire [8:0] hc;
	 wire [8:0] vc;
    
    // Initial values for Radastanian mode pixel and border palette bank
    reg  radasborderpalettehalf = 1'b0;
    reg [1:0] radaspixelpalettequarter = 2'b00;

    // Initial values for synch, syncv for all supported timings
    reg [8:0] hinit48k = 9'd112;
    reg [8:0] vinit48k = 9'd0;
    reg [8:0] hinit128k = 9'd116;
    reg [8:0] vinit128k = 9'd0;
    reg [8:0] hinitpen = 9'd110;
    reg [8:0] vinitpen = 9'd0;    

    // Initial values for offset and padding in Radastanian mode, used for HW scroller
    reg [13:0] radasoffset = 14'h0000;
    reg [7:0] radaspadding = 8'h00;
    reg ffbitmapofs = 1'b0;
    reg [7:0] lastdatatoradasoffset = 8'h00;
   
   // Signal when the vertical counter is in the line that we use to make the INT signal
   wire in_int_line;

    reg clkhalf14 = 1'b0;
    always @(posedge clk14)
        clkhalf14 <= ~clkhalf14;

	 pal_sync_generator syncs (
    .clk(clk7),
    .mode(mode),
    .rasterint_enable(rasterint_enable),
    .vretraceint_disable(vretraceint_disable),
    .raster_line(raster_line),
    .raster_int_in_progress(raster_int_in_progress),
    .csync_option(csync_option),
    
    .hinit48k(hinit48k),
    .vinit48k(vinit48k),
    .hinit128k(hinit128k),
    .vinit128k(vinit128k),
    .hinitpen(hinitpen),
    .vinitpen(vinitpen),
    
    .ri(ri),
    .gi(gi),
    .bi(bi),
    .hcnt(hc),
    .vcnt(vc),
    .ro(r),
    .go(g),
    .bo(b),
    .hsync(hsync),
    .vsync(vsync),
    .csync(csync),
    .int_n(int_n)
    );

///////////////////////////////////////////////
// ULA datapath
///////////////////////////////////////////////

    // Control signals generated from the control unit
    // or the rest of modules
    reg BitmapDataLoad;
    reg AttrDataLoad;
    reg WriteToPortFE;
    reg SerializerLoad;
    reg TimexConfigLoad;
    reg AttrOutputLoad;
    reg PaletteRegLoad;
    reg ConfigRegLoad;
    reg PaletteLoad;
    reg BitmapAddr;
    reg AttrAddr;
    reg CALoad;
    reg VideoEnable;

    wire RadasEnabled;  // =1 is el modo radastaniano est� habilitado
    
    // BitmapData register
    reg [7:0] BitmapData = 8'h00;
    always @(posedge clk7) begin
      if (BitmapDataLoad)
         BitmapData <= vramdata;
    end
    
    // AttrData register
    reg [7:0] AttrData = 8'h00;
    always @(posedge clk7) begin
      if (AttrDataLoad)
         AttrData <= vramdata;
    end
    
    // Border register
    reg [2:0] Border = 3'b010;  // initial border colour is red
    always @(posedge clkregs) begin
      if (WriteToPortFE)
         Border <= din[2:0];
    end
    
    // BitmapSerializer register
    reg [7:0] BitmapSerializer = 8'h00;
    wire SerialOutput = BitmapSerializer[7];
    always @(posedge clk7) begin
      if (SerializerLoad)
         BitmapSerializer <= BitmapData;
      else
         BitmapSerializer <= {BitmapSerializer[6:0],1'b0};
    end
    
    // BitmapSerializerHR register
    reg [15:0] BitmapSerializerHR = 8'h00;
    wire SerialOutputHR = BitmapSerializerHR[15];
    always @(posedge clk14) begin
      if (SerializerLoad && clkhalf14)  // load enable only for a single 14MHz cycle
         BitmapSerializerHR <= {BitmapData,AttrData};
      else
         BitmapSerializerHR <= {BitmapSerializerHR[14:0],1'b0};
    end
    
    // Timex config register
    reg [7:0] TimexConfigReg = 8'h00;
    wire PG  = TimexConfigReg[0];
    wire HCL = TimexConfigReg[1];
    wire HR  = TimexConfigReg[2];
    assign doc_ext_option = enable_timexmmu & TimexConfigReg[7];
    wire [2:0] HRInk = TimexConfigReg[5:3];
    always @(posedge clkregs) begin
      if (rst_n == 1'b0)
         TimexConfigReg <= 8'h00;
      else if (TimexConfigLoad && trdos_active == 1'b0)
         TimexConfigReg <= din;
    end
    
    // Combinational logic between AttrData and AttrOutput
    reg [7:0] InputToAttrOutput;
    always @* begin
      InputToAttrOutput = AttrData;
      case ({VideoEnable,HR})
         2'b00 : InputToAttrOutput = (RadasEnabled)? {radasborderpalettehalf,Border,radasborderpalettehalf,Border} : {2'b00,Border,3'b000};
         2'b01,
         2'b11 : InputToAttrOutput = {2'b01,~HRInk,HRInk};
         2'b10 : InputToAttrOutput = AttrData;
      endcase
    end
    
    // AttrOutput register
    reg [7:0] AttrOutput = 8'h00;
    reg [7:0] BorderColorDelayed;  // used to delay 0.5T the assignment from border to AttrOutput while in Pentagon mode
    wire [2:0] StdPaperColour = AttrOutput[5:3];
    wire [2:0] StdInkColour = AttrOutput[2:0];
    wire Bright = AttrOutput[6];
    wire Flash = AttrOutput[7];
    always @(posedge clk7) begin
      BorderColorDelayed <= {2'b00,Border,3'b000};  // update always BorderColorDelayed
      if (mode == PENTAGON && (hc<(BHPIXEL+8) || hc>(EHPIXEL+12) || vc<BVPIXEL || vc>EVPIXEL))
         AttrOutput <= BorderColorDelayed;  // and in next pixel clock, update AttrOutput if in border and Pentagon mode is on
      else if (AttrOutputLoad)
         AttrOutput <= InputToAttrOutput;
    end
    
    // Combinational logic to generate pixel bit
    reg Pixel;
    always @* begin
      if (HR)
         Pixel = SerialOutputHR;
      else
         Pixel = SerialOutput;
    end
    
    // Flash!
    reg [4:0] FlashCounter = 5'h00;
    wire FlashFF = FlashCounter[4];
    wire PixelWFlash = Pixel ^ (Flash & FlashFF);
    always @(posedge clk7) begin
		if (vc==BVSYNC && hc==0)
			FlashCounter <= FlashCounter + 1;
	end
   
   // Standard ULA final 4-bit IGRB colour
   reg [3:0] StdPixelColour;
   always @* begin
      if (PixelWFlash)
         StdPixelColour = {Bright,StdInkColour};
      else
         StdPixelColour = {Bright,StdPaperColour};
   end
   
   // LUT-based translatator from IGRB to 9-bit GRB
   `define none 3'b000
   `define half 3'b101
   `define full 3'b111
   reg [8:0] Std9bitColour;
	always @* begin
 	  case (StdPixelColour)  // speccy colour to GGGRRRBBB colour. If you want to alter the standard palette, 
	                         // this is what you need to touch ;)
				0,8: Std9bitColour = {`none,`none,`none};
				1:   Std9bitColour = {`none,`none,`half};
				2:   Std9bitColour = {`none,`half,`none};
				3:   Std9bitColour = {`none,`half,`half};
				4:   Std9bitColour = {`half,`none,`none};
				5:   Std9bitColour = {`half,`none,`half};
				6:   Std9bitColour = {`half,`half,`none};
				7:   Std9bitColour = {`half,`half,`half};
				9:   Std9bitColour = {`none,`none,`full};
				10:  Std9bitColour = {`none,`full,`none};
				11:  Std9bitColour = {`none,`full,`full};
				12:  Std9bitColour = {`full,`none,`none};
				13:  Std9bitColour = {`full,`none,`full};
				14:  Std9bitColour = {`full,`full,`none};
				15:  Std9bitColour = {`full,`full,`full};
				default: Std9bitColour = {`none,`none,`none};
	  endcase
	end
   
   // PaletteReg register (ULAplus)
   reg [6:0] PaletteReg = 7'h00;
   always @(posedge clkregs) begin
      if (PaletteRegLoad)
        PaletteReg <= din[6:0];
   end
   
   // ConfigReg register (ULAplus)
   reg ConfigReg = 1'b0;
   always @(posedge clkregs) begin
      if (rst_n == 1'b0)
         ConfigReg <= 1'b0;
      else if (ConfigRegLoad)
         ConfigReg <= din[0];
   end

   // RadasCtrl register
   reg [1:0] RadasCtrl = 2'b00;
   always @(posedge clkregs) begin
      if (rst_n == 1'b0)
         RadasCtrl <= 2'b00;
      else if (zxuno_addr == RADASCTRL && zxuno_regwr == 1'b1 && disable_radas == 1'b0)
         RadasCtrl <= din[1:0];
   end
   assign RadasEnabled = &RadasCtrl[1:0];

   wire ULAplusEnabled = ConfigReg | RadasEnabled;
   
   // Palette LUT
   wire [7:0] PaletteEntryToCPU;
   wire [7:0] ULAplusPaperColour;
   wire [7:0] ULAplusInkColour;
   
   wire [5:0] AddressA1 = (RadasEnabled)? {radaspixelpalettequarter,InputToAttrOutput[7:4]} :
                                          {InputToAttrOutput[7:6],1'b1,InputToAttrOutput[5:3]};
   wire [5:0] AddressA2 = (RadasEnabled)? {radaspixelpalettequarter,InputToAttrOutput[3:0]} :
                                          {InputToAttrOutput[7:6],1'b0,InputToAttrOutput[2:0]};
   lut palette (
      .clk(clk28),
      .load(PaletteLoad),
      .din(din),
      .a1(AddressA1),
      .a2(AddressA2),
      .a3(PaletteReg[5:0]),
      .do1(ULAplusPaperColour),
      .do2(ULAplusInkColour),
      .do3(PaletteEntryToCPU)
      );
      
   // AttrPlusOutput register
   reg [15:0] AttrPlusOutput = 16'h0000;
   always @(posedge clk7) begin
      if (AttrOutputLoad)
         AttrPlusOutput <= {ULAplusPaperColour,ULAplusInkColour};
   end
   
   // ULAplus final 8-bit GGGRRRBB colour
   reg [7:0] ULAplusPixelColour;
   always @* begin
      case ({RadasEnabled,hc[1],Pixel})
         3'b000,
         3'b010 : ULAplusPixelColour = AttrPlusOutput[15:8];
         3'b001,
         3'b011 : ULAplusPixelColour = AttrPlusOutput[7:0];
         3'b100,
         3'b101 : ULAplusPixelColour = AttrPlusOutput[15:8];  // pixel izquierdo del par
         3'b110,
         3'b111 : ULAplusPixelColour = AttrPlusOutput[7:0];   // pixel derecho del par
         default : ULAplusPixelColour = AttrPlusOutput[15:8];
      endcase
   end
   
   // 332-GRB to 333-GRB (blue turns from B1 B0 into B1 B0 B1)
   wire [8:0] ULAplus9bitColour = {ULAplusPixelColour,ULAplusPixelColour[1]};

   // Final stage. Final colour is connected to PAL generator
   always @* begin
      if (ULAplusEnabled) begin
         gi = ULAplus9bitColour[8:6];
         ri = ULAplus9bitColour[5:3];
         bi = ULAplus9bitColour[2:0];
      end
      else begin
         gi = Std9bitColour[8:6];
         ri = Std9bitColour[5:3];
         bi = Std9bitColour[2:0];
      end
   end

   // Column address register (CA)
   reg [4:0] CA = 5'h00;
   always @(posedge clk7) begin
      if (CALoad)
         CA <= hc[7:3];
   end

   // VRAM Address generation   
   wire [8:0] hcd = hc + 9'hFF8;  // hc delayed 8 ticks
   always @* begin
     if (!RadasEnabled) begin
         if (BitmapAddr) begin
            va = {PG,vc[7:6],vc[2:0],vc[5:3],CA};
         end
         else if (AttrAddr) begin
            if (HCL==1'b0)
               va = {PG,3'b110,vc[7:3],CA};
            else
               va = {1'b1,vc[7:6],vc[2:0],vc[5:3],CA};
         end
         else
            va = 14'hZZZZ;
     end
     else begin         
         //va = {PG,vc[7:1],hcd[7:2]};
         va = {PG,vc[7:1],hcd[7:2]} + radasoffset + vc[7:1]*radaspadding;
     end
  end

///////////////////////////////////////////////
// ULA control unit
///////////////////////////////////////////////

   // control data flow from VRAM to RGB output
   reg Border_n;
   always @* begin
     if (vc>=BVPIXEL && vc<=EVPIXEL && hc>=BHPIXEL && hc<=EHPIXEL)
        Border_n = 1;
    else
        Border_n = 0;
	end

   always @* begin
      BitmapDataLoad = 1'b0;
      AttrDataLoad = 1'b0;
      SerializerLoad = 1'b0;
      VideoEnable = 1'b0;
      AttrOutputLoad = 1'b0;
      BitmapAddr = 1'b0;
      AttrAddr = 1'b0;
      CALoad = 1'b0;
      
      if (!RadasEnabled) begin   // Control para los modos est�ndar
      
         if (hc>=(BHPIXEL+8) && hc<=(EHPIXEL+8) && vc>=BVPIXEL && vc<=EVPIXEL) begin  // VidEN_n is low here: paper area
            VideoEnable = 1'b1;
            if (hc[2:0]==3'd4) begin
                SerializerLoad = 1'b1;  // updated every 8 pixel clocks, if we are in paper area
            end
         end
         if (hc[2:0] == 3'd4) begin        // hc=4,12,20,28,etc
            AttrOutputLoad = 1'b1;  // updated every 8 pixel clocks
         end
         if (hc[2:0]==3'd3) begin
            CALoad = 1'b1;
         end
         if (hc>=BHPIXEL && hc<=EHPIXEL && vc>=BVPIXEL && vc<=EVPIXEL) begin
            if (hc[3:0]==4'd8 || hc[3:0]==4'd12) begin
               BitmapAddr = 1'b1;
            end
            if (hc[3:0]==4'd9 || hc[3:0]==4'd13) begin
               BitmapAddr = 1'b1;
               BitmapDataLoad = 1'b1;
            end
            if (hc[3:0]==4'd10 || hc[3:0]==4'd14) begin
               AttrAddr = 1'b1;
            end
            if (hc[3:0]==4'd11 || hc[3:0]==4'd15) begin
               AttrAddr = 1'b1;
               AttrDataLoad = 1'b1;
            end
         end
      end
      
      else begin  // Control para el modo radastaniano
         if (hc[1:0]==2'b11) begin   // trasladamos dos p�xeles a la salida
            AttrOutputLoad = 1'b1;
         end
         if (hc>=(BHPIXEL+8) && hc<=(EHPIXEL+8) && vc>=BVPIXEL && vc<=EVPIXEL) begin  // VidEN_n is low here: paper area
            VideoEnable = 1'b1;
            if (hc[1:0]==2'b01) begin  // s�lo durante video activo: se lee la memoria de pantalla
               AttrDataLoad = 1'b1;
            end
         end
      end
      
   end

///////////////////////////////////////////////
// ULA interface with CPU
///////////////////////////////////////////////

   parameter
      TIMEXPORT    = 8'hFF,
      TIMEXMMU     = 8'hF4,
      ULAPLUSADDR  = 16'hBF3B,
      ULAPLUSDATA  = 16'hFF3B;
      
   parameter
      HOFFS48K     = 8'h80,
      VOFFS48K     = 8'h81,
      HOFFS128K    = 8'h82,
      VOFFS128K    = 8'h83,
      HOFFSPEN     = 8'h84,
      VOFFSPEN     = 8'h85;
      
   parameter
      RADASCTRL    = 8'h40,
      RADASOFFSET  = 8'h41,
      RADASPADDING = 8'h42,
      RADASPALBANK = 8'h43;
         
   // Z80 writes values into registers
   // Port 0xFE
   always @(posedge clkregs) begin
      if (WriteToPortFE) begin
         {spk,mic} <= din[4:3];
      end
   end
  
   // TIMEX and ULAplus ports
   always @* begin
      TimexConfigLoad = 1'b0;
      PaletteRegLoad = 1'b0;
      ConfigRegLoad = 1'b0;
      PaletteLoad = 1'b0;
      WriteToPortFE = 1'b0;
      if (iorq_n==1'b0 && wr_n==1'b0) begin
         if (a[0]==1'b0 && (!enable_timexmmu || a[7:0]!=TIMEXMMU))
            WriteToPortFE = 1'b1;
         else if (a[7:0]==TIMEXPORT && !disable_timexscr)
            TimexConfigLoad = 1'b1;
         else if (a==ULAPLUSADDR && !disable_ulaplus)
            PaletteRegLoad = 1'b1;
         else if (a==ULAPLUSDATA && !disable_ulaplus) begin
            if (PaletteReg[6]==1'b0)  // writting a new value into palette LUT
               PaletteLoad = 1'b1;
            else
               ConfigRegLoad = 1'b1;  // writting a new value into ULAplus config register
         end
      end
   end
   
   // Sync and radastanian palette adjustment
   always @(posedge clkregs) begin
      if (zxuno_regwr == 1'b1) begin
         case (zxuno_addr)
            HOFFS48K:  hinit48k  <= {din,1'b0};
            VOFFS48K:  vinit48k  <= {din,1'b0};
            HOFFS128K: hinit128k <= {din,1'b0};
            VOFFS128K: vinit128k <= {din,1'b0};
            HOFFSPEN:  hinitpen  <= {din,1'b0};
            VOFFSPEN:  vinitpen  <= {din,1'b0};
            RADASPALBANK: {radasborderpalettehalf,radaspixelpalettequarter} <= din[2:0];
         endcase
      end
   end
   
   // Control de offsets del modo radastaniano
   reg offset_reg_accessed = 1'b0;
   always @(posedge clkregs) begin
      if (rst_n == 1'b0) begin
         ffbitmapofs <= 1'b0;
         radasoffset <= 14'h0000;
         radaspadding <= 8'h00;
      end
      else begin
         if (regaddr_changed && zxuno_addr == RADASOFFSET)
            ffbitmapofs <= 1'b0;
         else if (offset_reg_accessed == 1'b0 && zxuno_addr == RADASOFFSET && (zxuno_regrd == 1'b1 || zxuno_regwr == 1'b1)) begin
            if (zxuno_regwr == 1'b1 && ffbitmapofs == 1'b0) begin
               radasoffset[7:0] <= din;
            end
            else if (zxuno_regwr == 1'b1 && ffbitmapofs == 1'b1) begin
               radasoffset[13:8] <= din[5:0];
            end
            else if (zxuno_regrd == 1'b1 && ffbitmapofs == 1'b0) begin
               lastdatatoradasoffset <= radasoffset[7:0];
            end
            else if (zxuno_regrd == 1'b1 && ffbitmapofs == 1'b1) begin
               lastdatatoradasoffset <= {2'b00,radasoffset[13:8]};
            end
            ffbitmapofs <= ~ffbitmapofs;
            offset_reg_accessed <= 1'b1;
         end
         else if (zxuno_regwr == 1'b1 && zxuno_addr == RADASPADDING) begin
            radaspadding <= din;
         end
         if (offset_reg_accessed == 1'b1 && zxuno_regwr == 1'b0 && zxuno_regwr == 1'b0)
            offset_reg_accessed <= 1'b0;
      end
   end

	reg post_processed_ear;  // EAR signal after being altered by the keyboard current issue
	always @* begin
		if (issue2_keyboard)
			post_processed_ear = ear ^ (spk | mic);
		else
			post_processed_ear = ear ^ spk;
    end

   // Z80 gets values from registers (or floating bus)
   always @* begin
      dout = 8'hFF;
      if (iorq_n==1'b0 && rd_n==1'b0) begin
         if (a[0]==1'b0 && (a[7:0]!=TIMEXMMU || !enable_timexmmu))
            dout = {1'b1,post_processed_ear,1'b1,kbd};
         else if (a==ULAPLUSADDR && !disable_ulaplus)
            dout = {1'b0,PaletteReg};
         else if (a==ULAPLUSDATA && PaletteReg[6]==1'b0 && !disable_ulaplus)
            dout = PaletteEntryToCPU;
         else if (a==ULAPLUSDATA && PaletteReg[6]==1'b1 && !disable_ulaplus)
            dout = {7'b0000000,ConfigReg};
         else if (a[7:0]==TIMEXPORT && enable_timexmmu && !disable_timexscr)
            dout = TimexConfigReg;
         else if (zxuno_addr == HOFFS48K && zxuno_regrd == 1'b1)
            dout = hinit48k[8:1];
         else if (zxuno_addr == VOFFS48K && zxuno_regrd == 1'b1)
            dout = vinit48k[8:1];
         else if (zxuno_addr == HOFFS128K && zxuno_regrd == 1'b1)
            dout = hinit128k[8:1];
         else if (zxuno_addr == VOFFS128K && zxuno_regrd == 1'b1)
            dout = vinit128k[8:1];
         else if (zxuno_addr == HOFFSPEN && zxuno_regrd == 1'b1)
            dout = hinitpen[8:1];
         else if (zxuno_addr == VOFFSPEN && zxuno_regrd == 1'b1)
            dout = vinitpen[8:1];
         else if (zxuno_addr == RADASCTRL && zxuno_regrd == 1'b1 && !disable_radas)
            dout = {6'b000000,RadasCtrl};
         else if (zxuno_addr == RADASOFFSET && zxuno_regrd == 1'b1 && !disable_radas)
            dout = lastdatatoradasoffset;
         else if (zxuno_addr == RADASPADDING && zxuno_regrd == 1'b1 && !disable_radas)
            dout = radaspadding;
         else if (zxuno_addr == RADASPALBANK && zxuno_regrd == 1'b1 && !disable_radas)
            dout = {5'b00000, radasborderpalettehalf,radaspixelpalettequarter};
         else begin
            if (BitmapAddr || AttrAddr)
                dout = vramdata;
            else
                dout = 8'hFF;
         end
      end
   end
        
///////////////////////////////////
// AUXILIARY SIGNALS FOR CONTENTION CONTROL
///////////////////////////////////
   wire iorequla = !iorq_n && (a[0]==0);
   wire iorequlaplus = !iorq_n && (a==ULAPLUSADDR || a==ULAPLUSDATA);
   wire ioreqall_n = !(iorequlaplus || iorequla || ioreqbank);

///////////////////////////////////
// CPU CLOCK GENERATION (Altwasser method)
///////////////////////////////////

//`define MASTERCPUCLK clk7
//   reg ioreqtw3 = 0;
//   reg mreqt23 = 0;
//    wire N1y2 = ~access_to_contmem | ioreqall_n;
//    wire N3 = hc[3:0]>=4'd4;
//    wire N4 = ~Border_n | ~ioreqtw3 | ~mreqt23 | ~cpuclk;
//    wire N5 = ~(N1y2 | N3 | N4);
//    wire N6 = ~(hc[3:0]>=4'd4 | ~Border_n | ~cpuclk | ioreqall_n | ~ioreqtw3);
//    
//	always @(posedge cpuclk) begin
//       ioreqtw3 <= ioreqall_n;
//       mreqt23 <= mreq_n;
//	end
//
//	wire Nor1 = (~access_to_contmem & ioreqall_n) | (hc[3:0]<4'd12) | 
//                (~Border_n | ~ioreqtw3 | ~cpuclk | ~mreqt23);
//	wire Nor2 = (hc[3:0]<4'd4) | ~Border_n | ~cpuclk | ioreqall_n | ~ioreqtw3;
//	wire CLKContention = ~Nor1 | ~Nor2;
//
//	always @(posedge cpuclk) begin
//      if (!CLKContention) begin
//         ioreqtw3 <= ioreqall_n;
//         mreqt23 <= mreq_n;
//      end
//	end
//
//   assign CPUContention = ~(!CLKContention || RadasEnabled || disable_contention);

///////////////////////////////////
// CPU CLOCK GENERATION (CSmith method)
///////////////////////////////////

    reg MayContend_n;
    always @(negedge clk7) begin  // esto era negedge clk7 en el esquem�tico
       if (hc[3:0]>4'd3 && Border_n==1'b1)
         MayContend_n <= 1'b0;
       else
         MayContend_n <= 1'b1;
    end
    
    reg CauseContention_n;
    always @* begin
        if ((access_to_contmem || !ioreqall_n) && !RadasEnabled && !disable_contention)
            CauseContention_n = 1'b0;
        else
            CauseContention_n = 1'b1;
    end
    
    reg CancelContention = 1'b1;
    always @(posedge cpuclk) begin
        if (!mreq_n || !ioreqall_n)
            CancelContention <= 1'b1;
        else
            CancelContention <= 1'b0;
    end
    
    //assign cpuclk = (~(MayContend_n | CauseContention_n | CancelContention)) | hc[0];
    
    assign CPUContention = (~(MayContend_n | CauseContention_n | CancelContention));
	 
	 assign hcnt_o = hc;
	 assign vcnt_o = vc;
	 assign invert_o = FlashCounter[3];
	 assign debug = TimexConfigReg;

endmodule
