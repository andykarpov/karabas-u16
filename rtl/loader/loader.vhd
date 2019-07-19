-------------------------------------------------------------------[18.07.2019]
-- u16-Loader
-- DEVBOARD ReVerSE-U16

library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all; 

entity loader is
port (
	-- clocks
	CLK   : in std_logic;	
	CLK14 : in std_logic;
	CLK7  : in std_logic;
	ENA7 	: in std_logic;
	ENA14 : in std_logic;
	ENA3_5 : in std_logic;
	
	-- global reset
	RESET : in std_logic;
	
	-- RAM interface
	RAM_A 	: out std_logic_vector(24 downto 0);
	RAM_DI 	: out std_logic_vector(7 downto 0);
	RAM_DO 	: in std_logic_vector(7 downto 0);
	RAM_WR	: out std_logic;
	RAM_RD	: out std_logic;
	RAM_RFSH	: out std_logic;

	-- SPI FLASH (M25P16)
	DATA0		: in std_logic;
	NCSO		: out std_logic;
	DCLK		: out std_logic;
	ASDO		: out std_logic;

	-- VGA output
	VGA_R		: out std_logic_vector(1 downto 0);
	VGA_G		: out std_logic_vector(1 downto 0);
	VGA_B		: out std_logic_vector(1 downto 0);
	VGA_HS		: out std_logic;
	VGA_VS		: out std_logic;
	VGA_BLANK : out std_logic;

	-- loader state pulses
	LOADER_ACTIVE : out std_logic;
	LOADER_RESET : out std_logic
);
end loader;

architecture rtl of loader is

-- CPU0
signal cpu0_reset_n	: std_logic;
signal cpu0_clk		: std_logic;
signal cpu0_a_bus	: std_logic_vector(15 downto 0);
signal cpu0_do_bus	: std_logic_vector(7 downto 0);
signal cpu0_di_bus	: std_logic_vector(7 downto 0);
signal cpu0_d_bus	: std_logic_vector(7 downto 0);
signal cpu0_mreq_n	: std_logic;
signal cpu0_iorq_n	: std_logic;
signal cpu0_wr_n	: std_logic;
signal cpu0_rd_n	: std_logic;
signal cpu0_int_n	: std_logic;
signal cpu0_inta_n	: std_logic;
signal cpu0_m1_n	: std_logic;
signal cpu0_rfsh_n	: std_logic;
signal cpu0_ena		: std_logic;
signal cpu0_mult	: std_logic_vector(1 downto 0);
signal cpu0_mem_wr	: std_logic;
signal cpu0_mem_rd	: std_logic;
signal cpu0_nmi_n	: std_logic;
-- Memory
signal rom_do_bus	: std_logic_vector(7 downto 0);
signal ram_a_bus	: std_logic_vector(11 downto 0);
-- Port
signal port_xxfe_reg : std_logic_vector(7 downto 0) := "00000000";
signal port_1ffd_reg	: std_logic_vector(7 downto 0);
signal port_7ffd_reg	: std_logic_vector(7 downto 0);
signal port_dffd_reg	: std_logic_vector(7 downto 0);
signal port_eff7_reg	: std_logic_vector(7 downto 0);
signal port_0000_reg	: std_logic_vector(7 downto 0) := "00000000";
signal port_0001_reg	: std_logic_vector(7 downto 0) := "00000000";
-- Video
signal vid_a_bus	: std_logic_vector(12 downto 0);
signal vid_di_bus	: std_logic_vector(7 downto 0);
signal vid_wr		: std_logic;
signal vid_scr		: std_logic;
signal vid_hsync	: std_logic;
signal vid_vsync	: std_logic;
signal vid_hcnt		: std_logic_vector(8 downto 0);
signal vid_int		: std_logic;
signal rgb		: std_logic_vector(5 downto 0);
signal vga_hsync	: std_logic;
signal vga_vsync	: std_logic;
signal vga_sblank	: std_logic;
signal VideoR		: std_logic_vector(1 downto 0);
signal VideoG		: std_logic_vector(1 downto 0);
signal VideoB		: std_logic_vector(1 downto 0);
signal Hsync		: std_logic;
signal Vsync		: std_logic;
signal Sblank		: std_logic;
-- SPI
signal spi_wr		: std_logic;
signal spi_do_bus	: std_logic_vector(7 downto 0);
signal spi_busy		: std_logic;
signal spi_si		: std_logic;
signal spi_so		: std_logic;
signal spi_clk		: std_logic;
signal spi_cs_n		: std_logic;
-- SDRAM
signal sdr_do_bus	: std_logic_vector(7 downto 0);
signal sdr_wr		: std_logic;
signal sdr_rd		: std_logic;
signal sdr_rfsh		: std_logic;
-- System
signal cpuclk		: std_logic;
signal selector		: std_logic_vector(4 downto 0);
signal loader_act 	: std_logic := '1';
signal loader_act_reg : std_logic := '1';
signal kb_do_bus	: std_logic_vector(4 downto 0) := "11111";
signal mux		: std_logic_vector(3 downto 0);

signal reset_cnt  : std_logic_vector(3 downto 0) := "0000";

--signal cpu0_m1 : std_logic;
--signal cpu0_mreq : std_logic;
--signal cpu0_iorq : std_logic;
--signal cpu0_wr : std_logic;

-- A-Z80 CPU
component z80_top_direct_n
port (
	nRESET	: in std_logic;
	CLK		: in std_logic;
	nWAIT		: in std_logic;
	nINT		: in std_logic;
	nNMI		: in std_logic;
	nBUSRQ	: in std_logic;
	nM1		: out std_logic;
	nMREQ		: out std_logic;
	nIORQ		: out std_logic;
	nRD		: out std_logic;
	nWR		: out std_logic;
	nRFSH		: out std_logic;
	nHALT		: out std_logic;
	nBUSACK	: out std_logic;
	A		   : out std_logic_vector(15 downto 0);
	D		   : inout std_logic_vector(7 downto 0)
);
end component;


begin
	
--U1: entity work.nz80cpu
--port map (
--	I_WAIT		=> cpuclk,
--	I_RESET		=> RESET,
--	I_CLK		=> CLK,
--	I_NMI		=> not(cpu0_nmi_n),
--	I_INT		=> not(cpu0_int_n),
--	I_DATA		=> cpu0_di_bus,
--	O_DATA		=> cpu0_do_bus,
--	O_ADDR		=> cpu0_a_bus,
--	O_M1		=> cpu0_m1,
--	O_MREQ		=> cpu0_mreq,
--	O_IORQ		=> cpu0_iorq,
--	O_WR		=> cpu0_wr,
--	O_HALT		=> open );	

U1: z80_top_direct_n
port map(
	nRESET			=> cpu0_reset_n,
	CLK				=> cpuclk,
	nWAIT				=> '1',
	nINT				=> cpu0_int_n,
	nNMI				=> cpu0_nmi_n,
	nBUSRQ			=> '1',
	nM1				=> cpu0_m1_n,
	nMREQ				=> cpu0_mreq_n,
	nIORQ				=> cpu0_iorq_n,
	nRD				=> cpu0_rd_n,
	nWR				=> cpu0_wr_n,
	nRFSH				=> cpu0_rfsh_n,
	nHALT				=> open,
	nBUSACK			=> open,
	A					=> cpu0_a_bus,
	D					=> cpu0_d_bus
);
	
-- Video Spectrum/Pentagon
U2: entity work.loader_video
port map (
	CLK		=> CLK,
	ENA		=> ENA7,
	INT		=> cpu0_int_n,
	A			=> vid_a_bus,
	DI			=> vid_di_bus,
	BORDER 	=> port_xxfe_reg(2 downto 0),
	RGB		=> rgb,
	HSYNC		=> vid_hsync,
	VSYNC		=> vid_vsync,
	BLANK 	=> open
	);
	
-- Video memory
U3: entity work.loader_ram
port map (
	clock_a		=> CLK,
	clock_b		=> CLK,
	address_a	=> vid_scr & cpu0_a_bus(12 downto 0),
	address_b	=> port_7ffd_reg(3) & vid_a_bus,
	data_a		=> cpu0_do_bus,
	data_b		=> "11111111",
	q_a		=> open,
	q_b		=> vid_di_bus,
	wren_a		=> vid_wr,
	wren_b		=> '0');

-- ROM 1K
U6: entity work.loader_rom
port map (
	address => cpu0_a_bus(12 downto 0),
	clock => CLK,
	q => rom_do_bus
);
	
-- SPI FLASH 25MHz 

U8: entity work.loader_spi
port map (
	RESET		=> RESET,
	CLK		=> CLK,
	SCK		=> CLK14,
	A		=> cpu0_a_bus(0),
	DI		=> cpu0_do_bus,
	DO		=> spi_do_bus,
	WR		=> spi_wr,
	BUSY		=> spi_busy,
	CS_n		=> spi_cs_n,
	SCLK		=> spi_clk,
	MOSI		=> spi_si,
	MISO		=> spi_so);
	
-- ENC424J600 <> MP25P16
process (port_0001_reg, loader_act, spi_si, spi_so, spi_clk, spi_cs_n)
begin
	if port_0001_reg(0) = '1' or loader_act = '0' then
		NCSO <= '1';
		spi_so <= '1';
	else
		NCSO <= spi_cs_n;
		spi_so <= DATA0;
	end if;
end process;	
	
ASDO <= spi_si;
DCLK <= spi_clk;
	
-------------------------------------------------------------------------------

cpu0_reset_n <= not(RESET);	-- CPU сброс
cpu0_inta_n <= cpu0_iorq_n or cpu0_m1_n;		-- INTA
cpu0_nmi_n <= '1';				-- NMI
cpu0_ena <= ENA3_5;
cpuclk <= CLK and cpu0_ena;

cpu0_d_bus <= cpu0_di_bus when selector /= "11111" else (others => 'Z');
cpu0_do_bus <= cpu0_d_bus; -- when selector = "11111" else (others => '1');

--cpu0_m1_n <= not cpu0_m1;
--cpu0_mreq_n <= not cpu0_mreq;
--cpu0_iorq_n <= not cpu0_iorq;
--cpu0_wr_n <= not cpu0_wr;
--cpu0_rd_n <= not cpu0_wr_n;
--cpu0_rfsh_n <= '1';

-------------------------------------------------------------------------------
-- RAM
sdr_wr <= '1' when cpu0_mreq_n = '0' and cpu0_wr_n = '0' and (cpu0_a_bus(15 downto 14) /= "00") else '0';
sdr_rd <= not (cpu0_mreq_n or cpu0_rd_n);
sdr_rfsh <= not cpu0_rfsh_n;

RAM_A <= ram_a_bus & cpu0_a_bus(12 downto 0);
RAM_DI <= cpu0_do_bus;
sdr_do_bus <= RAM_DO;
RAM_WR <= sdr_wr;
RAM_RD <= sdr_rd;
RAM_RFSH <= sdr_rfsh;

-------------------------------------------------------------------------------
-- Регистры
process (RESET, CLK, cpu0_a_bus, port_0000_reg, cpu0_mreq_n, cpu0_iorq_n, cpu0_m1_n, cpu0_wr_n, cpu0_do_bus, port_0001_reg)
begin
	if RESET = '1' then
		port_0000_reg <= (others => '0');	-- маска по AND порта #DFFD
		port_0001_reg <= (others => '0');	-- bit2 = (0:Loader ON, 1:Loader OFF); bit1 = (0:SRAM<->CPU0, 1:SRAM<->GS); bit0 = (0:M25P16, 1:ENC424J600)
		loader_act <= '1';
	elsif CLK'event and CLK = '1' then
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus(15 downto 0) = X"0000" then port_0000_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus(15 downto 0) = X"0001" then port_0001_reg <= cpu0_do_bus; end if;
		if cpu0_m1_n = '0' and cpu0_mreq_n = '0' and cpu0_a_bus = X"0000" and port_0001_reg(2) = '1' then loader_act <= '0'; end if;
	end if;
end process;

process (RESET, CLK, loader_act, loader_act_reg)
begin
	if RESET = '1' then
		loader_act_reg <= '1';
	elsif CLK'event and CLK = '1' then
		if (loader_act_reg = '1' and loader_act = '0') then 
			loader_act_reg <= '0';
		end if;
	end if;
end process;


process (RESET, CLK, reset_cnt, loader_act_reg)
begin
	if RESET = '1' then
		reset_cnt <= "0000";
	elsif CLK'event and CLK = '1' then
		if (loader_act_reg = '0' and reset_cnt /= "1000") then 
			reset_cnt <= reset_cnt + 1;
		end if;
	end if;
end process;

process (RESET, CLK, cpu0_a_bus, cpu0_iorq_n, port_7ffd_reg, port_dffd_reg, cpu0_wr_n, cpu0_do_bus)
begin
	if RESET = '1' then
		port_eff7_reg <= (others => '0');
		port_1ffd_reg <= (others => '0');
		port_7ffd_reg <= (others => '0');
		port_dffd_reg <= (others => '0');
	elsif CLK'event and CLK = '1' then
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus(7 downto 0) = X"FE" then port_xxfe_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"EFF7" then port_eff7_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"1FFD" then port_1ffd_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"7FFD" and port_7ffd_reg(5) = '0' then port_7ffd_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"DFFD" and port_7ffd_reg(5) = '0' then port_dffd_reg <= cpu0_do_bus; end if;
	end if;
end process;

------------------------------------------------------------------------------
-- Селектор
mux <= '0' & cpu0_a_bus(15 downto 13);

process (mux, port_7ffd_reg, port_dffd_reg, port_0000_reg, cpu0_a_bus)
begin
	case mux is
		when "0000" => ram_a_bus <= "100001000" & (not(port_1ffd_reg(1))) & (port_7ffd_reg(4) and not(port_1ffd_reg(1))) & '0';	-- Seg0 ROM 0000-1FFF
		when "0001" => ram_a_bus <= "100001000" & (not(port_1ffd_reg(1))) & (port_7ffd_reg(4) and not(port_1ffd_reg(1))) & '1';	-- Seg0 ROM 2000-3FFF	
		when "0010" => ram_a_bus <= "000000001010";	-- Seg1 RAM 4000-5FFF
		when "0011" => ram_a_bus <= "000000001011";	-- Seg1 RAM 6000-7FFF
		when "0100" => ram_a_bus <= "000000000100";	-- Seg2 RAM 8000-9FFF
		when "0101" => ram_a_bus <= "000000000101";	-- Seg2 RAM A000-BFFF
		when "0110" => ram_a_bus <= (port_dffd_reg and port_0000_reg) & port_7ffd_reg(2 downto 0) & '0';	-- Seg3 RAM C000-DFFF
		when "0111" => ram_a_bus <= (port_dffd_reg and port_0000_reg) & port_7ffd_reg(2 downto 0) & '1';	-- Seg3 RAM E000-FFFF
		when others => null;
	end case;
end process;

-------------------------------------------------------------------------------
-- Port I/O
spi_wr 		<= '1' when (cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus(7 downto 1) = "0000001") else '0';

-------------------------------------------------------------------------------
-- Шина данных CPU0
process (selector, rom_do_bus, sdr_do_bus, spi_do_bus, spi_busy, port_7ffd_reg, port_dffd_reg)
begin
	case selector is
		when "00000" => cpu0_di_bus <= rom_do_bus;
		when "00010" => cpu0_di_bus <= sdr_do_bus;
		when "00011" => cpu0_di_bus <= spi_do_bus;
		when "00100" => cpu0_di_bus <= spi_busy & "1111111";
		when "00111" => cpu0_di_bus <= "11111111";
		when "10100" => cpu0_di_bus <= port_7ffd_reg;
		when "10101" => cpu0_di_bus <= port_dffd_reg;		
		when others  => cpu0_di_bus <= (others => '1');
	end case;
end process;

selector <= 
			"00000" when (cpu0_mreq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 14) = "00") else						-- Loader ROM 
			"00010" when (cpu0_mreq_n = '0' and cpu0_rd_n = '0') else 																		-- SDRAM	
			"00011" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"02") else 						-- M25P16
			"00100" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"03") else 						-- M25P16
			"00111" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"FE") else 						-- Клавиатура, порт xxFE						
			"10100" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 0) = X"7FFD") else						-- port #7FFD
			"10101" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 0) = X"DFFD") else						-- port #DFFD			
			(others => '1');

-------------------------------------------------------------------------------
-- Video
vid_wr	<= '1' when cpu0_mreq_n = '0' and cpu0_wr_n = '0' and ((ram_a_bus = "000000001010") or (ram_a_bus = "000000001110")) else '0'; 
vid_scr	<= '1' when (ram_a_bus = "000000001110") else '0';

U30 : entity work.loader_scan_convert
generic map (
	-- mark active area of input video
	cstart      	=>  38,  -- composite sync start
	clength     	=> 352,  -- composite sync length
	-- output video timing
	hA		=>  24,	-- h front porch
	hB		=>  32,	-- h sync
	hC		=>  40,	-- h back porch
	hD		=> 352,	-- visible video
--	vA		=>   0,	-- v front porch (not used)
	vB		=>   2,	-- v sync
	vC		=>  10,	-- v back porch
	vD		=> 284,	-- visible video
	hpad		=>   0,	-- create H black border
	vpad		=>   0	-- create V black border
)
port map (
	I_VIDEO		=> rgb,
	I_HSYNC		=> vid_hsync,
	I_VSYNC		=> vid_vsync,
	O_VIDEO(5 downto 4)	=> VideoR,
	O_VIDEO(3 downto 2)	=> VideoG,
	O_VIDEO(1 downto 0)	=> VideoB,
	O_HSYNC		=> HSync,
	O_VSYNC		=> VSync,
	O_CMPBLK_N	=> sblank,
	CLK		=> CLK7,
	CLK_x2		=> CLK14);

VGA_R <= VideoR;
VGA_G <= VideoG;
VGA_B <= VideoB;
VGA_HS <= HSync;
VGA_VS <= VSync;
VGA_BLANK <= sblank;

LOADER_ACTIVE <= loader_act_reg;
LOADER_RESET <= reset_cnt(2);

end rtl;