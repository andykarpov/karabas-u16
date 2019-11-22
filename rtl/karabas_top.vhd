-------------------------------------------------------------------[18.11.2019]
-- u16-Karabas Version 1.1
-- DEVBOARD ReVerSE-U16
-------------------------------------------------------------------------------
-- V1.0	   18.07.2019  initial version
-- V1.1		18.11.2019  Added ZXUNO registers and UART

-- Copyright (c) 2011-2014 MVV
-- Copyright (c) 2019 Andy Karpov
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- * Redistributions of source code must retain the above copyright notice,
--   this list of conditions and the following disclaimer.
--
-- * Redistributions in synthesized form must reproduce the above copyright
--   notice, this list of conditions and the following disclaimer in the
--   documentation and/or other materials provided with the distribution.
--
-- * Neither the name of the author nor the names of other contributors may
--   be used to endorse or promote products derived from this software without
--   specific prior written agreement from the author.
--
-- * License is granted for non-commercial use only.  A fee may not be charged
--   for redistributions as source code or in synthesized/hardware form without 
--   specific prior written agreement from the author.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.

library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all; 

-- M9K 46K:
-- 0000-B7FF

-- SDRAM 32M:
-- 0000000-1FFFFFF

-- 4 3210 9876 5432 1098 7654 3210
-- 0 00xx_xxxx xxxx_xxxx xxxx_xxxx	0000000-03FFFFF		RAM 	  4MB
-- 0 xxxx_xxxx xxxx_xxxx xxxx_xxxx	0400000-0FFFFFF		-----------
-- 1 0000_0xxx xxxx_xxxx xxxx_xxxx	1000000-107FFFF		512K
-- 1 0000_1000 00xx_xxxx xxxx_xxxx	1080000-1003FFF		GLUK	   16K
-- 1 0000_1000 01xx_xxxx xxxx_xxxx	1084000-1007FFF		TR-DOS	16K
-- 1 0000_1000 10xx_xxxx xxxx_xxxx	1088000-100BFFF		ROM'86	16K
-- 1 0000_1000 11xx_xxxx xxxx_xxxx	108C000-100FFFF		ROM'82	16K
-- 1 0000_1001 000x_xxxx xxxx_xxxx	1090000-1091FFF		divMMC	 8K


-- FLASH 2048K:
-- 00000-5FFFF		Cyclone EP4C22 config 
-- 60000-63FFF		free 				16K
-- 64000-67FFF		free 				16K
-- 68000-6BFFF		GLUK 				16K
-- 6C000-6FFFF		TR-DOS 			16K
-- 70000-73FFF		OS'86 			16K
-- 74000-77FFF		OS'82 			16K
-- 78000-7AFFF		free			 	8K
-- 7B000-7BFFF		free		 		8К
-- 7C000-7FFFF		free				16К

entity karabas_top is
port (
	-- Clock (50MHz)
	CLK_50MHZ	: in std_logic;

	-- SDRAM (32MB 16x16bit)
	SDRAM_DQ		: inout std_logic_vector(15 downto 0);
	SDRAM_A		: out std_logic_vector(12 downto 0);
	SDRAM_BA	: out std_logic_vector(1 downto 0);
	SDRAM_CLK	: out std_logic;
	SDRAM_DQML	: out std_logic;
	SDRAM_DQMH	: out std_logic;
	SDRAM_NWE	: out std_logic;
	SDRAM_NCAS	: out std_logic;
	SDRAM_NRAS	: out std_logic;

	-- RTC (DS1338Z-33+)
	I2C_SCL		: inout std_logic;
	I2C_SDA		: inout std_logic;
	SQW 			: in std_logic;  -- dedicated clock / input only
	
	-- SPI FLASH (M25P16)
	DATA0		: in std_logic;
	NCSO		: out std_logic;
	DCLK		: out std_logic;
	ASDO		: out std_logic;

	-- SPI (ENC424J600)
	ETH_SO		: in std_logic;
	ETH_NINT		: in std_logic;
	ETH_NCS		: out std_logic;

	-- HDMI
	TMDS	: out std_logic_vector(7 downto 0);

	-- External I/O
	OUT_L	: out std_logic; -- DN (PIN_68) 
	OUT_R	: out std_logic; -- DP (PIN_69)
	
	-- SD/MMC Card
	SD_SO			: in std_logic;
	SD_SI			: out std_logic;
	SD_CLK		: out std_logic;
	SD_NCS		: out std_logic;
	SD_NDET 		: in std_logic; -- dedicated clock / input only
	
	-- USB
	USB_NRESET     : in std_logic;
	USB_TX         : in std_logic;
	USB_IO1        : in std_logic;
	USB_RX 			: in std_logic;
	USB_CLK 			: in std_logic;
	USB_SI 			: in std_logic;
	USB_NCS 			: in std_logic;
	USB_SO 			: in std_logic; -- dedicated clock / input only
	USB_IO3 			: in std_logic; -- dedicated clock / input only 
	
	-- UART / ESP8266
	UART_RX 			: in std_logic;  -- BP
	UART_TX 			: out std_logic; -- AP
	UART_RTS 		: out std_logic; -- AN
	UART_CTS 		: in std_logic;  -- BN
	
	-- uBus
--	AP 				: in std_logic;
--	AN 				: in std_logic;
--	BP					: in std_logic; -- dedicated clock / input only 
--	BN 				: in std_logic; -- dedicated clock / input only
	CP					: in std_logic; -- dedicated clock / input only
	CN 				: in std_logic  -- dedicated clock / input only	
);
end karabas_top;

architecture rtl of karabas_top is

-- CPU0
signal cpu0_reset_n	: std_logic;
signal cpu0_clk		: std_logic;
signal cpu0_a_bus	: std_logic_vector(15 downto 0);
signal cpu0_do_bus	: std_logic_vector(7 downto 0);
signal cpu0_di_bus	: std_logic_vector(7 downto 0);
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
signal cpu0_wait_n : std_logic := '1';
-- Memory
signal ram_a_bus	: std_logic_vector(11 downto 0);
-- Port
signal port_xxfe_reg	: std_logic_vector(7 downto 0) := "00000000";
signal port_7ffd_reg	: std_logic_vector(7 downto 0);
signal port_1ffd_reg	: std_logic_vector(7 downto 0);
signal port_dffd_reg : std_logic_vector(7 downto 0);

-- PS/2 Keyboard
signal kb_do_bus	: std_logic_vector(4 downto 0);
signal kb_reset : std_logic := '0';
signal kb_magic : std_logic := '0';
signal kb_special : std_logic := '0';
signal kb_turbo : std_logic := '0';

-- Joy
signal joy_bus : std_logic_vector(4 downto 0) := "11111";

-- Mouse
signal ms_x		: std_logic_vector(7 downto 0);
signal ms_y		: std_logic_vector(7 downto 0);
signal ms_z		: std_logic_vector(7 downto 0);
signal ms_b		: std_logic_vector(7 downto 0);

-- Video
signal vid_a_bus	: std_logic_vector(12 downto 0);
signal vid_di_bus	: std_logic_vector(7 downto 0);
signal vid_wr		: std_logic;
signal vid_scr		: std_logic;
signal vid_hsync	: std_logic;
signal vid_vsync	: std_logic;
signal vid_int		: std_logic;
signal vid_attr	: std_logic_vector(7 downto 0);
signal vid_rgb		: std_logic_vector(5 downto 0);
signal vid_rgb_osd : std_logic_vector(5 downto 0);
signal vid_border : std_logic_vector(2 downto 0);
signal vid_invert : std_logic;

signal vid_hcnt 	: std_logic_vector(8 downto 0);
signal vid_vcnt 	: std_logic_vector(8 downto 0);

signal vga_hsync	: std_logic;
signal vga_vsync	: std_logic;
signal vga_blank	: std_logic;
signal vga_r		: std_logic_vector(1 downto 0);
signal vga_g		: std_logic_vector(1 downto 0);
signal vga_b		: std_logic_vector(1 downto 0);
-- Z-Controller
signal zc_do_bus	: std_logic_vector(7 downto 0);
signal zc_rd		: std_logic;
signal zc_wr		: std_logic;
signal zc_cs_n		: std_logic;
signal zc_sclk		: std_logic;
signal zc_mosi		: std_logic;
signal zc_miso		: std_logic;
-- divmmc
signal divmmc_do	: std_logic_vector(7 downto 0);
signal divmmc_amap	: std_logic;
signal divmmc_e3reg	: std_logic_vector(7 downto 0);	
signal divmmc_cs_n	: std_logic;
signal divmmc_sclk	: std_logic;
signal divmmc_mosi	: std_logic;
-- SPI
signal spi_si		: std_logic;
signal spi_so		: std_logic;
signal spi_clk		: std_logic;
signal spi_wr		: std_logic;
signal spi_cs_n		: std_logic;
signal spi_do_bus	: std_logic_vector(7 downto 0);
signal spi_busy		: std_logic;
-- MC146818A
signal mc146818_wr	: std_logic;
signal mc146818_a_bus	: std_logic_vector(5 downto 0);
signal mc146818_do_bus	: std_logic_vector(7 downto 0);
signal mc146818_busy		: std_logic;
signal port_bff7	: std_logic;
signal port_eff7_reg	: std_logic_vector(7 downto 0);
signal fd_port 	: std_logic;
signal fd_sel 		: std_logic;

signal cs_xxfe : std_logic := '0'; 
signal cs_xxff : std_logic := '0';
signal cs_eff7 : std_logic := '0';
signal cs_dff7 : std_logic := '0';
signal cs_7ffd : std_logic := '0';
signal cs_1ffd : std_logic := '0';
signal cs_dffd : std_logic := '0';
signal cs_fffd : std_logic := '0';
signal cs_xxfd : std_logic := '0';

-- SDRAM
signal sdr_a_bus  : std_logic_vector(24 downto 0);
signal sdr_di_bus : std_logic_vector(7 downto 0);
signal sdr_do_bus	: std_logic_vector(7 downto 0);
signal sdr_wr		: std_logic;
signal sdr_rd		: std_logic;
signal sdr_rfsh	: std_logic;
-- TurboSound
signal ssg_sel		: std_logic;
signal ssg_cn0_bus	: std_logic_vector(7 downto 0);
signal ssg_cn0_a	: std_logic_vector(7 downto 0);
signal ssg_cn0_b	: std_logic_vector(7 downto 0);
signal ssg_cn0_c	: std_logic_vector(7 downto 0);
signal ssg_cn1_bus	: std_logic_vector(7 downto 0);
signal ssg_cn1_a	: std_logic_vector(7 downto 0);
signal ssg_cn1_b	: std_logic_vector(7 downto 0);
signal ssg_cn1_c	: std_logic_vector(7 downto 0);
signal audio_l		: std_logic_vector(15 downto 0);
signal audio_r		: std_logic_vector(15 downto 0);
signal sound		: std_logic_vector(7 downto 0);
-- Soundrive
signal covox_a		: std_logic_vector(7 downto 0);
signal covox_b		: std_logic_vector(7 downto 0);
signal covox_c		: std_logic_vector(7 downto 0);
signal covox_d		: std_logic_vector(7 downto 0);
-- SAA1099
signal saa_wr_n		: std_logic;
signal saa_out_l	: std_logic_vector(7 downto 0);
signal saa_out_r	: std_logic_vector(7 downto 0);
-- CLOCK
signal clk_bus		: std_logic;
signal clk_sdr		: std_logic;
signal clk_hdmi		: std_logic;
signal clk7		: std_logic;
signal clk14		: std_logic;
signal clk_saa 	: std_logic;
------------------------------------
signal ena_14mhz	: std_logic;
signal ena_7mhz		: std_logic;
signal ena_3_5mhz	: std_logic;
signal ena_1_75mhz	: std_logic;
signal ena_0_4375mhz	: std_logic;
signal ena_cnt		: std_logic_vector(5 downto 0);
-- System
signal reset		: std_logic;
signal areset		: std_logic;
signal locked		: std_logic;
signal loader_act	: std_logic := '1';
signal loader_reset : std_logic := '0';
signal dos_act		: std_logic := '1';
signal cpuclk		: std_logic;
signal selector		: std_logic_vector(7 downto 0);
signal mux		: std_logic_vector(3 downto 0);
signal ram_ext : std_logic_vector(7 downto 0) := "00000000";
signal ram_ext_lock : std_logic_vector(1 downto 0) := "00";
-- Loader
signal loader_ram_di	: std_logic_vector(7 downto 0);
signal loader_ram_do	: std_logic_vector(7 downto 0);
signal loader_ram_a	: std_logic_vector(24 downto 0);
signal loader_ram_wr : std_logic;
signal loader_ram_rd : std_logic;
signal loader_ram_rfsh : std_logic;
-- Host 
signal host_ram_di	: std_logic_vector(7 downto 0);
signal host_ram_do	: std_logic_vector(7 downto 0);
signal host_ram_a	: std_logic_vector(24 downto 0);
signal host_ram_wr : std_logic;
signal host_ram_rd : std_logic;
signal host_ram_rfsh : std_logic;
signal host_vga_r : std_logic_vector(1 downto 0);
signal host_vga_g : std_logic_vector(1 downto 0);
signal host_vga_b : std_logic_vector(1 downto 0);
signal host_vga_hs : std_logic;
signal host_vga_vs : std_logic;
signal host_vga_sblank : std_logic;
-- UART 
signal uart_oe_n   : std_logic := '1';
signal uart_do_bus : std_logic_vector(7 downto 0);
-- ZXUNO ports
signal zxuno_regrd : std_logic;
signal zxuno_regwr : std_logic;
signal zxuno_addr : std_logic_vector(7 downto 0);
signal zxuno_regaddr_changed : std_logic;
signal zxuno_addr_oe_n : std_logic;
signal zxuno_addr_to_cpu : std_logic_vector(7 downto 0);

-- DivMMC / Z-Controller mode
signal sd_mode : std_logic := '0'; -- 0 = ZC, 1 = DivMMC

component saa1099
port (
	clk_sys		: in std_logic;
	ce		: in std_logic;		--8 MHz
	rst_n		: in std_logic;
	cs_n		: in std_logic;
	a0		: in std_logic;		--0=data, 1=address
	wr_n		: in std_logic;
	din		: in std_logic_vector(7 downto 0);
	out_l		: out std_logic_vector(7 downto 0);
	out_r		: out std_logic_vector(7 downto 0));
end component;

component zxunoregs
port (
	clk: in std_logic;
	rst_n : in std_logic;
	a : in std_logic_vector(15 downto 0);
	iorq_n : in std_logic;
	rd_n : in std_logic;
	wr_n : in std_logic;
	din : in std_logic_vector(7 downto 0);
	dout : out std_logic_vector(7 downto 0);
	oe_n : out std_logic;
	addr : out std_logic_vector(7 downto 0);
	read_from_reg: out std_logic;
	write_to_reg: out std_logic;
	regaddr_changed: out std_logic);
end component;

component zxunouart
port (
	clk : in std_logic;
	zxuno_addr : in std_logic_vector(7 downto 0);
	zxuno_regrd : in std_logic;
	zxuno_regwr : in std_logic;
	din : in std_logic_vector(7 downto 0);
	dout : out std_logic_vector(7 downto 0);
	oe_n : out std_logic;
	uart_tx : out std_logic;
	uart_rx : in std_logic;
	uart_rts : out std_logic);
end component;

component uart 
port ( 
	clk: in std_logic;
	txdata: in std_logic_vector(7 downto 0);
	txbegin: in std_logic;
	txbusy : out std_logic;
	rxdata : out std_logic_vector(7 downto 0);
	rxrecv : out std_logic;
	data_read : in std_logic;
	rx : in std_logic;
	tx : out std_logic;
	rts: out std_logic);
end component;

begin

-- PLL
U0: entity work.altpll0
port map (
	areset			=> areset,
	inclk0			=> CLK_50MHZ,	--  50.0 MHz
	locked			=> locked,
	c0					=> clk_bus,		--  28.0 MHz
	c1					=> clk7,			--   7.0 MHz
	c2					=> clk14,		--  14.0 MHz
	c3					=> open,			--  84.0 MHz
	c4					=> clk_hdmi);	-- 140.0 MHz
	
-- SDRAM PLL
U00: entity work.altpll1
port map (
	areset			=> areset,
	inclk0			=> CLK_50MHZ,	--  50.0 MHz
	locked 			=> open,
	c0					=> clk_sdr,			-- 84.0 MHz
	c1 				=> clk_saa);		--  8.0 MHz	
	
-- Zilog Z80A CPU
U1: entity work.T80se
generic map (
	Mode		=> 0,	-- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
	T2Write		=> 1,	-- 0 => WR_n active in T3, /=0 => WR_n active in T2
	IOWait		=> 1 )	-- 0 => Single cycle I/O, 1 => Std I/O cycle

port map (
	RESET_n		=> not reset,
	CLK_n		=> clk_bus,
	ENA		=> cpuclk,
	WAIT_n		=> cpu0_wait_n,
	INT_n		=> cpu0_int_n,
	NMI_n		=> cpu0_nmi_n,
	BUSRQ_n		=> '1',
	M1_n		=> cpu0_m1_n,
	MREQ_n		=> cpu0_mreq_n,
	IORQ_n		=> cpu0_iorq_n,
	RD_n		=> cpu0_rd_n,
	WR_n		=> cpu0_wr_n,
	RFSH_n		=> cpu0_rfsh_n,
	HALT_n		=> open,--cpu_halt_n,
	BUSAK_n		=> open,--cpu_basak_n,
	A		=> cpu0_a_bus,
	DI		=> cpu0_di_bus,
	DO		=> cpu0_do_bus);
	
-- Loader
U2: entity work.loader
port map(
	CLK 				=> clk_bus,
	RESET 			=> areset,

	RAM_A 			=> loader_ram_a,
	RAM_DI 			=> loader_ram_di,
	RAM_DO 			=> loader_ram_do,
	RAM_WR 			=> loader_ram_wr,
	RAM_RD 			=> loader_ram_rd,
	RAM_RFSH 		=> loader_ram_rfsh,

	DATA0				=> DATA0,
	NCSO				=> NCSO,
	DCLK				=> DCLK,
	ASDO				=> ASDO,

	LOADER_ACTIVE 	=> loader_act,
	LOADER_RESET 	=> loader_reset
);	
	
-- Video Spectrum/Pentagon
U3: entity work.video
port map (
	CLK				=> clk_bus,
	ENA				=> ena_7mhz,
	INT				=> cpu0_int_n,
	BORDER			=> vid_border,	-- Биты D0..D2 порта xxFE определяют цвет бордюра
	TURBO 			=> not(cpu0_mult(0)),
	ATTR_O			=> vid_attr,
	A					=> vid_a_bus,
	DI					=> vid_di_bus,
	BLANK 			=> open,
	RGB				=> vid_rgb,
	HSYNC				=> vid_hsync,
	VSYNC				=> vid_vsync,
	INVERT_O 		=> vid_invert,
	
	HCNT_O 			=> vid_hcnt,
	VCNT_O			=> vid_vcnt
	
	);
	
U3_1: entity work.osd
port map (
	CLK 	=> clk_bus,
	EN 	=> '1',
	RGB_I => vid_rgb,
	RGB_O => vid_rgb_osd,
	HCNT_I => vid_hcnt,
	VCNT_I => vid_vcnt,
	PORT_1 => port_1ffd_reg,
	PORT_2 => port_eff7_reg,
	PORT_3 => port_7ffd_reg,
	PORT_4 => port_dffd_reg	
);
	
-- Video memory
U4: entity work.altram1
port map (
	clock_a			=> clk_bus,
	clock_b			=> clk_bus,
	address_a		=> vid_scr & cpu0_a_bus(12 downto 0),
	address_b		=> port_7ffd_reg(3) & vid_a_bus,
	data_a			=> cpu0_do_bus,
	data_b			=> "11111111",
	q_a				=> open,
	q_b				=> vid_di_bus,
	wren_a			=> vid_wr,
	wren_b			=> '0');

-- USB HID
U5: entity work.deserializer
generic map (
	divisor			=> 434)		-- divisor = 50MHz / 115200 Baud = 434
port map(
	I_CLK				=> CLK_50MHZ,
	I_CLK_RATE 		=> vid_invert,
	I_RESET			=> areset,
	I_RX				=> USB_TX,
	I_NEWFRAME		=> USB_IO1,
	I_ADDR			=> cpu0_a_bus(15 downto 8),
	O_KEYBOARD_DO_BUS		=> kb_do_bus,
	O_MOUSE_X		=> ms_x,
	O_MOUSE_Y		=> ms_y,
	O_MOUSE_Z		=> ms_z,
	O_MOUSE_BUTTONS => ms_b,
	O_JOYSTICK 		=> joy_bus,
	O_RESET 	=> kb_reset,
	O_MAGIC => kb_magic,
	O_SPECIAL => kb_special,
	O_TURBO => kb_turbo
	);
	
-- Z-Controller
U6: entity work.zcontroller
port map (
	RESET				=> reset,
	CLK				=> clk_bus,
	A					=> cpu0_a_bus(5),
	DI					=> cpu0_do_bus,
	DO					=> zc_do_bus,
	RD					=> zc_rd,
	WR					=> zc_wr,
	SDDET				=> '0', --SD_NDET,
	SDPROT			=> '0',
	CS_n				=> zc_cs_n,
	SCLK				=> zc_sclk,
	MOSI				=> zc_mosi,
	MISO				=> SD_SO);
	
-- divmmc interface
U18: entity work.divmmc
port map (
	CLK		=> clk_bus,
	EN		=> sd_mode,
	RESET		=> reset,
	ADDR		=> cpu0_a_bus,
	DI		=> cpu0_do_bus,
	DO		=> divmmc_do,
	WR_N		=> cpu0_wr_n,
	RD_N		=> cpu0_rd_n,
	IORQ_N		=> cpu0_iorq_n,
	MREQ_N		=> cpu0_mreq_n,
	M1_N		=> cpu0_m1_n,
	E3REG		=> divmmc_e3reg,
	AMAP		=> divmmc_amap,
	CS_N		=> divmmc_cs_n,
	SCLK		=> divmmc_sclk,
	MOSI		=> divmmc_mosi,
	MISO		=> SD_SO);

	
-- TurboSound
U7: entity work.turbosound
port map (
	I_CLK		=> clk_bus,
	I_ENA		=> ena_1_75mhz,
	I_ADDR		=> cpu0_a_bus,
	I_DATA		=> cpu0_do_bus,
	I_WR_N		=> cpu0_wr_n,
	I_IORQ_N	=> cpu0_iorq_n,
	I_M1_N		=> cpu0_m1_n,
	I_RESET_N	=> not reset,
	O_SEL		=> ssg_sel,
	-- ssg0
	O_SSG0_DA	=> ssg_cn0_bus,
	O_SSG0_AUDIO_A	=> ssg_cn0_a,
	O_SSG0_AUDIO_B	=> ssg_cn0_b,
	O_SSG0_AUDIO_C	=> ssg_cn0_c,
	-- ssg1
	O_SSG1_DA	=> ssg_cn1_bus,
	O_SSG1_AUDIO_A	=> ssg_cn1_a,
	O_SSG1_AUDIO_B	=> ssg_cn1_b,
	O_SSG1_AUDIO_C	=> ssg_cn1_c);

-- SDRAM Controller
U8: entity work.sdram
port map (
	CLK				=> clk_sdr,
	A					=> sdr_a_bus, 
	DI					=> sdr_di_bus,
	DO					=> sdr_do_bus,
	WR					=> sdr_wr,
	RD					=> sdr_rd,
	RFSH				=> sdr_rfsh,
	RFSHREQ			=> open,
	IDLE				=> open,
	CK					=> SDRAM_CLK,
	RAS_n				=> SDRAM_NRAS,
	CAS_n				=> SDRAM_NCAS,
	WE_n				=> SDRAM_NWE,
	DQML				=> SDRAM_DQML,
	DQMH				=> SDRAM_DQMH,
	BA					=> SDRAM_BA,
	MA					=> SDRAM_A,
	DQ					=> SDRAM_DQ);

-- MC146818A
U9: entity work.mc146818a
port map (
	RESET				=> reset,
	CLK				=> clk_bus,
	ENA				=> ena_0_4375mhz,
	CS					=> '1',
	WR					=> mc146818_wr,
	A					=> mc146818_a_bus,
	DI					=> cpu0_do_bus,
	DO					=> mc146818_do_bus,
	I2C_SDA 			=> I2C_SDA,
	I2C_SCL 		 	=> I2C_SCL,
	BUSY 				=> mc146818_busy
);

-- Soundrive
U10: entity work.soundrive
port map (
	I_RESET		=> reset,
	I_CLK		=> clk_bus,
	I_CS		=> '1',
	I_WR_N		=> cpu0_wr_n,
	I_ADDR		=> cpu0_a_bus(7 downto 0),
	I_DATA		=> cpu0_do_bus,
	I_IORQ_N	=> cpu0_iorq_n,
	I_DOS		=> dos_act,
	O_COVOX_A	=> covox_a,
	O_COVOX_B	=> covox_b,
	O_COVOX_C	=> covox_c,
	O_COVOX_D	=> covox_d);

-- Delta-Sigma
U11: entity work.dac
port map (
    I_CLK   			=> clk_sdr,
    I_RESET 			=> areset,
    I_DATA		=> audio_l,
    O_DAC   		=> OUT_L);

-- Delta-Sigma
U12: entity work.dac
port map (
    I_CLK   			=> clk_sdr,
    I_RESET 			=> areset,
    I_DATA		=> audio_r,
    O_DAC   		=> OUT_R);
	 
-- Scan doubler
U13 : entity work.scan_convert
generic map (
	-- mark active area of input video
	cstart      	=>  46,  -- composite sync start -- 38
	clength     	=> 352,  -- composite sync length
	-- output video timing
	hA					=>  24,	-- h front porch
	hB					=>  32,	-- h sync
	hC					=>  40,	-- h back porch
 	hD					=> 352,	-- visible video
--	vA					=>   0,	-- v front porch (not used)
	vB					=>   2,	-- v sync
	vC					=>  10,	-- v back porch
	vD					=> 284,	-- visible video
	hpad				=>   0,	-- create H black border
	vpad				=>   0	-- create V black border
)
port map (
	I_VIDEO			=> vid_rgb_osd,
	I_HSYNC			=> vid_hsync,
	I_VSYNC			=> vid_vsync,
	O_VIDEO(5 downto 4)	=> host_vga_r,
	O_VIDEO(3 downto 2)	=> host_vga_g,
	O_VIDEO(1 downto 0)	=> host_vga_b,
	O_HSYNC			=> host_vga_hs,
	O_VSYNC			=> host_vga_vs,
	O_CMPBLK_N		=> host_vga_sblank,
	CLK				=> clk7,
	CLK_x2			=> clk14);
	
-- HDMI output
U14: entity work.hdmi
generic map (
	FREQ				=> 28000000,	-- pixel clock frequency = 25.2MHz
	FS					=> 32000,	-- audio sample rate - should be 32000, 41000 or 48000 = 48KHz
	CTS				=> 28000,	-- CTS = Freq(pixclk) * N / (128 * Fs)
	N					=> 6144)	-- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300 (Check HDMI spec 7.2 for details)
port map (
	I_CLK_VGA		=> clk_bus, -- 28 MHz
	I_CLK_TMDS		=> clk_hdmi, -- 140 MHz
	I_HSYNC			=> vga_hsync,
	I_VSYNC			=> vga_vsync,
	I_BLANK			=> not vga_blank,
	I_RED				=> vga_r & vga_r & vga_r & vga_r,
	I_GREEN			=> vga_g & vga_g & vga_g & vga_g,
	I_BLUE			=> vga_b & vga_b & vga_b & vga_b,
	I_AUDIO_PCM_L 	=> audio_l,
	I_AUDIO_PCM_R	=> audio_r,
	O_TMDS			=> TMDS);

-- no sound version
--U14: entity work.hdmi
--port map (
--	I_CLK_PIXEL		=> clk_bus, -- 28 MHz
--	I_CLK_TMDS		=> clk_hdmi, -- 140 MHz
--	I_HSYNC			=> vga_hsync,
--	I_VSYNC			=> vga_vsync,
--	I_BLANK			=> not vga_blank,
--	I_RED				=> vga_r & vga_r & vga_r & vga_r,
--	I_GREEN			=> vga_g & vga_g & vga_g & vga_g,
--	I_BLUE			=> vga_b & vga_b & vga_b & vga_b,
--	O_TMDS			=> TMDS);

U15: saa1099
port map(
	clk_sys		=> clk_saa,
	ce		=> '1',			-- 8 MHz
	rst_n		=> not reset,
	cs_n		=> '0',
	a0		=> cpu0_a_bus(8),		-- 0=data, 1=address
	wr_n		=> saa_wr_n,
	din		=> cpu0_do_bus,
	out_l		=> saa_out_l,
	out_r		=> saa_out_r);
	
-- UART (via ZX UNO ports #FC3B / #FD3B) 
U16: zxunoregs 
port map(
	clk => clk_bus, -- todo
	rst_n => not reset,
	a => cpu0_a_bus,
	iorq_n => cpu0_iorq_n,
	rd_n => cpu0_rd_n,
	wr_n => cpu0_wr_n,
	din => cpu0_do_bus,
	dout => zxuno_addr_to_cpu,
	oe_n => zxuno_addr_oe_n,
	addr => zxuno_addr,
	read_from_reg => zxuno_regrd,
	write_to_reg => zxuno_regwr,
	regaddr_changed => zxuno_regaddr_changed);

U17: zxunouart 
port map(
	clk => clk7,
	zxuno_addr => zxuno_addr,
	zxuno_regrd => zxuno_regrd,
	zxuno_regwr => zxuno_regwr,
	din => cpu0_do_bus,
	dout => uart_do_bus,
	oe_n => uart_oe_n,
	uart_tx => UART_TX,
	uart_rx => UART_RX,
	uart_rts => UART_RTS);
	
-------------------------------------------------------------------------------
-- Global signals

process (clk_bus)
begin
	if clk_bus'event and clk_bus = '0' then
		ena_cnt <= ena_cnt + 1;
	end if;
end process;

ena_14mhz <= ena_cnt(0);
ena_7mhz <= ena_cnt(1) and ena_cnt(0);
ena_3_5mhz <= ena_cnt(2) and ena_cnt(1) and ena_cnt(0);
ena_1_75mhz <= ena_cnt(3) and ena_cnt(2) and ena_cnt(1) and ena_cnt(0);
ena_0_4375mhz <= ena_cnt(5) and ena_cnt(4) and ena_cnt(3) and ena_cnt(2) and ena_cnt(1) and ena_cnt(0);

areset <= not USB_NRESET;					 -- global reset
reset <= areset or kb_reset or not(locked) or loader_reset or loader_act; -- hot reset

sd_mode <= '1' when kb_special = '1' else '0';

cpu0_reset_n <= not(reset) and not(loader_reset);					-- CPU reset
cpu0_inta_n <= cpu0_iorq_n or cpu0_m1_n;	-- INTA
cpu0_nmi_n <= '0' when kb_magic = '1' else '1';				-- NMI
--cpu0_wait_n <= '1';
--cpuclk <= clk_bus and cpu0_ena when mc146818_busy = '0' else '0';
cpu0_wait_n <= not mc146818_busy; -- WAIT
cpuclk <= clk_bus and cpu0_ena;
cpu0_mult <= "01"; -- disabled turbo --'0' & port_1ffd_reg(2); -- turbo switch
process (cpu0_mult, ena_3_5mhz, ena_7mhz, ena_14mhz)
begin
	case cpu0_mult is
		when "00" => cpu0_ena <= ena_7mhz;
		when "01" => cpu0_ena <= ena_3_5mhz;
		when others => null;
	end case;
end process;

-------------------------------------------------------------------------------
-- RAM

host_ram_a <= ram_a_bus & cpu0_a_bus(12 downto 0);
host_ram_di <= cpu0_do_bus;
--host_ram_wr <= '1' when cpu0_mreq_n = '0' and cpu0_wr_n = '0' and (mux = "1000" or mux(3 downto 2) = "01" or mux(3 downto 1) = "001" or mux(3 downto 2) = "11" or mux(3 downto 1) = "101") else '0';
host_ram_wr <= '1' when cpu0_mreq_n = '0' and cpu0_wr_n = '0' and (mux = "1001" or mux(3 downto 2) = "11" or mux(3 downto 2) = "01" or mux(3 downto 1) = "101" or mux(3 downto 1) = "001") else '0';

host_ram_rd <= not (cpu0_mreq_n or cpu0_rd_n);
host_ram_rfsh <= not cpu0_rfsh_n;

-- bridge between loader and host machine
sdr_a_bus <= loader_ram_a when loader_act = '1' else host_ram_a;
sdr_di_bus <= loader_ram_di when loader_act = '1' else host_ram_di;
loader_ram_do <= sdr_do_bus;-- when loader_act = '1' else (others => '1');
host_ram_do <= sdr_do_bus;-- when loader_act = '0' else (others => '1');
sdr_wr <= loader_ram_wr when loader_act = '1' else host_ram_wr;
sdr_rd <= loader_ram_rd when loader_act = '1' else host_ram_rd;
sdr_rfsh <= loader_ram_rfsh when loader_act = '1' else host_ram_rfsh;

-------------------------------------------------------------------------------
-- SD

SD_NCS	<= zc_cs_n when sd_mode = '0' else divmmc_cs_n;
SD_CLK 	<= zc_sclk when sd_mode = '0' else divmmc_sclk;
SD_SI 	<= zc_mosi when sd_mode = '0' else divmmc_mosi;

-------------------------------------------------------------------------------
-- Ports

-- #FD port correction
-- IN A, (#FD) - read a value from a hardware port 
-- OUT (#FD), A - writes the value of the second operand into the port given by the first operand.
fd_sel <= '0' when (
	(cpu0_do_bus(7 downto 4) = "1101" and cpu0_do_bus(2 downto 0) = "011") or 
	(cpu0_di_bus(7 downto 4) = "1101" and cpu0_di_bus(2 downto 0) = "011")) else '1'; 

-- TODO
process(fd_sel, reset, cpu0_m1_n)
begin
	if reset='1' then
		fd_port <= '1';
	elsif rising_edge(cpu0_m1_n) then 
		fd_port <= fd_sel;
	end if;
end process;

ram_ext_lock <= port_1ffd_reg(1) & port_7ffd_reg(5);
cs_xxfe <= '1' when cpu0_iorq_n = '0' and cpu0_m1_n = '1' and cpu0_a_bus(0) = '0' else '0';
cs_xxff <= '1' when cpu0_iorq_n = '0' and cpu0_m1_n = '1' and cpu0_a_bus(7 downto 0) = X"FF" else '0';
cs_eff7 <= '1' when cpu0_iorq_n = '0' and cpu0_m1_n = '1' and cpu0_a_bus = X"EFF7" else '0';
cs_dff7 <= '1' when cpu0_iorq_n = '0' and cpu0_m1_n = '1' and cpu0_a_bus = X"DFF7" and port_eff7_reg(7) = '1' else '0';
cs_fffd <= '1' when cpu0_iorq_n = '0' and cpu0_m1_n = '1' and cpu0_a_bus = X"FFFD" and fd_port = '1' else '0';
cs_1ffd <= '1' when cpu0_iorq_n = '0' and cpu0_m1_n = '1' and cpu0_a_bus = X"1FFD" and fd_port = '1' else '0';
cs_dffd <= '1' when cpu0_iorq_n = '0' and cpu0_m1_n = '1' and cpu0_a_bus = X"DFFD" and fd_port = '1' else '0';
cs_7ffd <= '1' when cpu0_iorq_n = '0' and cpu0_m1_n = '1' and cpu0_a_bus = X"7FFD" else '0';
cs_xxfd <= '1' when cpu0_iorq_n = '0' and cpu0_m1_n = '1' and cpu0_a_bus(15) = '0' and cpu0_a_bus(1) = '0' and fd_port = '0' else '0';


process (reset, areset, clk_bus, cpu0_a_bus, dos_act, cs_xxfe, cs_eff7, cs_dff7, cs_7ffd, cs_1ffd, cs_xxfd, port_7ffd_reg, port_1ffd_reg, cpu0_mreq_n, cpu0_m1_n, cpu0_wr_n, cpu0_do_bus, fd_port)
begin
	if reset = '1' then
		port_eff7_reg <= (others => '0');
		port_7ffd_reg <= (others => '0');
		port_dffd_reg <= (others => '0');
		port_1ffd_reg <= (others => '0');--(7 downto 2) <= (others => '0'); -- skip turbo / memlock bits on reset
		dos_act <= '1';
	elsif clk_bus'event and clk_bus = '1' then

		-- #FE
		if cs_xxfe = '1' and cpu0_wr_n = '0' then 
			port_xxfe_reg <= cpu0_do_bus; 
		end if;

		-- #EFF7
		if cs_eff7 = '1' and cpu0_wr_n = '0' then 
			port_eff7_reg <= cpu0_do_bus; 
		end if;
		
		-- #DFF7
		if cs_dff7 = '1' and cpu0_wr_n = '0' then 
			mc146818_a_bus <= cpu0_do_bus(5 downto 0); 
		end if;

		-- #1FFD
		if cs_1ffd = '1' and cpu0_wr_n = '0' then
			port_1ffd_reg <= cpu0_do_bus;
		end if;

		-- #DFFD
		if cs_dffd = '1' and cpu0_wr_n = '0' then
			port_dffd_reg <= cpu0_do_bus;
		end if;
		
		-- #7FFD
		if cs_7ffd = '1' and cpu0_wr_n = '0' and ram_ext_lock /= "11" then
			port_7ffd_reg <= cpu0_do_bus;
		-- #FD
		elsif cs_xxfd = '1' and cpu0_wr_n = '0' and ram_ext_lock /= "11" then -- short #FD
			port_7ffd_reg <= cpu0_do_bus;
		end if;
		
		-- TR-DOS FLAG
		if cpu0_m1_n = '0' and cpu0_mreq_n = '0' and cpu0_a_bus(15 downto 8) = X"3D" and port_7ffd_reg(4) = '1' then dos_act <= '1';
		elsif cpu0_m1_n = '0' and cpu0_mreq_n = '0' and cpu0_a_bus(15 downto 14) /= "00" then dos_act <= '0'; end if;
		
	end if;
end process;

------------------------------------------------------------------------------
-- RAM mux / ext

mux <= ((divmmc_amap or divmmc_e3reg(7)) and sd_mode) & cpu0_a_bus(15 downto 13);
ram_ext <= 
	port_dffd_reg(2 downto 0) & port_7ffd_reg(5) & port_7ffd_reg(6) & port_7ffd_reg(7) & port_1ffd_reg(7) & port_1ffd_reg(4) when ram_ext_lock(1) = '0'
	else "00000000";

process (mux, port_7ffd_reg, cpu0_a_bus, dos_act, ram_ext, divmmc_e3reg, sd_mode, port_1ffd_reg)
begin
	case mux is
		when "0000" => ram_a_bus <= "100001000" & ((not(dos_act) and not(port_1ffd_reg(1))) or sd_mode) & (port_7ffd_reg(4) and not(port_1ffd_reg(1))) & '0';	-- Seg0 ROM 0000-1FFF
		when "0001" => ram_a_bus <= "100001000" & ((not(dos_act) and not(port_1ffd_reg(1))) or sd_mode) & (port_7ffd_reg(4) and not(port_1ffd_reg(1))) & '1';	-- Seg0 ROM 2000-3FFF	
		when "1000" => ram_a_bus <= "100001001000";	-- ESXDOS ROM 0000-1FFF
		when "1001" => ram_a_bus <= "100000" & divmmc_e3reg(5 downto 0);	-- ESXDOS RAM 2000-3FFF		
		when "0010"|"1010" => ram_a_bus <= "000000001010";	-- Seg1 RAM 4000-5FFF
		when "0011"|"1011" => ram_a_bus <= "000000001011";	-- Seg1 RAM 6000-7FFF
		when "0100"|"1100" => ram_a_bus <= "000000000100";	-- Seg2 RAM 8000-9FFF
		when "0101"|"1101" => ram_a_bus <= "000000000101";	-- Seg2 RAM A000-BFFF
		when "0110"|"1110" => ram_a_bus <= ram_ext & port_7ffd_reg(2 downto 0) & '0';	-- Seg3 RAM C000-DFFF
		when "0111"|"1111" => ram_a_bus <= ram_ext & port_7ffd_reg(2 downto 0) & '1';	-- Seg3 RAM E000-FFFF		
		when others => null;
	end case;
end process;

ETH_NCS <= '1';

-------------------------------------------------------------------------------
-- Audio mixer

-- 16bit Delta-Sigma DAC
audio_l <= "0000000000000000" when loader_act = '1' else ("000" & port_xxfe_reg(4) & "000000000000") + ("000" & ssg_cn0_a & "00000") + ("000" & ssg_cn0_b & "00000") + ("000" & ssg_cn1_a & "00000") + ("000" & ssg_cn1_b & "00000") + ("000" & covox_a   & "00000") + ("000" & covox_b   & "00000") + ("000" & saa_out_l & "00000");
audio_r <= "0000000000000000" when loader_act = '1' else ("000" & port_xxfe_reg(4) & "000000000000") + ("000" & ssg_cn0_c & "00000") + ("000" & ssg_cn0_b & "00000") + ("000" & ssg_cn1_c & "00000") + ("000" & ssg_cn1_b & "00000") + ("000" & covox_c   & "00000") + ("000" & covox_d   & "00000") + ("000" & saa_out_r & "00000");

-- SAA1099
saa_wr_n <= '0' when (cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus(7 downto 0) = "11111111" and dos_act = '0') else '1';

-------------------------------------------------------------------------------
-- Port I/O

mc146818_wr 	<= '1' when (port_bff7 = '1' and cpu0_wr_n = '0') else '0';
port_bff7 	<= '1' when (cpu0_iorq_n = '0' and cpu0_a_bus = X"BFF7" and cpu0_m1_n = '1' and port_eff7_reg(7) = '1') else '0';
zc_wr 		<= '1' when (cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus(7 downto 6) = "01" and cpu0_a_bus(4 downto 0) = "10111") else '0';
zc_rd 		<= '1' when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(7 downto 6) = "01" and cpu0_a_bus(4 downto 0) = "10111") else '0';

-------------------------------------------------------------------------------
-- CPU0 Data bus

process (selector, host_ram_do, mc146818_do_bus, kb_do_bus, zc_do_bus, ssg_cn0_bus, ssg_cn1_bus, port_7ffd_reg, vid_attr, port_eff7_reg)
begin
	case selector is
		when x"00" => cpu0_di_bus <= host_ram_do;
		when x"01" => cpu0_di_bus <= mc146818_do_bus;
		when x"02" => cpu0_di_bus <= "111" & kb_do_bus;
		when x"03" => cpu0_di_bus <= zc_do_bus;
		when x"04" => cpu0_di_bus <= "000" & joy_bus;
		when x"05" => cpu0_di_bus <= ssg_cn0_bus;
		when x"06" => cpu0_di_bus <= ssg_cn1_bus;
		when x"07" => cpu0_di_bus <= port_1ffd_reg;
		when x"08" => cpu0_di_bus <= port_7ffd_reg;
--		when x"09" => cpu0_di_bus <= port_7ffd_reg;
		when x"0A" => cpu0_di_bus <= ms_z(3 downto 0) & '1' & not ms_b(2) & not ms_b(0) & not ms_b(1);
		when x"0B" => cpu0_di_bus <= ms_x;
		when x"0C" => cpu0_di_bus <= not(ms_y);
		when x"0D" => cpu0_di_bus <= divmmc_do;
		when x"0E" => cpu0_di_bus <= zxuno_addr_to_cpu;
		when x"0F" => cpu0_di_bus <= uart_do_bus;
--		when x"11" => cpu0_di_bus <= vid_attr;
		when others  => cpu0_di_bus <= (others => '1');
	end case;
end process;

selector <= 
			x"00" when (cpu0_mreq_n = '0' and cpu0_rd_n = '0') else 																									-- SDRAM
			x"01" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_m1_n = '1' and port_bff7 = '1' and port_eff7_reg(7) = '1') else 									-- MC146818A
			x"02" when (cs_xxfe = '1' and cpu0_rd_n = '0') else 													-- Keyboard, port #FE
			x"03" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_m1_n = '1' and cpu0_a_bus( 7 downto 6) = "01" and cpu0_a_bus(4 downto 0) = "10111") and sd_mode = '0' else 	-- Z-Controller
			x"04" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_m1_n = '1' and cpu0_a_bus( 7 downto 0) = X"1F" and dos_act = '0') else 							-- Joystick, port #1F
			x"05" when (cs_fffd = '1' and cpu0_rd_n = '0' and ssg_sel = '0') else -- TurboSound
			x"06" when (cs_fffd = '1' and cpu0_rd_n = '0' and ssg_sel = '1') else
			x"07" when (cs_1ffd = '1' and cpu0_rd_n = '0') else										-- port #1FFD
			x"08" when (cs_7ffd = '1' and cpu0_rd_n = '0') else										-- port #7FFD
--			x"09" when (cs_xxfd = '1' and cpu0_rd_n = '0') else 									-- port #FD
    		x"0A" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus = X"FADF") else										-- Mouse0 port key, z
		   x"0B" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus = X"FBDF") else										-- Mouse0 port x
		   x"0C" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus = X"FFDF") else										-- Mouse0 port y 
			x"0D" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"EB" and sd_mode = '1') else -- DivMMC
			x"0E" when zxuno_addr_oe_n = '0' else -- ZX UNO address 
			x"0F" when uart_oe_n = '0' else -- UART
--			x"10" when (cs_xxff = '1' and cpu0_rd_n = '0' and is_port_ff = '1') else 		-- port #FF (Timex)
--			x"11" when (cs_xxff = '1' and cpu0_rd_n = '0' and is_port_ff = '0') else 		-- port #FF (normal)
			(others => '1');

-------------------------------------------------------------------------------
-- Video

vid_wr	<= '1' when cpu0_mreq_n = '0' and cpu0_wr_n = '0' and ((ram_a_bus = "000000001010") or (ram_a_bus = "000000001110")) else '0'; 
vid_scr	<= '1' when (ram_a_bus = "000000001110") else '0';

vga_r <= host_vga_r;
vga_g <= host_vga_g;
vga_b <= host_vga_b;
vga_hsync <= host_vga_hs;
vga_vsync <= host_vga_vs;
vga_blank <= host_vga_sblank;	

-- border latch
process(clk_bus, ena_7mhz, port_xxfe_reg)
begin 
	if (clk_bus'event and clk_bus = '1') then 
		if (ena_7mhz = '1') then
			vid_border <= port_xxfe_reg(2 downto 0);
		end if;
	end if;
end process;

end rtl;
