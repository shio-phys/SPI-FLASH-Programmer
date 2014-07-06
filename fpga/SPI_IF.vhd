--------------------------------------------------------------------------------
--! @file   SPI_IF.vhd
--! @brief  SPI interface to SPI Flash ROM
--! @author Takehiro Shiozaki
--! @date   2014-06-24
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity SPI_IF is
    port(
        CLK : in std_logic;
        RESET : in std_logic;

        DIN : in std_logic_vector(7 downto 0);
        DOUT : out std_logic_vector(7 downto 0);
        START : in std_logic;
        BUSY : out std_logic;

        SPI_SCLK : out std_logic;
        SPI_MISO : in std_logic;
        SPI_MOSI : out std_logic
    );
end SPI_IF;

architecture RTL of SPI_IF is
    signal DinReg : std_logic_vector(7 downto 0);

    signal BitSel : std_logic_vector(2 downto 0);
    signal BitSelCountDown : std_logic;
    signal BitSelCountClear : std_logic;

    signal ShiftReg : std_logic_vector(7 downto 0);
    signal ShiftRegEnable : std_logic;

    signal SpiSclkPre : std_logic;
    signal SpiMosiPre : std_logic;

    type State is (IDLE, PREPARE, SCLK_LOW, SCLK_HIGH, PAUSE);
    signal CurrentState, NextState : State;
begin
    process(CLK)
    begin
        if(CLK'event and CLK = '1') then
            if(START = '1') then
                DinReg <= DIN;
            end if;
        end if;
    end process;

    SpiMosiPre <= DinReg(conv_integer(BitSel));

    process(CLK)
    begin
        if(CLK'event and CLK = '1') then
            if(ShiftRegEnable = '1') then
                ShiftReg <= ShiftReg(6 downto 0) & SPI_MISO;
            end if;
        end if;
    end process;

    DOUT <= ShiftReg;

    process(CLK)
    begin
        if(CLK'event and CLK = '1') then
            if(BitSelCountClear = '1') then
                BitSel <= (others => '1');
            elsif(BitSelCountDown = '1') then
                BitSel <= BitSel - 1;
            end if;
        end if;
    end process;

    process(CLK)
    begin
        if(CLK'event and CLK = '1') then
            if(RESET = '1') then
                CurrentState <= IDLE;
            else
                CurrentState <= NextState;
            end if;
        end if;
    end process;

    process(CurrentState, START, BitSel)
    begin
        case CurrentState is
            when IDLE =>
                if(START = '1') then
                    NextState <= PREPARE;
                else
                    NextState <= CurrentState;
                end if;
            when PREPARE =>
                NextState <= SCLK_LOW;
            when SCLK_LOW =>
                NextState <= SCLK_HIGH;
            when SCLK_HIGH =>
                if(BitSel = 0) then
                    NextState <= PAUSE;
                else
                    NextState <= SCLK_LOW;
                end if;
            when PAUSE =>
                NextState <= IDLE;
        end case;
    end process;

    SpiSclkPre <= '1' when(CurrentState = SCLK_HIGH) else
                  '0';
    ShiftRegEnable <= '1' when(CurrentState = SCLK_HIGH) else
                      '0';
    BitSelCountDown <= '1' when(CurrentState = SCLK_HIGH) else
                       '0';
    BitSelCountClear <= '1' when(CurrentState = IDLE) else
                        '0';
    BUSY <= '1' when(CurrentState /= IDLE) else
            '0';

    process(CLK)
    begin
        if(CLK'event and CLK = '1') then
            SPI_SCLK <= SpiSclkPre;
        end if;
    end process;

    process(CLK)
    begin
        if(CLK'event and CLK = '1') then
            SPI_MOSI <= SpiMosiPre;
        end if;
    end process;

end RTL;
