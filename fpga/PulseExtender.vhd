--------------------------------------------------------------------------------
--! @file   PulseExtender.vhd
--! @brief  Expand width of pulse
--! @author Takehiro Shiozaki
--! @date   2013-10-28
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity PulseExtender is
    generic(
        G_WIDTH : integer
    );
    port(
        CLK : in  std_logic;
        RESET : in  std_logic;
        DIN : in  std_logic;
        DOUT : out  std_logic
    );
end PulseExtender;

architecture RTL of PulseExtender is

    signal Dff : std_logic_vector(G_WIDTH - 1 downto 0);
    constant C_ALL_ZERO : std_logic_vector(G_WIDTH - 1 downto 0) := (others => '0');

begin

    process(CLK, RESET)
    begin
        if(RESET = '1') then
            Dff <= (others => '0');
        elsif(CLK'event and CLK = '1') then
            Dff <= Dff(Dff'high - 1 downto 0) & DIN;
        end if;
    end process;

    process(CLK, RESET)
    begin
        if(RESET = '1') then
            DOUT <= '0';
        elsif(CLK'event and CLK = '1') then
            if(Dff /= C_ALL_ZERO) then
                DOUT <= '1';
            else
                DOUT <= '0';
            end if;
        end if;
    end process;
end RTL;

