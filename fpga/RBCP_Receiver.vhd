--------------------------------------------------------------------------------
--! @file   RBCP_Receiver.vhd
--! @brief  convert RBCP signal to SRAM write signal
--! @author Takehiro Shiozaki
--! @date   2013-11-01
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity RBCP_Receiver is
	 generic ( G_ADDR : std_logic_vector(31 downto 0);
	           G_LEN : integer;
				  G_ADDR_WIDTH : integer
				);
    port ( CLK : in std_logic;
	        RESET : in std_logic;

		     -- RBCP interface
			  RBCP_ACT : in std_logic;
			  RBCP_ADDR : in std_logic_vector(31 downto 0);
			  RBCP_WE : in std_logic;
			  RBCP_WD : in std_logic_vector(7 downto 0);
			  RBCP_ACK : out std_logic;

			  -- output
			  ADDR : out std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
			  WE : out std_logic;
			  WD : out std_logic_vector(7 downto 0)
			  );
end RBCP_Receiver;

architecture RTL of RBCP_Receiver is

	signal int_WE : std_logic;

	signal DelayedWe : std_logic_vector(1 downto 0);

begin

	WD <= RBCP_WD;

	int_WE <= '1' when(RBCP_ACT = '1' and RBCP_WE = '1' and
	                   G_ADDR <= RBCP_ADDR and RBCP_ADDR <= G_ADDR + G_LEN - 1) else
	          '0';
	WE <= int_WE;

	process(CLK, RESET)
	begin
		if(RESET = '1') then
			DelayedWe <= (others => '0');
		elsif(CLK'event and CLK = '1') then
			DelayedWe(0) <= int_WE;
			DelayedWe(1) <= DelayedWe(0);
		end if;
	end process;

	RBCP_ACK <= DelayedWe(1);

	ADDR <= conv_std_logic_vector(conv_integer(RBCP_ADDR - G_ADDR), G_ADDR_WIDTH);
end RTL;

