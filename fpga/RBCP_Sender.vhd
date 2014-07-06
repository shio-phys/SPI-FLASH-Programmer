--------------------------------------------------------------------------------
--! @file   RBCP_Sender.vhd
--! @brief  convert RBCP signal to SRAM read signal
--! @author Takehiro Shiozaki
--! @date   2013-11-05
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity RBCP_Sender is
	generic ( G_ADDR : std_logic_vector(31 downto 0);
	           G_LEN : integer;
				  G_ADDR_WIDTH : integer
				);
    port ( CLK : in  std_logic;
           RESET : in  std_logic;

			  -- RBCP interface
			  RBCP_ACT : in std_logic;
			  RBCP_ADDR : in std_logic_vector(31 downto 0);
			  RBCP_RE : in std_logic;
			  RBCP_RD : out std_logic_vector(7 downto 0);
			  RBCP_ACK : out std_logic;

			  -- SRAM interface
			  ADDR : out std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
			  RD : in std_logic_vector(7 downto 0)
			  );
end RBCP_Sender;

architecture RTL of RBCP_Sender is

	signal ReadEnable : std_logic;
	signal DelayedReadEnable : std_logic_vector(1 downto 0);
	signal DelayedRd : std_logic_vector(7 downto 0);
	signal DelayedAddr : std_logic_vector(G_ADDR_WIDTH - 1 downto 0);

begin

	ReadEnable <= '1' when(RBCP_ACT = '1' and RBCP_RE = '1' and
							 G_ADDR <= RBCP_ADDR and RBCP_ADDR <= G_ADDR + G_LEN - 1) else
				 '0';

	process(CLK, RESET)
	begin
		if(RESET = '1') then
			DelayedReadEnable <= (others => '0');
		elsif(CLK'event and CLK = '1') then
			DelayedReadEnable(0) <= ReadEnable;
			DelayedReadEnable(1) <= DelayedReadEnable(0);
		end if;
	end process;

	process(CLK, RESET)
	begin
		if(RESET = '1') then
			DelayedRd <= (others => '0');
		elsif(CLK'event and CLK = '1') then
			DelayedRd <= RD;
		end if;
	end process;
	RBCP_RD <= DelayedRd;

	process(CLK, RESET)
	begin
		if(RESET = '1') then
			RBCP_ACK <= '0';
		elsif(CLK'event and CLK = '1') then
			RBCP_ACK <= DelayedReadEnable(1);
		end if;
	end process;

	process(CLK, RESET)
	begin
		if(RESET = '1') then
			DelayedAddr <= (others => '0');
		elsif(CLK'event and CLK = '1') then
			DelayedAddr <= conv_std_logic_vector(conv_integer(RBCP_ADDR - G_ADDR), G_ADDR_WIDTH);
		end if;
	end process;

	ADDR <= DelayedAddr;

end RTL;

