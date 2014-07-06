--------------------------------------------------------------------------------
--! @file   SynchEdgeDetector.vhd
--! @brief  Synchronize async signal and detect positive edge
--! @author Takehiro Shiozaki
--! @date   2013-11-11
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity SynchEdgeDetector is
    port ( CLK : in  std_logic;
           RESET : in  std_logic;
           DIN : in  std_logic;
           DOUT : out  std_logic);
end SynchEdgeDetector;

architecture RTL of SynchEdgeDetector is

	component Synchronizer
	port(
		CLK : in std_logic;
		RESET : in std_logic;
		DIN : in std_logic;
		DOUT : out std_logic
		);
	end component;

	signal SynchronizedDin : std_logic;
	signal DelayedDin : std_logic;

begin

	Synchronizer_0: Synchronizer port map(
		CLK => CLK,
		RESET => RESET,
		DIN => DIN,
		DOUT => SynchronizedDin
	);

	process(CLK, RESET)
	begin
		if(RESET = '1') then
			DelayedDin <= '0';
		elsif(CLK'event and CLK = '1') then
			DelayedDin <= SynchronizedDin;
		end if;
	end process;

	DOUT <= (not DelayedDin) and SynchronizedDin;

end RTL;

