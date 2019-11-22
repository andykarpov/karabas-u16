--------------------------------------------------------------------------------
--
--   FileName:         ds1307.vhd
--   Dependencies:     i2c_master.vhd (Version 2.2)
--
--   Version History
--   Version 1.0 09/16/2019 Andy Karpov
--     Initial Release
--
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY ds1307 IS
  GENERIC(
    sys_clk_freq   :       INTEGER := 50_000_000;                      --input clock speed from user logic in Hz
    ds1307_addr    :       STD_LOGIC_VECTOR(6 DOWNTO 0) := "1101000"); --I2C address of the rtc ds1307
  PORT(
    clk            : IN    STD_LOGIC;                                  --system clock
    reset_n        : IN    STD_LOGIC;                                  --asynchronous active-low reset
    scl            : INOUT STD_LOGIC;                                  --I2C serial clock
    sda            : INOUT STD_LOGIC;                                  --I2C serial data
    rtc_rd         : IN    STD_LOGIC;                                  --begin ds1307 read cycle
    rtc_wr         : IN    STD_LOGIC;                                  --begin ds1307 write cycle
    rtc_register   : IN    STD_LOGIC_VECTOR(7 DOWNTO 0);               --ds1307 register pointer to read/write to
    rtc_data_in    : IN    STD_LOGIC_VECTOR(7 DOWNTO 0);               --ds1307 incoming data to write
    rtc_data_out   : OUT   STD_LOGIC_VECTOR(7 downto 0);               --ds1307 outgoing data to read
    rtc_busy       : OUT   STD_LOGIC;                                  --ds1307 operation is in progress
    rtc_data_ready : OUT   STD_LOGIC;
    i2c_ack_err    : OUT   STD_LOGIC                                   --I2C slave acknowledge error flag
);
END ds1307;

ARCHITECTURE behavior OF ds1307 IS
  TYPE machine IS(start, write_data, read_data, output_result); --needed states
  SIGNAL state       : machine;                       --state machine
  SIGNAL i2c_ena     : STD_LOGIC;                     --i2c enable signal
  SIGNAL i2c_addr    : STD_LOGIC_VECTOR(6 DOWNTO 0);  --i2c address signal
  SIGNAL i2c_rw      : STD_LOGIC;                     --i2c read/write command signal
  SIGNAL i2c_data_wr : STD_LOGIC_VECTOR(7 DOWNTO 0);  --i2c write data
  SIGNAL i2c_data_rd : STD_LOGIC_VECTOR(7 DOWNTO 0);  --i2c read data
  SIGNAL i2c_busy    : STD_LOGIC;                     --i2c busy signal
  SIGNAL busy_prev   : STD_LOGIC;                     --previous value of i2c busy signal
  SIGNAL rtc_dout_r  : STD_LOGIC_VECTOR(15 DOWNTO 0); --data buffer

  COMPONENT i2c_master IS
    GENERIC(
     input_clk : INTEGER;  --input clock speed from user logic in Hz
     bus_clk   : INTEGER); --speed the i2c bus (scl) will run at in Hz
    PORT(
     clk       : IN     STD_LOGIC;                    --system clock
     reset_n   : IN     STD_LOGIC;                    --active low reset
     ena       : IN     STD_LOGIC;                    --latch in command
     addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
     rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
     data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
     busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
     data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
     ack_error : BUFFER STD_LOGIC;                    --flag if improper acknowledge from slave
     sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
     scl       : INOUT  STD_LOGIC);                   --serial clock output of i2c bus
  END COMPONENT;

BEGIN

  --instantiate the i2c master
  i2c_master_0:  i2c_master
    GENERIC MAP(input_clk => sys_clk_freq, bus_clk => 400_000)
    PORT MAP(clk => clk, reset_n => reset_n, ena => i2c_ena, addr => i2c_addr,
             rw => i2c_rw, data_wr => i2c_data_wr, busy => i2c_busy,
             data_rd => i2c_data_rd, ack_error => i2c_ack_err, sda => sda,
             scl => scl);

  PROCESS(clk, reset_n)
    VARIABLE busy_cnt : INTEGER RANGE 0 TO 2 := 0;               --counts the busy signal transistions during one transaction
    VARIABLE counter  : INTEGER RANGE 0 TO sys_clk_freq/10 := 0; --counts 100ms to wait before communicating
  BEGIN
    IF(reset_n = '0') THEN               --reset activated
      counter := 0;                        --clear wait counter
      i2c_ena <= '0';                      --clear i2c enable
      busy_cnt := 0;                       --clear busy counter
      rtc_data_out <= (OTHERS => '0');      --clear result output
      rtc_busy <= '1';
      rtc_data_ready <= '0';
      state <= start;                      --return to start state
    ELSIF(clk'EVENT AND clk = '1') THEN  --rising edge of system clock
      CASE state IS                        --state machine

        --give RTC 100ms to power up before communicating
        WHEN start =>
          IF(counter < sys_clk_freq/10) THEN   --100ms not yet reached
            counter := counter + 1;              --increment counter
            rtc_busy <= '1';
            rtc_data_ready <= '0';
          ELSE                                 --100ms reached
            counter := 0;                        --clear counter
            state <= output_result;             --advance to output_result, if any
          END IF;

        --write data to the desired RTC register
        WHEN write_data =>
          rtc_busy <= '1';
          rtc_data_ready <= '0';
          busy_prev <= i2c_busy;                       --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND i2c_busy = '1') THEN  --i2c busy just went high
            busy_cnt := busy_cnt + 1;                    --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                             --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                    --no command latched in yet
              i2c_ena <= '1';                              --initiate the transaction
              i2c_addr <= ds1307_addr;                --set the address of the ds1307
              i2c_rw <= '0';                               --command 1 is a write
              i2c_data_wr <= rtc_register;                --set the rtc register to write to
            WHEN 1 =>                                    --1st busy high: command 1 latched, okay to issue command 2
              i2c_data_wr <= rtc_data_in;                       --write the new data value into the register
            WHEN 2 =>                                    --2nd busy high: command 2 latched
              i2c_ena <= '0';                              --deassert enable to stop transaction after command 2
              IF(i2c_busy = '0') THEN                      --transaction complete
                busy_cnt := 0;                               --reset busy_cnt for next transaction
                state <= output_result;                    --output result
              END IF;
            WHEN OTHERS => NULL;
          END CASE;

        --set the register pointer
        WHEN set_reg_pointer =>
          rtc_busy <= '1';
          rtc_data_ready <= '0';
          busy_prev <= i2c_busy;                       --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND i2c_busy = '1') THEN  --i2c busy just went high
            busy_cnt := busy_cnt + 1;                    --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                             --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                    --no command latched in yet
              i2c_ena <= '1';                              --initiate the transaction
              i2c_addr <= ds1307_addr;                      --set the address of the ds1307
              i2c_rw <= '0';                               --command 1 is a write
              i2c_data_wr <= rtc_register;                   --set the RTC register
            WHEN 1 =>                                    --1st busy high: command 1 latched
              i2c_ena <= '0';                              --deassert enable to stop transaction after command 1
              IF(i2c_busy = '0') THEN                      --transaction complete
                busy_cnt := 0;                               --reset busy_cnt for next transaction
                state <= read_data;                          --advance to reading the data
              END IF;
            WHEN OTHERS => NULL;
          END CASE;

        --read rtc register data
        WHEN read_data =>
          rtc_busy <= '1';
          rtc_data_ready <= '0';
          busy_prev <= i2c_busy;                       --capture the value of the previous i2c busy signal
          IF(busy_prev = '0' AND i2c_busy = '1') THEN  --i2c busy just went high
            busy_cnt := busy_cnt + 1;                    --counts the times busy has gone from low to high during transaction
          END IF;
          CASE busy_cnt IS                             --busy_cnt keeps track of which command we are on
            WHEN 0 =>                                    --no command latched in yet
              i2c_ena <= '1';                              --initiate the transaction
              i2c_addr <= ds1307_addr;                --set the address of the ds1307
              i2c_rw <= '1';                               --command 1 is a read
            WHEN 1 =>                                    --2nd busy high: command 2 latched
              i2c_ena <= '0';                              --deassert enable to stop transaction after command 2
              IF(i2c_busy = '0') THEN                      --indicates data read in command 2 is ready
                rtc_dout_r(7 DOWNTO 0) <= i2c_data_rd;        --retrieve LSB data from command 2
                busy_cnt := 0;                               --reset busy_cnt for next transaction
                state <= output_result;                      --advance to output the result
                rtc_data_ready <= '1';
              END IF;
           WHEN OTHERS => NULL;
          END CASE;

        --output the RTC register
        WHEN output_result =>
          rtc_data_out <= rtc_dout_r(7 downto 0); --write data from reg to output
          rtc_busy <= '0';
          -- next state
          if (rtc_wr = '1') then
            state <= write_data;
          else if (rtc_rd = '1') then
            state <= set_reg_pointer;
          else
            state <= output_result;

        --default to start state
        WHEN OTHERS =>
          state <= start;

      END CASE;
    END IF;
  END PROCESS;
END behavior;
