--------------------------------------------------------------------------------------------------------
-- Design Name      : Memory Bank
-- Description      : A synchronous read/write memory bank.
-- Default Specs    : Infers a XST Block RAM of 1 kB, 32-bit data, 256 addressable locations
--                    read, write latency = 1 clock cycle 
-- Developer		  : Mitu Raj, iammituraj@gmail.com
-- Date     		  : 26-03-2019
-- Tested on 		  : Virtex-4 ML403 Board, ISE 14.7 XST
-- Comments         : - Synthesisablity of default values on mem array depends on the board and tool
--                    - Mem array tested to infer Block RAM only on Xilinx FPGAs
--                    - If distributed RAM/flipflops are inferred, memory size may have to be reduced 
--								depending on the availability of resources on FPGA, it will reduce routing time
---------------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Memory_Bank is
    Generic ( word_size     : integer := 32; -- DEFAULT SPECS
			     addr_width    : integer := 8  -- DEFAULT SPECS
				);
    Port ( clock      : in  STD_LOGIC;   -- MEMORY CLOCK      
           reset      : in STD_LOGIC;    -- ASYNC RESET SIGNAL    
           rd         : in  STD_LOGIC;   -- READ SIGNAL 
           wr         : in STD_LOGIC;	  -- WRITE SIGNAL		  
           addr       : in  STD_LOGIC_VECTOR (addr_width-1 downto 0); -- ADDRESS INPUT
           data_in    : in  STD_LOGIC_VECTOR (word_size-1  downto 0); -- DATA INPUT FOR WRITE
           data_out   : out  STD_LOGIC_VECTOR (word_size-1  downto 0); -- DATA OUT FOR READ
           data_ready : out  STD_LOGIC); -- TO ACKNOWLEDGE THE END OF DATA PROCESSING
end Memory_Bank;

architecture Behavioral of Memory_Bank is

-- USER DEFINED DATA TYPE
type ram is array (0 to 2**addr_width-1) of STD_LOGIC_VECTOR (word_size-1 downto 0);

-- FUNCTION TO FILL MEMORY WITH DEFAULT VALUES 0 TO 255 FOR LOCATIONS 0 TO 255
function fill_mem
return ram is
variable data_memory_temp : ram;
begin
for i in 0 to 2**addr_width-1 loop
    data_memory_temp(i) := STD_LOGIC_VECTOR(to_unsigned(i,word_size));
end loop;
return data_memory_temp;
end function fill_mem;

-- INSTANCE OF DATA MEMORY
signal data_memory : ram := fill_mem;

begin

process(clock)
begin
if rising_edge(clock) then    	
   if wr = '1' then
	   data_memory(to_integer(unsigned(addr))) <= data_in;  -- SYNCHRONOUS WRITE
      data_out <= data_memory(to_integer(unsigned(addr))); -- SYNCHRONOUS READ	
	elsif rd = '1' then
	   data_out <= data_memory(to_integer(unsigned(addr))); -- SYNCHRONOUS READ
	else
	   data_out <= data_memory(to_integer(unsigned(addr))); -- SYNCHRONOUS READ
	end if;	
end if;
end process;

process(clock,reset)
begin
if reset = '0' then -- ACTIVE LOW ASYNC RESET
   data_ready <= '0';
elsif rising_edge(clock) then
	if wr = '1' then
		data_ready <= '1'; -- DATA IS WRITTEN, ACKNOWLDGE THE PROCESSOR
	elsif rd = '1' then
		data_ready <= '1'; -- DATA CAN BE READ, ACKNOWLEDGE THE PROCESSOR
	else
		data_ready <= '0';
	end if;
end if;
end process;

end Behavioral;

