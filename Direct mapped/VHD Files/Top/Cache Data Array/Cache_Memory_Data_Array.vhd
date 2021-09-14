------------------------------------------------------------------------------------------------------
-- Design Name      : Cache Memory Data Array
-- Description      : synchronous memory to store cache lines
-- Default Specs    : - 256 bytes single-bank cache, inferred using Flip-Flops
--                    - Max. depth of 16 entries, block/cache line size = 16 bytes (four 32-bit words)
--                    - Initially two cycles latency for consecutive read, then data read every cycle
--                    - #R/W PROTOCOL WITH PROCESSOR AS FOLLOWS (READ = 2 CYCLES, WRITE = 1 CYCLES)
--                      1st cycle --> address placed, rd/wr signal asserted by processo
                        2nd cycle --> data available/writtten
                        3rd cycle --> data read by processor--								
--                    - Writes/Reads one word at a time from processor
--                    - Accepts 16 bytes block from Main Memory							
-- Developer		  : Mitu Raj, iammituraj@gmail.com
-- Date     		  : 20-03-2019
-- Tested on 		  : Virtex-4 ML403 Board, ISE 14.7 XST
-- Comments         : 128*16 = 2048 Flip-flops generated for the cache memory
--                    if slow synthesis, reduce memory size by decrementing index
-------------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Cache_Memory_Data_Array is
    Generic ( index_bits  	  : integer := 4;   -- 16 ENTRIES, DEFAULT SPECS
	           offset_bits 	  : integer := 2;   -- TO CHOOSE A WORD FROM A BLOCK SIZE = 4 MEMORY WORDS, DEFAULT SPECS
				  block_size     : integer := 128; -- DEFAULT SPECS, = DATA BUS WIDTH OF THE MEMORY SYSTEM
				  mem_word_size  : integer := 32;  -- WORD SIZE OF MEMORY BANKS, DEFAULT SPECS
				  proc_word_size : integer := 32;  -- WORD SIZE FOR OUR PROCESSOR DATA BUS, DEFAULT SPECS
				  blk_0_offset : integer   := 127; -- CACHE BLOCK ---> |BLOCK 0 | BLOCK 1 | BLOCK 2| BLOCK 3|
				  blk_1_offset : integer   := 95;
				  blk_2_offset : integer   := 63;
				  blk_3_offset : integer   := 31
	         );
    Port ( clock  		 : in STD_LOGIC; -- CACHE CLOCK SAME AS PROCESSOR CLOCK      
			  refill 		 : in STD_LOGIC; -- MISS, REFILL CACHE USING DATA FROM MEMORY
			  update 		 : in STD_LOGIC; -- HIT, UPDATE CACHE USING DATA FROM PROCESSOR
			  index         : in STD_LOGIC_VECTOR (index_bits-1 downto 0);      -- INDEX SELECTION
			  offset 		 : in STD_LOGIC_VECTOR (offset_bits-1 downto 0);     -- OFFSET SELECTION
			  data_from_mem : in STD_LOGIC_VECTOR (block_size-1 downto 0);      -- DATA FROM MEMORY
			  write_data    : in STD_LOGIC_VECTOR (proc_word_size-1 downto 0);  -- DATA FROM PROCESSOR
			  read_data     : out STD_LOGIC_VECTOR(proc_word_size-1 downto 0)); -- DATA TO PROCESSOR			  
end Cache_Memory_Data_Array;

architecture Behavioral of Cache_Memory_Data_Array is

-- USER DEFINED DATA TYPE
-- CONTIGUOUS MEMORY OF WORD-SIZE DATA.
type ram is array (0 to 2**(index_bits+offset_bits)-1) of STD_LOGIC_VECTOR (mem_word_size-1 downto 0);

-- INSTANCE OF CACHE MEMORY
signal cache_memory : ram := (OTHERS => (OTHERS =>'0'));

begin

process(clock)

-- USER VARIABLES
variable v0 : STD_LOGIC_VECTOR (index_bits+offset_bits-1 downto 0);
variable v1 : STD_LOGIC_VECTOR (index_bits+offset_bits-1 downto 0);
variable v2 : STD_LOGIC_VECTOR (index_bits+offset_bits-1 downto 0);
variable v3 : STD_LOGIC_VECTOR (index_bits+offset_bits-1 downto 0);
variable v4 : STD_LOGIC_VECTOR (index_bits+offset_bits-1 downto 0);

begin
if rising_edge(clock) then   
   v0 := index & offset; 
   v1 := index & "00";
	v2 := index & "01";
	v3 := index & "10";
	v4 := index & "11";	
   if update = '1' then    -- HIT, UPDATE CACHE BLOCK USING WORD FROM PROCESSOR	
	   cache_memory(to_integer(unsigned(v0))) <= write_data; 
	elsif refill = '1' then -- MISS, REFILL CACHE BLOCK USING DATA BLOCK FROM MEMORY		   
	   cache_memory(to_integer(unsigned(v1))) <= data_from_mem(blk_0_offset downto blk_1_offset+1);
		cache_memory(to_integer(unsigned(v2))) <= data_from_mem(blk_1_offset downto blk_2_offset+1);
		cache_memory(to_integer(unsigned(v3))) <= data_from_mem(blk_2_offset downto blk_3_offset+1);
		cache_memory(to_integer(unsigned(v4))) <= data_from_mem(blk_3_offset downto 0);
	end if;	
	read_data <= cache_memory(to_integer(unsigned(v0))); -- READ WORD FROM CACHE, ALWAYS AVAILABLE
end if;
end process;

end Behavioral;

