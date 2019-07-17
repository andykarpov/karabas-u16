-------------------------------------------------------------------[29.07.2014]
-- u16-Speccy Version 0.9.2
-- DEVBOARD ReVerSE-U16
-------------------------------------------------------------------------------
-- V0.1	   12.02.2011  TOP          	: первая версия
-- V0.5    20.11.2011  gs           	: добавлен GS
-- V0.5.1  11.12.2011  TOP          	: cброс GS на клавише 'F10'
-- V0.5.2  14.12.2011  uart         	: добавлен модуль UART
-- V0.5.3  20.12.2011  gs           	: INT, CPU GS @ 84MHz
-- V0.6    16.12.2012  loader       	: ROM теперь считывается из M25P40
-- V0.7    29.05.2013  t80s         	: обновлен T80CPU
--                     gs           	: исправлена работа защелок bit7_flag, bit0_flag (синхронный процесс), частота 21МГц, добавленна громкость каналов
-- V0.8    21.07.2013  zcontroller  	: работа модуля ZC при key_f(9) on/off
--                     gs           	: исправлена работа int_n (синхронный процесс)
-- V0.8.1  23.07.2013  TOP          	: устранена ошибка переключения видео страниц в vid_wr (shurik-ua)
-- V0.8.2  24.07.2013  zcontroller  	: Clock 28МГц
-- V0.8.3  10.08.2013  io_ps2_mouse 	: ticksPerUsec * 3500000 в модулях io_ps2_mouse и io_ps2_keyboard
-- V0.8.4  01.09.2013  spi          	: независимая работа интерфейса от системной частоты
-- V0.8.5  07.09.2013  ay8910       	: YM2149 временно заменил на AY8910, был слышен шум после остановки проигрывания
-- V0.8.6  09.03.2014  sdram        	: изменения в контроллере SDRAM
--                     video        	: добавлена рамка, кнопка 'F7' = On/Off    
-- V0.8.7  27.03.2014  video        	: изменения видео режимов pentagon, spectrum
--                     divmmc       	: добавлен divMMC (8K ROM + 512K RAM)
--                     TOP          	: изменен селектор данных CPU на MUX
-- V0.8.8  01.04.2014  divmmc       	: исправление в переключении после чтения опкода (shurik-ua)
--                     sdram        	: добавлены защелки RD, WR, RFSH для предотвращения повторного захвата запросов
--                     TOP          	: добавлено чтение из портов 7FFD и DFFD. Кнопка 'F3' = 3.5MHz/7.0MHz, 'F9' = 7.0MHz/14.0MHz
-------------------------------------------------------------------------------
-- V0.9.0  14.07.2014  TOP       	: перенос на плату ReVerSE-U16. Добавлены модули hdmi.vhd, serializer.vhd, encoder.vhd
--                     video       	: добавлен сигнал BLANK                    
-- V0.9.2  29.07.2014  dac       	: добавлен Delta-Sigma DAC
-- V0.9.3  09.08.2014  TOP		: добавлен ENC424J600

-- http://zx.pk.ru/showthread.php?t=13875

-- Copyright (c) 2011-2014 MVV
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
-- 0 00xx_xxxx xxxx_xxxx xxxx_xxxx	0000000-03FFFFF		RAM 	4MB
-- 0 xxxx_xxxx xxxx_xxxx xxxx_xxxx	0400000-0FFFFFF		-----------
-- 1 0000_0xxx xxxx_xxxx xxxx_xxxx	1000000-107FFFF		divMMC 512K
-- 1 0000_1000 00xx_xxxx xxxx_xxxx	1080000-1003FFF		GLUK	16K
-- 1 0000_1000 01xx_xxxx xxxx_xxxx	1084000-1007FFF		TR-DOS	16K
-- 1 0000_1000 10xx_xxxx xxxx_xxxx	1088000-100BFFF		ROM'86	16K
-- 1 0000_1000 11xx_xxxx xxxx_xxxx	108C000-100FFFF		ROM'82	16K
-- 1 0000_1001 000x_xxxx xxxx_xxxx	1090000-1091FFF		divMMC	 8K


-- FLASH 2048K:
-- 00000-5FFFF		Конфигурация Cyclone EP3C10
-- 60000-63FFF		General Sound ROM	16K  ОТКЛЮЧЕНО
-- 64000-67FFF		General Sound ROM	16K  ОТКЛЮЧЕНО
-- 68000-6BFFF		GLUK 			16K
-- 6C000-6FFFF		TR-DOS 			16K
-- 70000-73FFF		OS'86 			16K
-- 74000-77FFF		OS'82 			16K
-- 78000-7AFFF		DivMMC			 8K
-- 7B000-7BFFF		свободно		 8К
-- 7C000-7FFFF		свободно		16К

entity speccy is
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

	-- SPI FLASH (M25P16)
	DATA0		: in std_logic;
	NCSO		: out std_logic;
	DCLK		: out std_logic;
	ASDO		: out std_logic;

	-- SPI (ENC424J600)
	ETH_SO		: in std_logic;
	ETH_NINT	: in std_logic;
	ETH_NCS		: out std_logic;

	-- HDMI
	TMDS	: out std_logic_vector(7 downto 0);

	-- External I/O
	OUT_L	: out std_logic;
	OUT_R	: out std_logic;
	
	-- SD/MMC Card
	SD_SO		: in std_logic;
	SD_SI		: out std_logic;
	SD_CLK		: out std_logic;
	SD_NCS		: out std_logic;
	
	-- USB
	USB_NRESET              : in std_logic;
	USB_TX                  : in std_logic;
	USB_IO1                 : in std_logic
);
end speccy;

architecture rtl of speccy is

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
signal port_xxfe_reg	: std_logic_vector(7 downto 0) := "00000000";
signal port_1ffd_reg	: std_logic_vector(7 downto 0);
signal port_7ffd_reg	: std_logic_vector(7 downto 0);
signal port_dffd_reg	: std_logic_vector(7 downto 0);
signal port_0000_reg	: std_logic_vector(7 downto 0) := "00000000";
signal port_0001_reg	: std_logic_vector(7 downto 0) := "00000000";
-- PS/2 Keyboard
signal kb_do_bus	: std_logic_vector(4 downto 0);
signal kb_f_bus		: std_logic_vector(12 downto 1);
signal kb_joy_bus	: std_logic_vector(4 downto 0);
--signal kb_num		: std_logic := '1';
-- PS/2 Mouse
signal ms_but_bus	: std_logic_vector(7 downto 0);
signal ms_present	: std_logic;
signal ms_left		: std_logic;
signal ms_x_bus		: std_logic_vector(7 downto 0);
signal ms_y_bus		: std_logic_vector(7 downto 0);
signal ms_clk_out	: std_logic;
signal ms_buf_out	: std_logic;
-- Video
signal vid_a_bus	: std_logic_vector(12 downto 0);
signal vid_di_bus	: std_logic_vector(7 downto 0);
signal vid_wr		: std_logic;
signal vid_scr		: std_logic;
signal vid_hsync	: std_logic;
signal vid_vsync	: std_logic;
signal vid_hcnt		: std_logic_vector(8 downto 0);
signal vid_int		: std_logic;
--signal vid_border	: std_logic;
signal vid_attr	: std_logic_vector(7 downto 0);
--signal vid_blank	: std_logic;
signal rgb		: std_logic_vector(5 downto 0);

signal vga_hsync	: std_logic;
signal vga_vsync	: std_logic;
signal vga_blank	: std_logic;
-- Z-Controller
signal zc_do_bus	: std_logic_vector(7 downto 0);
signal zc_rd		: std_logic;
signal zc_wr		: std_logic;
signal zc_cs_n		: std_logic;
signal zc_sclk		: std_logic;
signal zc_mosi		: std_logic;
signal zc_miso		: std_logic;
-- SPI
signal spi_si		: std_logic;
signal spi_so		: std_logic;
signal spi_clk		: std_logic;
signal spi_wr		: std_logic;
signal spi_cs_n		: std_logic;
signal spi_do_bus	: std_logic_vector(7 downto 0);
signal spi_busy		: std_logic;
-- PCF8583
signal rtc_do_bus	: std_logic_vector(7 downto 0);
signal rtc_wr		: std_logic;
-- MC146818A
signal mc146818_wr	: std_logic;
signal mc146818_a_bus	: std_logic_vector(5 downto 0);
signal mc146818_do_bus	: std_logic_vector(7 downto 0);
signal mc146818_busy		: std_logic;
signal port_bff7	: std_logic;
signal port_eff7_reg	: std_logic_vector(7 downto 0);
-- TDA1543
signal dac_data		: std_logic;
signal dac_ws		: std_logic;
-- SDRAM
signal sdr_do_bus	: std_logic_vector(7 downto 0);
signal sdr_wr		: std_logic;
signal sdr_rd		: std_logic;
signal sdr_rfsh		: std_logic;
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
signal dac_s_l		: std_logic_vector(15 downto 0);
signal dac_s_r		: std_logic_vector(15 downto 0);
signal sound		: std_logic_vector(7 downto 0);
-- Soundrive
signal covox_a		: std_logic_vector(7 downto 0);
signal covox_b		: std_logic_vector(7 downto 0);
signal covox_c		: std_logic_vector(7 downto 0);
signal covox_d		: std_logic_vector(7 downto 0);
-- General Sound
signal gs_a		: std_logic_vector(13 downto 0) := "00000000000000";
signal gs_b		: std_logic_vector(13 downto 0) := "00000000000000";
signal gs_c		: std_logic_vector(13 downto 0) := "00000000000000";
signal gs_d		: std_logic_vector(13 downto 0) := "00000000000000";
signal gs_do_bus	: std_logic_vector(7 downto 0);
signal gs_mdo		: std_logic_vector(7 downto 0);
signal gs_ma		: std_logic_vector(18 downto 0);
signal gs_mwe_n		: std_logic := '1';
-- UART
signal uart_do_bus	: std_logic_vector(7 downto 0);
signal uart_wr		: std_logic;
signal uart_rd		: std_logic;
signal uart_tx_busy	: std_logic;
signal uart_rx_avail	: std_logic;
signal uart_rx_error	: std_logic;
-- CLOCK
signal clk_bus		: std_logic;
signal clk_sdr		: std_logic;
signal clk_interface	: std_logic;
signal clk_codec	: std_logic;
signal clk_hdmi		: std_logic;
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
signal key_reset	: std_logic;
signal locked		: std_logic;
signal loader_act	: std_logic := '1';
signal loader_act_reg : std_logic := '1';
signal dos_act		: std_logic := '1';
signal cpuclk		: std_logic;
signal selector		: std_logic_vector(4 downto 0);
signal key_f		: std_logic_vector(12 downto 1);
signal key		: std_logic_vector(12 downto 1) := "000100000000";
-- CNTR
signal cntr_rgb		: std_logic_vector(5 downto 0);
signal cntr_hs		: std_logic;
signal cntr_vs		: std_logic;
signal cntr_rd		: std_logic;
signal cntr_io_flag	: std_logic;
signal cntr_addr_reg	: std_logic_vector(15 downto 0);
signal cntr_data_reg	: std_logic_vector(7 downto 0);
-- divmmc
--signal divmmc_do	: std_logic_vector(7 downto 0);
--signal divmmc_amap	: std_logic;
--signal divmmc_e3reg	: std_logic_vector(7 downto 0);	
--signal divmmc_cs_n	: std_logic;
--signal divmmc_sclk	: std_logic;
--signal divmmc_mosi	: std_logic;
signal mux		: std_logic_vector(3 downto 0);

signal VideoR		: std_logic_vector(1 downto 0);
signal VideoG		: std_logic_vector(1 downto 0);
signal VideoB		: std_logic_vector(1 downto 0);
signal Hsync		: std_logic;
signal Vsync		: std_logic;
signal Sblank		: std_logic;
signal clk7		: std_logic;
signal clk14		: std_logic;

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

-- PLL
U0: entity work.altpll0
port map (
	areset		=> areset,
	inclk0		=> CLK_50MHZ,	--  50.0 MHz
	locked		=> locked,
	c0		=> clk_bus,	--  28.0 MHz
	c1		=> clk7,	--clk_codec,		--   9.2 MHz
	c2		=> clk14,	--clk_interface,	--  21.0 MHz
	c3		=> clk_sdr,	--  84.0 MHz
	c4		=> clk_hdmi);	-- 140.0 MHz
	
-- Zilog Z80A CPU
U1: z80_top_direct_n
port map(
	nRESET		=> cpu0_reset_n,
	CLK		=> cpuclk,
	nWAIT		=> '1',
	nINT		=> cpu0_int_n,
	nNMI		=> cpu0_nmi_n,
	nBUSRQ		=> '1',
	nM1		=> cpu0_m1_n,
	nMREQ		=> cpu0_mreq_n,
	nIORQ		=> cpu0_iorq_n,
	nRD		=> cpu0_rd_n,
	nWR		=> cpu0_wr_n,
	nRFSH		=> cpu0_rfsh_n,
	nHALT		=> open,
	nBUSACK		=> open,
	A		=> cpu0_a_bus,
	D		=> cpu0_d_bus
);

cpu0_d_bus <= cpu0_di_bus when selector /= "11111" else (others => 'Z');
cpu0_do_bus <= cpu0_d_bus when selector = "11111" else (others => '1');

-- Video Spectrum/Pentagon
U2: entity work.video
port map (
	CLK		=> clk_bus,
	ENA		=> ena_7mhz,

	INT		=> cpu0_int_n,
	BORDER		=> port_xxfe_reg(2 downto 0),	-- Биты D0..D2 порта xxFE определяют цвет бордюра
	ATTR_O		=> vid_attr,
	A		=> vid_a_bus,
	DI		=> vid_di_bus,
	BLANK => open,
	RGB		=> rgb,
	HSYNC		=> vid_hsync,
	VSYNC		=> vid_vsync);
	
-- Video memory
U3: entity work.altram1
port map (
	clock_a		=> clk_bus,
	clock_b		=> clk_bus,
	address_a	=> vid_scr & cpu0_a_bus(12 downto 0),
	address_b	=> port_7ffd_reg(3) & vid_a_bus,
	data_a		=> cpu0_do_bus,
	data_b		=> "11111111",
	q_a		=> open,
	q_b		=> vid_di_bus,
	wren_a		=> vid_wr,
	wren_b		=> '0');

-- USB HID
U4: entity work.deserializer
generic map (
	divisor			=> 434)		-- divisor = 50MHz / 115200 Baud = 434
port map(
	I_CLK			=> CLK_50MHZ,
	I_RESET			=> areset,
	I_RX			=> USB_TX,
	I_NEWFRAME		=> USB_IO1,
	I_ADDR			=> cpu0_a_bus(15 downto 8),
	O_MOUSE0_X		=> open, --ms_x_bus,
	O_MOUSE0_Y		=> open, --ms_y_bus,
	O_MOUSE0_Z		=> open, --ms_z_bus,
	O_MOUSE0_BUTTONS	=> open, --ms_but_bus,
	O_MOUSE1_X		=> open,
	O_MOUSE1_Y		=> open,
	O_MOUSE1_Z		=> open,
	O_MOUSE1_BUTTONS	=> open,
	O_KEY0			=> open,--kb_key0,
	O_KEY1			=> open,--kb_key1,
	O_KEY2			=> open,--kb_key2,
	O_KEY3			=> open,--kb_key3,
	O_KEY4			=> open,--kb_key4,
	O_KEY5			=> open,--kb_key5,
	O_KEY6			=> open,--kb_key6,
	O_KEYBOARD_SCAN		=> kb_do_bus,
	O_KEYBOARD_FKEYS	=> kb_f_bus,
	O_KEYBOARD_JOYKEYS	=> kb_joy_bus,
	O_KEYBOARD_CTLKEYS	=> open);	
	
key_reset <= kb_f_bus(4);
	
-- ROM 1K
U6: entity work.altram0
port map (
	clock_a		=> clk_bus,
	clock_b		=> clk_bus,
--	address_a	=> cpu0_a_bus(9 downto 0),
	address_a	=> cpu0_a_bus(12 downto 0),
	address_b	=> "0000000000000",
	data_a	 	=> cpu0_do_bus,
	data_b	 	=> "00000000",
	q_a	 	=> rom_do_bus,
	q_b	 	=> open,
	wren_a	 	=> '0',
	wren_b	 	=> '0');
	
-- Z-Controller
U7: entity work.zcontroller
port map (
	RESET		=> reset,
	CLK		=> clk_bus,
	A		=> cpu0_a_bus(5),
	DI		=> cpu0_do_bus,
	DO		=> zc_do_bus,
	RD		=> zc_rd,
	WR		=> zc_wr,
	SDDET		=> '0', --SD_NDET,
	SDPROT		=> '0',
	CS_n		=> zc_cs_n,
	SCLK		=> zc_sclk,
	MOSI		=> zc_mosi,
	MISO		=> SD_SO);
	
-- SPI FLASH 25MHz Max SCK -- Ethernet ENC424J600

U8: entity work.spi
port map (
	RESET		=> reset,
	CLK		=> clk_bus,
	SCK		=> clk14,	--clk_interface,
	A		=> cpu0_a_bus(0),
	DI		=> cpu0_do_bus,
	DO		=> spi_do_bus,
	WR		=> spi_wr,
	BUSY		=> spi_busy,
	CS_n		=> spi_cs_n,
	SCLK		=> spi_clk,
	MOSI		=> spi_si,
	MISO		=> spi_so);

-- TurboSound
U9: entity work.turbosound
port map (
	RESET		=> reset,
	CLK		=> clk_bus,
	ENA		=> ena_1_75mhz,
	A		=> cpu0_a_bus,
	DI		=> cpu0_do_bus,
	WR_n		=> cpu0_wr_n,
	IORQ_n		=> cpu0_iorq_n,
	M1_n		=> cpu0_m1_n,
	SEL		=> ssg_sel,
	CN0_DO		=> ssg_cn0_bus,
	CN0_A		=> ssg_cn0_a,
	CN0_B		=> ssg_cn0_b,
	CN0_C		=> ssg_cn0_c,
	CN1_DO		=> ssg_cn1_bus,
	CN1_A		=> ssg_cn1_a,
	CN1_B		=> ssg_cn1_b,
	CN1_C		=> ssg_cn1_c);

-- SDRAM Controller
U11: entity work.sdram
port map (
	CLK		=> clk_sdr,
	A		=> ram_a_bus & cpu0_a_bus(12 downto 0),
	DI		=> cpu0_do_bus,
	DO		=> sdr_do_bus,
	WR		=> sdr_wr,
	RD		=> sdr_rd,
	RFSH		=> sdr_rfsh,
	RFSHREQ		=> open,
	IDLE		=> open,
	CK		=> SDRAM_CLK,
	RAS_n		=> SDRAM_NRAS,
	CAS_n		=> SDRAM_NCAS,
	WE_n		=> SDRAM_NWE,
	DQML		=> SDRAM_DQML,
	DQMH		=> SDRAM_DQMH,
	BA		=> SDRAM_BA,
	MA		=> SDRAM_A,
	DQ		=> SDRAM_DQ);

-- I2C Controller
--U12: entity work.i2c
--port map (
--	RESET		=> reset,
--	CLK		=> clk_bus,
--	ENA		=> ena_0_4375mhz,
--	A		=> cpu0_a_bus(4),
--	DI		=> cpu0_do_bus,
--	DO		=> rtc_do_bus,
--	WR		=> rtc_wr,
--	I2C_SCL		=> I2C_SCL,
--	I2C_SDA		=> I2C_SDA);

-- MC146818A
U13: entity work.mc146818a
port map (
	RESET		=> reset,
	CLK		=> clk_bus,
	ENA		=> ena_0_4375mhz,
	CS		=> '1',
	WR		=> mc146818_wr,
	A		=> mc146818_a_bus,
	DI		=> cpu0_do_bus,
	DO		=> mc146818_do_bus,
	I2C_SDA 	=> I2C_SDA,
	I2C_SCL  => I2C_SCL,
	BUSY 		=> mc146818_busy
);

-- Soundrive
U14: entity work.soundrive
port map (
	RESET		=> reset,
	CLK		=> clk_bus,
	CS		=> key_f(11),
	WR_n		=> cpu0_wr_n,
	A		=> cpu0_a_bus(7 downto 0),
	DI		=> cpu0_do_bus,
	IORQ_n		=> cpu0_iorq_n,
	DOS		=> dos_act,
	OUTA		=> covox_a,
	OUTB		=> covox_b,
	OUTC		=> covox_c,
	OUTD		=> covox_d);

-- General Sound
--U15: entity work.gs
--port map (
--	RESET		=> not port_0001_reg(2) or kb_f_bus(10) or areset,	-- клавиша [F10] reset GS
--	CLK		=> clk_bus,
--	CLKGS		=> clk_interface,
--	A		=> cpu0_a_bus,
--	DI		=> cpu0_do_bus,
--	DO		=> gs_do_bus,
--	WR_n		=> cpu0_wr_n,
--	RD_n		=> cpu0_rd_n,
--	IORQ_n		=> cpu0_iorq_n,
--	M1_n		=> cpu0_m1_n,
--	OUTA		=> gs_a,
--	OUTB		=> gs_b,
--	OUTC		=> gs_c,
--	OUTD		=> gs_d,
--	MA		=> gs_ma,
--	MDI		=> SRAM_D,
--	MDO		=> gs_mdo,
--	MWE_n		=> gs_mwe_n);

-- UART
--U16: entity work.uart
--generic map (
--	-- divisor = 28MHz / 115200 Baud = 243
--	divisor		=> 243)
--port map (
--	CLK		=> clk_bus,
--	RESET		=> reset,
--	WR		=> uart_wr,
--	RD		=> uart_rd,
--	DI		=> cpu0_do_bus,
--	DO		=> uart_do_bus,
--	TXBUSY		=> uart_tx_busy,
--	RXAVAIL		=> uart_rx_avail,
--	RXERROR		=> uart_rx_error,
--	RXD		=> TXD,
--	TXD		=> RXD);

-- divmmc interface
--U18: entity work.divmmc
--port map (
--	CLK		=> clk_bus,
--	EN		=> key_f(6),
--	RESET		=> reset,
--	ADDR		=> cpu0_a_bus,
--	DI		=> cpu0_do_bus,
--	DO		=> divmmc_do,
--	WR_N		=> cpu0_wr_n,
--	RD_N		=> cpu0_rd_n,
--	IORQ_N		=> cpu0_iorq_n,
--	MREQ_N		=> cpu0_mreq_n,
--	M1_N		=> cpu0_m1_n,
--	E3REG		=> divmmc_e3reg,
--	AMAP		=> divmmc_amap,
--	CS_N		=> divmmc_cs_n,
--	SCLK		=> divmmc_sclk,
--	MOSI		=> divmmc_mosi,
--	MISO		=> SD_SO);

-- Delta-Sigma
U19: entity work.dac
port map (
    CLK   		=> clk_sdr,
    RESET 		=> areset,
    DAC_DATA		=> dac_s_l,
    DAC_OUT   		=> OUT_L);

-- Delta-Sigma
U20: entity work.dac
port map (
    CLK   		=> clk_sdr,
    RESET 		=> areset,
    DAC_DATA		=> dac_s_r,
    DAC_OUT   		=> OUT_R);

-------------------------------------------------------------------------------
-- Формирование глобальных сигналов
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

areset <= not USB_NRESET;				-- глобальный сброс
reset <= areset or key_reset or not locked;		-- горячий сброс

cpu0_reset_n <= not(reset) and not(kb_f_bus(4));	-- CPU сброс
cpu0_inta_n <= cpu0_iorq_n or cpu0_m1_n;		-- INTA
cpu0_nmi_n <= not kb_f_bus(5);				-- NMI

-------------------------------------------------------------------------------
-- SDRAM
--sdr_wr <= '1' when cpu0_mreq_n = '0' and cpu0_wr_n = '0' and ((mux = "1001" and (divmmc_e3reg(1 downto 0) /= "11" and divmmc_e3reg(6) /= '1')) or mux(3 downto 2) = "11" or mux(3 downto 2) = "01" or mux(3 downto 1) = "101" or mux(3 downto 1) = "001") else '0';
--sdr_wr <= '1' when cpu0_mreq_n = '0' and cpu0_wr_n = '0' and (mux = "1001" or mux(3 downto 2) = "11" or mux(3 downto 2) = "01" or mux(3 downto 1) = "101" or mux(3 downto 1) = "001") else '0';
sdr_wr <= '1' when cpu0_mreq_n = '0' and cpu0_wr_n = '0' and (mux(3 downto 2) = "01" or mux(3 downto 1) = "001") else '0';
sdr_rd <= not (cpu0_mreq_n or cpu0_rd_n);
sdr_rfsh <= not cpu0_rfsh_n;

-------------------------------------------------------------------------------
-- Делитель
cpuclk <= clk_bus and cpu0_ena;
cpu0_mult <= "00"; -- key_f(9) & key_f(3);	-- 00 = 3.5MHz; 01 = 7.0MHz; 10 = 7MHz; 11 = 14MHz
process (cpu0_mult, ena_3_5mhz, ena_7mhz, ena_14mhz)
begin
	case cpu0_mult is
		when "00" => cpu0_ena <= ena_3_5mhz;
		when "01" => cpu0_ena <= ena_7mhz;
		when "10" => cpu0_ena <= ena_7mhz;
		when "11" => cpu0_ena <= ena_14mhz;
		when others => null;
	end case;
end process;

-------------------------------------------------------------------------------
-- SD					
SD_NCS	<= zc_cs_n;
SD_CLK 	<= zc_sclk;
SD_SI 	<= zc_mosi;

-------------------------------------------------------------------------------
-- Регистры
process (areset, clk_bus, cpu0_a_bus, port_0000_reg, cpu0_mreq_n, cpu0_wr_n, cpu0_do_bus, port_0001_reg)
begin
	if areset = '1' then
		port_0000_reg <= (others => '0');	-- маска по AND порта #DFFD
		port_0001_reg <= (others => '0');	-- bit2 = (0:Loader ON, 1:Loader OFF); bit1 = (0:SRAM<->CPU0, 1:SRAM<->GS); bit0 = (0:M25P16, 1:ENC424J600)
		loader_act <= '1';
	elsif clk_bus'event and clk_bus = '1' then
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"0000" and loader_act_reg = '1' then port_0000_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"0001" and loader_act_reg = '1' then port_0001_reg <= cpu0_do_bus; end if;
		if cpu0_m1_n = '0' and cpu0_mreq_n = '0' and cpu0_a_bus = X"0000" and port_0001_reg(2) = '1' and loader_act_reg = '1' then loader_act <= '0'; end if;
	end if;
end process;

process (areset, clk_bus, loader_act)
begin
	if areset = '1' then
		loader_act_reg <= '1';
	elsif clk_bus'event and clk_bus = '1' then
		if loader_act = '0' then 
			loader_act_reg <= '0';
		end if;
	end if;
end process;

process (reset, clk_bus, cpu0_a_bus, dos_act, port_1ffd_reg, port_7ffd_reg, port_dffd_reg, cpu0_mreq_n, cpu0_wr_n, cpu0_do_bus)
begin
	if reset = '1' then
		port_eff7_reg <= (others => '0');
		port_1ffd_reg <= (others => '0');
		port_7ffd_reg <= (others => '0');
		port_dffd_reg <= (others => '0');
		dos_act <= '1';
	elsif clk_bus'event and clk_bus = '1' then
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus(7 downto 0) = X"FE" then port_xxfe_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"EFF7" then port_eff7_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"1FFD" then port_1ffd_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"7FFD" and port_7ffd_reg(5) = '0' then port_7ffd_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"DFFD" and port_7ffd_reg(5) = '0' then port_dffd_reg <= cpu0_do_bus; end if;
		if cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus = X"DFF7" and port_eff7_reg(7) = '1' then mc146818_a_bus <= cpu0_do_bus(5 downto 0); end if;
		if cpu0_m1_n = '0' and cpu0_mreq_n = '0' and cpu0_a_bus(15 downto 8) = X"3D" and port_7ffd_reg(4) = '1' then dos_act <= '1';
		elsif cpu0_m1_n = '0' and cpu0_mreq_n = '0' and cpu0_a_bus(15 downto 14) /= "00" then dos_act <= '0'; end if;
	end if;
end process;

------------------------------------------------------------------------------
-- Селектор
mux <= '0' & cpu0_a_bus(15 downto 13);

-- ram_a_bus:
-- 4 3210 9876 5432 1098 7654 3210
-- 0 00xx_xxxx xxxx_xxxx xxxx_xxxx	0000000-03FFFFF		RAM 	4MB
-- 0 xxxx_xxxx xxxx_xxxx xxxx_xxxx	0400000-0FFFFFF		-----------
-- 1 0000_0xxx xxxx_xxxx xxxx_xxxx	1000000-107FFFF		divMMC 512K
-- 1 0000_1000 00xx_xxxx xxxx_xxxx	1080000-1003FFF		GLUK	16K
-- 1 0000_1000 01xx_xxxx xxxx_xxxx	1084000-1007FFF		TR-DOS	16K
-- 1 0000_1000 10xx_xxxx xxxx_xxxx	1088000-100BFFF		ROM'86	16K
-- 1 0000_1000 11xx_xxxx xxxx_xxxx	108C000-100FFFF		ROM'82	16K

-- todo: блокировку памяти >128Кб. Управляется через бит D1 порта #1FFD, как и в P1024.
-- переписать менеджер памяти под стандарт пентагона или кая
-- переделать лоадер соотв (или вынести его вообще в отдельный модуль)

process (mux, port_7ffd_reg, port_dffd_reg, port_0000_reg, ram_a_bus, cpu0_a_bus, dos_act, port_1ffd_reg, loader_act_reg)
begin
	case mux is
		when "0000" => ram_a_bus <= "100001000" & (not(dos_act) and not(port_1ffd_reg(1))) & (port_7ffd_reg(4) and not(port_1ffd_reg(1))) & '0';	-- Seg0 ROM 0000-1FFF
		when "0001" => ram_a_bus <= "100001000" & (not(dos_act) and not(port_1ffd_reg(1))) & (port_7ffd_reg(4) and not(port_1ffd_reg(1))) & '1';	-- Seg0 ROM 2000-3FFF
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
-- ENC424J600 <> MP25P16
process (port_0001_reg, spi_si, spi_so, spi_clk, spi_cs_n)
begin
	if port_0001_reg(0) = '1' then
		NCSO <= '1';
		spi_so <= ETH_SO;
		ETH_NCS <= spi_cs_n;
	else
		NCSO <= spi_cs_n;
		spi_so <= DATA0;
		ETH_NCS <= '1';
	end if;
end process;

ASDO <= spi_si;
DCLK <= spi_clk;


-------------------------------------------------------------------------------
-- Audio mixer

-- 16bit Delta-Sigma DAC
audio_l <= (others => '0') when loader_act = '1' else ("00000000" & port_xxfe_reg(4) & "0000000") + ("00000000" & ssg_cn0_a) + ("00000000" & ssg_cn0_b) + ("00000000" & ssg_cn1_a) + ("00000000" & ssg_cn1_b) + ("00000000" & covox_a) + ("00000000" & covox_b);
audio_r <= (others => '0') when loader_act = '1' else ("00000000" & port_xxfe_reg(4) & "0000000") + ("00000000" & ssg_cn0_c) + ("00000000" & ssg_cn0_b) + ("00000000" & ssg_cn1_c) + ("00000000" & ssg_cn1_b) + ("00000000" & covox_c) + ("00000000" & covox_d);

-- Convert signed audio data (range 127 to -128) to simple unsigned value.
dac_s_l <= std_logic_vector(unsigned(audio_l + 2048));
dac_s_r <= std_logic_vector(unsigned(audio_r + 2048));

-------------------------------------------------------------------------------
-- Port I/O
rtc_wr		<= '1' when (cpu0_a_bus(7 downto 5) = "100" and cpu0_a_bus(3 downto 0) = "1100" and cpu0_wr_n = '0' and cpu0_iorq_n = '0') else '0';	-- Port xx8C/xx9C[xxxxxxxx_100n1100]
mc146818_wr 	<= '1' when (port_bff7 = '1' and cpu0_wr_n = '0') else '0';
port_bff7 	<= '1' when (cpu0_iorq_n = '0' and cpu0_a_bus = X"BFF7" and cpu0_m1_n = '1' and port_eff7_reg(7) = '1') else '0';
spi_wr 		<= '1' when (cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus(7 downto 1) = "0000001") else '0';
--uart_wr 	<= '1' when (cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus(7 downto 0) = X"BC") else '0';	-- Port xxBC[xxxxxxxx_10111100]
--uart_rd 	<= '1' when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(7 downto 0) = X"BC") else '0';	-- Port xxBC[xxxxxxxx_10111100]
--ms_left 	<= not(ms_left) when (ms_but_bus(1)'event and ms_but_bus(1) = '1' and ms_but_bus(0) = '1');
zc_wr 		<= '1' when (cpu0_iorq_n = '0' and cpu0_wr_n = '0' and cpu0_a_bus(7 downto 6) = "01" and cpu0_a_bus(4 downto 0) = "10111") else '0';
zc_rd 		<= '1' when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(7 downto 6) = "01" and cpu0_a_bus(4 downto 0) = "10111") else '0';


-------------------------------------------------------------------------------
-- Функциональные клавиши Fx

-- F4 = CPU RESET, F5 = NMI, F11 = soundrive
process (clk_bus, key, kb_f_bus, key_f)
begin
	if (clk_bus'event and clk_bus = '1') then
		key <= kb_f_bus;
		if (kb_f_bus /= key) then
			key_f <= key_f xor key;
		end if;
	end if;
end process;

-------------------------------------------------------------------------------
-- Шина данных CPU0
process (selector, rom_do_bus, sdr_do_bus, spi_do_bus, spi_busy, rtc_do_bus, mc146818_do_bus, kb_do_bus, zc_do_bus, ms_but_bus, ms_x_bus, ms_y_bus, kb_joy_bus, ssg_cn0_bus, ssg_cn1_bus, uart_tx_busy, uart_rx_error,
		 uart_rx_avail, uart_do_bus, gs_do_bus, port_7ffd_reg, port_dffd_reg, vid_attr)
begin
	case selector is
		when "00000" => cpu0_di_bus <= rom_do_bus;
--		when "00001" => cpu0_di_bus <= SRAM_D;
		when "00010" => cpu0_di_bus <= sdr_do_bus;
		when "00011" => cpu0_di_bus <= spi_do_bus;
		when "00100" => cpu0_di_bus <= spi_busy & "1111111";
--		when "00101" => cpu0_di_bus <= rtc_do_bus;
		when "00110" => cpu0_di_bus <= mc146818_do_bus;
		when "00111" => cpu0_di_bus <= "111" & kb_do_bus;
		when "01000" => cpu0_di_bus <= zc_do_bus;
--		when "01001" => cpu0_di_bus <= ms_but_bus(7 downto 4) & '1' & not(ms_but_bus(2) & ms_but_bus(0) & ms_but_bus(1));
--		when "01010" => cpu0_di_bus <= ms_but_bus(7 downto 4) & '1' & not(ms_but_bus(2) & ms_but_bus(1) & ms_but_bus(0));
--		when "01011" => cpu0_di_bus <= ms_x_bus;
--		when "01100" => cpu0_di_bus <= ms_y_bus;
		when "01101" => cpu0_di_bus <= "000" & kb_joy_bus;
		when "01110" => cpu0_di_bus <= ssg_cn0_bus;
		when "01111" => cpu0_di_bus <= ssg_cn1_bus;
--		when "10000" => cpu0_di_bus <= uart_tx_busy & CBUS4 & "1111" & uart_rx_error & uart_rx_avail;
--		when "10001" => cpu0_di_bus <= uart_do_bus;
--		when "10010" => cpu0_di_bus <= gs_do_bus;
--		when "10011" => cpu0_di_bus <= divmmc_do;
		when "10100" => cpu0_di_bus <= port_7ffd_reg;
		when "10101" => cpu0_di_bus <= port_dffd_reg;
		when "10110" => cpu0_di_bus <= vid_attr;
		when others  => cpu0_di_bus <= (others => '1');
	end case;
end process;

selector <= "00000" when (cpu0_mreq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 14) = "00" and loader_act = '1') else
--			"00001" when (cpu0_mreq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15) = '1' and port_0001_reg(2) = '0') else
			"00010" when (cpu0_mreq_n = '0' and cpu0_rd_n = '0') else 																				-- SDRAM
			"00011" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"02" and loader_act_reg = '1') else 						-- M25P16
			"00100" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"03" and loader_act_reg = '1') else 						-- M25P16
--			"00101" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 5) = "100" and cpu0_a_bus(3 downto 0) = "1100") else 	-- RTC
			"00110" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and port_bff7 = '1' and port_eff7_reg(7) = '1') else 				-- MC146818A
			"00111" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"FE") else 						-- Клавиатура, порт xxFE
			"01000" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 6) = "01" and cpu0_a_bus(4 downto 0) = "10111") else 	-- Z-Controller
--			"01001" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 0) = X"FADF" and ms_present = '1' and ms_left = '0') else 	-- Mouse Port FADF[11111010_11011111] = <Z>1<MB><LB><RB>
--			"01010" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 0) = X"FADF" and ms_present = '1' and ms_left = '1') else
--			"01011" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 0) = X"FBDF" and ms_present = '1') else			-- Port FBDF[11111011_11011111] = <X>
--			"01100" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 0) = X"FFDF" and ms_present = '1') else			-- Port FFDF[11111111_11011111] = <Y>
--			"01101" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"1F" and dos_act = '0' and kb_num = '1') else 	-- Joystick, порт xx1F
			"01101" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"1F" and dos_act = '0') else 			-- Joystick, порт xx1F
			"01110" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 0) = X"FFFD" and ssg_sel = '0') else 			-- TurboSound
			"01111" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 0) = X"FFFD" and ssg_sel = '1') else
--			"10000" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"AC") else						-- UART
--			"10001" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"BC") else
--			"10010" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 4) = "1011" and cpu0_a_bus(2 downto 0) = "011") else	-- General Sound
--			"10011" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"EB" and key_f(6) = '1') else			-- DivMMC
			"10100" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 0) = X"7FFD") else						-- чтение порта 7FFD
			"10101" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus(15 downto 0) = X"DFFD") else						-- чтение порта DFFD
			"10110" when (cpu0_iorq_n = '0' and cpu0_rd_n = '0' and cpu0_a_bus( 7 downto 0) = X"FF") else			-- порт атрибутов #FF
			(others => '1');

-------------------------------------------------------------------------------
-- Video
vid_wr	<= '1' when cpu0_mreq_n = '0' and cpu0_wr_n = '0' and ((ram_a_bus = "000000001010") or (ram_a_bus = "000000001110")) else '0'; 
vid_scr	<= '1' when (ram_a_bus = "000000001110") else '0';

-----------------------------------------------------------------
-- video scan converter required to display video on VGA hardware
-----------------------------------------------------------------
-- active resolution 192x256
-- take note: the values below are relative to the CLK period not standard VGA clock period
inst_scan_conv : entity work.scan_convert
generic map (
	-- mark active area of input video
	cstart      	=>  46,  -- composite sync start -- 38
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
	CLK		=> clk7,
	CLK_x2		=> clk14);

inst_dvid: entity work.hdmi
generic map (
	FREQ		=> 25200000,	-- pixel clock frequency = 25.2MHz
	FS		=> 48000,	-- audio sample rate - should be 32000, 41000 or 48000 = 48KHz
	CTS		=> 25200,	-- CTS = Freq(pixclk) * N / (128 * Fs)
	N		=> 6144)	-- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300 (Check HDMI spec 7.2 for details)
port map (
	I_CLK_VGA	=> clk_bus,
	I_CLK_TMDS	=> clk_hdmi,
	I_HSYNC		=> HSync,
	I_VSYNC		=> VSync,
	I_BLANK		=> not sblank,
	I_RED		=> VideoR & VideoR & VideoR & VideoR,--osd_red,
	I_GREEN		=> VideoG & VideoG & VideoG & VideoG,--osd_green,
	I_BLUE		=> VideoB & VideoB & VideoB & VideoB,--osd_blue,
	I_AUDIO_PCM_L 	=> audio_l,
	I_AUDIO_PCM_R	=> audio_r,
	O_TMDS		=> TMDS);

end rtl;