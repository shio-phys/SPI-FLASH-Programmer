--------------------------------------------------------------------------------
--! @file   Synchronizer.vhd
--! @brief  Synchronize async signal
--! @author Takehiro Shiozaki
--! @date   2013-10-28
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity Synchronizer is
    port(
        CLK : in  std_logic;
        RESET : in  std_logic;
        DIN : in std_logic;
        DOUT : out std_logic
    );
end Synchronizer;

architecture RTL of Synchronizer is
    signal temp : std_logic;

    attribute dont_touch : string;
    attribute dont_touch of DoubleFFSynchronizerFF1 : label is "true";
    attribute dont_touch of DoubleFFSynchronizerFF2 : label is "true";
begin

    DoubleFFSynchronizerFF1 : FDC
    generic map(
        INIT => '0'
    )
    port map(
        Q => temp,
        C => CLK,
        CLR => RESET,
        D => DIN
    );

    DoubleFFSynchronizerFF2 : FDC
    generic map(
        INIT => '0'
    )
    port map(
        Q => DOUT,
        C => CLK,
        CLR => RESET,
        D => temp
    );

end RTL;

