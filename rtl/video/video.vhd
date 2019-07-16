-------------------------------------------------------------------[16.07.2019]
-- VIDEO Pentagon mode
-------------------------------------------------------------------------------

library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.numeric_std.ALL;
use IEEE.std_logic_unsigned.all;

entity video is
	port (
		CLK		: in std_logic;							-- системная частота
		ENA		: in std_logic;							-- 7MHz ticks
		BORDER	: in std_logic_vector(2 downto 0);	-- цвет бордюра (порт #xxFE)
		DI			: in std_logic_vector(7 downto 0);	-- видеоданные
		
		INT		: out std_logic;
		ATTR_O	: out std_logic_vector(7 downto 0);
		A			: out std_logic_vector(12 downto 0);
		BLANK		: out std_logic;						-- BLANK
		RGB		: out std_logic_vector(5 downto 0);		-- RRGGBB
		HSYNC		: out std_logic;
		VSYNC		: out std_logic);
end entity;

architecture rtl of video is

	signal invert   : unsigned(4 downto 0) := "00000";

	signal chr_col_cnt : unsigned(2 downto 0) := "000"; -- Character column counter
	signal chr_row_cnt : unsigned(2 downto 0) := "000"; -- Character row counter

	signal hor_cnt  : unsigned(5 downto 0) := "000000"; -- Horizontal counter
	signal ver_cnt  : unsigned(5 downto 0) := "000000"; -- Vertical counter

	signal attr     : std_logic_vector(7 downto 0);
	signal shift    : std_logic_vector(7 downto 0);
	
	signal paper_r  : std_logic;
	signal blank_r  : std_logic;
	signal attr_r   : std_logic_vector(7 downto 0);
	signal shift_r  : std_logic_vector(7 downto 0);

	signal paper     : std_logic;
	signal black 	  : std_logic;	
	
	signal VIDEO_R 	: std_logic;
	signal VIDEO_G 	: std_logic;
	signal VIDEO_B 	: std_logic;
	signal VIDEO_I 	: std_logic;	

begin

	-- sync, counters
	process( CLK, ENA, chr_col_cnt, hor_cnt, chr_row_cnt, ver_cnt)
	begin
		if CLK'event and CLK = '1' then
		
			if ENA = '1' then
			
				if chr_col_cnt = 7 then
				
					if hor_cnt = 55 then
						hor_cnt <= (others => '0');
					else
						hor_cnt <= hor_cnt + 1;
					end if;
					
					if hor_cnt = 39 then
						if chr_row_cnt = 7 then
							if ver_cnt = 39 then
								ver_cnt <= (others => '0');
								invert <= invert + 1;
							else
								ver_cnt <= ver_cnt + 1;
							end if;
						end if;
						chr_row_cnt <= chr_row_cnt + 1;
					end if;
				end if;

				-- h/v sync

				if chr_col_cnt = 7 then

					if (hor_cnt(5 downto 2) = "1010") then 
						HSYNC <= '0';
					else 
						HSYNC <= '1';
					end if;
					
					if ver_cnt /= 31 then
						VSYNC <= '1';
					elsif chr_row_cnt = 3 or chr_row_cnt = 4 or ( chr_row_cnt = 5 and ( hor_cnt >= 40 or hor_cnt < 12 ) ) then
						VSYNC<= '0';
					else 
						VSYNC <= '1';
					end if;
					
				end if;
			
				-- int
				if chr_col_cnt = 6 and hor_cnt(2 downto 0) = "111" then
					if ver_cnt = 29 and chr_row_cnt = 7 and hor_cnt(5 downto 3) = "100" then
						INT <= '0';
					else
						INT <= '1';
					end if;
				end if;

				chr_col_cnt <= chr_col_cnt + 1;
			end if;
		end if;
	end process;

	-- r/g/b
	process( CLK, ENA, paper_r, shift_r, attr_r, invert, blank_r )
	begin
		if CLK'event and CLK = '1' then
			if ENA = '1' then
				if paper_r = '0' then           
					if( shift_r(7) xor ( attr_r(7) and invert(4) ) ) = '1' then
						VIDEO_B <= attr_r(0);
						VIDEO_R <= attr_r(1);
						VIDEO_G <= attr_r(2);
					else
						VIDEO_B <= attr_r(3);
						VIDEO_R <= attr_r(4);
						VIDEO_G <= attr_r(5);
						end if;
				else
					if blank_r = '0' then
						VIDEO_B <= '0';
						VIDEO_R <= '0';
						VIDEO_G <= '0';
						else
						VIDEO_B <= BORDER(0);
						VIDEO_R <= BORDER(1);
						VIDEO_G <= BORDER(2);
					end if;
				end if;
			end if;

		end if;
	end process;

	-- brightness
	process( CLK, ENA, paper_r, attr_r )
	begin
		if CLK'event and CLK = '1' then
			if ENA = '1' then
				if paper_r = '0' and attr_r(6) = '1' then
					VIDEO_I <= '1';
				else
					VIDEO_I <= '0';
				end if;
			end if;
		end if;
	end process;

	-- paper, blank
	process( CLK, ENA, chr_col_cnt, hor_cnt, ver_cnt )
	begin
		if CLK'event and CLK = '1' then
			if ENA = '1' then
				if chr_col_cnt = 7 then
					attr_r <= attr;
					shift_r <= shift;

					if ((hor_cnt(5 downto 0) > 38 and hor_cnt(5 downto 0) < 48) or ver_cnt(5 downto 1) = 15) then
						blank_r <= '0';
					else 
						blank_r <= '1';
					end if;
					
					paper_r <= paper;
				else
					shift_r(7 downto 1) <= shift_r(6 downto 0);
					shift_r(0) <= '0';
				end if;

			end if;
		end if;
	end process;
	
	-- video mem read cycle
	process (CLK, ENA)
	begin 
		if (CLK'event and CLK = '1') then 
			if (ENA = '1') then 
				case chr_col_cnt(2 downto 0) is
					when "000" => -- data request
						A <= std_logic_vector( ver_cnt(4 downto 3) & chr_row_cnt & ver_cnt(2 downto 0) & hor_cnt(4 downto 0) );
					when "001" => -- read data into shift register
						shift <= DI;
					when "010" => -- attribute request 
						A <= std_logic_vector( "110" & ver_cnt(4 downto 0) & hor_cnt(4 downto 0) );
					when "011" => -- read attributes
						attr <= DI;
					when others => null;
				end case;
			end if;
		end if;
	end process;

black <= '1' when VIDEO_R='0' and VIDEO_G='0' and VIDEO_B = '0' else '0';
RGB 	<= VIDEO_R & VIDEO_I & VIDEO_G & VIDEO_I & VIDEO_B & VIDEO_I when black = '0' else "000000";
ATTR_O	<= attr_r;
BLANK	<= blank_r;
paper <= '0' when hor_cnt(5) = '0' and ver_cnt(5) = '0' and ( ver_cnt(4) = '0' or ver_cnt(3) = '0' ) else '1';

end architecture;