--------------------------------------------------------------------------------
--! @file   Synchronizer.vhd
--! @brief  Synchronize async signal
--! @author Takehiro Shiozaki
--! @date   2013-10-28
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity SynchronizerNbit is
    generic(
        G_BITS : integer
    );
    port(
        CLK : in  std_logic;
        RESET : in  std_logic;
        DIN : in std_logic_vector(G_BITS - 1 downto 0);
        DOUT : out std_logic_vector(G_BITS - 1 downto 0)
    );
end SynchronizerNbit;

architecture RTL of SynchronizerNbit is

    component Synchronizer is
    port(
        CLK : in  std_logic;
        RESET : in  std_logic;
        DIN : in std_logic;
        DOUT : out std_logic
    );
    end component;

begin

    Synchronizer1bit: for i in 0 to G_BITS - 1 generate
        Synchronizer_0: Synchronizer
        port map(
            CLK => CLK,
            RESET => RESET,
            DIN => DIN(i),
            DOUT => DOUT(i)
        );
    end generate Synchronizer1bit;

end RTL;

