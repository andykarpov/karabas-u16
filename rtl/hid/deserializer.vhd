-------------------------------------------------------------------[31.12.2016]
-- CONTROLLER USB HID scancode to Spectrum matrix conversion
-------------------------------------------------------------------------------
-- Engineer: MVV <mvvproject@gmail.com>
-- Modified by: Andy Karpov <andy.karpov@gmail.com>

library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all; 

entity deserializer is
generic (
	divisor			: integer := 434 );	-- divisor = 50MHz / 115200 Baud = 434
port (
	I_CLK			: in std_logic;
	I_CLK_RATE 	: in std_logic;
	I_RESET			: in std_logic;
	I_RX			: in std_logic;
	I_NEWFRAME		: in std_logic;
	I_ADDR			: in std_logic_vector(15 downto 8);
	O_KEYBOARD_DO_BUS		: out std_logic_vector(4 downto 0);
	O_MOUSE_X		: out std_logic_vector(7 downto 0);
	O_MOUSE_Y		: out std_logic_vector(7 downto 0);
	O_MOUSE_Z		: out std_logic_vector(7 downto 0);
	O_MOUSE_BUTTONS		: out std_logic_vector(7 downto 0);	
	O_JOYSTICK 		: out std_logic_vector(4 downto 0);
	O_RESET 		: out std_logic;
	O_MAGIC 	 	: out std_logic;
	O_TURBO 		: out std_logic;
	O_SPECIAL	: out std_logic
);
end deserializer;

architecture rtl of deserializer is
	signal count		: integer range 0 to 8;
	signal data		: std_logic_vector(7 downto 0);
	signal ready		: std_logic;
	signal device_id	: std_logic_vector(7 downto 0);
	
	signal x		: std_logic_vector(8 downto 0) := "111111111";
	signal y		: std_logic_vector(8 downto 0) := "000000000";
	signal z		: std_logic_vector(8 downto 0) := "111111111";
	signal b		: std_logic_vector(7 downto 0) := "00000000";
	
	signal joy 	: std_logic_vector(4 downto 0) := "00000";
	
	TYPE matrix IS (ZX_K_CS, ZX_K_A, ZX_K_Q, ZX_K_1, 
						 ZX_K_0, ZX_K_P, ZX_K_ENT, ZX_K_SP,
						 ZX_K_Z, ZX_K_S, ZX_K_W, ZX_K_2,
						 ZX_K_9, ZX_K_O, ZX_K_L, ZX_K_SS,
						 ZX_K_X, ZX_K_D, ZX_K_E, ZX_K_3,
						 ZX_K_8, ZX_K_I, ZX_K_K, ZX_K_M,
						 ZX_K_C, ZX_K_F, ZX_K_R, ZX_K_4,
						 ZX_K_7, ZX_K_U, ZX_K_J, ZX_K_N,
						 ZX_K_V, ZX_K_G, ZX_K_T, ZX_K_5,
						 ZX_K_6, ZX_K_Y, ZX_K_H, ZX_K_B
						 );
						 
	type kb_matrix is array(matrix) of std_logic;
						 
	signal kb_data : kb_matrix := (others => '0'); -- 40 keys
	
	 signal reset   : std_logic := '0';
	 signal turbo   : std_logic := '0';
	 signal magic   : std_logic := '0';
	 signal special : std_logic := '0';	
	 
	 signal is_shift : std_logic := '0';
	 signal is_ctrl : std_logic := '0';
	 signal is_alt : std_logic := '0';
	 signal is_del : std_logic := '0';
	 signal is_cs_used : std_logic := '0';
	 signal is_ss_used : std_logic := '0';
	 signal is_esc : std_logic := '0';
	 signal is_bksp : std_logic := '0';
	 
	 signal is_macros : std_logic := '0';
	 type macros_machine is (MACRO_START, MACRO_CS_ON, MACRO_SS_ON, MACRO_SS_OFF, MACRO_KEY, MACRO_CS_OFF, MACRO_END);
	 signal macros_key : matrix;
	 signal macros_state : macros_machine := MACRO_START;	
	 
	 signal prev_clk_rate : std_logic := '0';
	 
begin

	inst_rx : entity work.receiver
	generic map (
		divisor		=> 434 )	-- divisor = 50MHz / 115200 Baud = 434
	port map (
		I_CLK		=> I_CLK,
		I_RESET		=> I_RESET,
		I_RX		=> I_RX,
		O_DATA		=> data,
		O_READY		=> ready
	);
	
	O_RESET <= reset;
	O_MAGIC <= magic;
	O_TURBO <= turbo;
	O_SPECIAL <= special;
	
	-- Mouse
	O_MOUSE_BUTTONS <= b;
	O_MOUSE_X		 <= x(7 downto 0);
	O_MOUSE_Y		 <= y(7 downto 0);
	O_MOUSE_Z		 <= z(7 downto 0);
	
	-- Joy 
	O_JOYSTICK <= joy;

	process( kb_data, I_ADDR)
	begin
		O_KEYBOARD_DO_BUS(0) <=	not(( kb_data(ZX_K_CS)  and not(I_ADDR(8)  ) ) 
					or    ( kb_data(ZX_K_A)  and not(I_ADDR(9)  ) ) 
					or    ( kb_data(ZX_K_Q) and not(I_ADDR(10) ) ) 
					or    ( kb_data(ZX_K_1) and not(I_ADDR(11) ) ) 
					or    ( kb_data(ZX_K_0) and not(I_ADDR(12) ) ) 
					or    ( kb_data(ZX_K_P) and not(I_ADDR(13) ) ) 
					or    ( kb_data(ZX_K_ENT) and not(I_ADDR(14) ) ) 
					or    ( kb_data(ZX_K_SP) and not(I_ADDR(15) ) )  );

		O_KEYBOARD_DO_BUS(1) <=	not( ( kb_data(ZX_K_Z)  and not(I_ADDR(8) ) ) 
					or   ( kb_data(ZX_K_S)  and not(I_ADDR(9) ) ) 
					or   ( kb_data(ZX_K_W) and not(I_ADDR(10)) ) 
					or   ( kb_data(ZX_K_2) and not(I_ADDR(11)) ) 
					or   ( kb_data(ZX_K_9) and not(I_ADDR(12)) ) 
					or   ( kb_data(ZX_K_O) and not(I_ADDR(13)) ) 
					or   ( kb_data(ZX_K_L) and not(I_ADDR(14)) ) 
					or   ( kb_data(ZX_K_SS) and not(I_ADDR(15)) ) );

		O_KEYBOARD_DO_BUS(2) <=		not( ( kb_data(ZX_K_X) and not( I_ADDR(8)) ) 
					or   ( kb_data(ZX_K_D) and not( I_ADDR(9)) ) 
					or   ( kb_data(ZX_K_E) and not(I_ADDR(10)) ) 
					or   ( kb_data(ZX_K_3) and not(I_ADDR(11)) ) 
					or   ( kb_data(ZX_K_8) and not(I_ADDR(12)) ) 
					or   ( kb_data(ZX_K_I) and not(I_ADDR(13)) ) 
					or   ( kb_data(ZX_K_K) and not(I_ADDR(14)) ) 
					or   ( kb_data(ZX_K_M) and not(I_ADDR(15)) ) );

		O_KEYBOARD_DO_BUS(3) <=		not( ( kb_data(ZX_K_C) and not( I_ADDR(8)) ) 
					or   ( kb_data(ZX_K_F) and not( I_ADDR(9)) ) 
					or   ( kb_data(ZX_K_R) and not(I_ADDR(10)) ) 
					or   ( kb_data(ZX_K_4) and not(I_ADDR(11)) ) 
					or   ( kb_data(ZX_K_7) and not(I_ADDR(12)) ) 
					or   ( kb_data(ZX_K_U) and not(I_ADDR(13)) ) 
					or   ( kb_data(ZX_K_J) and not(I_ADDR(14)) ) 
					or   ( kb_data(ZX_K_N) and not(I_ADDR(15)) ) );

		O_KEYBOARD_DO_BUS(4) <=		not( ( kb_data(ZX_K_V) and not( I_ADDR(8)) ) 
					or   ( kb_data(ZX_K_G) and not( I_ADDR(9)) ) 
					or   ( kb_data(ZX_K_T) and not(I_ADDR(10)) ) 
					or   ( kb_data(ZX_K_5) and not(I_ADDR(11)) ) 
					or   ( kb_data(ZX_K_6) and not(I_ADDR(12)) ) 
					or   ( kb_data(ZX_K_Y) and not(I_ADDR(13)) ) 
					or   ( kb_data(ZX_K_H) and not(I_ADDR(14)) ) 
					or   ( kb_data(ZX_K_B) and not(I_ADDR(15)) ) );
	end process;
	
	process (I_RESET, I_CLK, data, I_NEWFRAME, ready)
	begin
		if I_RESET = '1' then
			count <= 0;
			kb_data <= (others => '0');
			is_shift <= '0';
			is_ctrl <= '0';
			is_alt <= '0';
			is_del <= '0';
			is_cs_used <= '0';
			is_ss_used <= '0';
			is_esc <= '0';
			is_bksp <= '0';
			reset <= '0';
			x <= (others => '1');
			y <= (others => '0');
			z <= (others => '1');
			b <= (others => '0');
			
		elsif I_CLK'event and I_CLK = '1' then
		
			prev_clk_rate <= I_CLK_RATE;
		
			if reset = '1' then 
				-- while reset => kill the pressed keys
				kb_data <= (others => '0');
				is_shift <= '0';
				is_ctrl <= '0';
				is_alt <= '0';
				is_del <= '0';
				is_cs_used <= '0';
				is_ss_used <= '0';
				is_esc <= '0';
				is_bksp <= '0';
				reset <= '0';
				magic <= '0';
				
			elsif is_macros = '1' then 
				if I_CLK_RATE /= prev_clk_rate then -- falling edge of KB CLK RATE
					case macros_state is 
						when MACRO_START  => kb_data <= (others => '0'); macros_state <= MACRO_CS_ON;
						when MACRO_CS_ON  => kb_data(ZX_K_CS) <= '1';    macros_state <= MACRO_SS_ON;
						when MACRO_SS_ON  => kb_data(ZX_K_SS) <= '1';    macros_state <= MACRO_SS_OFF;
						when MACRO_SS_OFF => kb_data(ZX_K_SS) <= '0';    macros_state <= MACRO_KEY;
						when MACRO_KEY    => kb_data(macros_key) <= '1'; macros_state <= MACRO_CS_OFF;
						when MACRO_CS_OFF => kb_data(ZX_K_CS) <= '0'; kb_data(macros_key) <= '0'; macros_state <= MACRO_END;
						when MACRO_END    => kb_data <= (others => '0'); is_macros <= '0';        macros_state <= MACRO_START;
						when others => null;
					end case;
				end if;

			elsif I_NEWFRAME = '0' then
				count <= 0;
				
			elsif count = 0 and ready = '1' then
				count <= 1;
				device_id <= data;
				case data(3 downto 0) is
					when x"6" =>	-- Keyboard
						kb_data <= (others => '0');
						is_shift <= '0';
						is_ctrl <= '0';
						is_alt <= '0';
						is_del <= '0';
						is_cs_used <= '0';
						is_ss_used <= '0';
						is_esc <= '0';
						is_bksp <= '0';
						reset <= '0';
						magic <= '0';
					when others => null;
				end case;
			elsif ready = '1' then
				count <= count + 1;
				case device_id is
				
					when x"02" | x"82" =>	-- Mouse
					-- Input report - 5 bytes
 					--     Byte | D7      D6      D5      D4      D3      D2      D1      D0
					--    ------+---------------------------------------------------------------------
					--      0   |  0       0       0    Forward  Back    Middle  Right   Left (Button)
					--      1   |                             X
					--      2   |                             Y
					--      3   |                       Vertical Wheel
					--      4   |                    Horizontal (Tilt) Wheel
					
						case count is
							when 1 => b <= data;		-- Buttons
							when 2 => x <= x + data;	-- Left/Right delta
							when 3 => y <= y + data;	-- Up/Down delta
							when 4 => z <= z + data;	-- Wheel delta
							when others => null;
						end case;
						
					when x"04" | x"84" =>	-- HID Gamepad
						case count is
							when 4 => joy(0) <= data(7);		-- Right
										 joy(1) <= not data(6); -- Left
							when 5 => joy(2) <= data(7);			-- Down
										 joy(3) <= not data(6);		-- Up
							when 6 => joy(4) <= data(6) or data(7) or data(5) or data(4); -- Fire
							when others => null;
						end case;
				
					when x"06" | x"86" =>	-- Keyboard
						if count = 1 then
						
							-- Shift -> CS
							if data(1) = '1' or data(5) = '1' then kb_data(ZX_K_CS) <= '1'; is_shift <= '1'; end if;
							
							-- Ctrl -> SS
							if data(0) = '1' or data(4) = '1' then kb_data(ZX_K_SS) <= '1'; is_ctrl <= '1'; end if;
							
							-- Alt -> SS+CS
							if data(2) = '1' or data(6) = '1' then kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_SS) <= '1'; is_alt <= '1'; is_cs_used <= '1'; end if;

							-- 0 - E0 Left Ctrl
							-- 1 - E1 Left Shift
							-- 2 - E2 Left Alt 
							-- 3 - E3 Left Gui 
							-- 4 - E4 Right Ctrl 
							-- 5 - E5 Right Shigt 
							-- 6 - E6 Right Alt 
							-- 7 - E7 Right Gui
						else
							case data is
							
								-- DEL -> SS + C
								when X"4c" => kb_data(ZX_K_SS) <= '1'; kb_data(ZX_K_C) <= '1'; is_del <= '1';
								
								-- INS -> SS + A
								when X"49" => kb_data(ZX_K_SS) <= '1'; kb_data(ZX_K_A) <= '1'; 
								
								-- Cursor -> CS + 5,6,7,8
								when X"50" =>	kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_5) <= '1'; is_cs_used <= '1';
								when X"51" =>	kb_data(ZX_K_CS) <= '1'; kb_Data(ZX_K_6) <= '1'; is_cs_used <= '1';
								when X"52" =>	kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_7) <= '1'; is_cs_used <= '1';
								when X"4f" =>	kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_8) <= '1'; is_cs_used <= '1';
								
								-- ESC -> CS + Space 
								when X"29" => kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_SP) <= '1'; is_cs_used <= '1'; is_esc <= '1';
								
								-- Backspace -> CS + 0
								when X"2a" => kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_0) <= '1'; is_cs_used <= '1'; is_bksp <= '1';
								
								-- Enter
								when X"28" =>	kb_data(ZX_K_ENT) <= '1'; -- normal
								when X"58" =>  kb_data(ZX_K_ENT) <= '1'; -- keypad 
								
								-- Space 
								when X"2c" =>	kb_data(ZX_K_SP) <= '1';
								
								-- Letters
								when X"04" =>	kb_data(ZX_K_A) <= '1'; -- A
								when X"05" =>	kb_data(ZX_K_B) <= '1'; -- B								
								when X"06" =>	kb_data(ZX_K_C) <= '1'; -- C
								when X"07" =>	kb_data(ZX_K_D) <= '1'; -- D
								when X"08" =>	kb_data(ZX_K_E) <= '1'; -- E
								when X"09" =>	kb_data(ZX_K_F) <= '1'; -- F
								when X"0a" =>	kb_data(ZX_K_G) <= '1'; -- G
								when X"0b" =>	kb_data(ZX_K_H) <= '1'; -- H
								when X"0c" =>	kb_data(ZX_K_I) <= '1'; -- I
								when X"0d" =>	kb_data(ZX_K_J) <= '1'; -- J
								when X"0e" =>	kb_data(ZX_K_K) <= '1'; -- K
								when X"0f" =>	kb_data(ZX_K_L) <= '1'; -- L
								when X"10" =>	kb_data(ZX_K_M) <= '1'; -- M
								when X"11" =>	kb_data(ZX_K_N) <= '1'; -- N
								when X"12" =>	kb_data(ZX_K_O) <= '1'; -- O
								when X"13" =>	kb_data(ZX_K_P) <= '1'; -- P
								when X"14" =>	kb_data(ZX_K_Q) <= '1'; -- Q
								when X"15" =>	kb_data(ZX_K_R) <= '1'; -- R
								when X"16" =>	kb_data(ZX_K_S) <= '1'; -- S
								when X"17" =>	kb_data(ZX_K_T) <= '1'; -- T
								when X"18" =>	kb_data(ZX_K_U) <= '1'; -- U
								when X"19" =>	kb_data(ZX_K_V) <= '1'; -- V
								when X"1a" =>	kb_data(ZX_K_W) <= '1'; -- W
								when X"1b" =>	kb_data(ZX_K_X) <= '1'; -- X
								when X"1c" =>	kb_data(ZX_K_Y) <= '1'; -- Y
								when X"1d" =>	kb_data(ZX_K_Z) <= '1'; -- Z								
								
								-- Digits
								when X"1e" =>	kb_data(ZX_K_1) <= '1'; -- 1
								when X"1f" =>	kb_data(ZX_K_2) <= '1'; -- 2
								when X"20" =>	kb_data(ZX_K_3) <= '1'; -- 3
								when X"21" =>	kb_data(ZX_K_4) <= '1'; -- 4
								when X"22" =>	kb_data(ZX_K_5) <= '1'; -- 5
								when X"23" =>	kb_data(ZX_K_6) <= '1'; -- 6
								when X"24" =>	kb_data(ZX_K_7) <= '1'; -- 7
								when X"25" =>	kb_data(ZX_K_8) <= '1'; -- 8
								when X"26" =>	kb_data(ZX_K_9) <= '1'; -- 9
								when X"27" =>	kb_data(ZX_K_0) <= '1'; -- 0

								-- Numpad digits
								when X"59" =>	kb_data(ZX_K_1) <= '1'; -- 1
								when X"5A" =>	kb_data(ZX_K_2) <= '1'; -- 2
								when X"5B" =>	kb_data(ZX_K_3) <= '1'; -- 3
								when X"5C" =>	kb_data(ZX_K_4) <= '1'; -- 4
								when X"5D" =>	kb_data(ZX_K_5) <= '1'; -- 5
								when X"5E" =>	kb_data(ZX_K_6) <= '1'; -- 6
								when X"5F" =>	kb_data(ZX_K_7) <= '1'; -- 7
								when X"60" =>	kb_data(ZX_K_8) <= '1'; -- 8
								when X"61" =>	kb_data(ZX_K_9) <= '1'; -- 9
								when X"62" =>	kb_data(ZX_K_0) <= '1'; -- 0

								-- Special keys 
								
								-- '/" -> SS+P / SS+7
								when X"34" => kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_P) <= '1'; else kb_data(ZX_K_7) <= '1'; end if; is_ss_used <= is_shift;
								
								-- ,/< -> SS+N / SS+R
								when X"36" => kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_R) <= '1'; else kb_data(ZX_K_N) <= '1'; end if; is_ss_used <= is_shift;
								
								-- ./> -> SS+M / SS+T
								when X"37" => kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_T) <= '1'; else kb_data(ZX_K_M) <= '1'; end if; is_ss_used <= is_shift;
								
								-- ;/: -> SS+O / SS+Z
								when X"33" => kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_Z) <= '1'; else kb_data(ZX_K_O) <= '1'; end if; is_ss_used <= is_shift;
								
								-- [,{ -> SS+Y / SS+F
								when X"2F" => is_macros <= '1'; if is_shift = '1' then macros_key <= ZX_K_F; else macros_key <= ZX_K_Y; end if; 
								
								-- ],} -> SS+U / SS+G
								when X"30" => is_macros <= '1'; if is_shift = '1' then macros_key <= ZX_K_G; else macros_key <= ZX_K_U; end if; 
								
								-- /,? -> SS+V / SS+C
								when X"38" => kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_C) <= '1'; else kb_data(ZX_K_V) <= '1'; end if; is_ss_used <= is_shift;
								
								-- \,| -> SS+D / SS+S
								when X"31" => is_macros <= '1'; if is_shift = '1' then macros_key <= ZX_K_S; else macros_key <= ZX_K_D; end if; 
								
								-- =,+ -> SS+L / SS+K
								when X"2E" => kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_K) <= '1'; else kb_data(ZX_K_L) <= '1'; end if; is_ss_used <= is_shift;
								
								-- -,_ -> SS+J / SS+0
								when X"2D" => kb_data(ZX_K_SS) <= '1'; if is_shift = '1' then kb_data(ZX_K_0) <= '1'; else kb_data(ZX_K_J) <= '1'; end if; is_ss_used <= is_shift;

								-- `,~ -> SS+X / SS+A
								when X"35" => 
									if (is_shift = '1') then 
										is_macros <= '1'; macros_key <= ZX_K_A; 
									else
										kb_data(ZX_K_SS) <= '1'; kb_data(ZX_K_X) <= '1'; is_ss_used <= '1';
									end if;
	
								-- Keypad * -> SS+B
								when X"55" => kb_data(ZX_K_SS) <= '1'; kb_data(ZX_K_B) <= '1'; 
								
								-- Keypad - -> SS+J
								when X"56" => kb_data(ZX_K_SS) <= '1'; kb_data(ZX_K_J) <= '1';
								
								-- Keypad + -> SS+K
								when X"57" => kb_data(ZX_K_SS) <= '1'; kb_data(ZX_K_K) <= '1';
								
								-- Tab -> CS + I
								when X"2B" => kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_I) <= '1'; is_cs_used <= '1';
								
								-- CapsLock -> CS + SS
								when X"39" => kb_data(ZX_K_SS) <= '1'; kb_data(ZX_K_CS) <= '1'; is_cs_used <= '1';
								
								-- PgUp -> CS+3 for ZX
								when X"4B" => kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_3) <= '1'; is_cs_used <= '1';

								-- PgDown -> CS+4 for ZX
								when X"4E" => kb_data(ZX_K_CS) <= '1'; kb_data(ZX_K_4) <= '1'; is_cs_used <= '1';
								
								-- Scroll Lock -> Special
								when X"47" => special <= not(special);
								
								-- PrintScreen -> Turbo
								when X"46" => turbo <= not(turbo);
								
								-- F2 -> Magic
								when X"3B" => magic <= '1';
								
								when others => null;
							end case;
							
							-- cleanup CS key when SS is marked
							if (is_ss_used = '1' and is_cs_used = '0') then 
								kb_data(ZX_K_CS) <= '0';
							end if;
							
							-- reset by ctrl+alt+del
							if (is_ctrl = '1' and is_alt = '1' and is_del = '1') then 
								is_ctrl <= '0';
								is_alt <= '0';
								is_del <= '0';
								is_shift <= '0';
								is_ss_used <= '0';
								is_cs_used <= '0';
								reset <= '1';
							end if;
							
							-- something else by ctrl+alt+backspace
							if (is_ctrl = '1' and is_alt = '1' and is_bksp = '1') then 
								is_ctrl <= '0';
								is_alt <= '0';
								is_del <= '0';
								is_shift <= '0';
								is_ss_used <= '0';
								is_cs_used <= '0';
								-- TODO								
							end if;
							
						end if;
					
					when others => null;
				end case;
			end if;
		end if;
	end process;

end architecture;
