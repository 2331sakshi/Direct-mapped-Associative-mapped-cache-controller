-----------------------------------------------------------------------------------------------------
-- Design Name      : Cache Controller
-- Description      : A Direct Mapped Cache Controller
-- Default Specs    : - Single-banked Write-Through Cache Controller
--                    - Addresses 16 entries/cache lines, 256 bytes Direct Mapped Cache
--                    - No-write allocate(Write-Around) Policy
--                    - No Write Buffer, or other optimisations
--		      - Tag Array incorporated
--                    - Assuming address placed on the 0th cycle,
--                      READ HIT   --> Net Access Time = 2 cycles
--                      WRITE HIT  --> Net Access Time = 4 cycles cz of Write-Through Scheme
--							   READ MISS  --> 4 stall cycles Penalty, Net Access Time = 6 cycles
--                      WRITE MISS --> Net Access Time = 4 cycles
-- Developer		  : Mitu Raj, iammituraj@gmail.com
-- Date     		  : 26-03-2019
-- Tested on 		  : Virtex-4 ML403 Board, ISE 14.7 XST
-- Performance      : 195 MHz max. Freq for Balanced Optimisation Synthesis Strategy
-- Comments         : Tag memory array is implemented in Flip-Flops
------------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Cache_Controller is
	 Generic ( index_bits  	  : integer := 4;   -- 16 ENTRIES, DEFAULT SPECS FROM DATA ARRAY
			     tag_bits       : integer := 4    -- DERIVED FROM DEFAULT SPECS OF ADDRESS BUS WIDTH
				);
	 Port ( clock			 : in STD_LOGIC;   -- MAIN CLOCK
			  reset			 : in STD_LOGIC;   -- ASYNC RESET
			  flush			 : in STD_LOGIC;   -- TO FLUSH THE CACHE DATA ARRAY, INVALIDATE ALL LINES
			  rd   			 : in STD_LOGIC;   -- READ REQUEST FROM PROCESSOR
			  wr   			 : in STD_LOGIC;   -- WRITE REQUEST FROM PROCESSOR
			  index			 : in STD_LOGIC_VECTOR (index_bits-1 downto 0); -- INDEX OF THE ADDRESS REQUESTED
			  tag  			 : in STD_LOGIC_VECTOR (tag_bits-1 downto 0);   -- TAG OF THE ADDRESS REQUESTED
			  ready			 : in STD_LOGIC;   -- DATA READY SIGNAL FROM MEMORY
			  refill			 : out STD_LOGIC;  -- REFILL SIGNAL TO DATA ARRAY
			  update			 : out STD_LOGIC;  -- UPDATE SIGNAL TO DATA ARRAY
			  read_from_mem : out STD_LOGIC;  -- READ SIGNAL TO DATA MEMORY
			  write_to_mem  : out STD_LOGIC;  -- WRITE SIGNAL TO DATA MEMORY
			  stall 			 : out STD_LOGIC); -- SIGNAL TO STALL THE PROCESSOR		  
end Cache_Controller;

architecture Behavioral of Cache_Controller is

-- ALL INTERNAL SIGNALS
signal STATE : STD_LOGIC_VECTOR (7 downto 0) := (OTHERS => '0'); -- STATE SIGNAL
signal HIT   : STD_LOGIC := '0'; -- SIGNAL TO INDICATE HIT
signal MISS  : STD_LOGIC := '0'; -- SIGNAL TO INDICATE MISS

-- USER DEFINED TYPE
type ram is array (0 to 2**index_bits-1) of STD_LOGIC_VECTOR (tag_bits downto 0);

-- INSTANCE OF RAM AS TAG ARRAY
signal tag_array : ram := (OTHERS => (OTHERS =>'0'));

begin

process(clock, reset)

-- USER VARIABLES
variable temp_tag   : STD_LOGIC_VECTOR (tag_bits downto 0);
variable temp_index : integer;

begin
if reset = '0' then
   -- RESETTING INTERNAL SIGNALS
	STATE <= (OTHERS => '0'); 
	HIT   <= '0';
	MISS  <= '0';
	tag_array <= (OTHERS => (OTHERS =>'0'));
	-- RESETTING OUT PORT SIGNALS
	stall <= '0';
	read_from_mem <= '0';
	write_to_mem  <= '0';
	refill <= '0';
	update <= '0';
elsif rising_edge(clock) then
   if flush = '1' then -- HIGH PRIORITY SIGNAL TO FLUSH ENTIRE CACHE
	   tag_array <= (OTHERS => (OTHERS => '0')); -- INVALIDATE ALL CACHE LINES
	else
		Case STATE is
			when x"00"  => -- INIT STATE, WHERE ALL REQUESTS START PROCESSING
								-- READ DATA IS ALWAYS AVAILABLE IN THIS STATE REGARDLESS OF HIT/MISS
                      temp_tag   := '1' & tag;
							 temp_index := to_integer(unsigned(index));
							 if ((temp_tag XOR tag_array(temp_index)) = "00000") then -- CHECKING IF VALID BIT = '1' AND TAGS ARE MATCHING
							    if wr = '1' then        -- IF WRITE REQUEST + HIT, UPDATE CACHE, INITIATE MEMORY WRITE									 
									 HIT   <= '1';        -- HIT OCCURED
									 MISS  <= '0';
									 stall <= '1';		    -- STALL CZ MAIN MEMORY ACCESS
									 update <= '1';       -- UPDATES CACHE
								    refill <= '0';
							       write_to_mem <= '1'; -- INITIATE WRITE TO MEMORY
								    read_from_mem <= '0';
									 STATE <= x"01";      -- GO TO WRITE HIT STATE
								 elsif rd = '1' then -- IF READ REQUEST + HIT, DO NOTHING
									 HIT  <= '1';
									 MISS <= '0';
								    STATE <= x"00";  
                         else -- IF NO REQUEST, DO NOTHING
									 HIT  <= '0';     
									 MISS <= '0';
									 STATE <= x"00";
								 end if;
							 elsif wr = '1' then -- IF WRITE REQUEST + MISS, DIRECT MEMORY WRITE (WRITE-AROUND)
								 HIT   <= '0';    
								 MISS  <= '1';    	  -- MISS OCCURED
								 stall <= '1';			  -- STALL CZ MAIN MEMORY ACCESS
								 update <= '0';  		  -- NO UPDATE ON CACHE
								 refill <= '0';
							    write_to_mem <= '1';  -- INITIATE WRITE TO MEMORY
								 read_from_mem <= '0';
								 STATE <= x"01";       -- GO TO WRITE MISS STATE
							 elsif rd = '1' then -- IF READ REQUEST + MISS, INITIATE REFILL CACHE
								 HIT    <= '0';    
								 MISS   <= '1';        -- MISS OCCURED
								 stall  <= '1';		  -- STALL CZ MAIN MEMORY ACCESS
								 update <= '0';   
								 refill <= '0';   
							    write_to_mem <= '0';
								 read_from_mem <= '1'; -- INITIATE READ FROM MEMORY
								 STATE <= x"02";       -- GO TO READ MISS STATE
							 else -- IF NO REQUEST, DO NOTHING
								 HIT  <= '0';     
								 MISS <= '0';
								 STATE <= x"00";
							 end if;	
         when x"01"  => -- WRITE HIT/MISS STATE, WAIT HERE UNTIL DATA IS WRITTEN TO MEMORY
							 update <= '0';          -- STOP UPDATING CACHE
							 refill <= '0';
							 if ready = '1' then     -- IF READY, ACKNOWLEDGE THE MEMORY
							    stall <= '0';        -- SIGNAL PROCESSOR THAT NEW REQUEST CAN BE INITIATED
								 write_to_mem  <= '0';-- ACKNOWLEDGING THE MEMORY
								 read_from_mem <= '0';
								 STATE <= x"07";      -- GO TO GLOBAL WAIT STATE
							 else
								 STATE <= x"01";      -- WAIT HERE 
							 end if;		
			when x"02"	=> -- READ MISS STATE, WAIT HERE UNTIL DATA FROM MEMORY IS READY
							 if ready = '1' then
								 read_from_mem <= '0';-- ACKNOWLEDGING MEMORY
								 write_to_mem  <= '0';
								 refill <= '1';       -- INITIATE REFILLING CACHE DATA ARRAY
								 update <= '0';
								 STATE <= x"03";      -- GO TO REFILL DE-ASSERT STATE
							 else
								 STATE <= x"02";      -- WAIT HERE
							 end if;
			when x"03"  => -- REFILL DE-ASSERT STATE
							 refill <= '0';
                      update <= '0';							 
							 temp_index := to_integer(unsigned(index)); -- UPDATING CORRESPONDING TAG
							 tag_array(temp_index) <= '1' & tag; 
							 STATE  <= x"04";			 -- GO TO STALL DE-ASSERT STATE
			when x"04"	=> -- STALL DE-ASSERT STATE
							 stall <= '0';
							 STATE <= x"07";			 -- GO TO GLOBAL WAIT STATE
			when x"07"  => -- GLOBAL WAIT STATE, AFTER FURNISHING EVERY REQUEST, PROCESSOR MAY GENERATE NEW REQUEST IN MEAN TIME
							 ---- MAKE SURE ALL SIGNALS ARE AT THEIR INIT DEFAULT VALUES
							 HIT    <= '0';
							 MISS   <= '0';
							 stall  <= '0';
							 refill <= '0';
							 update <= '0';
							 read_from_mem <= '0';
							 write_to_mem  <= '0';
							 if wr = '0' and rd = '0' then -- IF PROCESSOR FINISHED CURRENT REQUEST 
							    STATE <= x"00";            -- GO TO INIT STATE
							 else
							    STATE <= x"07";
							 end if;
			when OTHERS =>
							 STATE <= x"00";
		end Case;
	end if;
end if; -- RISING EDGE
end process;

end Behavioral;

