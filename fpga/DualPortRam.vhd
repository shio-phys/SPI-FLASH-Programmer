--------------------------------------------------------------------------------
--! @file   DualPortRam.vhd
--! @brief  Dual port RAM
--! @author Takehiro Shiozaki
--! @date   2013-11-05
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity DualPortRam is
	 generic (
		G_WIDTH : integer;
		G_DEPTH : integer
		);
    port ( -- write
			  WCLK : in  std_logic;
			  DIN : in std_logic_vector(G_WIDTH - 1 downto 0);
			  WADDR : in std_logic_vector(G_DEPTH - 1 downto 0);
			  WE : in std_logic;

			  -- read
			  RCLK : in std_logic;
			  DOUT : out std_logic_vector(G_WIDTH - 1 downto 0);
			  RADDR : in std_logic_vector(G_DEPTH - 1 downto 0)
			  );
end DualPortRam;

architecture RTL of DualPortRam is

	subtype RamWord is std_logic_vector(G_WIDTH - 1 downto 0);
	type RamArray is array (0 to 2 ** G_DEPTH - 1) of RamWord;
	signal RamData : RamArray;

	signal WriteAddress : integer range 0 to 2 ** G_DEPTH - 1;
	signal ReadAddress : integer range 0 to 2 ** G_DEPTH - 1;

begin

	WriteAddress <= conv_integer(WADDR);
	ReadAddress <= conv_integer(RADDR);

	process(WCLK)
	begin
		if(WCLK'event and WCLK = '1') then
			if(WE = '1') then
				RamData(WriteAddress) <= DIN;
			end if;
		end if;
	end process;

	process(RCLK)
	begin
		if(RCLK'event and RCLK = '1') then
			DOUT <= RamData(ReadAddress);
		end if;
	end process;

end RTL;

