library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fifo is
generic (depth : integer := 16);  --depth of fifo
port (    clk : in std_logic;
          reset : in std_logic;
          enr : in std_logic;   --enable read,should be '0' when not in use.
          enw : in std_logic;    --enable write,should be '0' when not in use.
          data_in : in std_logic_vector (7 downto 0);     --input data
          data_out : out std_logic_vector(7 downto 0);    --output data
          fifo_empty : out std_logic;     --set as '1' when the queue is empty
          fifo_full : out std_logic     --set as '1' when the queue is full
         );
end fifo;

architecture Behavioral of fifo is

type memory_type is array (0 to depth-1) of std_logic_vector(7 downto 0);
signal memory : memory_type :=(others => (others => '0'));   --memory for queue.
signal readptr,writeptr : integer := 0;  --read and write pointers.
signal empty,full : std_logic := '0';

begin

fifo_empty <= empty;
fifo_full <= full;

process(Clk,reset)
--this is the number of elements stored in fifo at a time.
--this variable is used to decide whether the fifo is empty or full.
variable num_elem : integer := 0;  
begin
if(reset = '1') then
    data_out <= (others => '0');
    empty <= '0';
    full <= '0';
    readptr <= 0;
    writeptr <= 0;
    num_elem := 0;
elsif(rising_edge(Clk)) then
    if(enr = '1' and empty = '0') then  --read
        data_out <= memory(readptr);
        readptr <= readptr + 1;      
        num_elem := num_elem-1;
    end if;
    if(enw ='1' and full = '0') then    --write
        memory(writeptr) <= data_in;
        writeptr <= writeptr + 1;  
        num_elem := num_elem+1;
    end if;
    --rolling over of the indices.
    if(readptr = depth-1) then      --resetting read pointer.
        readptr <= 0;
    end if;
    if(writeptr = depth-1) then        --resetting write pointer.
        writeptr <= 0;
    end if; 
    --setting empty and full flags.
    if(num_elem = 0) then
        empty <= '1';
    else
        empty <= '0';
    end if;
    if(num_elem = depth) then
        full <= '1';
    else
        full <= '0';
    end if;
end if; 
end process;

end Behavioral;